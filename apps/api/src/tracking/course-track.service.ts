import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { CAMEROON_TIME_ZONE } from '../common/time.js';
import type { RiderPosition } from '../dispatch/presence.service.js';
import { OrderEventsBus } from '../events/order-events.bus.js';
import { Prisma } from '../generated/prisma/client.js';
import type { CourseAlertKind, OrderStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { type GeoPoint, haversineMeters } from '../routing/distance.service.js';
import { currentStop, summarizeTrack } from './track-analysis.js';
import type { CourseAlertDto, CourseTrackDto } from './tracking.schemas.js';

/** Points détaillés gardés 90 jours, sauf litige ou incident encore ouvert. */
export const TRACK_RETENTION_DAYS = 90;
/** Enlèvement, livraison ou retour validé au-delà : alerte (position du téléphone). */
export const ACTION_FAR_METERS = 200;
/** Arrêt avec le colis à bord au-delà : alerte, sauf près du vendeur ou du client. */
export const LONG_STOP_SECONDS = 15 * 60;
export const NEAR_STOP_METERS = 150;
/** Plus aucune position pendant ce temps : alerte. */
export const TRACK_GAP_SECONDS = 20 * 60;
/**
 * Durée prévue de la livraison (colis à bord) : distance de la course à 15 km/h, vitesse
 * prudente d'une moto dans les embouteillages de Douala, 15 minutes au moins. Alerte au double.
 */
export const EXPECTED_SPEED_MPS = 15_000 / 3600;
export const MIN_EXPECTED_SECONDS = 15 * 60;
export const OVERDUE_FACTOR = 2;
/** Éloignement toléré au-delà de la distance de départ (détours, rues à sens unique). */
export const MOVING_AWAY_METERS = 2_000;
/** Position assez récente pour juger de l'éloignement. */
const FRESH_POINT_SECONDS = 10 * 60;

/** Durée prévue, en secondes, pour livrer une course de cette distance. */
export function expectedDeliverySeconds(distanceMeters: number): number {
  return Math.max(MIN_EXPECTED_SECONDS, Math.round(distanceMeters / EXPECTED_SPEED_MPS));
}
/**
 * Prime d'approche : trajet réellement parcouru de l'acceptation à l'enlèvement, en part de
 * la distance annoncée au moment de la proposition. En dessous : alerte (position déclarée
 * loin du vendeur pour toucher la prime). La route est d'ordinaire plus longue que la ligne
 * droite : la moitié laisse une large marge aux positions manquantes.
 */
export const APPROACH_MIN_TRAVEL_SHARE = 0.5;
/** Un point toutes les ~10 s au plus par course (les positions arrivent toutes les 10 s). */
const MIN_POINT_INTERVAL_MS = 8_000;
/** Points différés acceptés : de l'acceptation à la fin de la course, à ces marges près. */
const BATCH_MARGIN_MS = 2 * 60_000;

const ACTIVE: readonly OrderStatus[] = ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'];
const PARCEL_ON_BOARD: readonly OrderStatus[] = ['PICKED_UP', 'IN_DELIVERY'];

export interface TrackPointInput extends GeoPoint {
  at: Date;
  accuracy?: number | undefined;
  speed?: number | undefined;
  mocked?: boolean | undefined;
}

type ActionKind = 'PICKUP' | 'DELIVERY' | 'FAILURE' | 'RETURN';

/**
 * Trajet des courses (sécurité, litiges, fraude) : chaque position reçue pendant une course
 * est enregistrée, de l'acceptation à la fin, jamais en dehors. Les positions gardées sur le
 * téléphone sans réseau arrivent en lot. Alertes au support : action validée loin de
 * l'adresse, long arrêt avec le colis à bord, position simulée, trajet coupé, prime
 * d'approche sans trajet correspondant. Résumé calculé
 * à la fin ; points détaillés effacés après 90 jours sauf litige ou incident ouvert.
 */
@Injectable()
export class CourseTrackService implements OnModuleInit {
  private readonly logger = new Logger(CourseTrackService.name);
  private readonly lastStored = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly bus: OrderEventsBus,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  onModuleInit(): void {
    // Fin de la course pour ce livreur (livrée, retournée, annulée, rendue) : résumé.
    this.bus.subscribe('course-track', async ({ order, from, to }) => {
      const riderId = order.riderId ?? (from ? await this.lastRiderOf(order.id) : null);
      const left = from !== null && ACTIVE.includes(from) && !ACTIVE.includes(to);
      if (left && riderId) await this.finish(order.id, riderId);
    });
  }

  // --- Enregistrement -----------------------------------------------------------------------

  /** Position reçue en direct pendant les courses en cours du livreur. */
  async record(
    riderId: string,
    orderIds: readonly string[],
    position: RiderPosition,
  ): Promise<void> {
    const now = Date.now();
    const due = orderIds.filter(
      (id) => now - (this.lastStored.get(`${id}:${riderId}`) ?? 0) >= MIN_POINT_INTERVAL_MS,
    );
    if (due.length === 0) return;
    for (const id of due) this.lastStored.set(`${id}:${riderId}`, now);
    try {
      await this.prisma.courseTrackPoint.createMany({
        data: due.map((orderId) => ({ orderId, riderId, ...pointData(position) })),
        skipDuplicates: true,
      });
      if (position.mocked) {
        for (const orderId of due) await this.raiseMocked(orderId, riderId, position);
      }
    } catch (error) {
      // Le trajet ne doit jamais empêcher la présence ni le suivi en direct.
      this.logger.error(
        'Point de trajet non enregistré',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  /**
   * Positions gardées sur le téléphone sans réseau, envoyées au retour du réseau. Seuls les
   * points de la course (de l'acceptation à sa fin) sont gardés ; un renvoi est sans effet.
   */
  async recordBatch(
    userId: string,
    orderId: string,
    points: readonly TrackPointInput[],
  ): Promise<{ accepted: number; ignored: number }> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (order?.riderId !== rider.id || !order.assignedAt)
      throw AppError.notFound('ORDER_NOT_FOUND');
    const now = Date.now();
    const start = order.assignedAt.getTime() - BATCH_MARGIN_MS;
    const ended = ACTIVE.includes(order.status)
      ? now
      : (order.deliveredAt ?? order.cancelledAt ?? order.updatedAt).getTime();
    const end = Math.min(ended + BATCH_MARGIN_MS, now + BATCH_MARGIN_MS);
    const kept = points.filter((p) => p.at.getTime() >= start && p.at.getTime() <= end);
    const result = await this.prisma.courseTrackPoint.createMany({
      data: kept.map((p) => ({ orderId, riderId: rider.id, late: true, ...pointData(p) })),
      skipDuplicates: true,
    });
    const mocked = kept.find((p) => p.mocked);
    if (mocked) await this.raiseMocked(orderId, rider.id, mocked);
    // Course déjà terminée : le résumé tient compte des points arrivés en retard.
    if (!ACTIVE.includes(order.status)) await this.finish(orderId, rider.id);
    return { accepted: result.count, ignored: points.length - kept.length };
  }

  /** Enlèvement, livraison ou retour : la position du téléphone est comparée à l'adresse. */
  async checkAction(
    order: { id: string; riderId: string | null },
    action: ActionKind,
    at: GeoPoint,
    address: GeoPoint,
  ): Promise<void> {
    if (!order.riderId) return;
    const meters = Math.round(haversineMeters(at, address));
    if (meters <= ACTION_FAR_METERS) return;
    // L'action est déjà validée : une alerte manquée ne doit pas la faire échouer.
    try {
      await this.alert(order.id, order.riderId, 'ACTION_FAR', `ACTION_FAR:${action}`, {
        action,
        meters,
        latitude: at.latitude,
        longitude: at.longitude,
      });
    } catch (error) {
      this.logger.error(
        'Alerte de position non créée',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  // --- Surveillance des courses en cours -----------------------------------------------------

  /**
   * Toutes les 5 minutes : long arrêt avec le colis à bord, trajet coupé, livraison bien plus
   * longue que prévu, livreur qui s'éloigne de la destination.
   */
  @Cron('*/5 * * * *', { name: 'course-track-scan', timeZone: CAMEROON_TIME_ZONE })
  async scheduledScan(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.scan(new Date());
  }

  async scan(now: Date): Promise<number> {
    const orders = await this.prisma.order.findMany({
      where: { status: { in: [...ACTIVE] }, riderId: { not: null } },
      include: { pickupAddress: true, dropoffAddress: true },
    });
    // Tournée (2c) : seul l'arrêt en cours est surveillé ; les autres colis attendent leur tour
    // (pas de trajet propre, et le livreur va d'abord ailleurs).
    const watched = new Map<string, (typeof orders)[number]>();
    const rank = (order: (typeof orders)[number]) =>
      (order.status === 'IN_DELIVERY' ? 0 : 1000) + (order.stopSeq ?? 999);
    for (const order of orders) {
      if (!order.tourId) continue;
      const best = watched.get(order.tourId);
      if (!best || rank(order) < rank(best)) watched.set(order.tourId, order);
    }
    let raised = 0;
    for (const order of orders) {
      if (order.tourId && watched.get(order.tourId)?.id !== order.id) continue;
      const riderId = order.riderId as string;
      const since = new Date(now.getTime() - (LONG_STOP_SECONDS + 10 * 60) * 1000);
      const recent = await this.prisma.courseTrackPoint.findMany({
        where: { orderId: order.id, riderId, recordedAt: { gte: since } },
        orderBy: { recordedAt: 'asc' },
      });
      const last = recent.at(-1) ?? (await this.lastPoint(order.id, riderId));
      const silentSince = last?.recordedAt ?? order.assignedAt ?? order.updatedAt;
      const silence = (now.getTime() - silentSince.getTime()) / 1000;
      if (silence >= TRACK_GAP_SECONDS) {
        raised += await this.alert(order.id, riderId, 'TRACK_GAP', 'TRACK_GAP', {
          lastPointAt: last?.recordedAt.toISOString() ?? null,
          minutes: Math.round(silence / 60),
        });
      }
      if (!PARCEL_ON_BOARD.includes(order.status)) continue;

      // Livraison bien plus longue que prévu, colis à bord.
      if (order.pickedUpAt) {
        const elapsed = (now.getTime() - order.pickedUpAt.getTime()) / 1000;
        const expected = expectedDeliverySeconds(order.distanceMeters);
        if (elapsed >= OVERDUE_FACTOR * expected) {
          raised += await this.alert(order.id, riderId, 'OVERDUE', 'OVERDUE', {
            pickedUpAt: order.pickedUpAt.toISOString(),
            minutes: Math.round(elapsed / 60),
            expectedMinutes: Math.round(expected / 60),
          });
        }
      }

      // Livreur bien plus loin de la destination qu'au moment de l'enlèvement.
      if (last && (now.getTime() - last.recordedAt.getTime()) / 1000 <= FRESH_POINT_SECONDS) {
        const start = haversineMeters(order.pickupAddress, order.dropoffAddress);
        const away = haversineMeters(last, order.dropoffAddress);
        if (away >= start + MOVING_AWAY_METERS) {
          raised += await this.alert(order.id, riderId, 'MOVING_AWAY', 'MOVING_AWAY', {
            kilometersFromDropoff: Math.round(away / 100) / 10,
            kilometersAtPickup: Math.round(start / 100) / 10,
            latitude: last.latitude,
            longitude: last.longitude,
          });
        }
      }

      const stop = currentStop(
        recent.map((p) => ({ latitude: p.latitude, longitude: p.longitude, at: p.recordedAt })),
      );
      if (!stop || stop.seconds < LONG_STOP_SECONDS) continue;
      const nearStop =
        haversineMeters(stop.at, order.pickupAddress) <= NEAR_STOP_METERS ||
        haversineMeters(stop.at, order.dropoffAddress) <= NEAR_STOP_METERS;
      if (nearStop) continue;
      raised += await this.alert(order.id, riderId, 'LONG_STOP', 'LONG_STOP', {
        since: stop.since.toISOString(),
        minutes: Math.round(stop.seconds / 60),
        latitude: stop.at.latitude,
        longitude: stop.at.longitude,
      });
    }
    return raised;
  }

  // --- Fin de course et conservation ---------------------------------------------------------

  /** Résumé du trajet d'un livreur sur une course (recalculé si des points arrivent ensuite). */
  async finish(orderId: string, riderId: string): Promise<void> {
    const points = await this.prisma.courseTrackPoint.findMany({
      where: { orderId, riderId },
      orderBy: { recordedAt: 'asc' },
      select: { latitude: true, longitude: true, recordedAt: true, mocked: true },
    });
    const summary = summarizeTrack(
      points.map((p) => ({
        latitude: p.latitude,
        longitude: p.longitude,
        at: p.recordedAt,
        mocked: p.mocked,
      })),
    );
    const data = { ...summary, computedAt: new Date() };
    await this.prisma.courseTrack.upsert({
      where: { orderId_riderId: { orderId, riderId } },
      create: { orderId, riderId, ...data },
      update: data,
    });
    if (summary.longestGapSeconds >= TRACK_GAP_SECONDS) {
      await this.alert(orderId, riderId, 'TRACK_GAP', 'TRACK_GAP', {
        lastPointAt: null,
        minutes: Math.round(summary.longestGapSeconds / 60),
      });
    }
    await this.checkApproach(orderId, riderId);
  }

  /**
   * Prime d'approche payée pour une course : le trajet enregistré jusqu'au vendeur doit
   * correspondre à la distance annoncée dans la proposition (revue de sécurité, phase 7).
   * Sans assez de points, l'alerte de trajet coupé couvre déjà le cas.
   */
  private async checkApproach(orderId: string, riderId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { riderId: true, approachBonus: true, assignedAt: true, pickedUpAt: true },
    });
    if (!order?.assignedAt || !order.pickedUpAt) return;
    if (order.approachBonus <= 0 || order.riderId !== riderId) return;
    const offer = await this.prisma.dispatchOffer.findFirst({
      where: { orderId, riderId, outcome: 'ACCEPTED' },
      orderBy: { offeredAt: 'desc' },
      select: { approachMeters: true },
    });
    const announced = offer?.approachMeters;
    if (!announced) return;
    const points = await this.prisma.courseTrackPoint.findMany({
      where: { orderId, riderId, recordedAt: { gte: order.assignedAt, lte: order.pickedUpAt } },
      orderBy: { recordedAt: 'asc' },
      select: { latitude: true, longitude: true, recordedAt: true, mocked: true },
    });
    if (points.length < 2) return;
    const traveled = summarizeTrack(
      points.map((p) => ({ latitude: p.latitude, longitude: p.longitude, at: p.recordedAt })),
    ).distanceMeters;
    if (traveled >= announced * APPROACH_MIN_TRAVEL_SHARE) return;
    await this.alert(orderId, riderId, 'APPROACH_BONUS', 'APPROACH_BONUS', {
      announcedMeters: announced,
      traveledMeters: Math.round(traveled),
      bonus: order.approachBonus,
    });
  }

  /** Chaque nuit : points de plus de 90 jours effacés, sauf litige ou incident ouvert. */
  @Cron('30 3 * * *', { name: 'course-track-retention', timeZone: CAMEROON_TIME_ZONE })
  async scheduledPurge(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    const purged = await this.purge(new Date());
    this.logger.log(
      `Trajets des courses : ${purged} points effacés (conservation ${TRACK_RETENTION_DAYS} jours)`,
    );
  }

  async purge(now: Date): Promise<number> {
    const cutoff = new Date(now.getTime() - TRACK_RETENTION_DAYS * 24 * 3_600_000);
    const deleted = await this.prisma.$executeRaw`
      DELETE FROM course_track_points p
       WHERE p.recorded_at < ${cutoff}
         AND NOT EXISTS (SELECT 1 FROM tickets t
                          WHERE t.order_id = p.order_id AND t.status IN ('OPEN', 'IN_PROGRESS'))
         AND NOT EXISTS (SELECT 1 FROM safety_alerts s
                          WHERE s.order_id = p.order_id AND s.resolved_at IS NULL)
         AND NOT EXISTS (SELECT 1 FROM course_alerts a
                          WHERE a.order_id = p.order_id AND a.acknowledged_at IS NULL)`;
    await this.prisma.$executeRaw`
      UPDATE course_tracks c SET points_purged_at = ${now}
       WHERE c.points_purged_at IS NULL AND c.ended_at < ${cutoff}
         AND NOT EXISTS (SELECT 1 FROM course_track_points p
                          WHERE p.order_id = c.order_id AND p.rider_id = c.rider_id)`;
    return deleted;
  }

  // --- Consultation par l'équipe ---------------------------------------------------------------

  /** Trajet d'une course pour l'équipe : chaque consultation est tracée dans l'audit. */
  async view(
    actor: AuthUser,
    orderId: string,
    request: Request,
  ): Promise<z.output<typeof CourseTrackDto>> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const [summaries, points, alerts] = await Promise.all([
      this.prisma.courseTrack.findMany({ where: { orderId }, orderBy: { startedAt: 'asc' } }),
      this.prisma.courseTrackPoint.findMany({ where: { orderId }, orderBy: { recordedAt: 'asc' } }),
      this.prisma.courseAlert.findMany({
        where: { orderId },
        orderBy: { createdAt: 'asc' },
        include: { order: { select: { reference: true } } },
      }),
    ]);
    await this.audit.record({
      actor,
      action: 'order.track_viewed',
      entityType: 'order',
      entityId: orderId,
      request,
    });
    return {
      orderId,
      reference: order.reference,
      status: order.status,
      summaries: summaries.map((t) => ({
        riderId: t.riderId,
        pointCount: t.pointCount,
        distanceMeters: t.distanceMeters,
        startedAt: t.startedAt?.toISOString() ?? null,
        endedAt: t.endedAt?.toISOString() ?? null,
        longestGapSeconds: t.longestGapSeconds,
        longestStopSeconds: t.longestStopSeconds,
        mockedPoints: t.mockedPoints,
        pointsPurgedAt: t.pointsPurgedAt?.toISOString() ?? null,
      })),
      points: points.map((p) => ({
        riderId: p.riderId,
        at: p.recordedAt.toISOString(),
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        mocked: p.mocked,
        late: p.late,
      })),
      alerts: alerts.map(alertDto),
    };
  }

  async listAlerts(status: 'open' | 'all'): Promise<z.output<typeof CourseAlertDto>[]> {
    const alerts = await this.prisma.courseAlert.findMany({
      where: status === 'open' ? { acknowledgedAt: null } : {},
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { order: { select: { reference: true } } },
    });
    return alerts.map(alertDto);
  }

  async acknowledge(
    id: string,
    actor: AuthUser,
    note: string | undefined,
  ): Promise<z.output<typeof CourseAlertDto>> {
    const updated = await this.prisma.courseAlert.updateMany({
      where: { id, acknowledgedAt: null },
      data: { acknowledgedAt: new Date(), acknowledgedById: actor.id, note: note ?? null },
    });
    const alert = await this.prisma.courseAlert.findUnique({
      where: { id },
      include: { order: { select: { reference: true } } },
    });
    if (!alert) throw AppError.notFound('COURSE_ALERT_NOT_FOUND');
    if (updated.count === 1) {
      await this.audit.record({
        actor,
        action: 'course_alert.acknowledged',
        entityType: 'course_alert',
        entityId: id,
        after: { note },
      });
    }
    return alertDto(alert);
  }

  // --- Alertes -------------------------------------------------------------------------------

  private async raiseMocked(orderId: string, riderId: string, at: GeoPoint): Promise<void> {
    await this.alert(orderId, riderId, 'MOCK_LOCATION', 'MOCK_LOCATION', {
      latitude: at.latitude,
      longitude: at.longitude,
    });
  }

  /** Une alerte par sujet et par course ; prévient le support en direct. Renvoie 1 si créée. */
  private async alert(
    orderId: string,
    riderId: string,
    kind: CourseAlertKind,
    dedupeKey: string,
    details: Record<string, unknown>,
  ): Promise<number> {
    try {
      const alert = await this.prisma.courseAlert.create({
        data: { orderId, riderId, kind, dedupeKey, details: details as Prisma.InputJsonValue },
        include: { order: { select: { reference: true } } },
      });
      this.realtime.toOps('ops.course-alert', {
        id: alert.id,
        orderId,
        reference: alert.order.reference,
        riderId,
        kind,
        details,
        createdAt: alert.createdAt.toISOString(),
      });
      return 1;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') return 0;
      throw error;
    }
  }

  private async lastPoint(orderId: string, riderId: string) {
    return this.prisma.courseTrackPoint.findFirst({
      where: { orderId, riderId },
      orderBy: { recordedAt: 'desc' },
    });
  }

  private async lastRiderOf(orderId: string): Promise<string | null> {
    const point = await this.prisma.courseTrackPoint.findFirst({
      where: { orderId },
      orderBy: { recordedAt: 'desc' },
      select: { riderId: true },
    });
    return point?.riderId ?? null;
  }
}

function alertDto(alert: {
  id: string;
  orderId: string;
  riderId: string;
  kind: CourseAlertKind;
  details: Prisma.JsonValue;
  createdAt: Date;
  acknowledgedAt: Date | null;
  note: string | null;
  order: { reference: string };
}): z.output<typeof CourseAlertDto> {
  return {
    id: alert.id,
    orderId: alert.orderId,
    reference: alert.order.reference,
    riderId: alert.riderId,
    kind: alert.kind,
    details: (alert.details ?? {}) as Record<string, unknown>,
    createdAt: alert.createdAt.toISOString(),
    acknowledgedAt: alert.acknowledgedAt?.toISOString() ?? null,
    note: alert.note,
  };
}

function pointData(
  p: { latitude: number; longitude: number; at: Date } & Partial<TrackPointInput>,
) {
  return {
    recordedAt: p.at,
    latitude: p.latitude,
    longitude: p.longitude,
    accuracy: p.accuracy ?? null,
    speed: p.speed ?? null,
    mocked: p.mocked ?? false,
  };
}
