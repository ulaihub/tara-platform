import { z } from 'zod';
import { Latitude, Longitude } from '../geo/geo.schemas.js';
import { VehicleTypeEnum } from '../riders/riders.schemas.js';

export const SurchargeCodeEnum = z
  .enum(['EXPRESS', 'HEAVY_PARCEL', 'NIGHT', 'FAILED_ATTEMPT', 'RETURN', 'WEATHER', 'HANDLING'])
  .meta({ id: 'SurchargeCode' });
export const PackageSizeEnum = z.enum(['S', 'M', 'L', 'XL', 'BULKY']).meta({
  id: 'PackageSize',
  description:
    'S ≤ 2 kg, M ≤ 5 kg, L ≤ 10 kg, XL ≤ 20 kg ; BULKY : gros objet (électroménager, meuble, plus de 20 kg), tricycle ou camionnette',
});
export const PromoKindEnum = z
  .enum(['FIXED_AMOUNT', 'PERCENT', 'FIXED_PRICE'])
  .meta({ id: 'PromoKind' });

const Fcfa = z.int().min(0).max(10_000_000);

export const PricingGridBody = z
  .object({
    name: z.string().trim().min(2).max(80),
    city: z.string().trim().min(2).max(60),
    vehicleType: VehicleTypeEnum.default('MOTORBIKE'),
    riderShareBps: z.int().min(0).max(10_000).default(7000),
    perKmBeyondLastTier: Fcfa,
    tiers: z
      .array(z.object({ upToMeters: z.int().min(1).max(200_000), price: Fcfa }))
      .min(1)
      .max(20),
    surcharges: z
      .array(
        z.object({
          code: SurchargeCodeEnum,
          amount: Fcfa.optional(),
          percentBps: z.int().min(0).max(10_000).optional(),
          active: z.boolean().default(true),
        }),
      )
      .max(7)
      .default([]),
    /** Active la grille immédiatement ; l'ancienne grille de la ville est archivée. */
    activate: z.boolean().default(false),
  })
  .superRefine((grid, ctx) => {
    const tiers = [...grid.tiers].sort((a, b) => a.upToMeters - b.upToMeters);
    tiers.forEach((tier, index) => {
      const previous = tiers[index - 1];
      if (previous && previous.upToMeters === tier.upToMeters) {
        ctx.addIssue({ code: 'custom', path: ['tiers'], message: 'paliers en double' });
      }
      if (previous && previous.price > tier.price) {
        ctx.addIssue({
          code: 'custom',
          path: ['tiers'],
          message: 'le prix ne peut pas baisser avec la distance',
        });
      }
    });
    const codes = grid.surcharges.map((s) => s.code);
    if (new Set(codes).size !== codes.length) {
      ctx.addIssue({ code: 'custom', path: ['surcharges'], message: 'supplément en double' });
    }
    grid.surcharges.forEach((s, index) => {
      if ((s.amount === undefined) === (s.percentBps === undefined)) {
        ctx.addIssue({
          code: 'custom',
          path: ['surcharges', index],
          message: 'indiquer soit un montant, soit un pourcentage',
        });
      }
    });
  });

export const PricingGridDto = z
  .object({
    id: z.uuid(),
    name: z.string(),
    city: z.string(),
    vehicleType: VehicleTypeEnum,
    riderShareBps: z.int(),
    perKmBeyondLastTier: z.int(),
    active: z.boolean(),
    validFrom: z.iso.datetime(),
    validTo: z.iso.datetime().nullable(),
    tiers: z.array(z.object({ upToMeters: z.int(), price: z.int() })),
    surcharges: z.array(
      z.object({
        code: SurchargeCodeEnum,
        amount: z.int().nullable(),
        percentBps: z.int().nullable(),
        active: z.boolean(),
      }),
    ),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'PricingGrid' });

export const PricingGridListQuery = z.object({ city: z.string().min(1).max(60).optional() });

export const SurchargePatchBody = z.object({ active: z.boolean() });

export const PromoCodeBody = z.object({
  code: z
    .string()
    .trim()
    .toUpperCase()
    .regex(/^[A-Z0-9-]{3,32}$/, 'lettres, chiffres et tirets, 3 à 32 caractères'),
  kind: PromoKindEnum,
  /** FCFA pour FIXED_AMOUNT et FIXED_PRICE ; points de base pour PERCENT (1000 = 10 %). */
  value: z.int().min(1).max(10_000_000),
  maxRedemptions: z.int().min(1).optional(),
  perUserLimit: z.int().min(1).max(100).default(1),
  newCustomersOnly: z.boolean().default(false),
  validFrom: z.iso.datetime().optional(),
  validTo: z.iso.datetime().optional(),
});

export const PromoCodeDto = z
  .object({
    id: z.uuid(),
    code: z.string(),
    kind: PromoKindEnum,
    value: z.int(),
    maxRedemptions: z.int().nullable(),
    perUserLimit: z.int(),
    newCustomersOnly: z.boolean(),
    validFrom: z.iso.datetime(),
    validTo: z.iso.datetime().nullable(),
    active: z.boolean(),
    redemptions: z.int(),
  })
  .meta({ id: 'PromoCode' });

export const PromoPatchBody = z.object({ active: z.boolean() });

/** Point de départ ou d'arrivée : une adresse enregistrée, ou un point GPS pour une estimation. */
export const PointRef = z
  .union([
    z.object({ addressId: z.uuid() }),
    z.object({ latitude: Latitude, longitude: Longitude }),
  ])
  .meta({ id: 'PointRef' });

