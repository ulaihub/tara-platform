import { Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { hashCode, randomDigits, randomReadableId, randomToken } from '../common/crypto.js';
import { pageOf } from '../common/pagination.js';
import { Prisma, type Order, type OrderEvent } from '../generated/prisma/client.js';
import type { ActorRole } from '../generated/prisma/enums.js';
import { OrderEventsBus, type OrderChange } from '../events/order-events.bus.js';
import { OrderTransitionHooks } from '../events/order-transition.hooks.js';
import { AddressesService } from '../geo/addresses.service.js';
import { type FullQuote, PricingService } from '../pricing/pricing.service.js';
import { PromoService } from '../pricing/promo.service.js';
import { ratingDto } from './ratings.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { prohibitedWarning } from '../parcel-analysis/parcel-analysis.schemas.js';
import { MediaService } from '../storage/media.service.js';
import { BEFORE_PICKUP } from './order-state-machine.js';
import { OrderTransitionsService } from './order-transitions.service.js';
import {
  type AdminTransitionBody,
  type CreateBatchBody,
  type CreatedBatchDto,
  type CreatedOrderDto,
  type CreateOrderBody,
  type DeliveryItem,
  MAX_COD_AMOUNT,
  type OrderDto,
  ACTIVE_ORDER_STATUSES,
  type OrderListQuery,
  type OrderSummaryDto,
  type RecipientDto,
  type RecipientResponseBody,
} from './orders.schemas.js';
import { trackingUrl } from './tracking-url.js';

const ADDRESS_INCLUDE = {
  include: { neighborhood: { select: { id: true, name: true } } },
} as const;
const ORDER_INCLUDE = {
  pickupAddress: ADDRESS_INCLUDE,
  dropoffAddress: ADDRESS_INCLUDE,
  events: { orderBy: { recordedAt: 'asc' } },
  rider: {
    select: {
      vehicleType: true,
      plateNumber: true,
      user: { select: { fullName: true, phone: true } },
    },
  },
  ratings: { select: { raterId: true, score: true, comment: true, createdAt: true } },
  batch: { select: { _count: { select: { orders: true } } } },
} as const satisfies Prisma.OrderInclude;

/** Statuts où l'expéditeur peut joindre le livreur. */
const RIDER_REACHABLE: readonly string[] = [
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
];

/** « Jean Mbarga » → « Jean M. » : assez pour reconnaître le livreur à la porte. */
export function shortName(fullName: string | null): string {
  const [first = '', last] = (fullName ?? '').trim().split(/\s+/);
  return last ? `${first} ${last[0]?.toUpperCase()}.` : first || 'Livreur';
}

type OrderFull = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

interface Shared {
  pickupAddressId: string;
  isExpress: boolean;
  scheduledFor?: string | undefined;
  feePayer: 'SENDER' | 'RECIPIENT';
  feePaymentMethod: 'MOMO_MTN' | 'MOMO_ORANGE' | 'CASH' | 'WALLET';
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

/**
 * Une commande part tout de suite à la recherche d'un livreur si elle n'est pas programmée
 * et que ses frais sont réglés ou le seront à l'enlèvement ou à la livraison. Sinon elle
 * attend le paiement Mobile Money (POST /orders/{id}/pay) ou son créneau.
 */
function dispatchesImmediately(order: Order): boolean {
  return !order.scheduledFor && readyForDispatch(order);
}

/**
 * Une commande peut partir en recherche de livreur si ses frais sont réglés (prépaiement
 * Mobile Money ou solde Tara) ou le seront en espèces ou par le destinataire.
 */
export function readyForDispatch(
  order: Pick<Order, 'feePayer' | 'feePaymentMethod' | 'feePaidAt'>,
): boolean {
  return (
    order.feePayer === 'RECIPIENT' || order.feePaymentMethod === 'CASH' || order.feePaidAt !== null
  );
}

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pricing: PricingService,
    private readonly promos: PromoService,
    private readonly addresses: AddressesService,
    private readonly transitions: OrderTransitionsService,
    private readonly events: OrderEventsBus,
    private readonly hooks: OrderTransitionHooks,
    private readonly audit: AuditService,
    private readonly media: MediaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // --- Lecture ---------------------------------------------------------------------------

  async toDtos(orders: OrderFull[]): Promise<z.output<typeof OrderDto>[]> {
    const unique = new Map(
      orders.flatMap((o) => [o.pickupAddress, o.dropoffAddress]).map((a) => [a.id, a] as const),
    );
    const dtos = await this.addresses.toDtos([...unique.values()]);
    const byId = new Map(dtos.map((dto) => [dto.id, dto]));
    return orders.map((order) => this.toDto(order, byId));
  }

  private toDto(
    order: OrderFull,
    addresses: Map<string, z.output<typeof OrderDto>['pickup']>,
  ): z.output<typeof OrderDto> {
    const pickup = addresses.get(order.pickupAddressId);
    const dropoff = addresses.get(order.dropoffAddressId);
    if (!pickup || !dropoff) throw new Error(`Adresses manquantes pour ${order.reference}`);
    return {
      id: order.id,
      reference: order.reference,
      status: order.status,
      trackingUrl: trackingUrl(this.env, order.trackingToken),
      batchId: order.batchId,
      batchNumber: order.batchNumber,
      batchSize: order.batch?._count.orders ?? null,
      isExpress: order.isExpress,
      scheduledFor: order.scheduledFor?.toISOString() ?? null,
      packageSize: order.packageSize,
      packageContents: order.packageContents,
      packageDescription: order.packageDescription,
      isFragile: order.isFragile,
      loadingHelp: order.loadingHelp,
      declaredValue: order.declaredValue,
      instructions: order.instructions,
      pickup,
      dropoff,
      recipient: {
        name: order.recipientName,
        phone: order.recipientPhone,
        confirmedAt: order.recipientConfirmedAt?.toISOString() ?? null,
        available: order.recipientAvailable,
        note: order.recipientNote,
      },
      pricing: {
        currency: 'XAF',
        distanceMeters: order.distanceMeters,
        basePrice: order.basePrice,
        surchargesTotal: order.surchargesTotal,
        discountTotal: order.discountTotal,
        totalPrice: order.totalPrice,
        feePayer: order.feePayer,
        feePaymentMethod: order.feePaymentMethod,
        feePaid: order.feePaidAt !== null,
        codAmount: order.codAmount,
        retryFee: order.retryFee,
        returnFee: order.returnFee,
      },
      riderId: order.riderId,
      rider: order.rider
        ? {
            name: shortName(order.rider.user.fullName),
            phone: RIDER_REACHABLE.includes(order.status) ? order.rider.user.phone : null,
            vehicleType: order.rider.vehicleType,
            plateNumber: order.rider.plateNumber,
          }
        : null,
      attemptCount: order.attemptCount,
      failure: this.failureOf(order),
      cancelReason: order.cancelReason,
      rating: ratingDto(order.ratings.find((r) => r.raterId === order.senderId)),
      timeline: order.events.map((event: OrderEvent) => ({
        status: event.toStatus,
        at: event.occurredAt.toISOString(),
        actorRole: event.actorRole,
        failureReason: event.failureReason,
        note: event.note,
      })),
      createdAt: order.createdAt.toISOString(),
    };
  }

  /** Dernier échec de livraison, tant que la course n'est pas repartie (E6). */
  private failureOf(order: OrderFull): z.output<typeof OrderDto>['failure'] {
    if (order.status !== 'DELIVERY_FAILED' || !order.failedAt) return null;
    const event = order.events.findLast((e: OrderEvent) => e.toStatus === 'DELIVERY_FAILED');
    return {
      reason: order.failureReason,
      note: event?.note ?? null,
      at: order.failedAt.toISOString(),
      decision: order.failureDecision,
      retryAllowed: order.attemptCount < 2,
      decisionDueAt: order.failureDecision
        ? null
        : new Date(
            order.failedAt.getTime() + this.env.FAILURE_DECISION_TIMEOUT_MINUTES * 60_000,
          ).toISOString(),
    };
  }

  private async loadFull(id: string): Promise<OrderFull> {
    const order = await this.prisma.order.findUnique({ where: { id }, include: ORDER_INCLUDE });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    return order;
  }

  private async dtoOf(id: string): Promise<z.output<typeof OrderDto>> {
    const [dto] = await this.toDtos([await this.loadFull(id)]);
    return dto as z.output<typeof OrderDto>;
  }

  /** Rôle de l'utilisateur vis-à-vis de la commande, ou null s'il n'y a pas accès. */
  private async roleOn(user: AuthUser, order: Order): Promise<ActorRole | null> {
    if (order.senderId === user.id) return 'SENDER';
    if (user.roles.includes('DISPATCHER') || user.roles.includes('ADMIN')) return 'DISPATCHER';
    if (user.roles.includes('SUPPORT')) return 'SUPPORT';
    if (order.riderId) {
      const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
      if (rider?.id === order.riderId) return 'RIDER';
    }
    return null;
  }

  async get(user: AuthUser, id: string): Promise<z.output<typeof OrderDto>> {
    const order = await this.loadFull(id);
    if (!(await this.roleOn(user, order))) throw AppError.notFound('ORDER_NOT_FOUND');
    const [dto] = await this.toDtos([order]);
    return dto as z.output<typeof OrderDto>;
  }

  async list(
    user: AuthUser,
    query: z.output<typeof OrderListQuery>,
  ): Promise<{ items: z.output<typeof OrderSummaryDto>[]; nextCursor: string | null }> {
    const rows = await this.prisma.order.findMany({
      where: {
        senderId: user.id,
        ...(query.status ? { status: query.status } : {}),
        ...(query.scope === 'active' ? { status: { in: [...ACTIVE_ORDER_STATUSES] } } : {}),
        ...(query.scope === 'history' ? { status: { notIn: [...ACTIVE_ORDER_STATUSES] } } : {}),
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      orderBy: { id: 'desc' },
      take: query.limit + 1,
      include: {
        dropoffAddress: { select: { landmark: true, neighborhood: { select: { name: true } } } },
      },
    });
    const page = pageOf(rows, query.limit);
    return {
      items: page.items.map((order) => ({
        id: order.id,
        reference: order.reference,
        status: order.status,
        recipientName: order.recipientName,
        dropoffLandmark: order.dropoffAddress.landmark,
        dropoffNeighborhood: order.dropoffAddress.neighborhood?.name ?? null,
        totalPrice: order.totalPrice,
        codAmount: order.codAmount,
        scheduledFor: order.scheduledFor?.toISOString() ?? null,
        failureDecision: order.status === 'DELIVERY_FAILED' ? order.failureDecision : null,
        createdAt: order.createdAt.toISOString(),
      })),
      nextCursor: page.nextCursor,
    };
  }

  // --- Création (C1, C3, C4) -------------------------------------------------------------

  /**
   * Photos de colis jointes : à l'expéditeur, du bon type ; l'avertissement de leur analyse
   * (objets interdits vus sur la photo) suit la commande pour l'équipe et le livreur.
   */
  private async parcelWarnings(
    user: AuthUser,
    items: z.output<typeof DeliveryItem>[],
  ): Promise<Map<string, string | null>> {
    const warnings = new Map<string, string | null>();
    for (const key of new Set(items.flatMap((item) => item.parcelPhotoKey ?? []))) {
      await this.media.assertOwned(user.id, key, ['PARCEL_PHOTO']);
      const analysis = await this.prisma.parcelAnalysis.findUnique({ where: { photoKey: key } });
      warnings.set(key, analysis ? prohibitedWarning(analysis.result) : null);
    }
    return warnings;
  }

  private async checkCommercialRules(
    user: AuthUser,
    shared: Shared,
    items: z.output<typeof DeliveryItem>[],
  ): Promise<{ merchantId: string | null; senderName: string }> {
    const sender = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      include: { merchant: true },
    });
    for (const item of items) {
      if (item.codAmount > 0 && !sender.merchant)
        throw AppError.unprocessable('MERCHANT_REQUIRED_FOR_COD');
      if (item.codAmount > MAX_COD_AMOUNT) {
        throw AppError.unprocessable('COD_AMOUNT_TOO_HIGH', {
          max: MAX_COD_AMOUNT.toLocaleString('fr-FR'),
        });
      }
    }
    if (shared.feePayer === 'RECIPIENT' && shared.feePaymentMethod === 'WALLET') {
      throw AppError.unprocessable('PAYMENT_METHOD_NOT_ALLOWED');
    }
    return {
      merchantId: sender.merchant?.id ?? null,
      senderName: sender.merchant?.shopName ?? sender.fullName ?? 'Un expéditeur',
    };
  }

  private orderData(
    user: AuthUser,
    shared: Shared,
    item: z.output<typeof DeliveryItem>,
    quote: FullQuote,
    context: {
      merchantId: string | null;
      reference: string;
      pickupCode: string;
      batchId?: string;
      /** Numéro du colis dans son envoi (1, 2, 3…). */
      batchNumber?: number;
      idempotencyKey?: string | undefined;
      /** Objets interdits que l'analyse de chaque photo de colis a cru voir. */
      parcelWarnings: Map<string, string | null>;
    },
  ): Prisma.OrderUncheckedCreateInput {
    return {
      parcelPhotoKey: item.parcelPhotoKey ?? null,
      parcelAiWarning: item.parcelPhotoKey
        ? (context.parcelWarnings.get(item.parcelPhotoKey) ?? null)
        : null,
      reference: context.reference,
      trackingToken: randomToken(16),
      senderId: user.id,
      merchantId: context.merchantId,
      batchId: context.batchId ?? null,
      batchNumber: context.batchNumber ?? null,
      pickupAddressId: shared.pickupAddressId,
      dropoffAddressId: item.dropoffAddressId,
      recipientName: item.recipientName,
      recipientPhone: item.recipientPhone,
      packageSize: item.packageSize,
      packageContents: item.packageContents,
      packageDescription: item.packageDescription ?? null,
      isFragile: item.isFragile,
      loadingHelp: item.packageSize === 'BULKY' && item.loadingHelp,
      declaredValue: item.declaredValue ?? null,
      instructions: item.instructions ?? null,
      isExpress: shared.isExpress,
      scheduledFor: quote.scheduledFor,
      pricingGridId: quote.grid.id,
      distanceMeters: quote.route.meters,
      basePrice: quote.price.basePrice,
      surchargesTotal: quote.price.surchargesTotal,
      discountTotal: quote.price.discountTotal,
      proDiscountBps: quote.price.proDiscountBps,
      totalPrice: quote.price.totalPrice,
      riderEarning: quote.price.riderEarning,
      platformFee: quote.price.platformFee,
      retryFee: quote.price.retryFee,
      returnFee: quote.price.returnFee,
      feePayer: shared.feePayer,
      feePaymentMethod: shared.feePaymentMethod,
      codAmount: item.codAmount,
      pickupCodeHash: hashCode(
        this.env.CODE_HASH_SECRET,
        `pickup:${context.reference}`,
        context.pickupCode,
      ),
      idempotencyKey: context.idempotencyKey ?? null,
    };
  }

  /** Crée la commande, son historique et, si possible, la lance tout de suite. */
  private async insert(
    tx: Prisma.TransactionClient,
    user: AuthUser,
    data: Prisma.OrderUncheckedCreateInput,
  ): Promise<{ order: Order; changes: OrderChange[] }> {
    let created = await tx.order.create({ data });
    await tx.orderEvent.create({
      data: {
        orderId: created.id,
        toStatus: 'CREATED',
        actorId: user.id,
        actorRole: 'SENDER',
        occurredAt: created.createdAt,
      },
    });
    // Prépaiement par le solde Tara, contrôles financiers (voir OrderFinanceService).
    await this.hooks.run({
      tx,
      before: null,
      after: created,
      to: 'CREATED',
      actor: { id: user.id, role: 'SENDER' },
    });
    created = await tx.order.findUniqueOrThrow({ where: { id: created.id } });
    const creation: OrderChange = {
      order: created,
      from: null,
      to: 'CREATED',
      actor: { id: user.id, role: 'SENDER' },
    };
    if (!dispatchesImmediately(created)) return { order: created, changes: [creation] };
    const { order, change } = await this.transitions.applyIn(tx, created, 'SEARCHING_RIDER', {
      id: null,
      role: 'SYSTEM',
    });
    return { order, changes: [creation, change] };
  }

  async create(
    user: AuthUser,
    body: z.output<typeof CreateOrderBody>,
    idempotencyKey: string | undefined,
  ): Promise<z.output<typeof CreatedOrderDto>> {
    const replay = await this.replay(user, idempotencyKey);
    if (replay) return replay;

    const context = {
      ...(await this.checkCommercialRules(user, body, [body])),
      parcelWarnings: await this.parcelWarnings(user, [body]),
    };
    const quote = await this.pricing.quote(user, {
      pickup: { addressId: body.pickupAddressId },
      dropoff: { addressId: body.dropoffAddressId },
      packageSize: body.packageSize,
      isExpress: body.isExpress,
      loadingHelp: body.loadingHelp,
      scheduledFor: body.scheduledFor,
      promoCode: body.promoCode,
    });
    const pickupCode = randomDigits(4);

    for (let attempt = 0; attempt < 3; attempt += 1) {
      const reference = `TR-${randomReadableId(6)}`;
      try {
        const { order, changes } = await this.prisma.$transaction(async (tx) => {
          if (quote.promo) {
            // Verrou puis nouvelle vérification : le quota ne peut pas être dépassé en parallèle.
            await this.promos.lock(quote.promo.code, tx);
            await this.promos.validate(quote.promo.code, user.id, new Date(), tx);
          }
          const created = await this.insert(
            tx,
            user,
            this.orderData(user, body, body, quote, {
              ...context,
              reference,
              pickupCode,
              idempotencyKey,
            }),
          );
          if (quote.promo) {
            await tx.promoRedemption.create({
              data: {
                promoId: quote.promo.id,
                userId: user.id,
                orderId: created.order.id,
                discount: quote.price.discountTotal,
              },
            });
          }
          return created;
        });
        // Message au destinataire, recherche de livreur, temps réel : après validation.
        await this.events.publishAll(changes);
        return { order: await this.dtoOf(order.id), pickupCode, replayed: false };
      } catch (error) {
        if (!isUniqueViolation(error)) throw error;
        const concurrent = await this.replay(user, idempotencyKey);
        if (concurrent) return concurrent;
        // Sinon : collision de référence, on retente avec une autre.
      }
    }
    throw new Error('Impossible de générer une référence de commande unique');
  }

  private async replay(
    user: AuthUser,
    idempotencyKey: string | undefined,
  ): Promise<z.output<typeof CreatedOrderDto> | null> {
    if (!idempotencyKey) return null;
    const existing = await this.prisma.order.findUnique({ where: { idempotencyKey } });
    if (!existing) return null;
    if (existing.senderId !== user.id) throw AppError.conflict('IDEMPOTENCY_CONFLICT');
    return { order: await this.dtoOf(existing.id), pickupCode: null, replayed: true };
  }

  /** Lot de 1 à 10 livraisons depuis un même point, avec un seul code d'enlèvement (C4). */
  async createBatch(
    user: AuthUser,
    body: z.output<typeof CreateBatchBody>,
    idempotencyKey: string | undefined,
  ): Promise<z.output<typeof CreatedBatchDto>> {
    if (idempotencyKey) {
      const existing = await this.prisma.orderBatch.findUnique({
        where: { idempotencyKey },
        include: { orders: true },
      });
      if (existing) {
        if (existing.senderId !== user.id) throw AppError.conflict('IDEMPOTENCY_CONFLICT');
        return this.batchDto(existing.id, null, true);
      }
    }

    const context = {
      ...(await this.checkCommercialRules(user, body, body.items)),
      parcelWarnings: await this.parcelWarnings(user, body.items),
    };
    const quotes = await Promise.all(
      body.items.map((item) =>
        this.pricing.quote(user, {
          pickup: { addressId: body.pickupAddressId },
          dropoff: { addressId: item.dropoffAddressId },
          packageSize: item.packageSize,
          isExpress: body.isExpress,
          loadingHelp: item.loadingHelp,
          scheduledFor: body.scheduledFor,
        }),
      ),
    );
    const pickupCode = randomDigits(4);

    let batchId: string;
    try {
      const { batch, changes } = await this.prisma.$transaction(async (tx) => {
        const batch = await tx.orderBatch.create({
          data: {
            senderId: user.id,
            pickupAddressId: body.pickupAddressId,
            idempotencyKey: idempotencyKey ?? null,
          },
        });
        const changes: OrderChange[] = [];
        for (const [index, item] of body.items.entries()) {
          const quote = quotes[index] as FullQuote;
          const reference = `TR-${randomReadableId(6)}`;
          const inserted = await this.insert(
            tx,
            user,
            this.orderData(user, body, item, quote, {
              ...context,
              reference,
              pickupCode,
              batchId: batch.id,
              batchNumber: index + 1,
            }),
          );
          changes.push(...inserted.changes);
        }
        return { batch, changes };
      });
      batchId = batch.id;
      await this.events.publishAll(changes);
    } catch (error) {
      if (idempotencyKey && isUniqueViolation(error)) {
        const existing = await this.prisma.orderBatch.findUnique({ where: { idempotencyKey } });
        if (existing?.senderId === user.id) return this.batchDto(existing.id, null, true);
      }
      throw error;
    }
    return this.batchDto(batchId, pickupCode, false);
  }

  private async batchDto(
    batchId: string,
    pickupCode: string | null,
    replayed: boolean,
  ): Promise<z.output<typeof CreatedBatchDto>> {
    const orders = await this.prisma.order.findMany({
      where: { batchId },
      orderBy: { batchNumber: 'asc' },
      include: ORDER_INCLUDE,
    });
    return { batchId, pickupCode, replayed, orders: await this.toDtos(orders) };
  }

  // --- Actions sur une commande -----------------------------------------------------------

  async cancel(user: AuthUser, id: string, reason: string): Promise<z.output<typeof OrderDto>> {
    const order = await this.prisma.order.findUnique({ where: { id } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const role = await this.roleOn(user, order);
    if (!role || role === 'RIDER') throw AppError.notFound('ORDER_NOT_FOUND');
    await this.transitions.apply(id, 'CANCELLED', { id: user.id, role }, { note: reason });
    return this.dtoOf(id);
  }

  /**
   * Nouveau code d'enlèvement (code perdu) ; pour un lot, le même code pour tout le lot.
   * Après un échec de livraison, c'est le code de retour de cette commande qui est refait.
   */
  async regeneratePickupCode(user: AuthUser, id: string): Promise<{ pickupCode: string }> {
    const order = await this.prisma.order.findUnique({ where: { id } });
    if (!order || order.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    const returning = order.status === 'DELIVERY_FAILED';
    if (!returning && !BEFORE_PICKUP.includes(order.status)) {
      throw AppError.conflict('PICKUP_ALREADY_DONE');
    }
    const siblings =
      order.batchId && !returning
        ? await this.prisma.order.findMany({
            where: { batchId: order.batchId, status: { in: BEFORE_PICKUP } },
          })
        : [order];
    const pickupCode = randomDigits(4);
    await this.prisma.$transaction(
      siblings.map((sibling) =>
        this.prisma.order.update({
          where: { id: sibling.id },
          data: {
            pickupCodeHash: hashCode(
              this.env.CODE_HASH_SECRET,
              `pickup:${sibling.reference}`,
              pickupCode,
            ),
            // Nouveau code : le compteur d'erreurs du livreur repart de zéro (E3).
            pickupCodeFailures: 0,
          },
        }),
      ),
    );
    return { pickupCode };
  }

  /** Changement de statut forcé par les opérations (D3 manuel, incidents), tracé. */
  async adminTransition(
    user: AuthUser,
    id: string,
    body: z.output<typeof AdminTransitionBody>,
    request: Request,
  ): Promise<z.output<typeof OrderDto>> {
    // Sans livreur, la machine à états renvoie l'erreur de validation adaptée.
    if (body.to === 'ASSIGNED' && body.riderId) {
      const rider = await this.prisma.riderProfile.findUnique({ where: { id: body.riderId } });
      if (!rider || rider.status !== 'ACTIVE') throw AppError.unprocessable('RIDER_NOT_FOUND');
    }
    const before = await this.prisma.order.findUnique({ where: { id } });
    const order = await this.transitions.apply(
      id,
      body.to,
      { id: user.id, role: 'DISPATCHER' },
      { riderId: body.riderId, failureReason: body.failureReason, note: body.note },
    );
    await this.audit.record({
      actor: user,
      action: 'order.transition',
      entityType: 'order',
      entityId: id,
      before: { status: before?.status },
      after: { status: order.status, ...body },
      request,
    });
    return this.dtoOf(id);
  }

  // --- Destinataires (B4, B5) -------------------------------------------------------------

  async recipients(
    user: AuthUser,
    q: string | undefined,
  ): Promise<z.output<typeof RecipientDto>[]> {
    const search = q ?? '';
    const rows = await this.prisma.$queryRaw<
      { phone: string; name: string; addressId: string; lastOrderAt: Date; ordersCount: bigint }[]
    >`
      SELECT DISTINCT ON (o.recipient_phone)
             o.recipient_phone AS phone,
             o.recipient_name AS name,
             o.dropoff_address_id AS "addressId",
             o.created_at AS "lastOrderAt",
             COUNT(*) OVER (PARTITION BY o.recipient_phone) AS "ordersCount"
        FROM orders o
       WHERE o.sender_id = ${user.id}::uuid
         AND o.status <> 'CANCELLED'
         AND o.pii_masked_at IS NULL
         AND (${search} = '' OR o.recipient_name ILIKE '%' || ${search} || '%' OR o.recipient_phone LIKE '%' || ${search} || '%')
       ORDER BY o.recipient_phone, o.created_at DESC
       LIMIT 50`;
    const addresses = await this.prisma.address.findMany({
      where: { id: { in: rows.map((row) => row.addressId) } },
      ...ADDRESS_INCLUDE,
    });
    const byId = new Map((await this.addresses.toDtos(addresses)).map((dto) => [dto.id, dto]));
    return rows
      .sort((a, b) => b.lastOrderAt.getTime() - a.lastOrderAt.getTime())
      .flatMap((row) => {
        const lastAddress = byId.get(row.addressId);
        return lastAddress
          ? [
              {
                phone: row.phone,
                name: row.name,
                ordersCount: Number(row.ordersCount),
                lastOrderAt: row.lastOrderAt.toISOString(),
                lastAddress,
              },
            ]
          : [];
      });
  }

  // --- Page de suivi publique (C5, F2) -----------------------------------------------------

  /** Réponse du destinataire au message de confirmation (C5). */
  async recipientResponse(
    token: string,
    body: z.output<typeof RecipientResponseBody>,
  ): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { trackingToken: token } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const { count } = await this.prisma.order.updateMany({
      where: { id: order.id, recipientConfirmedAt: null, status: { in: BEFORE_PICKUP } },
      data: {
        recipientConfirmedAt: new Date(),
        recipientAvailable: body.available,
        recipientNote: body.note ?? null,
      },
    });
    if (count !== 1) {
      throw AppError.conflict(
        order.recipientConfirmedAt ? 'RECIPIENT_ALREADY_RESPONDED' : 'PICKUP_ALREADY_DONE',
      );
    }
  }
}
