import { z } from 'zod';
import { Latitude, Longitude } from '../geo/geo.schemas.js';
import { VehicleTypeEnum } from '../riders/riders.schemas.js';

export const SurchargeCodeEnum = z
  .enum(['EXPRESS', 'HEAVY_PARCEL', 'NIGHT', 'FAILED_ATTEMPT', 'RETURN', 'WEATHER'])
  .meta({ id: 'SurchargeCode' });
export const PackageSizeEnum = z
  .enum(['S', 'M', 'L', 'XL'])
  .meta({ id: 'PackageSize', description: 'S ≤ 2 kg, M ≤ 5 kg, L ≤ 10 kg, XL ≤ 20 kg' });
export const PromoKindEnum = z
  .enum(['FIXED_AMOUNT', 'PERCENT', 'FIXED_PRICE'])
  .meta({ id: 'PromoKind' });

const Fcfa = z.int().min(0).max(10_000_000);

export const PricingGridBody = z
  .object({
    name: z.string().trim().min(2).max(80),
    city: z.string().trim().min(2).max(60),
    vehicleType: VehicleTypeEnum.default('MOTORBIKE'),
    riderShareBps: z.int().min(0).max(10_000).default(8000),
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
      .max(6)
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
    basePrice: z.int(),
    surcharges: z.array(z.object({ code: SurchargeCodeEnum, amount: z.int() })),
    discountTotal: z.int(),
    totalPrice: z.int(),
    promoCode: z.string().nullable(),
  })
  .meta({ id: 'Quote' });
