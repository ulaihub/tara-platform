import { Inject, Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { verifyCode } from '../common/crypto.js';
import { AppError } from '../common/errors/app-error.js';
import { pageOf } from '../common/pagination.js';
import { cameroonDate, periodStart } from '../common/time.js';
import { ACTIVE_RIDER_STATUSES } from '../dispatch/dispatch.service.js';
import { OnlineTimeService } from '../dispatch/online-time.service.js';
import { riderPayable } from '../finance/ledger.accounts.js';
import { OrderFinanceService } from '../finance/order-finance.service.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import type { Order, Prisma, RiderProfile } from '../generated/prisma/client.js';
import type { FailureReason, OrderStatus, ProofKind } from '../generated/prisma/enums.js';
import { AddressesService } from '../geo/addresses.service.js';
import { checkTransition } from '../orders/order-state-machine.js';
import {
  OrderTransitionsService,
  type TransitionOptions,
} from '../orders/order-transitions.service.js';
import { ratingDto } from '../orders/ratings.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { DistanceService, type GeoPoint, haversineMeters } from '../routing/distance.service.js';
import { NotificationService } from '../notifications/notification.service.js';
import { waitingFeeMax } from '../orders/waiting-fee.js';

/** Distance au point d'enlèvement au-delà de laquelle l'arrivée n'est pas acceptée (D). */
const ARRIVAL_MAX_METERS = 300;
import { CourseTrackService } from '../tracking/course-track.service.js';
import { MediaService } from '../storage/media.service.js';
import type {
  DeliverBody,
  EarningsDto,
  FailBody,
  RefuseParcelBody,
  PickupBody,
  PositionActionBody,
  ReturnBody,
  RiderOrderDto,
  RiderOrdersQuery,
  RiderRouteDto,
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
  codCollection: { select: { collectedAmount: true, method: true } },
  ratings: { select: { raterId: true, score: true, comment: true, createdAt: true } },
} as const satisfies Prisma.OrderInclude;

type RiderOrder = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

type ActionContext = z.output<typeof PositionActionBody>;

/**
 * Actions du livreur sur ses courses (E2 à E9), côté serveur. Chaque action est rejouable
 * sans effet de bord grâce à son identifiant (`clientEventId`) : l'app hors ligne peut
 * renvoyer sa file d'actions autant de fois que nécessaire.
 */
/** Appels au destinataire exigés avant un échec, selon le motif (E6). */
const CALLS_REQUIRED: Record<FailureReason, number | 'policy'> = {
  RECIPIENT_ABSENT: 'policy',
  RECIPIENT_UNREACHABLE: 'policy',
  ADDRESS_NOT_FOUND: 'policy',
  OTHER: 1,
  REFUSED: 0,
  PAYMENT_REFUSED: 0,
  DAMAGED: 0,
};

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
    private readonly onlineTime: OnlineTimeService,
    private readonly distance: DistanceService,
    private readonly tracks: CourseTrackService,
    private readonly notifications: NotificationService,
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

  /**
   * Photo de façade ou note vocale d'une adresse de la course (B2) : pour son livreur, tant
   * que la course est en cours. Ensuite, comme pour un autre livreur, introuvable.
   */
  async addressMedia(
    userId: string,
    orderId: string,
    stop: 'pickup' | 'dropoff',
    kind: 'photo' | 'voice',
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    const { order } = await this.load(userId, orderId);
    if (!(ACTIVE_RIDER_STATUSES as readonly OrderStatus[]).includes(order.status)) {
      throw AppError.notFound('MEDIA_NOT_FOUND');
    }
    const address = stop === 'pickup' ? order.pickupAddress : order.dropoffAddress;
    const key = kind === 'photo' ? address.photoKey : address.voiceNoteKey;
    if (!key) throw AppError.notFound('MEDIA_NOT_FOUND');
    return this.media.read(key);
  }

  /** Photo du colis jointe par l'expéditeur, pour le livreur de la course en cours. */
  async parcelPhoto(
    userId: string,
    orderId: string,
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    const { order } = await this.load(userId, orderId);
    if (
      !order.parcelPhotoKey ||
      !(ACTIVE_RIDER_STATUSES as readonly OrderStatus[]).includes(order.status)
    ) {
      throw AppError.notFound('MEDIA_NOT_FOUND');
    }
    return this.media.read(order.parcelPhotoKey);
  }

  async get(userId: string, orderId: string): Promise<z.output<typeof RiderOrderDto>> {
    const { order } = await this.load(userId, orderId);
    const [dto] = await this.toDtos([order]);
    return dto as z.output<typeof RiderOrderDto>;
  }

  /** Itinéraire de la position du livreur à la prochaine étape de sa course (E2). */
  async route(
    userId: string,
    orderId: string,
    from: GeoPoint,
  ): Promise<z.output<typeof RiderRouteDto>> {
    const { order } = await this.load(userId, orderId);
    const target = navigationTarget(order);
    if (!target) throw AppError.conflict('ORDER_NOT_IN_PROGRESS', { status: order.status });
    const route = await this.distance.path(from, target);
    return {
      stop: target === order.pickupAddress ? 'PICKUP' : 'DROPOFF',
      meters: route.meters,
      seconds: route.seconds,
      source: route.source,
      path: route.path,
    };
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
        batchNumber: order.batchNumber,
        packageSize: order.packageSize,
        packageContents: order.packageContents,
        packageDescription: order.packageDescription,
        isFragile: order.isFragile,
        loadingHelp: order.loadingHelp,
        hasParcelPhoto: order.parcelPhotoKey !== null,
        parcelWarning: order.parcelAiWarning,
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
        // Part du livreur plus les primes payées par Tara, figées à l'acceptation (H4).
        riderEarning: order.riderEarning + order.approachBonus + order.boostBonus,
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
        failureReason: order.failureReason,
        failedAt: order.failedAt?.toISOString() ?? null,
        failureDecisionDueAt:
          order.status === 'DELIVERY_FAILED' && !order.failureDecision && order.failedAt
            ? new Date(
                order.failedAt.getTime() + this.env.FAILURE_DECISION_TIMEOUT_MINUTES * 60_000,
              ).toISOString()
            : null,
        awaitingSupportValidation: awaiting.has(order.id),
        assignedAt: order.assignedAt?.toISOString() ?? null,
        arrivedPickupAt: order.arrivedPickupAt?.toISOString() ?? null,
        pickedUpAt: order.pickedUpAt?.toISOString() ?? null,
        deliveredAt: order.deliveredAt?.toISOString() ?? null,
        completedAt:
          (order.deliveredAt ?? order.returnedAt ?? order.cancelledAt)?.toISOString() ?? null,
        rating: ratingDto(order.ratings.find((r) => r.raterId !== order.senderId)),
        collected: order.codCollection
          ? {
              amount: order.codCollection.collectedAmount,
              method: order.codCollection.method === 'CASH' ? 'CASH' : 'MOBILE_MONEY',
            }
          : null,
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

  /**
   * Arrivé au point d'enlèvement (D) : sur place seulement (300 m au plus), une fois. Les
   * colis du même envoi pris par ce livreur attendent avec lui. L'expéditeur est prévenu.
   */
  async arrived(
    userId: string,
    orderId: string,
    body: z.output<typeof PositionActionBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    const { order } = await this.load(userId, orderId);
    if (order.status !== 'ASSIGNED') throw AppError.conflict('ARRIVAL_NOT_EXPECTED');
    if (order.arrivedPickupAt) return this.get(userId, orderId);
    const meters = Math.round(haversineMeters(body, order.pickupAddress));
    if (meters > ARRIVAL_MAX_METERS) throw AppError.unprocessable('NOT_AT_PICKUP', { meters });
    const at = new Date();
    await this.prisma.order.updateMany({
      where: {
        riderId: order.riderId,
        status: 'ASSIGNED',
        arrivedPickupAt: null,
        ...(order.batchId ? { batchId: order.batchId } : { id: order.id }),
      },
      data: { arrivedPickupAt: at },
    });
    await this.notifications.toUser(order.senderId, {
      template: 'RIDER_ARRIVED_PICKUP',
      params: {
        reference: order.reference,
        free: String(this.env.WAITING_FREE_MINUTES),
        fee: String(this.env.WAITING_FEE_PER_STEP),
        step: String(this.env.WAITING_STEP_MINUTES),
        max: String(waitingFeeMax(this.env)),
      },
      data: { type: 'order.arrived', orderId: order.id },
      orderId: order.id,
    });
    return this.get(userId, orderId);
  }

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
    await this.tracks.checkAction(order, 'PICKUP', body, order.pickupAddress);
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
          receivedBy: body.receivedBy ?? null,
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
        receivedBy: proof.receivedBy,
        collectAtDelivery:
          order.codAmount + (order.feePayer === 'RECIPIENT' ? order.totalPrice : 0),
        at: proof.occurredAt.toISOString(),
      });
      await this.tracks.checkAction(order, 'DELIVERY', body, order.dropoffAddress);
      return this.get(userId, orderId);
    }
    assertTransition(order, 'DELIVERED');
    await this.checkCode(order, 'delivery', body.deliveryCode);
    await this.act(userId, order, 'DELIVERED', body, {
      kind: 'DELIVERY',
      photoKey: body.photoKey,
      codeVerified: true,
    });
    await this.tracks.checkAction(order, 'DELIVERY', body, order.dropoffAddress);
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
    this.checkFailure(order, body);
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
    // Échec déclaré loin de l'adresse du destinataire : alerte au support (faux « absent »).
    await this.tracks.checkAction(order, 'FAILURE', body, order.dropoffAddress);
    if (body.reason === 'DAMAGED') await this.openDamageClaim(userId, order.id, body.note);
    return this.get(userId, orderId);
  }

  /**
   * Colis refusé parce qu'abîmé : une réclamation « Colis abîmé » est ouverte pour
   * l'expéditeur, en priorité haute, avec la photo prise par le livreur (preuves de la
   * commande). Une seule par commande.
   */
  private async openDamageClaim(
    riderUserId: string,
    orderId: string,
    note: string | undefined,
  ): Promise<void> {
    const existing = await this.prisma.ticket.findFirst({
      where: { orderId, category: 'DAMAGED_PARCEL', status: { in: ['OPEN', 'IN_PROGRESS'] } },
    });
    if (existing) return;
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      select: { reference: true, sender: { select: { id: true, phone: true } } },
    });
    await this.prisma.ticket.create({
      data: {
        openedById: riderUserId,
        requesterId: order.sender.id,
        contactPhone: order.sender.phone,
        orderId,
        category: 'DAMAGED_PARCEL',
        priority: 'HIGH',
        subject: `Colis ${order.reference} refusé : abîmé à la livraison`,
        messages: {
          create: {
            authorId: riderUserId,
            body: `Le destinataire a refusé le colis : il est abîmé. Photo jointe à la commande.${note ? ` Précision du livreur : ${note}` : ''}`,
          },
        },
      },
    });
  }

  /**
   * Colis refusé à l'enlèvement : il ne correspond pas à la commande (trop gros pour une
   * moto, trop lourd, autre chose que déclaré, objet interdit). Photo à l'appui, la
   * commande est annulée, l'expéditeur prévenu et le déplacement facturé (gros objets).
   */
  async refuseParcel(
    userId: string,
    orderId: string,
    body: z.output<typeof RefuseParcelBody>,
  ): Promise<z.output<typeof RiderOrderDto>> {
    if (await this.replayed(orderId, body.clientEventId)) return this.get(userId, orderId);
    const { order, rider } = await this.load(userId, orderId);
    if (order.status !== 'ASSIGNED') {
      throw AppError.conflict('PARCEL_REFUSAL_NOT_ALLOWED', { status: order.status });
    }
    await this.media.assertOwned(userId, body.photoKey, ['PROOF_PHOTO']);
    const occurredAt = this.occurredAt(body);
    const note = `Colis non conforme : ${PARCEL_REFUSAL_LABELS[body.reason]}${body.note ? ` · ${body.note}` : ''}`;
    const change: OrderChange = await this.prisma.$transaction(async (tx) => {
      await tx.deliveryProof.create({
        data: {
          orderId: order.id,
          kind: 'PICKUP_REFUSED',
          photoKey: body.photoKey,
          codeVerified: false,
          latitude: body.latitude,
          longitude: body.longitude,
          occurredAt,
          clientEventId: null,
        },
      });
      const result = await this.transitions.applyIn(
        tx,
        order,
        'CANCELLED',
        { id: userId, role: 'RIDER' },
        {
          note,
          latitude: body.latitude,
          longitude: body.longitude,
          occurredAt,
          clientEventId: body.clientEventId,
        },
      );
      await this.finance.chargeRefusedParcel(tx, order, rider.id);
      return result.change;
    });
    await this.bus.publish(change);
    return this.get(userId, orderId);
  }

  /**
   * Preuve d'appel exigée selon le motif (E6) : un faux « client absent » coûte une course
   * au client ; un refus sur place n'a pas besoin d'appel.
   */
  private checkFailure(order: Order, body: z.output<typeof FailBody>): void {
    if (body.reason === 'OTHER' && !body.note) {
      throw AppError.badRequest('VALIDATION_FAILED', {}, [{ path: 'note', message: 'requis' }]);
    }
    const rule = CALLS_REQUIRED[body.reason];
    const required = rule === 'policy' ? this.env.FAILURE_MIN_CALLS : rule;
    if (required === 0) return;
    // Le journal vient du téléphone : seuls comptent les appels de cette tentative (depuis
    // l'enlèvement, ou depuis l'échec précédent) et pas dans le futur.
    const from = (order.failedAt ?? order.pickedUpAt ?? order.assignedAt)?.getTime() ?? 0;
    const until = Date.now() + 2 * 60_000;
    const times = body.callLog
      .filter((call) => call.to === 'RECIPIENT')
      .map((call) => Date.parse(call.at))
      .filter((at) => at >= from && at <= until)
      .sort((a, b) => a - b);
    const spacing = required > 1 ? this.env.FAILURE_CALL_SPACING_MINUTES * 60_000 : 0;
    const spread = times.length > 0 ? (times.at(-1) ?? 0) - (times[0] ?? 0) : 0;
    if (times.length < required || spread < spacing) {
      if (required === 1) throw AppError.unprocessable('FAILURE_CALL_REQUIRED');
      throw AppError.unprocessable('FAILURE_CALLS_REQUIRED', {
        required,
        spacingMinutes: this.env.FAILURE_CALL_SPACING_MINUTES,
      });
    }
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
    // Pas de paiement, pas de colis (E6) : ce que le solde de l'expéditeur ne couvre pas est
    // encaissé avant de rendre le colis (le code n'est pas vérifié, donc pas consommé, avant).
    const collection = await this.finance.collectionState(order);
    if (!collection.complete) {
      throw AppError.conflict('RETURN_COLLECTION_REQUIRED', { amount: collection.due.total });
    }
    await this.checkCode(order, 'pickup', body.senderCode);
    await this.act(userId, order, 'RETURNED', body, {
      kind: 'RETURN',
      photoKey: body.photoKey ?? null,
      codeVerified: true,
    });
    await this.tracks.checkAction(order, 'RETURN', body, order.pickupAddress);
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
    // Gains réels : ce que le grand livre a crédité au livreur à la fin de ses courses
    // (livrées ou rendues), part des frais d'échec comprise.
    const credited = await this.prisma.$queryRaw<{ at: Date; amount: bigint }[]>`
      SELECT e.posted_at AS at, (-p.amount)::bigint AS amount
        FROM ledger_postings p
        JOIN journal_entries e ON e.id = p.entry_id
        JOIN ledger_accounts a ON a.id = p.account_id
       WHERE a.code = ${riderPayable(rider.id).code}
         AND e.kind = 'DELIVERY_COMPLETED'
         AND e.posted_at >= ${from} AND e.posted_at <= ${now}`;
    const [delivered, failed, returned, cash, onlineSeconds] = await Promise.all([
      this.prisma.order.findMany({
        where: { riderId: rider.id, status: 'DELIVERED', deliveredAt: { gte: from, lte: now } },
        select: { deliveredAt: true, riderEarning: true },
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
      this.onlineTime.seconds(rider.id, from, now, now),
    ]);
    const starts = bucketStarts(period, from);
    const series = starts.map((start) => ({
      start: start.toISOString(),
      earnings: 0,
      delivered: 0,
    }));
    // Dernière tranche commencée avant l'instant donné (les heures hors 6 h-22 h vont aux bords).
    const bucketOf = (at: Date) => {
      let index = 0;
      while (index + 1 < starts.length && (starts[index + 1] as Date) <= at) index++;
      return series[index];
    };
    for (const order of delivered) {
      const bucket = order.deliveredAt ? bucketOf(order.deliveredAt) : undefined;
      if (bucket) bucket.delivered += 1;
    }
    for (const credit of credited) {
      const bucket = bucketOf(credit.at);
      if (bucket) bucket.earnings += Number(credit.amount);
    }
    return {
      period,
      from: from.toISOString(),
      to: now.toISOString(),
      delivered: delivered.length,
      failed,
      returned,
      earnings: credited.reduce((sum, credit) => sum + Number(credit.amount), 0),
      cashCollected: cash._sum.collectedAmount ?? 0,
      onlineSeconds,
      bucket: period === 'day' ? 'two_hours' : period === 'week' ? 'day' : 'week',
      series,
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

/** Motifs de refus d'un colis à l'enlèvement, tels qu'écrits dans l'historique. */
const PARCEL_REFUSAL_LABELS: Record<z.output<typeof RefuseParcelBody>['reason'], string> = {
  TOO_BIG: 'trop grand pour le véhicule',
  TOO_HEAVY: 'trop lourd',
  NOT_AS_DECLARED: 'pas ce qui a été déclaré',
  FORBIDDEN_ITEM: 'objet interdit',
};

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
/** Débuts des tranches de l'histogramme des gains (voir RiderEarnings.series). */
export function bucketStarts(period: 'day' | 'week' | 'month', from: Date): Date[] {
  const hour = 3_600_000;
  const day = 24 * hour;
  switch (period) {
    case 'day':
      // 6 h, 8 h… 20 h : la première tranche reçoit aussi la nuit, la dernière le soir.
      return [0, 1, 2, 3, 4, 5, 6, 7].map((i) => new Date(from.getTime() + (6 + 2 * i) * hour));
    case 'week':
      return [0, 1, 2, 3, 4, 5, 6].map((i) => new Date(from.getTime() + i * day));
    case 'month': {
      const starts: Date[] = [];
      // Semaines du mois : 1er, 8, 15, 22, 29 (si ce jour existe dans le mois).
      const monthOf = (date: Date): string => cameroonDate(date).slice(0, 7);
      for (const offset of [0, 7, 14, 21, 28]) {
        const start = new Date(from.getTime() + offset * day);
        if (monthOf(start) === monthOf(from)) starts.push(start);
      }
      return starts;
    }
  }
}
