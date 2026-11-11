import { Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import type { Prisma } from '../generated/prisma/client.js';
import { OrdersService } from '../orders/orders.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { lateness, latenessRules } from './lateness.js';
import type {
  AdminOrderDto,
  AdminOrderListQuery,
  AdminOrderPageDto,
  AdminOrderRowDto,
  OrderNoteDto,
} from './admin-orders.schemas.js';

const ACTIVE: OrderStatus[] = [
  'CREATED',
  'SEARCHING_RIDER',
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
];
/** Avant l'enlèvement : l'équipe peut encore annuler ou confier la course à un autre livreur. */
const BEFORE_PICKUP: OrderStatus[] = ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'];

/** Début (UTC) d'un jour de Douala (UTC+1, sans heure d'été) donné au format AAAA-MM-JJ. */
export function doualaDayStart(day: string): Date {
  const [year, month, date] = day.split('-').map(Number);
  return new Date(Date.UTC(year ?? 1970, (month ?? 1) - 1, date ?? 1) - 3_600_000);
}

const ROW_INCLUDE = {
  sender: { select: { fullName: true, phone: true } },
  merchant: { select: { shopName: true } },
  rider: { select: { id: true, user: { select: { fullName: true, phone: true } } } },
  pickupAddress: { select: { neighborhood: { select: { name: true } } } },
  dropoffAddress: { select: { neighborhood: { select: { name: true } } } },
} as const;

const STOP_SELECT = {
  select: {
    label: true,
    landmark: true,
    latitude: true,
    longitude: true,
    contactName: true,
    contactPhone: true,
    photoKey: true,
    voiceNoteKey: true,
    neighborhood: { select: { name: true } },
  },
} as const;

/**
 * Commandes vues par l'équipe (H2) : recherche, fiche complète avec l'historique, notes
 * internes, annulation. La réattribution passe par l'attribution manuelle (D3).
 */
@Injectable()
export class AdminOrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly orders: OrdersService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async list(
    query: z.output<typeof AdminOrderListQuery>,
    now = new Date(),
  ): Promise<z.output<typeof AdminOrderPageDto>> {
    const and: Prisma.OrderWhereInput[] = [];
    const q = query.q?.trim();
    if (q) {
      const digits = q.replace(/\D/g, '');
      const or: Prisma.OrderWhereInput[] = [
        { reference: { contains: q.toUpperCase() } },
        { recipientName: { contains: q, mode: 'insensitive' } },
        { sender: { fullName: { contains: q, mode: 'insensitive' } } },
        { merchant: { shopName: { contains: q, mode: 'insensitive' } } },
      ];
      if (digits.length >= 4) {
        or.push(
          { recipientPhone: { contains: digits } },
          { sender: { phone: { contains: digits } } },
        );
      }
      and.push({ OR: or });
    }
    if (query.from) and.push({ createdAt: { gte: doualaDayStart(query.from) } });
    if (query.to) {
      and.push({ createdAt: { lt: new Date(doualaDayStart(query.to).getTime() + 86_400_000) } });
    }
    if (query.riderId) and.push({ riderId: query.riderId });
    switch (query.view) {
      case 'active':
        and.push({ status: { in: ACTIVE } });
        break;
      case 'delivered':
        and.push({ status: 'DELIVERED' });
        break;
      case 'cancelled':
        and.push({ status: { in: ['CANCELLED', 'RETURNED'] } });
        break;
      case 'problems':
        and.push({ OR: await this.problemFilters(now) });
        break;
      case 'all':
        break;
    }
    const where: Prisma.OrderWhereInput = and.length > 0 ? { AND: and } : {};
    const [rows, total] = await Promise.all([
      this.prisma.order.findMany({
        where,
        orderBy: { id: 'desc' },
        take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
        include: ROW_INCLUDE,
      }),
      this.prisma.order.count({ where }),
    ]);
    const rules = latenessRules(this.env);
    const items = rows.slice(0, query.limit).map((order): z.output<typeof AdminOrderRowDto> => {
      const delay = lateness(order, rules, now);
      return {
        id: order.id,
        reference: order.reference,
        status: order.status,
        createdAt: order.createdAt.toISOString(),
        scheduledFor: order.scheduledFor?.toISOString() ?? null,
        isExpress: order.isExpress,
        isBulky: order.packageSize === 'BULKY',
        senderName: order.merchant?.shopName ?? order.sender.fullName,
        senderPhone: order.sender.phone,
        recipientName: order.recipientName,
        rider: order.rider
          ? { id: order.rider.id, name: order.rider.user.fullName, phone: order.rider.user.phone }
          : null,
        pickupNeighborhood: order.pickupAddress.neighborhood?.name ?? null,
        dropoffNeighborhood: order.dropoffAddress.neighborhood?.name ?? null,
        totalPrice: order.totalPrice,
        codAmount: order.codAmount,
        delay: delay ? { ...delay, dueAt: delay.dueAt.toISOString() } : null,
      };
    });
    return {
      items,
      nextCursor: rows.length > query.limit ? (items.at(-1)?.id ?? null) : null,
      total,
    };
  }

  /**
   * Commandes qui demandent une action : échec en attente, recherche sans livreur signalée,
   * remise sans code à valider, alerte de trajet non vue, retard (calculé sur les commandes
   * en cours, peu nombreuses).
   */
  private async problemFilters(now: Date): Promise<Prisma.OrderWhereInput[]> {
    const rules = latenessRules(this.env);
    const active = await this.prisma.order.findMany({
      where: { status: { in: ['SEARCHING_RIDER', 'ASSIGNED', 'PICKED_UP', 'IN_DELIVERY'] } },
      select: {
        id: true,
        status: true,
        distanceMeters: true,
        createdAt: true,
        searchingSince: true,
        assignedAt: true,
        pickedUpAt: true,
        failedAt: true,
      },
      take: 5_000,
    });
    const late = active.filter((order) => lateness(order, rules, now) !== null).map((o) => o.id);
    return [
      { status: 'DELIVERY_FAILED' },
      { status: 'SEARCHING_RIDER', dispatchAlertedAt: { not: null } },
      {
        status: 'IN_DELIVERY',
        proofs: { some: { kind: 'DELIVERY', codeVerified: false, supportValidatorId: null } },
      },
      { courseAlerts: { some: { acknowledgedAt: null } } },
      ...(late.length > 0 ? [{ id: { in: late } }] : []),
    ];
  }

  async detail(id: string, now = new Date()): Promise<z.output<typeof AdminOrderDto>> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: {
        sender: { select: { id: true, fullName: true, phone: true } },
        merchant: { select: { shopName: true } },
        rider: {
          select: {
            id: true,
            vehicleType: true,
            plateNumber: true,
            user: { select: { fullName: true, phone: true } },
          },
        },
        pickupAddress: STOP_SELECT,
        dropoffAddress: STOP_SELECT,
        events: {
          orderBy: { occurredAt: 'asc' },
          include: { actor: { select: { fullName: true, phone: true } } },
        },
        proofs: { orderBy: { occurredAt: 'asc' } },
        codCollection: true,
        courseAlerts: { orderBy: { createdAt: 'desc' } },
        notes: {
          orderBy: { createdAt: 'desc' },
          include: { author: { select: { fullName: true, phone: true } } },
        },
      },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const delay = lateness(order, latenessRules(this.env), now);
    const stop = (address: typeof order.pickupAddress) => ({
      label: address.label,
      landmark: address.landmark,
      neighborhood: address.neighborhood?.name ?? null,
      latitude: address.latitude,
      longitude: address.longitude,
      contactName: address.contactName,
      contactPhone: address.contactPhone,
      hasPhoto: address.photoKey !== null,
      hasVoiceNote: address.voiceNoteKey !== null,
    });
    const iso = (at: Date | null) => at?.toISOString() ?? null;
    return {
      id: order.id,
      reference: order.reference,
      status: order.status,
      createdAt: order.createdAt.toISOString(),
      updatedAt: order.updatedAt.toISOString(),
      scheduledFor: iso(order.scheduledFor),
      isExpress: order.isExpress,
      delay: delay ? { ...delay, dueAt: delay.dueAt.toISOString() } : null,
      parcel: {
        size: order.packageSize,
        contents: order.packageContents,
        description: order.packageDescription,
        fragile: order.isFragile,
        loadingHelp: order.loadingHelp,
        declaredValue: order.declaredValue,
        instructions: order.instructions,
      },
      sender: {
        id: order.sender.id,
        name: order.sender.fullName,
        phone: order.sender.phone,
        shopName: order.merchant?.shopName ?? null,
      },
      recipient: {
        name: order.recipientName,
        phone: order.recipientPhone,
        confirmedAt: iso(order.recipientConfirmedAt),
        available: order.recipientAvailable,
        note: order.recipientNote,
      },
      pickup: stop(order.pickupAddress),
      dropoff: stop(order.dropoffAddress),
      rider: order.rider
        ? {
            id: order.rider.id,
            name: order.rider.user.fullName,
            phone: order.rider.user.phone,
            vehicleType: order.rider.vehicleType,
            plateNumber: order.rider.plateNumber,
          }
        : null,
      price: {
        distanceMeters: order.distanceMeters,
        basePrice: order.basePrice,
        surchargesTotal: order.surchargesTotal,
        discountTotal: order.discountTotal,
        totalPrice: order.totalPrice,
        riderEarning: order.riderEarning,
        platformFee: order.platformFee,
        retryFee: order.retryFee,
        returnFee: order.returnFee,
        feePayer: order.feePayer,
        feePaymentMethod: order.feePaymentMethod,
        feePaidAt: iso(order.feePaidAt),
      },
      cod:
        order.codAmount > 0
          ? {
              amount: order.codAmount,
              collectedAmount: order.codCollection?.collectedAmount ?? null,
              method: order.codCollection?.method ?? null,
              collectedAt: iso(order.codCollection?.collectedAt ?? null),
            }
          : null,
      attempts: order.attemptCount,
      failure:
        order.failedAt || order.failureReason
          ? {
              reason: order.failureReason,
              at: iso(order.failedAt),
              decision: order.failureDecision,
            }
          : null,
      cancelReason: order.cancelReason,
      timeline: order.events.map((event) => ({
        id: event.id,
        at: event.occurredAt.toISOString(),
        from: event.fromStatus,
        to: event.toStatus,
        actorRole: event.actorRole,
        actorName: event.actor?.fullName ?? event.actor?.phone ?? null,
        note: event.note,
        failureReason: event.failureReason,
      })),
      proofs: order.proofs.map((proof) => ({
        id: proof.id,
        kind: proof.kind,
        at: proof.occurredAt.toISOString(),
        codeVerified: proof.codeVerified,
        receivedBy: proof.receivedBy,
        hasPhoto: proof.photoKey !== null,
        validatedBySupport: proof.supportValidatorId !== null,
      })),
      courseAlerts: order.courseAlerts.map((alert) => ({
        id: alert.id,
        orderId: alert.orderId,
        reference: order.reference,
        riderId: alert.riderId,
        kind: alert.kind,
        details:
          alert.details && typeof alert.details === 'object' && !Array.isArray(alert.details)
            ? (alert.details as Record<string, unknown>)
            : {},
        createdAt: alert.createdAt.toISOString(),
        acknowledgedAt: iso(alert.acknowledgedAt),
        note: alert.note,
      })),
      notes: order.notes.map(noteDto),
      can: {
        cancel: BEFORE_PICKUP.includes(order.status),
        reassign: BEFORE_PICKUP.includes(order.status),
      },
    };
  }

  async addNote(
    user: AuthUser,
    orderId: string,
    body: string,
  ): Promise<z.output<typeof OrderNoteDto>> {
    const exists = await this.prisma.order.count({ where: { id: orderId } });
    if (exists === 0) throw AppError.notFound('ORDER_NOT_FOUND');
    const note = await this.prisma.orderNote.create({
      data: { orderId, authorId: user.id, body },
      include: { author: { select: { fullName: true, phone: true } } },
    });
    return noteDto(note);
  }

  /** Annulation par l'équipe, avant l'enlèvement, avec une raison (tracée et notifiée). */
  async cancel(
    user: AuthUser,
    orderId: string,
    reason: string,
    request: Request,
  ): Promise<z.output<typeof AdminOrderDto>> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { status: true },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    if (!BEFORE_PICKUP.includes(order.status)) {
      throw AppError.conflict('ORDER_NOT_CANCELLABLE', { status: order.status });
    }
    await this.orders.adminTransition(user, orderId, { to: 'CANCELLED', note: reason }, request);
    return this.detail(orderId);
  }
}

function noteDto(note: {
  id: string;
  body: string;
  createdAt: Date;
  author: { fullName: string | null; phone: string };
}): z.output<typeof OrderNoteDto> {
  return {
    id: note.id,
    body: note.body,
    createdAt: note.createdAt.toISOString(),
    authorName: note.author.fullName,
    authorPhone: note.author.phone,
  };
}
