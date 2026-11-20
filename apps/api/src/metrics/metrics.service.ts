import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { cameroonDate, periodStart } from '../common/time.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { MetricsDto, TodayDto } from './metrics.schemas.js';

const TZ = 'Africa/Douala';
const DAY_MS = 86_400_000;

const ratio = (part: number, whole: number): number | null =>
  whole > 0 ? Math.round((part / whole) * 1000) / 1000 : null;
const minutes = (value: number | null | undefined): number | null =>
  value === null || value === undefined ? null : Math.round(Number(value) * 10) / 10;

/**
 * Indicateurs du back-office (H7), heure du Cameroun : livraisons par jour, réussite, délais,
 * reversements le jour même, courses par livreur, rétention des boutiques, contrôle des
 * comptes et notes des livreurs. Comparés à la période précédente de même durée.
 */
@Injectable()
export class MetricsService {
  constructor(private readonly prisma: PrismaService) {}

  async metrics(days: number, now = new Date()): Promise<z.output<typeof MetricsDto>> {
    const to = now;
    const from = new Date(periodStart('day', now).getTime() - (days - 1) * DAY_MS);
    const before = new Date(from.getTime() - days * DAY_MS);

    const [
      daily,
      created,
      outcome,
      previous,
      delays,
      payouts,
      riders,
      perRiderDay,
      merchants,
      newMerchants,
      reports,
      ratings,
      lowRated,
    ] = await Promise.all([
      this.daily(from, to),
      this.prisma.order.count({ where: { createdAt: { gte: from, lt: to } } }),
      this.outcome(from, to),
      this.outcome(before, from),
      this.delays(from, to),
      this.prisma.$queryRaw<{ total: bigint; same_day: bigint }[]>`
        SELECT COUNT(*)::bigint AS total,
               COUNT(*) FILTER (WHERE (completed_at AT TIME ZONE ${TZ})::date
                                    = (requested_at AT TIME ZONE ${TZ})::date)::bigint AS same_day
          FROM payouts
         WHERE beneficiary = 'MERCHANT' AND status = 'SUCCEEDED'
           AND requested_at >= ${from} AND requested_at < ${to}`,
      this.prisma.$queryRaw<
        { rider_id: string; name: string | null; delivered: bigint; rating: number | null }[]
      >`
        SELECT o.rider_id, u.full_name AS name, COUNT(*)::bigint AS delivered,
               CASE WHEN r.rating_count > 0 THEN r.rating_sum::float / r.rating_count END AS rating
          FROM orders o
          JOIN rider_profiles r ON r.id = o.rider_id
          JOIN users u ON u.id = r.user_id
         WHERE o.status = 'DELIVERED' AND o.delivered_at >= ${from} AND o.delivered_at < ${to}
         GROUP BY o.rider_id, u.full_name, r.rating_sum, r.rating_count
         ORDER BY delivered DESC`,
      this.prisma.$queryRaw<{ value: number | null }[]>`
        SELECT AVG(n)::float AS value FROM (
          SELECT COUNT(*) AS n FROM orders
           WHERE status = 'DELIVERED' AND delivered_at >= ${from} AND delivered_at < ${to}
           GROUP BY rider_id, (delivered_at AT TIME ZONE ${TZ})::date) AS per_day`,
      this.prisma.$queryRaw<{ current: string[]; previous: string[] }[]>`
        SELECT
          COALESCE(ARRAY_AGG(DISTINCT merchant_id::text)
                   FILTER (WHERE created_at >= ${from}), '{}') AS current,
          COALESCE(ARRAY_AGG(DISTINCT merchant_id::text)
                   FILTER (WHERE created_at < ${from}), '{}') AS previous
          FROM orders
         WHERE merchant_id IS NOT NULL AND created_at >= ${before} AND created_at < ${to}`,
      this.prisma.merchantProfile.count({ where: { createdAt: { gte: from, lt: to } } }),
      this.prisma.reconciliationReport.findMany({
        // Journées (type date) : minuit UTC du jour, heure du Cameroun.
        where: {
          day: {
            gte: new Date(`${cameroonDate(from)}T00:00:00Z`),
            lte: new Date(`${cameroonDate(to)}T00:00:00Z`),
          },
        },
        select: { status: true, discrepancies: true },
      }),
      this.prisma.$queryRaw<{ average: number | null; count: bigint }[]>`
        SELECT AVG(g.score)::float AS average, COUNT(*)::bigint AS count
          FROM ratings g JOIN rider_profiles r ON r.user_id = g.ratee_id
         WHERE g.created_at >= ${from} AND g.created_at < ${to}`,
      this.prisma.$queryRaw<{ count: bigint }[]>`
        SELECT COUNT(*)::bigint AS count FROM rider_profiles
         WHERE rating_count >= 5 AND rating_sum::float / rating_count < 4`,
    ]);

    const payout = payouts[0];
    const merchantSets = merchants[0] ?? { current: [], previous: [] };
    const current = new Set(merchantSets.current);
    const retained = merchantSets.previous.filter((id) => current.has(id)).length;
    const rating = ratings[0];
    return {
      period: { from: cameroonDate(from), to: cameroonDate(to), days },
      daily,
      deliveries: {
        created,
        delivered: outcome.delivered,
        returned: outcome.returned,
        cancelled: outcome.cancelled,
        successRate: ratio(outcome.delivered, outcome.delivered + outcome.returned),
        firstAttemptRate: ratio(outcome.firstAttempt, outcome.delivered),
        previousDelivered: previous.delivered,
        previousSuccessRate: ratio(previous.delivered, previous.delivered + previous.returned),
      },
      delays,
      payouts: {
        merchantPayouts: Number(payout?.total ?? 0),
        sameDay: Number(payout?.same_day ?? 0),
        sameDayRate: ratio(Number(payout?.same_day ?? 0), Number(payout?.total ?? 0)),
      },
      riders: {
        active: riders.length,
        perRiderDay:
          perRiderDay[0]?.value === null || perRiderDay[0]?.value === undefined
            ? null
            : Math.round(perRiderDay[0].value * 10) / 10,
        top: riders.slice(0, 5).map((row) => ({
          riderId: row.rider_id,
          name: row.name,
          delivered: Number(row.delivered),
          rating: row.rating === null ? null : Math.round(row.rating * 10) / 10,
        })),
      },
      merchants: {
        active: current.size,
        previousActive: merchantSets.previous.length,
        retained,
        retentionRate: ratio(retained, merchantSets.previous.length),
        new: newMerchants,
      },
      reconciliation: {
        daysChecked: reports.length,
        daysWithIssues: reports.filter((report) => report.status === 'DISCREPANCIES').length,
        issues: reports.reduce(
          (sum, report) =>
            sum + (Array.isArray(report.discrepancies) ? report.discrepancies.length : 0),
          0,
        ),
      },
      ratings: {
        average:
          rating?.average === null || rating?.average === undefined
            ? null
            : Math.round(rating.average * 100) / 100,
        count: Number(rating?.count ?? 0),
        lowRated: Number(lowRated[0]?.count ?? 0),
      },
    };
  }

