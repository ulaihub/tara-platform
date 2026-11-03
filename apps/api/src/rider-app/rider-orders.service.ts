import { Inject, Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { verifyCode } from '../common/crypto.js';
import { AppError } from '../common/errors/app-error.js';
import { pageOf } from '../common/pagination.js';
import { CAMEROON_TIME_ZONE } from '../common/time.js';
import { ACTIVE_RIDER_STATUSES } from '../dispatch/dispatch.service.js';
import { OrderFinanceService } from '../finance/order-finance.service.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import type { Order, Prisma, RiderProfile } from '../generated/prisma/client.js';
import type { OrderStatus, ProofKind } from '../generated/prisma/enums.js';
import { AddressesService } from '../geo/addresses.service.js';
import { checkTransition } from '../orders/order-state-machine.js';
import {
  OrderTransitionsService,
  type TransitionOptions,
} from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { MediaService } from '../storage/media.service.js';
import type {
  DeliverBody,
  EarningsDto,
  FailBody,
  PickupBody,
  PositionActionBody,
  ReturnBody,
  RiderOrderDto,
  RiderOrdersQuery,
} from './rider-app.schemas.js';

/** Codes à 4 chiffres : au-delà de ce nombre d'erreurs, le code est bloqué (E3, E4). */
export const MAX_CODE_FAILURES = 5;
/** Une action hors ligne plus ancienne n'est plus acceptée (E7). */
const MAX_OFFLINE_AGE_MS = 72 * 3_600_000;
const MAX_CLOCK_SKEW_MS = 120_000;

const ORDER_INCLUDE = {
  pickupAddress: { include: { neighborhood: true } },
  dropoffAddress: { include: { neighborhood: true } },
  sender: { select: { fullName: true, phone: true, merchant: { select: { shopName: true } } } },
  merchant: { select: { shopName: true } },
} as const satisfies Prisma.OrderInclude;

type RiderOrder = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

type ActionContext = z.output<typeof PositionActionBody>;

/**
 * Actions du livreur sur ses courses (E2 à E9), côté serveur. Chaque action est rejouable
 * sans effet de bord grâce à son identifiant (`clientEventId`) : l'app hors ligne peut
 * renvoyer sa file d'actions autant de fois que nécessaire.
 */
@Injectable()
export class RiderOrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly transitions: OrderTransitionsService,
    private readonly bus: OrderEventsBus,
    private readonly addresses: AddressesService,
    private readonly media: MediaService,
    private readonly realtime: RealtimeService,
    private readonly finance: OrderFinanceService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // --- Lecture ------------------------------------------------------------------------------

  private async riderOf(userId: string): Promise<RiderProfile> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    return rider;
  }

  private async load(
    userId: string,
    orderId: string,
  ): Promise<{ rider: RiderProfile; order: RiderOrder }> {
    const rider = await this.riderOf(userId);
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: ORDER_INCLUDE,
    });
    // Une course d'un autre livreur est introuvable, pas interdite : rien n'est révélé.
    if (order?.riderId !== rider.id) throw AppError.notFound('ORDER_NOT_FOUND');
    return { rider, order };
  }

  async list(
    userId: string,
    query: z.output<typeof RiderOrdersQuery>,
  ): Promise<{ items: z.output<typeof RiderOrderDto>[]; nextCursor: string | null }> {
    const rider = await this.riderOf(userId);
    const active = query.scope === 'active';
    const rows = await this.prisma.order.findMany({
      where: {
        riderId: rider.id,
        status: active
          ? { in: [...ACTIVE_RIDER_STATUSES] }
          : { in: ['DELIVERED', 'RETURNED', 'CANCELLED'] },
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      include: ORDER_INCLUDE,
      orderBy: { id: 'desc' },
      take: query.limit + 1,
    });
    const page = pageOf(rows, query.limit);
    return { items: await this.toDtos(page.items), nextCursor: page.nextCursor };
  }

  async get(userId: string, orderId: string): Promise<z.output<typeof RiderOrderDto>> {
    const { order } = await this.load(userId, orderId);
    const [dto] = await this.toDtos([order]);
    return dto as z.output<typeof RiderOrderDto>;
  }

  private async toDtos(orders: RiderOrder[]): Promise<z.output<typeof RiderOrderDto>[]> {
    const unique = new Map(
      orders.flatMap((o) => [o.pickupAddress, o.dropoffAddress]).map((a) => [a.id, a] as const),
    );
    const addresses = new Map(
      (await this.addresses.toDtos([...unique.values()])).map((dto) => [dto.id, dto]),
    );
    const awaiting = await this.awaitingValidation(orders.map((order) => order.id));
    return orders.map((order) => {
      const pickup = addresses.get(order.pickupAddressId);
      const dropoff = addresses.get(order.dropoffAddressId);
      if (!pickup || !dropoff) throw new Error(`Adresses manquantes pour ${order.reference}`);
      const inProgress = (ACTIVE_RIDER_STATUSES as readonly OrderStatus[]).includes(order.status);
      const target = navigationTarget(order);
      return {
        id: order.id,
        reference: order.reference,
        status: order.status,
        packageSize: order.packageSize,
        isFragile: order.isFragile,
        isExpress: order.isExpress,
        instructions: order.instructions,
        pickup,
        dropoff,
        // Contacts visibles seulement pendant la course (données personnelles).
        sender: {
          name:
            order.merchant?.shopName ?? order.sender.merchant?.shopName ?? order.sender.fullName,
          phone: inProgress ? (order.pickupAddress.contactPhone ?? order.sender.phone) : null,
        },
        recipient: {
          name: inProgress ? order.recipientName : null,
          phone: inProgress ? order.recipientPhone : null,
        },
        riderEarning: order.riderEarning,
        collectAtPickup:
          order.feePayer === 'SENDER' && order.feePaymentMethod === 'CASH' ? order.totalPrice : 0,
        collectAtDelivery:
          order.codAmount + (order.feePayer === 'RECIPIENT' ? order.totalPrice : 0),
        navigation:
          inProgress && target
            ? {
                googleMaps: `https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving`,
                waze: `https://waze.com/ul?ll=${target.latitude},${target.longitude}&navigate=yes`,
              }
            : null,
        failureDecision: order.failureDecision,
        awaitingSupportValidation: awaiting.has(order.id),
        assignedAt: order.assignedAt?.toISOString() ?? null,
        pickedUpAt: order.pickedUpAt?.toISOString() ?? null,
        deliveredAt: order.deliveredAt?.toISOString() ?? null,
      };
    });
  }

  /** Commandes en livraison avec une livraison sans code déclarée, non encore validée (E4). */
  async awaitingValidation(orderIds: string[]): Promise<Set<string>> {
    if (orderIds.length === 0) return new Set();
    const rows = await this.prisma.$queryRaw<{ order_id: string }[]>`
      SELECT p.order_id
      FROM delivery_proofs p
      JOIN orders o ON o.id = p.order_id AND o.status = 'IN_DELIVERY'
      WHERE p.order_id = ANY(${orderIds}::uuid[])
        AND p.kind = 'DELIVERY' AND p.code_verified = false AND p.support_validator_id IS NULL
        AND p.recorded_at >= (
          SELECT max(e.recorded_at) FROM order_events e
          WHERE e.order_id = p.order_id AND e.to_status = 'IN_DELIVERY'
        )`;
    return new Set(rows.map((row) => row.order_id));
  }

  // --- Actions ------------------------------------------------------------------------------

  /** Enlèvement (E3) : code donné par l'expéditeur et photo du colis. */
  async pickup(
    userId: string,
    orderId: string,
    body: z.output<typeof PickupBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order } = await this.load(userId, orderId);
    assertTransition(order, 'PICKED_UP');
    await this.media.assertOwned(userId, body.photoKey, ['PROOF_PHOTO']);
    await this.checkCode(order, 'pickup', body.pickupCode);
    await this.act(userId, order, 'PICKED_UP', body, {
      kind: 'PICKUP',
      photoKey: body.photoKey,
      codeVerified: true,
    });
    return this.get(userId, orderId);
  }

  /** Départ vers le destinataire. */
  async depart(
    userId: string,
    orderId: string,
    body: z.output<typeof PositionActionBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order } = await this.load(userId, orderId);
    await this.act(userId, order, 'IN_DELIVERY', body);
    return this.get(userId, orderId);
  }

  /**
   * Livraison (E4) : avec le code du destinataire, la commande est livrée. Sans code
   * (destinataire qui l'a perdu, code bloqué), la preuve est enregistrée et le support
   * valide après avoir appelé le destinataire.
   */
  async deliver(
    userId: string,
    orderId: string,
    body: z.output<typeof DeliverBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { rider, order } = await this.load(userId, orderId);
    await this.media.assertOwned(userId, body.photoKey, ['PROOF_PHOTO']);
    // L'argent d'abord (E5) : le colis n'est remis qu'une fois tout encaissé.
    const collection = await this.finance.collectionState(order);
    if (!collection.complete) {
      throw AppError.conflict('COLLECTION_REQUIRED', { amount: collection.due.total });
    }
    if (body.deliveryCode === undefined) {
      if (order.status !== 'IN_DELIVERY') {
        throw AppError.conflict('ORDER_TRANSITION_INVALID', {
          from: order.status,
          to: 'DELIVERED',
        });
      }
      const proof = await this.prisma.deliveryProof.create({
        data: {
          orderId,
          kind: 'DELIVERY',
          photoKey: body.photoKey,
          codeVerified: false,
          latitude: body.latitude,
          longitude: body.longitude,
          occurredAt: this.occurredAt(body),
          clientEventId: body.clientEventId ?? null,
        },
      });
      this.realtime.toOps('ops.delivery-validation', {
        orderId,
        reference: order.reference,
        riderId: rider.id,
        proofId: proof.id,
        collectAtDelivery:
          order.codAmount + (order.feePayer === 'RECIPIENT' ? order.totalPrice : 0),
        at: proof.occurredAt.toISOString(),
      });
      return this.get(userId, orderId);
    }
    assertTransition(order, 'DELIVERED');
    await this.checkCode(order, 'delivery', body.deliveryCode);
    await this.act(userId, order, 'DELIVERED', body, {
      kind: 'DELIVERY',
      photoKey: body.photoKey,
      codeVerified: true,
    });
    return this.get(userId, orderId);
  }

  /** Échec de livraison (E6) : motif, photo du lieu et preuve d'appel obligatoires. */
  async fail(
    userId: string,
    orderId: string,
    body: z.output<typeof FailBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order } = await this.load(userId, orderId);
    await this.media.assertOwned(userId, body.photoKey, ['PROOF_PHOTO']);
    await this.act(
      userId,
      order,
      'DELIVERY_FAILED',
      body,
      {
        kind: 'FAILED_ATTEMPT',
        photoKey: body.photoKey,
        codeVerified: false,
        callLog: body.callLog,
      },
      { failureReason: body.reason, note: body.note },
    );
    return this.get(userId, orderId);
  }

  /** Nouvelle tentative après un échec. */
  async retry(
    userId: string,
    orderId: string,
    body: z.output<typeof PositionActionBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order } = await this.load(userId, orderId);
    await this.act(userId, order, 'IN_DELIVERY', body);
    return this.get(userId, orderId);
  }

  /** Retour du colis à l'expéditeur, validé par son code (celui de l'enlèvement). */
  async returnToSender(
    userId: string,
    orderId: string,
    body: z.output<typeof ReturnBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order } = await this.load(userId, orderId);
    assertTransition(order, 'RETURNED');
    if (body.photoKey) await this.media.assertOwned(userId, body.photoKey, ['PROOF_PHOTO']);
    await this.checkCode(order, 'pickup', body.senderCode);
    await this.act(userId, order, 'RETURNED', body, {
      kind: 'RETURN',
      photoKey: body.photoKey ?? null,
      codeVerified: true,
    });
    return this.get(userId, orderId);
  }

  /** Le livreur rend une course pas encore enlevée : elle repart en recherche sans lui. */
  async release(userId: string, orderId: string, reason: string): Promise<void> {
    await this.load(userId, orderId);
    await this.transitions.apply(
      orderId,
      'SEARCHING_RIDER',
      { id: userId, role: 'RIDER' },
      { note: reason },
    );
  }

  // --- Gains (E9) ---------------------------------------------------------------------------

  async earnings(
    userId: string,
    period: 'day' | 'week' | 'month',
    now = new Date(),
  ): Promise<z.output<typeof EarningsDto>> {
    const rider = await this.riderOf(userId);
    const from = periodStart(period, now);
    const [delivered, failed, returned, cash] = await Promise.all([
      this.prisma.order.aggregate({
        where: { riderId: rider.id, status: 'DELIVERED', deliveredAt: { gte: from, lte: now } },
        _count: true,
        _sum: { riderEarning: true },
      }),
      this.prisma.orderEvent.count({
        where: {
          actorId: userId,
          toStatus: 'DELIVERY_FAILED',
          occurredAt: { gte: from, lte: now },
        },
      }),
      this.prisma.orderEvent.count({
        where: { actorId: userId, toStatus: 'RETURNED', occurredAt: { gte: from, lte: now } },
      }),
      this.prisma.codCollection.aggregate({
        where: { riderId: rider.id, method: 'CASH', collectedAt: { gte: from, lte: now } },
        _sum: { collectedAmount: true },
      }),
    ]);
    return {
      period,
      from: from.toISOString(),
      to: now.toISOString(),
      delivered: delivered._count,
      failed,
      returned,
      earnings: delivered._sum.riderEarning ?? 0,
      cashCollected: cash._sum.collectedAmount ?? 0,
    };
  }

  // --- Outils -------------------------------------------------------------------------------

  /** L'action a déjà été enregistrée (synchronisation rejouée après une coupure, E7). */
  private async replayed(orderId: string, clientEventId: string | undefined): Promise<boolean> {
    if (!clientEventId) return false;
    const [event, proof] = await Promise.all([
      this.prisma.orderEvent.findUnique({ where: { clientEventId } }),
      this.prisma.deliveryProof.findUnique({ where: { clientEventId } }),
    ]);
    const known = event ?? proof;
    if (!known) return false;
    if (known.orderId !== orderId) throw AppError.conflict('IDEMPOTENCY_CONFLICT');
    return true;
  }

  private occurredAt(body: ActionContext): Date {
    if (!body.occurredAt) return new Date();
    const at = new Date(body.occurredAt);
    const now = Date.now();
    if (at.getTime() > now + MAX_CLOCK_SKEW_MS || at.getTime() < now - MAX_OFFLINE_AGE_MS) {
      throw AppError.badRequest('ACTION_TIME_INVALID');
    }
    return at;
  }

  /**
   * Vérifie un code à 4 chiffres. Chaque erreur est comptée (hors transaction, pour ne pas
   * être annulée avec l'action) : après MAX_CODE_FAILURES, le code est bloqué.
   */
  private async checkCode(order: Order, kind: 'pickup' | 'delivery', code: string): Promise<void> {
    const failures = kind === 'pickup' ? order.pickupCodeFailures : order.deliveryCodeFailures;
    const locked = kind === 'pickup' ? 'PICKUP_CODE_LOCKED' : 'DELIVERY_CODE_LOCKED';
    if (failures >= MAX_CODE_FAILURES) throw AppError.unprocessable(locked);
    const hash = kind === 'pickup' ? order.pickupCodeHash : order.deliveryCodeHash;
    if (hash && verifyCode(this.env.CODE_HASH_SECRET, `${kind}:${order.reference}`, code, hash)) {
      return;
    }
    const updated = await this.prisma.order.update({
      where: { id: order.id },
      data:
        kind === 'pickup'
          ? { pickupCodeFailures: { increment: 1 } }
          : { deliveryCodeFailures: { increment: 1 } },
    });
    const count = kind === 'pickup' ? updated.pickupCodeFailures : updated.deliveryCodeFailures;
    const remaining = MAX_CODE_FAILURES - count;
    if (remaining <= 0) throw AppError.unprocessable(locked);
    throw AppError.unprocessable(
      kind === 'pickup' ? 'PICKUP_CODE_INVALID' : 'DELIVERY_CODE_INVALID',
      {
        remaining,
      },
    );
  }

  /** Preuve éventuelle et changement de statut dans une même transaction, puis diffusion. */
  private async act(
    userId: string,
    order: Order,
    to: OrderStatus,
    context: ActionContext,
    proof?: {
      kind: ProofKind;
      photoKey: string | null;
      codeVerified: boolean;
      callLog?: unknown;
    },
    extra: Pick<TransitionOptions, 'failureReason' | 'note'> = {},
  ): Promise<void> {
    const occurredAt = this.occurredAt(context);
    const change: OrderChange = await this.prisma.$transaction(async (tx) => {
      if (proof) {
        await tx.deliveryProof.create({
          data: {
            orderId: order.id,
            kind: proof.kind,
            photoKey: proof.photoKey,
            codeVerified: proof.codeVerified,
            ...(proof.callLog ? { callLog: proof.callLog as Prisma.InputJsonValue } : {}),
            latitude: context.latitude,
            longitude: context.longitude,
            occurredAt,
            // L'identifiant de l'action reste sur l'événement de statut (rejeu, E7).
            clientEventId: null,
          },
        });
      }
      const result = await this.transitions.applyIn(
        tx,
        order,
        to,
        { id: userId, role: 'RIDER' },
        {
          ...extra,
          latitude: context.latitude,
          longitude: context.longitude,
          occurredAt,
          clientEventId: context.clientEventId,
        },
      );
      return result.change;
    });
    await this.bus.publish(change);
  }
}

