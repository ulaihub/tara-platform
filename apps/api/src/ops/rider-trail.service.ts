import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { PresenceService } from '../dispatch/presence.service.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  DistanceService,
  type GeoPoint,
  URBAN_SPEED_METERS_PER_SECOND,
} from '../routing/distance.service.js';
import { RoadService, sample, type TimedPoint } from '../routing/road.service.js';
import type { RiderTrailDto } from './ops.schemas.js';

/** Statuts où le livreur porte la course (ou va chercher le colis). */
const ON_COURSE: OrderStatus[] = ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'];
/** Points de trajet lus pour la carte (une course urbaine en compte bien moins). */
const MAX_TRACK_POINTS = 1_500;
/** Tracé GPS brut renvoyé quand il ne peut pas être recalé sur les rues. */
const MAX_RAW_POINTS = 300;

type Target = 'pickup' | 'dropoff' | null;

/** Prochain arrêt de la course, d'après son statut et, après un échec, la décision prise. */
export function targetOf(order: {
  status: OrderStatus;
  failureDecision: 'RETRY' | 'RETURN' | null;
}): Target {
  switch (order.status) {
    case 'ASSIGNED':
      return 'pickup';
    case 'PICKED_UP':
    case 'IN_DELIVERY':
      return 'dropoff';
    case 'DELIVERY_FAILED':
      return order.failureDecision === 'RETURN'
        ? 'pickup'
        : order.failureDecision === 'RETRY'
          ? 'dropoff'
          : null;
    default:
      return null;
  }
}

/**
 * Course d'un livreur sur la carte en direct (H1) : chemin parcouru depuis l'acceptation,
 * recalé sur les rues, et itinéraire routier jusqu'au prochain arrêt. Les points viennent
 * du trajet enregistré pendant la course ; la carte ne montre donc rien en dehors des
 * courses (vie privée du livreur).
 */
@Injectable()
export class RiderTrailService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly roads: RoadService,
    private readonly distance: DistanceService,
  ) {}

  async trail(riderId: string, orderId?: string): Promise<z.output<typeof RiderTrailDto>> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { id: riderId },
      select: { id: true },
    });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    const [orders, raw] = await Promise.all([
      this.prisma.order.findMany({
        where: {
          riderId,
          status: { in: ON_COURSE },
          ...(orderId ? { id: orderId } : {}),
        },
        orderBy: { assignedAt: 'desc' },
        take: 1,
        include: {
          pickupAddress: { select: { latitude: true, longitude: true } },
          dropoffAddress: { select: { latitude: true, longitude: true } },
        },
      }),
      this.presence.position(riderId),
    ]);
    const here: GeoPoint | null = raw
      ? ((await this.roads.snap(raw)) ?? { latitude: raw.latitude, longitude: raw.longitude })
      : null;
    const order = orders[0];
    if (!order) {
      return { riderId, order: null, position: here, traveled: null, remaining: null };
    }

    const target = targetOf(order);
    const points = await this.prisma.courseTrackPoint.findMany({
      where: {
        orderId: order.id,
        riderId,
        ...(order.assignedAt ? { recordedAt: { gte: order.assignedAt } } : {}),
      },
      orderBy: { recordedAt: 'desc' },
      take: MAX_TRACK_POINTS,
      select: { latitude: true, longitude: true, recordedAt: true, accuracy: true },
    });
    const timed: TimedPoint[] = points.reverse().map((point) => ({
      latitude: point.latitude,
      longitude: point.longitude,
      at: point.recordedAt,
      accuracy: point.accuracy,
    }));
    // Dernière position connue, plus récente que le dernier point enregistré.
    if (raw && (timed.at(-1)?.at.getTime() ?? 0) < raw.at.getTime()) {
      timed.push({ ...raw, accuracy: raw.accuracy ?? null });
    }

    let traveled: z.output<typeof RiderTrailDto>['traveled'] = null;
    if (timed.length >= 2) {
      const matched = await this.roads.match(timed);
      traveled = matched
        ? { path: matched, onRoads: true }
        : {
            path: sample(timed, MAX_RAW_POINTS).map((point): [number, number] => [
              point.longitude,
              point.latitude,
            ]),
            onRoads: false,
          };
    }

    let remaining: z.output<typeof RiderTrailDto>['remaining'] = null;
    const stop = target === 'pickup' ? order.pickupAddress : target ? order.dropoffAddress : null;
    if (stop && here) {
      const route = await this.distance.path(here, stop, 'full');
      remaining = {
        path: route.path,
        meters: route.meters,
        // Durée prudente : OSRM compte en voiture sur route dégagée, pas en moto dans Douala.
        seconds: Math.max(
          route.seconds ?? 0,
          Math.round(route.meters / URBAN_SPEED_METERS_PER_SECOND),
        ),
        onRoads: route.source === 'osrm',
      };
    }

    return {
      riderId,
      order: { id: order.id, reference: order.reference, status: order.status, target },
      position: here,
      traveled,
      remaining,
    };
  }
}
