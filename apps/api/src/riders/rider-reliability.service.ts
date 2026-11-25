import { Inject, Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import type { KycDocumentType } from '../generated/prisma/enums.js';
import { METERS_PER_MINUTE } from '../ops/lateness.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { RiderHistoryActionEnum, RiderReliabilityDto } from './riders.schemas.js';

type Window = z.output<typeof RiderReliabilityDto>['allTime'];
type HistoryItem = z.output<typeof RiderReliabilityDto>['history'][number];
type HistoryAction = z.output<typeof RiderHistoryActionEnum>;

const DAY = 86_400_000;
const HISTORY_LIMIT = 50;

/** Actions du journal d'audit montrées dans l'historique d'un livreur. */
const HISTORY_ACTIONS: Record<string, HistoryAction | ((after: Json) => HistoryAction)> = {
  'rider.applied': 'APPLIED',
  'rider.approve': 'APPROVED',
  'rider.reject': 'REJECTED',
  'rider.suspend': 'SUSPENDED',
  'rider.reactivate': 'REACTIVATED',
  'rider.cash_overdue': 'CASH_OVERDUE',
  'rider.cash_suspended': 'CASH_SUSPENDED',
  'finance.free_payout_set': 'FREE_PAYOUT_SET',
  'kyc_document.approved': 'DOCUMENT_APPROVED',
  'kyc_document.rejected': 'DOCUMENT_REJECTED',
};

type Json = Record<string, unknown>;

const text = (value: unknown): string | null =>
  typeof value === 'string' && value.trim() ? value.trim() : null;

/** Note montrée avec l'événement : motif, compte rendu ou nouveau seuil. */
function noteOf(action: HistoryAction, after: Json): string | null {
  switch (action) {
    case 'REJECTED':
    case 'SUSPENDED':
      return text(after.reason);
    case 'DOCUMENT_REJECTED':
      return text(after.rejectionReason);
    case 'FREE_PAYOUT_SET':
      return typeof after.freePayoutFrom === 'number'
        ? String(after.freePayoutFrom)
        : after.freePayoutFrom === null
          ? null
          : text(after.freePayoutFrom);
    default:
      return null;
  }
}

/**
 * Fiabilité d'un livreur (H3) : propositions acceptées, courses livrées et à l'heure,
 * échecs, colis refusés, notes, temps en ligne, alertes ; et l'historique des décisions.
 * Tout est relu dans les tables : rien n'est stocké en double.
 */
@Injectable()
export class RiderReliabilityService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async reliability(
    riderId: string,
    now = new Date(),
  ): Promise<z.output<typeof RiderReliabilityDto>> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { id: riderId },
      select: { id: true, userId: true, createdAt: true },
    });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    const last30Days = await this.window(rider, new Date(now.getTime() - 30 * DAY));
    const allTime = await this.window(rider, rider.createdAt);
    const history = await this.history(riderId);
    return { last30Days, allTime, history };
  }

  private async window(rider: { id: string; userId: string }, since: Date): Promise<Window> {
    const offers = await this.prisma.dispatchOffer.groupBy({
      by: ['outcome'],
      where: {
        riderId: rider.id,
        offeredAt: { gte: since },
        outcome: { in: ['ACCEPTED', 'DECLINED', 'EXPIRED'] },
      },
      _count: { _all: true },
    });
    const offerCount = (outcome: string): number =>
      offers.find((group) => group.outcome === outcome)?._count._all ?? 0;

    // À l'heure : livrée dans le temps attendu après l'enlèvement (ou après l'échec, pour
    // une nouvelle tentative), comme pour les alertes de retard de la carte en direct.
    const [delivered] = await this.prisma.$queryRaw<{ delivered: number; onTime: number }[]>`
      SELECT count(*)::int AS "delivered",
        count(*) FILTER (
          WHERE delivered_at <= greatest(picked_up_at, failed_at)
            + make_interval(mins => ceil(distance_meters::numeric / ${METERS_PER_MINUTE})::int
              + ${this.env.LATE_DELIVERY_MARGIN_MINUTES}::int)
        )::int AS "onTime"
      FROM orders
      WHERE rider_id = ${rider.id}::uuid AND status = 'DELIVERED' AND delivered_at >= ${since}`;

    const failed = await this.prisma.orderEvent.count({
      where: {
        actorId: rider.userId,
        actorRole: 'RIDER',
        toStatus: 'DELIVERY_FAILED',
        occurredAt: { gte: since },
      },
    });
    const parcelsRefused = await this.prisma.orderEvent.count({
      where: {
        actorId: rider.userId,
        actorRole: 'RIDER',
        toStatus: 'CANCELLED',
        occurredAt: { gte: since },
      },
    });
    // Notes données au livreur pour ses courses (pas celles reçues comme expéditeur).
    const ratings = await this.prisma.rating.aggregate({
      where: { rateeId: rider.userId, order: { riderId: rider.id }, createdAt: { gte: since } },
      _avg: { score: true },
      _count: { _all: true },
    });
    const [online] = await this.prisma.$queryRaw<{ minutes: number }[]>`
      SELECT coalesce(sum(extract(epoch FROM coalesce(ended_at, last_seen_at) - started_at)) / 60, 0)::int
        AS "minutes"
      FROM rider_online_sessions
      WHERE rider_id = ${rider.id}::uuid AND started_at >= ${since}`;
    const courseAlerts = await this.prisma.courseAlert.count({
      where: { riderId: rider.id, createdAt: { gte: since } },
    });
    const silentWithdrawals = await this.prisma.courseAlert.count({
      where: { riderId: rider.id, kind: 'RIDER_SILENT', createdAt: { gte: since } },
    });
    const sosAlerts = await this.prisma.safetyAlert.count({
      where: { riderId: rider.id, createdAt: { gte: since }, cancelledAt: null },
    });

    const average = ratings._avg.score;
    return {
      offers: {
        accepted: offerCount('ACCEPTED'),
        declined: offerCount('DECLINED'),
        expired: offerCount('EXPIRED'),
      },
      deliveries: {
        delivered: delivered?.delivered ?? 0,
        onTime: delivered?.onTime ?? 0,
        failed,
        parcelsRefused,
      },
      rating: {
        average: average === null ? null : Math.round(average * 10) / 10,
        count: ratings._count._all,
      },
      onlineMinutes: online?.minutes ?? 0,
      courseAlerts,
      sosAlerts,
      silentWithdrawals,
    };
  }

  /** Décisions, entretiens, pièces examinées et suspensions, du plus récent au plus ancien. */
  private async history(riderId: string): Promise<HistoryItem[]> {
    const documents = await this.prisma.kycDocument.findMany({
      where: { riderId },
      select: { id: true, type: true },
    });
    const documentTypes = new Map<string, KycDocumentType>(
      documents.map((doc) => [doc.id, doc.type]),
    );
    const logs = await this.prisma.auditLog.findMany({
      where: {
        action: { in: Object.keys(HISTORY_ACTIONS) },
        OR: [
          { entityType: { in: ['rider_profile', 'rider'] }, entityId: riderId },
          { entityType: 'kyc_document', entityId: { in: [...documentTypes.keys()] } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: HISTORY_LIMIT,
    });
    const actorIds = [...new Set(logs.map((log) => log.actorId).filter((id) => id !== null))];
    const actors = await this.prisma.user.findMany({
      where: { id: { in: actorIds } },
      select: { id: true, fullName: true, phone: true },
    });
    const names = new Map(actors.map((user) => [user.id, user.fullName ?? user.phone]));

    return logs.map((log) => {
      const after = (log.after ?? {}) as Json;
      const mapping = HISTORY_ACTIONS[log.action];
      const action = typeof mapping === 'function' ? mapping(after) : (mapping as HistoryAction);
      return {
        at: log.createdAt.toISOString(),
        action,
        // Le livreur lui-même (candidature) n'est pas un membre de l'équipe.
        by: log.actorId && action !== 'APPLIED' ? (names.get(log.actorId) ?? null) : null,
        note: noteOf(action, after),
        documentType:
          log.entityType === 'kyc_document' ? (documentTypes.get(log.entityId) ?? null) : null,
      };
    });
  }
}
