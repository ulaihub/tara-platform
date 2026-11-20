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

/** Accueil du back-office : la journée en cours (heure du Cameroun), en un coup d'œil. */
export const TodayDto = z
  .object({
    /** Commandes créées depuis minuit, et le même jour de la semaine dernière à la même heure. */
    orders: z.int(),
    previousOrders: z.int(),
    /** Livreur attribué, colis à bord ou en livraison. */
    inProgress: z.int(),
    /** En attente d'un livreur (hors livraisons programmées plus tard). */
    searching: z.int(),
    /** Livreurs validés et actifs (dénominateur de « en ligne »). */
    approvedRiders: z.int(),
    /** Réussite du jour et de la veille (livrés / livrés + rendus) ; null sans données. */
    successRate: z.number().nullable(),
    previousSuccessRate: z.number().nullable(),
    /** Délai médian commande → livraison, aujourd'hui et la veille, en minutes. */
    deliveryMinutes: z.number().nullable(),
    previousDeliveryMinutes: z.number().nullable(),
    /** Encaissé à la porte pour les boutiques aujourd'hui, en FCFA. */
    collected: z.int(),
    /** Commandes créées par heure, de 8 h à 21 h. */
    hourly: z.array(z.object({ hour: z.int(), orders: z.int() })),
    /** Quartiers de livraison les plus demandés aujourd'hui (3 au plus). */
    neighborhoods: z.array(z.object({ name: z.string(), orders: z.int() })),
  })
  .meta({ id: 'MetricsToday' });
