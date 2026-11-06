import { Inject, Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { PresenceService } from '../dispatch/presence.service.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SafetyAlertsService } from '../rider-app/safety-alerts.service.js';
import { CourseTrackService } from '../tracking/course-track.service.js';
import { type LatenessRules, lateness } from './lateness.js';
import type { LiveMapDto, LiveOrderDto, LiveRiderDto } from './ops.schemas.js';

/** Commandes en cours affichées sur la carte. */
const LIVE_STATUSES: OrderStatus[] = [
  'CREATED',
  'SEARCHING_RIDER',
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
];
/** Statuts où le colis est confié au livreur (ou en passe de l'être). */
const WITH_RIDER: OrderStatus[] = ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'];
/** Une commande programmée apparaît une heure avant son départ. */
const SCHEDULED_HORIZON_MS = 60 * 60_000;

const STOP = {
  select: {
    latitude: true,
    longitude: true,
    landmark: true,
    neighborhood: { select: { name: true } },
  },
} as const;

/**
 * Carte en direct (H1) : livreurs libres, en course ou hors ligne avec leur dernière
 * position, commandes en cours avec leurs retards, alertes de sécurité et de trajet. Une
 * seule lecture, rafraîchie toutes les quelques secondes par le back-office.
 */
@Injectable()
export class LiveMapService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly safety: SafetyAlertsService,
    private readonly tracks: CourseTrackService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private get rules(): LatenessRules {
    return {
      searchingSeconds: this.env.DISPATCH_ALERT_AFTER_SECONDS,
      pickupMinutes: this.env.LATE_PICKUP_MINUTES,
      deliveryMarginMinutes: this.env.LATE_DELIVERY_MARGIN_MINUTES,
    };
  }

  async snapshot(now = new Date()): Promise<z.output<typeof LiveMapDto>> {
    const [orders, online, safetyAlerts, courseAlerts] = await Promise.all([
      this.prisma.order.findMany({
        where: {
          status: { in: LIVE_STATUSES },
          OR: [
            { status: { not: 'CREATED' } },
            { scheduledFor: null },
            { scheduledFor: { lte: new Date(now.getTime() + SCHEDULED_HORIZON_MS) } },
          ],
        },
        orderBy: { createdAt: 'asc' },
        take: 2_000,
        include: {
          pickupAddress: STOP,
          dropoffAddress: STOP,
          merchant: { select: { shopName: true } },
          sender: { select: { fullName: true } },
          proofs: {
            where: { kind: 'DELIVERY', codeVerified: false, supportValidatorId: null },
            select: { id: true },
            take: 1,
          },
        },
      }),
      this.presence.onlineRiders(),
      this.safety.list('open'),
      this.tracks.listAlerts('open'),
    ]);

    const busy = new Map<string, string[]>();
    for (const order of orders) {
      if (order.riderId && WITH_RIDER.includes(order.status)) {
        busy.set(order.riderId, [...(busy.get(order.riderId) ?? []), order.id]);
      }
    }
    const riders = await this.prisma.riderProfile.findMany({
      where: { OR: [{ status: 'ACTIVE' }, { id: { in: [...busy.keys(), ...online.keys()] } }] },
      select: {
        id: true,
        vehicleType: true,
        plateNumber: true,
        ratingSum: true,
        ratingCount: true,
        user: { select: { fullName: true, phone: true } },
      },
    });
    const positions = await this.presence.positions(riders.map((rider) => rider.id));
    const staleBefore = now.getTime() - this.presence.staleAfterMs;

    const liveRiders = riders.map((rider): z.output<typeof LiveRiderDto> => {
      const seen = online.get(rider.id);
      const orderIds = busy.get(rider.id) ?? [];
      const position = positions.get(rider.id);
      const state = orderIds.length > 0 ? 'ON_COURSE' : seen === undefined ? 'OFFLINE' : 'FREE';
      return {
        id: rider.id,
        name: rider.user.fullName,
        phone: rider.user.phone,
        vehicleType: rider.vehicleType,
        plateNumber: rider.plateNumber,
        state,
        signalLost: state !== 'OFFLINE' && (position?.at.getTime() ?? 0) < staleBefore,
        position: position
          ? {
              latitude: position.latitude,
              longitude: position.longitude,
              heading: position.heading ?? null,
              at: position.at.toISOString(),
            }
          : null,
        orderIds,
        rating:
          rider.ratingCount > 0
            ? Math.round((rider.ratingSum / rider.ratingCount) * 10) / 10
            : null,
      };
    });

    const rules = this.rules;
    const liveOrders = orders.map((order): z.output<typeof LiveOrderDto> => {
      const delay = lateness(order, rules, now);
      return {
        id: order.id,
        reference: order.reference,
        status: order.status,
        isExpress: order.isExpress,
        scheduledFor: order.scheduledFor?.toISOString() ?? null,
        senderName: order.merchant?.shopName ?? order.sender.fullName,
        riderId: order.riderId,
        pickup: stop(order.pickupAddress),
        dropoff: stop(order.dropoffAddress),
        codAmount: order.codAmount,
        createdAt: order.createdAt.toISOString(),
        assignedAt: order.assignedAt?.toISOString() ?? null,
        pickedUpAt: order.pickedUpAt?.toISOString() ?? null,
        delay: delay ? { ...delay, dueAt: delay.dueAt.toISOString() } : null,
        awaitingValidation: order.status === 'IN_DELIVERY' && order.proofs.length > 0,
        awaitingDecision: order.status === 'DELIVERY_FAILED' && order.failureDecision === null,
      };
    });

    return {
      generatedAt: now.toISOString(),
      riders: liveRiders,
      orders: liveOrders,
      safetyAlerts,
      courseAlerts,
      rules: {
        searchingMinutes: rules.searchingSeconds / 60,
        pickupMinutes: rules.pickupMinutes,
        deliveryMarginMinutes: rules.deliveryMarginMinutes,
      },
    };
  }
}

function stop(address: {
  latitude: number;
  longitude: number;
  landmark: string;
  neighborhood: { name: string } | null;
}) {
  return {
    latitude: address.latitude,
    longitude: address.longitude,
    neighborhood: address.neighborhood?.name ?? null,
    landmark: address.landmark,
  };
}
