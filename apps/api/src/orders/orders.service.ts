import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { mapLimit } from '../common/concurrency.js';
import { AppError, localizedMessage } from '../common/errors/app-error.js';
import { resolveLocale } from '../common/i18n/locale.js';
import { hashCode, randomDigits, randomReadableId, randomToken } from '../common/crypto.js';
import { pageOf } from '../common/pagination.js';
import { Prisma, type Order, type OrderEvent } from '../generated/prisma/client.js';
import type { ActorRole } from '../generated/prisma/enums.js';
import { OrderEventsBus, type OrderChange } from '../events/order-events.bus.js';
import { OrderTransitionHooks } from '../events/order-transition.hooks.js';
import { AddressesService } from '../geo/addresses.service.js';
import { LocationLinksService } from '../geo/location-links.service.js';
import { NotificationService } from '../notifications/notification.service.js';
import { type FullQuote, PricingService, QUOTE_CONCURRENCY } from '../pricing/pricing.service.js';
import { PromoService } from '../pricing/promo.service.js';
import { ratingDto } from './ratings.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { prohibitedWarning } from '../parcel-analysis/parcel-analysis.schemas.js';
import { MediaService } from '../storage/media.service.js';
import { BEFORE_PICKUP } from './order-state-machine.js';
import { OrderTransitionsService } from './order-transitions.service.js';
import {
  PendingDeliveriesService,
  type PendingWithLink,
  StoredPending,
} from './pending-deliveries.service.js';
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
  type PaymentMethodEnum,
  type PendingDeliveryDto,
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
  batch: {
    select: {
      _count: {
        select: {
          orders: true,
          // Colis qui attendent encore l'adresse de leur client : ils ont déjà leur numéro.
          pendingDeliveries: { where: { orderId: null, cancelledAt: null } },
        },
      },
    },
  },
} as const satisfies Prisma.OrderInclude;