/** Refuse tôt une action impossible : un code n'est vérifié (et compté) qu'à bon escient. */
function assertTransition(order: Order, to: OrderStatus): void {
  if (!checkTransition({ from: order.status, to, actor: 'RIDER' }).ok) {
    throw AppError.conflict('ORDER_TRANSITION_INVALID', { from: order.status, to });
  }
}

/** Prochaine étape de la course, pour l'itinéraire. */
function navigationTarget(order: RiderOrder): { latitude: number; longitude: number } | null {
  switch (order.status) {
    case 'ASSIGNED':
      return order.pickupAddress;
    case 'PICKED_UP':
    case 'IN_DELIVERY':
      return order.dropoffAddress;
    case 'DELIVERY_FAILED':
      return order.failureDecision === 'RETURN' ? order.pickupAddress : order.dropoffAddress;
    default:
      return null;
  }
}

/** Début du jour, de la semaine (lundi) ou du mois, à l'heure du Cameroun. */
export function periodStart(period: 'day' | 'week' | 'month', now: Date): Date {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: CAMEROON_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  }).formatToParts(now);
  const get = (type: string): string => parts.find((part) => part.type === type)?.value ?? '';
  const year = Number(get('year'));
  const month = Number(get('month'));
  const day = Number(get('day'));
  const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(get('weekday'));
  // Le Cameroun est à UTC+1 toute l'année (pas d'heure d'été).
  const localMidnight = (y: number, m: number, d: number): Date =>
    new Date(Date.UTC(y, m - 1, d) - 3_600_000);
  switch (period) {
    case 'day':
      return localMidnight(year, month, day);
    case 'week':
      return localMidnight(year, month, day - weekday);
    case 'month':
      return localMidnight(year, month, 1);
  }
}
