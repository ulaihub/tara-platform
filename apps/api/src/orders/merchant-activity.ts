import { Controller, Get, Injectable } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { addDays, periodStart } from '../common/time.js';
import { ApiZodQuery, ApiZodResponse, ValidQuery } from '../common/validation/zod.js';
import { PrismaService } from '../prisma/prisma.service.js';

export const ActivityPeriodEnum = z.enum(['day', 'week', 'month']).meta({ id: 'ActivityPeriod' });

export const MerchantActivityQuery = z.object({ period: ActivityPeriodEnum.default('week') });

export const MerchantActivityDto = z
  .object({
    period: ActivityPeriodEnum,
    /** Début et fin de la période (heure du Cameroun), la fin exclue. */
    from: z.iso.datetime(),
    to: z.iso.datetime(),
    /** Jour : tranches de 2 h de 8 h à 22 h ; semaine : lundi → dimanche ; mois : semaines. */
    buckets: z.array(
      z.object({
        from: z.iso.datetime(),
        to: z.iso.datetime(),
        /** Ventes encaissées à la livraison (FCFA). */
        sales: z.int(),
        deliveries: z.int(),
      }),
    ),
    deliveries: z.int(),
    collected: z.int(),
    /** Part des colis livrés parmi ceux livrés ou retournés (0 à 100), null sans colis fini. */
    successRate: z.int().nullable(),
    /**
     * Évolution par rapport au même moment de la période précédente (hier à la même heure,
     * la semaine dernière au même jour…) : en %, et en points pour la réussite ; null sans base.
     */
    deliveriesChange: z.int().nullable(),
    collectedChange: z.int().nullable(),
    successRateChange: z.int().nullable(),
    /** Délai moyen entre la commande (ou l'heure prévue) et la livraison, en minutes. */
    averageMinutes: z.int().nullable(),
    /** Quartiers les plus livrés (4 au plus), part des livraisons en %. */
    zones: z.array(z.object({ name: z.string(), share: z.int() })),
  })
  .meta({ id: 'MerchantActivity' });

type Activity = z.output<typeof MerchantActivityDto>;
type Period = z.output<typeof ActivityPeriodEnum>;

/** Minuit (UTC) d'une date locale au Cameroun (UTC+1 toute l'année). */
const localMidnight = (year: number, month: number, day: number): Date =>
  new Date(Date.UTC(year, month - 1, day) - 3_600_000);

/** Bornes de la période en cours et de la précédente. */
export function activityBounds(
  period: Period,
  now: Date,
): { start: Date; end: Date; previousStart: Date } {
  const start = periodStart(period, now);
  if (period === 'day') return { start, end: addDays(start, 1), previousStart: addDays(start, -1) };
  if (period === 'week')
    return { start, end: addDays(start, 7), previousStart: addDays(start, -7) };
  const local = new Date(start.getTime() + 3_600_000);
  const year = local.getUTCFullYear();
  const month = local.getUTCMonth() + 1;
  return {
    start,
    end: localMidnight(year, month + 1, 1),
    previousStart: localMidnight(year, month - 1, 1),
  };
}

function bucketsOf(period: Period, start: Date, end: Date): { from: Date; to: Date }[] {
  if (period === 'day') {
    // 8 h, 10 h … 20 h ; la nuit est rattachée à la première ou à la dernière tranche.
    return Array.from({ length: 7 }, (_, i) => ({
      from: new Date(start.getTime() + (8 + 2 * i) * 3_600_000),
      to: new Date(start.getTime() + (10 + 2 * i) * 3_600_000),
    }));
  }
  const step = period === 'week' ? 1 : 7;
  const buckets: { from: Date; to: Date }[] = [];
  for (let from = start; from < end; from = addDays(from, step)) {
    const to = addDays(from, step);
    buckets.push({ from, to: to < end ? to : end });
  }
  return buckets;
}

const percentChange = (current: number, previous: number): number | null =>
  previous > 0 ? Math.round(((current - previous) / previous) * 100) : null;

/**
 * Tableau de bord d'une boutique (« Mon activité ») : livraisons, ventes encaissées,
 * réussite et délai, par jour, semaine ou mois, comparés au même moment de la période
 * précédente ; quartiers les plus livrés.
 */
