import { z } from 'zod';

export const MetricsQuery = z.object({
  /** Période : 7, 30 ou 90 derniers jours (aujourd'hui compris), heure du Cameroun. */
  days: z.coerce
    .number()
    .int()
    .refine((value) => [7, 30, 90].includes(value), '7, 30 ou 90')
    .default(30),
});

const Spread = z.object({
  /** Médiane et 9 sur 10, en minutes ; null sans données. */
  median: z.number().nullable(),
  p90: z.number().nullable(),
});

export const MetricsDto = z
  .object({
    period: z.object({ from: z.string(), to: z.string(), days: z.int() }),
    daily: z.array(
      z.object({
        day: z.string(),
        delivered: z.int(),
        failed: z.int(),
        returned: z.int(),
        cancelled: z.int(),
      }),
    ),
    deliveries: z.object({
      created: z.int(),
      delivered: z.int(),
      returned: z.int(),
      cancelled: z.int(),
      /** Livrées / (livrées + retournées). */
      successRate: z.number().nullable(),
      /** Livrées sans échec préalable / livrées. */
      firstAttemptRate: z.number().nullable(),
      /** Même mesure sur la période précédente, pour comparer. */
      previousDelivered: z.int(),
      previousSuccessRate: z.number().nullable(),
    }),
    delays: z.object({
      /** De la commande à l'acceptation par un livreur (hors courses programmées). */
      assign: Spread,
      /** De l'enlèvement à la remise. */
      delivery: Spread,
      /** De la commande à la remise (hors courses programmées). */
      total: Spread,
    }),
    payouts: z.object({
      merchantPayouts: z.int(),
      sameDay: z.int(),
      sameDayRate: z.number().nullable(),
    }),
    riders: z.object({
      active: z.int(),
      /** Courses par livreur et par jour travaillé. */
      perRiderDay: z.number().nullable(),
      top: z.array(
        z.object({
          riderId: z.uuid(),
          name: z.string().nullable(),
          delivered: z.int(),
          rating: z.number().nullable(),
        }),
      ),
    }),
    merchants: z.object({
      active: z.int(),
      previousActive: z.int(),
      /** Boutiques actives la période précédente et encore actives sur celle-ci. */
      retained: z.int(),
      retentionRate: z.number().nullable(),
      new: z.int(),
    }),
    reconciliation: z.object({
      daysChecked: z.int(),
      daysWithIssues: z.int(),
      issues: z.int(),
    }),
    ratings: z.object({
      /** Note moyenne donnée aux livreurs pendant la période (sur 5). */
      average: z.number().nullable(),
      count: z.int(),
      /** Livreurs sous 4/5 (5 notes au moins depuis le début). */
      lowRated: z.int(),
    }),
  })
  .meta({ id: 'Metrics' });