  /**
   * La journée en cours pour l'accueil : commandes (comparées au même jour de la semaine
   * dernière, à la même heure), en cours, réussite et délai (comparés à la veille), encaissé,
   * commandes par heure et quartiers les plus demandés.
   */
  async today(now = new Date()): Promise<z.output<typeof TodayDto>> {
    const start = periodStart('day', now);
    const yesterday = new Date(start.getTime() - DAY_MS);
    const lastWeek = new Date(start.getTime() - 7 * DAY_MS);
    const [orders, previousOrders, inProgress, searching, approvedRiders, outcome, previous] =
      await Promise.all([
        this.prisma.order.count({ where: { createdAt: { gte: start, lt: now } } }),
        this.prisma.order.count({
          where: { createdAt: { gte: lastWeek, lt: new Date(now.getTime() - 7 * DAY_MS) } },
        }),
        this.prisma.order.count({
          where: { status: { in: ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY'] } },
        }),
        this.prisma.order.count({
          where: {
            status: { in: ['CREATED', 'SEARCHING_RIDER'] },
            OR: [{ scheduledFor: null }, { scheduledFor: { lte: now } }],
          },
        }),
        this.prisma.riderProfile.count({ where: { status: 'ACTIVE' } }),
        this.outcome(start, now),
        this.outcome(yesterday, start),
      ]);
    const [delays, previousDelays, collected, hourly, neighborhoods] = await Promise.all([
      this.delays(start, now),
      this.delays(yesterday, start),
      this.prisma.codCollection.aggregate({
        where: { collectedAt: { gte: start, lt: now } },
        _sum: { collectedAmount: true },
      }),
      this.prisma.$queryRaw<{ hour: number; orders: bigint }[]>`
        SELECT h AS hour,
               (SELECT COUNT(*) FROM orders
                 WHERE created_at >= ${start} AND created_at < ${now}
                   AND EXTRACT(HOUR FROM created_at AT TIME ZONE ${TZ}) = h)::bigint AS orders
          FROM generate_series(8, 21) AS h
         ORDER BY h`,
      this.prisma.$queryRaw<{ name: string; orders: bigint }[]>`
        SELECT n.name, COUNT(*)::bigint AS orders
          FROM orders o
          JOIN addresses a ON a.id = o.dropoff_address_id
          JOIN zones n ON n.id = a.neighborhood_id
         WHERE o.created_at >= ${start} AND o.created_at < ${now}
         GROUP BY n.name
         ORDER BY orders DESC, n.name
         LIMIT 3`,
    ]);
    return {
      orders,
      previousOrders,
      inProgress,
      searching,
      approvedRiders,
      successRate: ratio(outcome.delivered, outcome.delivered + outcome.returned),
      previousSuccessRate: ratio(previous.delivered, previous.delivered + previous.returned),
      deliveryMinutes: delays.total.median,
      previousDeliveryMinutes: previousDelays.total.median,
      collected: collected._sum.collectedAmount ?? 0,
      hourly: hourly.map((row) => ({ hour: Number(row.hour), orders: Number(row.orders) })),
      neighborhoods: neighborhoods.map((row) => ({ name: row.name, orders: Number(row.orders) })),
    };
  }

  /** Une ligne par jour de la période, même sans activité. */
  private async daily(from: Date, to: Date) {
    const rows = await this.prisma.$queryRaw<
      { day: string; delivered: bigint; failed: bigint; returned: bigint; cancelled: bigint }[]
    >`
      SELECT d::date::text AS day,
             (SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED'
                AND (delivered_at AT TIME ZONE ${TZ})::date = d::date)::bigint AS delivered,
             (SELECT COUNT(*) FROM orders
                WHERE (failed_at AT TIME ZONE ${TZ})::date = d::date)::bigint AS failed,
             (SELECT COUNT(*) FROM orders
                WHERE (returned_at AT TIME ZONE ${TZ})::date = d::date)::bigint AS returned,
             (SELECT COUNT(*) FROM orders
                WHERE (cancelled_at AT TIME ZONE ${TZ})::date = d::date)::bigint AS cancelled
        FROM generate_series((${from}::timestamptz AT TIME ZONE ${TZ})::date,
                             (${to}::timestamptz AT TIME ZONE ${TZ})::date,
                             interval '1 day') AS d
       ORDER BY d`;
    return rows.map((row) => ({
      day: row.day,
      delivered: Number(row.delivered),
      failed: Number(row.failed),
      returned: Number(row.returned),
      cancelled: Number(row.cancelled),
    }));
  }

  private async outcome(from: Date, to: Date) {
    const [row] = await this.prisma.$queryRaw<
      { delivered: bigint; first_attempt: bigint; returned: bigint; cancelled: bigint }[]
    >`
      SELECT
        COUNT(*) FILTER (WHERE status = 'DELIVERED' AND delivered_at >= ${from}
                           AND delivered_at < ${to})::bigint AS delivered,
        COUNT(*) FILTER (WHERE status = 'DELIVERED' AND attempt_count = 0
                           AND delivered_at >= ${from} AND delivered_at < ${to})::bigint
          AS first_attempt,
        COUNT(*) FILTER (WHERE returned_at >= ${from} AND returned_at < ${to})::bigint
          AS returned,
        COUNT(*) FILTER (WHERE cancelled_at >= ${from} AND cancelled_at < ${to})::bigint
          AS cancelled
        FROM orders
       WHERE delivered_at >= ${from} OR returned_at >= ${from} OR cancelled_at >= ${from}`;
    return {
      delivered: Number(row?.delivered ?? 0),
      firstAttempt: Number(row?.first_attempt ?? 0),
      returned: Number(row?.returned ?? 0),
      cancelled: Number(row?.cancelled ?? 0),
    };
  }

  private async delays(from: Date, to: Date) {
    const [row] = await this.prisma.$queryRaw<
      {
        assign_median: number | null;
        assign_p90: number | null;
        delivery_median: number | null;
        delivery_p90: number | null;
        total_median: number | null;
        total_p90: number | null;
      }[]
    >`
      SELECT
        percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM assigned_at - created_at) / 60)
          FILTER (WHERE scheduled_for IS NULL AND assigned_at IS NOT NULL) AS assign_median,
        percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM assigned_at - created_at) / 60)
          FILTER (WHERE scheduled_for IS NULL AND assigned_at IS NOT NULL) AS assign_p90,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM delivered_at - picked_up_at) / 60)
          FILTER (WHERE picked_up_at IS NOT NULL) AS delivery_median,
        percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM delivered_at - picked_up_at) / 60)
          FILTER (WHERE picked_up_at IS NOT NULL) AS delivery_p90,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM delivered_at - created_at) / 60)
          FILTER (WHERE scheduled_for IS NULL) AS total_median,
        percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM delivered_at - created_at) / 60)
          FILTER (WHERE scheduled_for IS NULL) AS total_p90
        FROM orders
       WHERE status = 'DELIVERED' AND delivered_at >= ${from} AND delivered_at < ${to}
         -- Horodatages incohérents (horloge d'un téléphone, données reprises) écartés.
         AND delivered_at >= created_at
         AND (assigned_at IS NULL OR assigned_at >= created_at)
         AND (picked_up_at IS NULL OR picked_up_at <= delivered_at)`;
    return {
      assign: { median: minutes(row?.assign_median), p90: minutes(row?.assign_p90) },
      delivery: { median: minutes(row?.delivery_median), p90: minutes(row?.delivery_p90) },
      total: { median: minutes(row?.total_median), p90: minutes(row?.total_p90) },
    };
  }
}