@Injectable()
export class MerchantActivityService {
  constructor(private readonly prisma: PrismaService) {}

  async activity(userId: string, period: Period, now = new Date()): Promise<Activity> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId } });
    if (!merchant) throw AppError.notFound();
    const { start, end, previousStart } = activityBounds(period, now);
    const previousEnd = new Date(previousStart.getTime() + (now.getTime() - start.getTime()));
    const rows = await this.prisma.order.findMany({
      where: {
        merchantId: merchant.id,
        OR: [
          { status: 'DELIVERED', deliveredAt: { gte: previousStart, lt: end } },
          { status: 'RETURNED', returnedAt: { gte: previousStart, lt: end } },
        ],
      },
      select: {
        status: true,
        codAmount: true,
        createdAt: true,
        scheduledFor: true,
        deliveredAt: true,
        returnedAt: true,
        dropoffAddress: { select: { neighborhood: { select: { name: true } } } },
      },
    });
    const finishedAt = (row: (typeof rows)[number]): Date =>
      (row.status === 'DELIVERED' ? row.deliveredAt : row.returnedAt) ?? row.createdAt;
    const current = rows.filter((row) => finishedAt(row) >= start);
    const previous = rows.filter((row) => finishedAt(row) < previousEnd && finishedAt(row) < start);
    const summary = (list: typeof rows) => {
      const delivered = list.filter((row) => row.status === 'DELIVERED');
      const rate = list.length === 0 ? null : Math.round((delivered.length / list.length) * 100);
      return {
        delivered,
        deliveries: delivered.length,
        collected: delivered.reduce((sum, row) => sum + row.codAmount, 0),
        rate,
      };
    };
    const cur = summary(current);
    const before = summary(previous);

    const buckets = bucketsOf(period, start, end).map(({ from, to }) => ({
      from,
      to,
      sales: 0,
      deliveries: 0,
    }));
    for (const row of cur.delivered) {
      const at = finishedAt(row);
      let index = buckets.findIndex((b) => at >= b.from && at < b.to);
      if (index < 0) index = at < buckets[0]!.from ? 0 : buckets.length - 1;
      const bucket = buckets[index]!;
      bucket.sales += row.codAmount;
      bucket.deliveries += 1;
    }

    const minutes = cur.delivered.map(
      (row) => (finishedAt(row).getTime() - (row.scheduledFor ?? row.createdAt).getTime()) / 60_000,
    );
    const zones = new Map<string, number>();
    for (const row of cur.delivered) {
      const name = row.dropoffAddress.neighborhood?.name;
      if (name) zones.set(name, (zones.get(name) ?? 0) + 1);
    }

    return {
      period,
      from: start.toISOString(),
      to: end.toISOString(),
      buckets: buckets.map((b) => ({
        from: b.from.toISOString(),
        to: b.to.toISOString(),
        sales: b.sales,
        deliveries: b.deliveries,
      })),
      deliveries: cur.deliveries,
      collected: cur.collected,
      successRate: cur.rate,
      deliveriesChange: percentChange(cur.deliveries, before.deliveries),
      collectedChange: percentChange(cur.collected, before.collected),
      successRateChange: cur.rate !== null && before.rate !== null ? cur.rate - before.rate : null,
      averageMinutes:
        minutes.length === 0
          ? null
          : Math.max(0, Math.round(minutes.reduce((a, b) => a + b, 0) / minutes.length)),
      zones: [...zones.entries()]
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .slice(0, 4)
        .map(([name, count]) => ({
          name,
          share: Math.round((count / Math.max(1, cur.deliveries)) * 100),
        })),
    };
  }
}

@ApiTags('Mon compte')
@ApiBearerAuth()
@Controller('me/merchant/activity')
export class MerchantActivityController {
  constructor(private readonly service: MerchantActivityService) {}

  /** « Mon activité » de la boutique (réservé aux comptes boutique). */
  @Get()
  @ApiZodQuery(MerchantActivityQuery)
  @ApiZodResponse(MerchantActivityDto)
  get(
    @CurrentUser() user: AuthUser,
    @ValidQuery(MerchantActivityQuery) query: z.output<typeof MerchantActivityQuery>,
  ): Promise<Activity> {
    return this.service.activity(user.id, query.period);
  }
}