/** Un envoi de 100 colis s'écrit en une transaction : plus que les 5 s par défaut. */
const BATCH_TRANSACTION = { timeout: 60_000, maxWait: 10_000 } as const;

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
export class OrdersService implements OnModuleInit {
  private readonly logger = new Logger(OrdersService.name);

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
    private readonly pending: PendingDeliveriesService,
    private readonly links: LocationLinksService,
    private readonly notifications: NotificationService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Le client d'un colis en attente a placé son point : le colis part (voir releasePending). */
  onModuleInit(): void {
    this.links.onSubmitted(async (linkId) => {
      const row = await this.prisma.pendingDelivery.findUnique({
        where: { locationLinkId: linkId },
        select: { id: true },
      });
      if (row) await this.releasePending(row.id);
    });
  }

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
      batchSize: order.batch
        ? order.batch._count.orders + order.batch._count.pendingDeliveries
        : null,
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
        valueFee: order.valueFee,
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
        batchNumber: order.batchNumber,
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
    items: readonly Pick<z.output<typeof DeliveryItem>, 'parcelPhotoKey'>[],
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
    items: readonly Pick<z.output<typeof DeliveryItem>, 'codAmount'>[],
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
      valueFee: quote.price.valueFee,
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
      declaredValue: body.declaredValue,
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
      const existing = await this.prisma.orderBatch.findUnique({ where: { idempotencyKey } });
      if (existing) {
        if (existing.senderId !== user.id) throw AppError.conflict('IDEMPOTENCY_CONFLICT');
        return this.batchDto(existing.id, null, true);
      }
    }

    // Chaque colis garde son numéro (ordre de saisie), qu'il parte tout de suite ou plus tard.
    const ready = body.items.flatMap((item, index) =>
      item.dropoffAddressId
        ? [{ item: { ...item, dropoffAddressId: item.dropoffAddressId }, number: index + 1 }]
        : [],
    );
    const waiting = body.items.flatMap((item, index) =>
      item.askAddress ? [{ item, number: index + 1 }] : [],
    );
    const context = {
      ...(await this.checkCommercialRules(user, body, body.items)),
      parcelWarnings: await this.parcelWarnings(user, body.items),
    };
    if (waiting.length > 0) {
      // Rien n'est calculé pour eux maintenant : on vérifie au moins le départ et l'heure.
      await this.addresses.usableBy(user, body.pickupAddressId);
      this.pricing.scheduleFrom(body.scheduledFor, new Date());
      await this.pending.assertLinkQuota(user.id, waiting.length);
    }
    const quotes = await mapLimit(ready, QUOTE_CONCURRENCY, ({ item }) =>
      this.pricing.quote(user, {
        pickup: { addressId: body.pickupAddressId },
        dropoff: { addressId: item.dropoffAddressId },
        packageSize: item.packageSize,
        isExpress: body.isExpress,
        loadingHelp: item.loadingHelp,
        scheduledFor: body.scheduledFor,
        declaredValue: item.declaredValue,
      }),
    );
    const pickupCode = randomDigits(4);

    let batchId: string;
    let created: PendingWithLink[];
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const batch = await tx.orderBatch.create({
          data: {
            senderId: user.id,
            pickupAddressId: body.pickupAddressId,
            idempotencyKey: idempotencyKey ?? null,
            // Gardé (chiffré) seulement si des colis partiront plus tard avec le même code.
            pickupCodeSealed: waiting.length > 0 ? this.pending.sealCode(pickupCode) : null,
          },
        });
        const changes: OrderChange[] = [];
        for (const [index, { item, number }] of ready.entries()) {
          const inserted = await this.insert(
            tx,
            user,
            this.orderData(user, body, item, quotes[index] as FullQuote, {
              ...context,
              reference: `TR-${randomReadableId(6)}`,
              pickupCode,
              batchId: batch.id,
              batchNumber: number,
            }),
          );
          changes.push(...inserted.changes);
        }
        const pendingRows: PendingWithLink[] = [];
        for (const { item, number } of waiting) {
          pendingRows.push(
            await this.pending.createIn(tx, {
              senderId: user.id,
              merchantId: context.merchantId,
              batchId: batch.id,
              batchNumber: number,
              item,
              shared: {
                isExpress: body.isExpress,
                ...(body.scheduledFor ? { scheduledFor: body.scheduledFor } : {}),
                feePayer: body.feePayer,
                feePaymentMethod: body.feePaymentMethod,
              },
            }),
          );
        }
        return { batch, changes, pendingRows };
      }, BATCH_TRANSACTION);
      batchId = result.batch.id;
      created = result.pendingRows;
      await this.events.publishAll(result.changes);
    } catch (error) {
      if (idempotencyKey && isUniqueViolation(error)) {
        const existing = await this.prisma.orderBatch.findUnique({ where: { idempotencyKey } });
        if (existing?.senderId === user.id) return this.batchDto(existing.id, null, true);
      }
      throw error;
    }
    await this.pending.sendLinks(created, context.senderName);
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
    const pending = await this.pending.forBatch(batchId);
    return {
      batchId,
      pickupCode,
      replayed,
      orders: await this.toDtos(orders),
      pending: pending.map((row) => this.pending.toDto(row)),
    };
  }

  // --- Colis en attente de l'adresse de leur client (C4, B3) ----------------------------------

  /**
   * Le point du client est arrivé : la commande est créée dans l'envoi, sous le numéro réservé
   * et avec le même code d'enlèvement. Payée par le solde, ou par le destinataire, elle part
   * aussitôt ; par Mobile Money, elle attend que l'expéditeur valide le paiement. Si elle ne
   * peut pas être créée (solde insuffisant…), le colis reste en attente avec la raison et
   * l'expéditeur est prévenu. [paymentMethod] remplace celui de l'envoi (relance manuelle).
   */
  async releasePending(
    pendingId: string,
    paymentMethod?: z.output<typeof PaymentMethodEnum>,
  ): Promise<'RELEASED' | 'BLOCKED' | 'SKIPPED'> {
    const row = await this.prisma.pendingDelivery.findUnique({
      where: { id: pendingId },
      include: {
        locationLink: true,
        batch: true,
        sender: { select: { id: true, phone: true, roles: true, locale: true } },
      },
    });
    const addressId = row?.locationLink.addressId;
    if (!row || row.orderId || row.cancelledAt || !addressId) return 'SKIPPED';
    const user: AuthUser = row.sender;
    const stored = StoredPending.parse(row.item);
    // Une heure programmée déjà trop proche (ou passée) : le colis part tout de suite.
    const scheduledFor =
      stored.shared.scheduledFor &&
      new Date(stored.shared.scheduledFor).getTime() > Date.now() + 35 * 60_000
        ? stored.shared.scheduledFor
        : undefined;
    const shared: Shared = {
      pickupAddressId: row.batch.pickupAddressId,
      isExpress: stored.shared.isExpress,
      scheduledFor,
      feePayer: stored.shared.feePayer,
      feePaymentMethod: paymentMethod ?? stored.shared.feePaymentMethod,
    };
    const item = { ...stored.item, dropoffAddressId: addressId };
    const firstName = row.recipientName.trim().split(/\s+/)[0] ?? row.recipientName;
    let order: Order;
    try {
      if (!row.batch.pickupCodeSealed) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
      const pickupCode = this.pending.openCode(row.batch.pickupCodeSealed);
      const context = {
        ...(await this.checkCommercialRules(user, shared, [item])),
        parcelWarnings: await this.parcelWarnings(user, [item]),
      };
      const quote = await this.pricing.quote(user, {
        pickup: { addressId: shared.pickupAddressId },
        dropoff: { addressId },
        packageSize: item.packageSize,
        isExpress: shared.isExpress,
        loadingHelp: item.loadingHelp,
        scheduledFor: shared.scheduledFor,
        declaredValue: item.declaredValue,
      });
      const result = await this.prisma.$transaction(async (tx) => {
        const inserted = await this.insert(
          tx,
          user,
          this.orderData(user, shared, item, quote, {
            ...context,
            reference: `TR-${randomReadableId(6)}`,
            pickupCode,
            batchId: row.batchId,
            batchNumber: row.batchNumber,
          }),
        );
        // Deux arrivées du même point en même temps : une seule commande.
        const { count } = await tx.pendingDelivery.updateMany({
          where: { id: row.id, orderId: null, cancelledAt: null },
          data: { orderId: inserted.order.id, blockedReason: null },
        });
        if (count !== 1) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
        return inserted;
      });
      order = result.order;
      await this.events.publishAll(result.changes);
    } catch (error) {
      if (!(error instanceof AppError)) throw error;
      if (error.code === 'PENDING_DELIVERY_CLOSED') return 'SKIPPED';
      await this.pending.block(row.id, error);
      await this.notifications.toUser(user.id, {
        template: 'PENDING_DELIVERY_BLOCKED',
        params: {
          number: row.batchNumber,
          name: firstName,
          reason: localizedMessage(error, resolveLocale(undefined, user.locale)),
        },
        data: { type: 'pending_delivery.blocked', pendingId: row.id },
      });
      return 'BLOCKED';
    }
    await this.pending.forgetCodeIfDone(row.batchId);
    const toPay = order.status === 'CREATED' && !readyForDispatch(order);
    await this.notifications.toUser(user.id, {
      template: toPay ? 'PENDING_DELIVERY_TO_PAY' : 'PENDING_DELIVERY_RELEASED',
      params: {
        number: row.batchNumber,
        name: firstName,
        amount: order.totalPrice.toLocaleString('fr-FR'),
      },
      data: { type: 'pending_delivery.released', pendingId: row.id, orderId: order.id },
      orderId: order.id,
    });
    return 'RELEASED';
  }

  /**
   * Colis en attente de l'expéditeur. Un point arrivé dont la suite s'est perdue (redémarrage)
   * est rattrapé ici : le colis part avant d'être listé.
   */
  async listPending(user: AuthUser, open: boolean): Promise<z.output<typeof PendingDeliveryDto>[]> {
    const stuck = await this.prisma.pendingDelivery.findMany({
      where: {
        senderId: user.id,
        orderId: null,
        cancelledAt: null,
        blockedReason: null,
        locationLink: { submittedAt: { not: null } },
      },
      select: { id: true },
      take: 20,
    });
    for (const { id } of stuck) await this.releasePending(id);
    return (await this.pending.list(user, open)).map((row) => this.pending.toDto(row));
  }

  /** Relance d'un colis bloqué (solde rechargé, ou autre moyen de paiement choisi). */
  async retryPending(
    user: AuthUser,
    id: string,
    paymentMethod: z.output<typeof PaymentMethodEnum> | undefined,
  ): Promise<z.output<typeof PendingDeliveryDto>> {
    const row = await this.pending.owned(user, id);
    if (row.orderId || row.cancelledAt) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
    if (!row.locationLink.submittedAt) throw AppError.conflict('PENDING_NOT_BLOCKED');
    await this.releasePending(id, paymentMethod);
    return this.pending.toDto(await this.pending.owned(user, id));
  }

  async cancelPending(user: AuthUser, id: string): Promise<z.output<typeof PendingDeliveryDto>> {
    return this.pending.toDto(await this.pending.cancel(user, id));
  }

  async resendPending(user: AuthUser, id: string): Promise<z.output<typeof PendingDeliveryDto>> {
    const sender = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      include: { merchant: true },
    });
    const senderName = sender.merchant?.shopName ?? sender.fullName ?? 'Un expéditeur';
    return this.pending.toDto(await this.pending.resend(user, id, senderName));
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
    // Les colis d'un envoi qui partiront plus tard recevront ce nouveau code.
    const batchCode =
      order.batchId && !returning
        ? [
            this.prisma.orderBatch.updateMany({
              where: { id: order.batchId, pickupCodeSealed: { not: null } },
              data: { pickupCodeSealed: this.pending.sealCode(pickupCode) },
            }),
          ]
        : [];
    await this.prisma.$transaction([
      ...batchCode,
      ...siblings.map((sibling) =>
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
    ]);
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
