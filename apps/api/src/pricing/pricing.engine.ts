import { cameroonHour } from '../common/time.js';
import type { PackageSize, PromoKind, SurchargeCode } from '../generated/prisma/enums.js';

/**
 * Calcul du prix d'une livraison (C2). Fonction pure, sans accès à la base :
 * tous les cas sont couverts par des tests unitaires.
 *
 *   prix de base   = palier de distance, ou dernier palier + prix par km entamé au-delà
 *   suppléments    = express, colis XL, nuit (20 h – 6 h, heure du Cameroun), météo
 *   part livreur   = (base + suppléments) × part livreur, arrondie à l'inférieur
 *   remise         = code promo, financée par Tara (la part livreur n'est pas réduite)
 *   total          = base + suppléments − remise ; part Tara = total − part livreur
 *   frais d'échec  = nouvelle tentative et retour (montant fixe ou part du prix de base),
 *                    dus seulement si la livraison échoue, jamais dans le total
 */

export interface GridRules {
  riderShareBps: number;
  perKmBeyondLastTier: number;
  tiers: { upToMeters: number; price: number }[];
  surcharges: {
    code: SurchargeCode;
    amount: number | null;
    percentBps: number | null;
    active: boolean;
  }[];
}

export interface PriceInput {
  distanceMeters: number;
  packageSize: PackageSize;
  isExpress: boolean;
  /** Heure d'enlèvement prévue (maintenant, ou le créneau programmé). */
  at: Date;
  promo?: { kind: PromoKind; value: number } | null;
}

export interface PriceBreakdown {
  basePrice: number;
  surcharges: { code: SurchargeCode; amount: number }[];
  surchargesTotal: number;
  subtotal: number;
  discountTotal: number;
  totalPrice: number;
  riderEarning: number;
  platformFee: number;
  /** Frais d'échec, figés avec le prix et annoncés avant de commander (E6). */
  retryFee: number;
  returnFee: number;
}

export const NIGHT_START_HOUR = 20;
export const NIGHT_END_HOUR = 6;

/** Suppléments appliqués à l'échec ou au retour, jamais au moment du devis. */
const AFTER_THE_FACT: SurchargeCode[] = ['FAILED_ATTEMPT', 'RETURN'];

export function basePriceFor(
  rules: Pick<GridRules, 'tiers' | 'perKmBeyondLastTier'>,
  distanceMeters: number,
): number {
  const tiers = [...rules.tiers].sort((a, b) => a.upToMeters - b.upToMeters);
  const last = tiers.at(-1);
  if (!last) throw new Error('Grille tarifaire sans palier');
  const tier = tiers.find((t) => distanceMeters <= t.upToMeters);
  if (tier) return tier.price;
  const extraKm = Math.ceil((distanceMeters - last.upToMeters) / 1000);
  return last.price + extraKm * rules.perKmBeyondLastTier;
}

function applies(code: SurchargeCode, input: PriceInput): boolean {
  switch (code) {
    case 'EXPRESS':
      return input.isExpress;
    case 'HEAVY_PARCEL':
      return input.packageSize === 'XL';
    case 'NIGHT': {
      const hour = cameroonHour(input.at);
      return hour >= NIGHT_START_HOUR || hour < NIGHT_END_HOUR;
    }
    case 'WEATHER':
      // Activé et désactivé par l'équipe des opérations pendant les fortes pluies (C7).
      return true;
    case 'FAILED_ATTEMPT':
    case 'RETURN':
      return false;
  }
}

export function discountFor(promo: { kind: PromoKind; value: number }, subtotal: number): number {
  switch (promo.kind) {
    case 'FIXED_AMOUNT':
      return Math.min(promo.value, subtotal);
    case 'PERCENT':
      return Math.min(Math.floor((subtotal * promo.value) / 10_000), subtotal);
    case 'FIXED_PRICE':
      return Math.max(0, subtotal - promo.value);
  }
}

export function computePrice(rules: GridRules, input: PriceInput): PriceBreakdown {
  const basePrice = basePriceFor(rules, input.distanceMeters);
  const surcharges = rules.surcharges
    .filter((s) => s.active && !AFTER_THE_FACT.includes(s.code) && applies(s.code, input))
    .map((s) => ({
      code: s.code,
      amount: s.amount ?? Math.floor((basePrice * (s.percentBps ?? 0)) / 10_000),
    }))
    .sort((a, b) => a.code.localeCompare(b.code));
  const surchargesTotal = surcharges.reduce((sum, s) => sum + s.amount, 0);
  const subtotal = basePrice + surchargesTotal;
  const riderEarning = Math.floor((subtotal * rules.riderShareBps) / 10_000);
  const discountTotal = input.promo ? discountFor(input.promo, subtotal) : 0;
  const totalPrice = subtotal - discountTotal;
  const failureFee = (code: SurchargeCode) => {
    const rule = rules.surcharges.find((s) => s.code === code && s.active);
    if (!rule) return 0;
    return rule.amount ?? Math.floor((basePrice * (rule.percentBps ?? 0)) / 10_000);
  };
  return {
    basePrice,
    surcharges,
    surchargesTotal,
    subtotal,
    discountTotal,
    totalPrice,
    riderEarning,
    platformFee: totalPrice - riderEarning,
    retryFee: failureFee('FAILED_ATTEMPT'),
    returnFee: failureFee('RETURN'),
  };
}