export const QuoteBody = z.object({
  pickup: PointRef,
  dropoff: PointRef,
  packageSize: PackageSizeEnum,
  isExpress: z.boolean().default(false),
  /** Gros objet : aide au chargement par deux personnes (supplément manutention). */
  loadingHelp: z.boolean().default(false),
  scheduledFor: z.iso.datetime().optional(),
  promoCode: z.string().trim().max(32).optional(),
});

export const QuoteDto = z
  .object({
    city: z.string(),
    currency: z.literal('XAF'),
    distanceMeters: z.int(),
    distanceSource: z.enum(['osrm', 'estimate']),
    estimatedMinutes: z.int().nullable(),
    /** Véhicule de la course : moto, ou tricycle pour un gros objet. */
    vehicleType: VehicleTypeEnum,
    basePrice: z.int(),
    surcharges: z.array(z.object({ code: SurchargeCodeEnum, amount: z.int() })),
    discountTotal: z.int(),
    /** D'où vient la remise : code promo ou tarif pro (le plus avantageux, jamais les deux). */
    discountSource: z.enum(['PROMO', 'VOLUME']).nullable(),
    /** Tarif pro appliqué, en points de base (1000 = 10 %) ; 0 sinon. */
    proDiscountBps: z.int(),
    totalPrice: z.int(),
    promoCode: z.string().nullable(),
    /** Seulement si la livraison échoue (E6) : nouvelle tentative, retour à l'expéditeur. */
    retryFee: z.int(),
    returnFee: z.int(),
  })
  .meta({ id: 'Quote' });

// --- Modèle de prix (H4) : tarif pro, primes des livreurs, simulateur -----------------------

export const VolumeDiscountTier = z.object({
  /** Livraisons réussies du mois à partir desquelles la remise s'applique. */
  fromDeliveries: z.int().min(1).max(100_000),
  /** Remise en points de base (1000 = 10 %), 50 % au plus. */
  percentBps: z.int().min(1).max(5000),
});

export const PricingSettingsBody = z
  .object({
    volumeDiscounts: z.array(VolumeDiscountTier).max(5),
    approachBonusAmount: z.int().min(0).max(5000),
    approachBonusFromMeters: z.int().min(0).max(20_000),
  })
  .superRefine((settings, ctx) => {
    const tiers = [...settings.volumeDiscounts].sort((a, b) => a.fromDeliveries - b.fromDeliveries);
    tiers.forEach((tier, index) => {
      const previous = tiers[index - 1];
      if (!previous) return;
      if (previous.fromDeliveries === tier.fromDeliveries) {
        ctx.addIssue({ code: 'custom', path: ['volumeDiscounts'], message: 'palier en double' });
      } else if (previous.percentBps >= tier.percentBps) {
        ctx.addIssue({
          code: 'custom',
          path: ['volumeDiscounts'],
          message: 'la remise doit grandir avec le nombre de livraisons',
        });
      }
    });
  });

export const PricingSettingsDto = z
  .object({
    city: z.string(),
    volumeDiscounts: z.array(VolumeDiscountTier),
    approachBonusAmount: z.int(),
    approachBonusFromMeters: z.int(),
    /** null : jamais modifiés, les valeurs validées s'appliquent. */
    updatedAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'PricingSettings' });

export const RiderBoostBody = z
  .object({
    city: z.string().trim().min(2).max(60).default('Douala'),
    amount: z.int().min(50).max(5000),
    reason: z.string().trim().min(3).max(120),
    /** Par défaut : maintenant. */
    startsAt: z.iso.datetime().optional(),
    endsAt: z.iso.datetime(),
  })
  .superRefine((boost, ctx) => {
    const start = boost.startsAt ? Date.parse(boost.startsAt) : Date.now();
    const end = Date.parse(boost.endsAt);
    if (end <= start) {
      ctx.addIssue({ code: 'custom', path: ['endsAt'], message: 'la fin doit suivre le début' });
    } else if (end - start > 7 * 24 * 3_600_000) {
      ctx.addIssue({ code: 'custom', path: ['endsAt'], message: '7 jours au plus' });
    }
  });

export const RiderBoostStatusEnum = z
  .enum(['SCHEDULED', 'ACTIVE', 'ENDED', 'CANCELLED'])
  .meta({ id: 'RiderBoostStatus' });

export const RiderBoostDto = z
  .object({
    id: z.uuid(),
    city: z.string(),
    amount: z.int(),
    reason: z.string(),
    startsAt: z.iso.datetime(),
    endsAt: z.iso.datetime(),
    cancelledAt: z.iso.datetime().nullable(),
    status: RiderBoostStatusEnum,
    createdBy: z.string().nullable(),
    /** Courses acceptées avec cette prime, et ce qu'elle a coûté. */
    orders: z.int(),
    paid: z.int(),
  })
  .meta({ id: 'RiderBoost' });

export const RiderBoostListQuery = z.object({ city: z.string().min(1).max(60).optional() });

/** Prix d'une grille (en projet ou active) pour quelques distances, avant de l'enregistrer. */
export const PriceSimulationBody = z.object({
  riderShareBps: z.int().min(0).max(10_000),
  perKmBeyondLastTier: Fcfa,
  tiers: z
    .array(z.object({ upToMeters: z.int().min(1).max(200_000), price: Fcfa }))
    .min(1)
    .max(20),
  distancesMeters: z.array(z.int().min(0).max(200_000)).min(1).max(20),
});

export const PriceSimulationDto = z
  .object({
    rows: z.array(
      z.object({
        distanceMeters: z.int(),
        price: z.int(),
        riderEarning: z.int(),
        platformShare: z.int(),
      }),
    ),
  })
  .meta({ id: 'PriceSimulation' });
