import { cameroonHour } from '../common/time.js';
import type { PackageSize, PromoKind, SurchargeCode } from '../generated/prisma/enums.js';

/**
 * Calcul du prix d'une livraison (C2). Fonction pure, sans accès à la base :
 * tous les cas sont couverts par des tests unitaires.
 *
 *   prix de base   = palier de distance, ou dernier palier + prix par km entamé au-delà
 *   suppléments    = express, colis XL, nuit (20 h – 6 h, heure du Cameroun), météo,
 *                    manutention (gros objet, aide au chargement demandée)
 *   part livreur   = (base + suppléments) × part livreur, arrondie à l'inférieur
 *   remise         = code promo ou tarif pro (le plus avantageux des deux, jamais les deux),
 *                    financée par Tara : la part livreur n'est pas réduite. Le tarif pro est
 *                    arrondi à 50 F pour que le total se paie facilement en espèces.
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
  /** Gros objet : aide au chargement demandée (supplément manutention). */
  loadingHelp?: boolean;
  /** Heure d'enlèvement prévue (maintenant, ou le créneau programmé). */
  at: Date;
  promo?: { kind: PromoKind; value: number } | null;
  /** Tarif pro de la boutique selon ses livraisons du mois, en points de base (H4). */
  volumeDiscountBps?: number;
}

export interface PriceBreakdown {
  basePrice: number;
  surcharges: { code: SurchargeCode; amount: number }[];
  surchargesTotal: number;
  subtotal: number;
  discountTotal: number;
  /** D'où vient la remise : code promo, tarif pro, ou aucune. */
  discountSource: 'PROMO' | 'VOLUME' | null;
  /** Tarif pro appliqué (points de base) ; 0 si la remise vient d'un code promo. */
  proDiscountBps: number;
  totalPrice: number;
  riderEarning: number;
  platformFee: number;
  /** Frais d'échec, figés avec le prix et annoncés avant de commander (E6). */
  retryFee: number;
  returnFee: number;
}

export const NIGHT_START_HOUR = 20;
/** Pas d'arrondi du tarif pro : la monnaie se rend en pièces de 50 F. */
export const CASH_STEP = 50;
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
    case 'HANDLING':
      return input.packageSize === 'BULKY' && input.loadingHelp === true;
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
  const promoDiscount = input.promo ? discountFor(input.promo, subtotal) : 0;
  const volumeBps = Math.max(0, Math.min(10_000, input.volumeDiscountBps ?? 0));
  const volumeDiscount = Math.min(
    subtotal,
    Math.round((subtotal * volumeBps) / 10_000 / CASH_STEP) * CASH_STEP,
  );
  const volumeWins = volumeDiscount > 0 && volumeDiscount > promoDiscount;
  const discountTotal = volumeWins ? volumeDiscount : promoDiscount;
  const discountSource = volumeWins ? 'VOLUME' : promoDiscount > 0 ? 'PROMO' : null;
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
    discountSource,
    proDiscountBps: volumeWins ? volumeBps : 0,
    totalPrice,
    riderEarning,
    platformFee: totalPrice - riderEarning,
    retryFee: failureFee('FAILED_ATTEMPT'),
    returnFee: failureFee('RETURN'),
  };
}

/**
 * Véhicule de la course selon le colis : moto jusqu'au XL (20 kg), tricycle au-delà (gros
 * objet). La grille tarifaire suit le véhicule.
 */
export function vehicleForParcel(packageSize: PackageSize): 'MOTORBIKE' | 'TRICYCLE' {
  return packageSize === 'BULKY' ? 'TRICYCLE' : 'MOTORBIKE';
}

/** Le véhicule peut-il porter ce colis ? Un gros objet ne monte pas sur une moto. */
export function vehicleCarries(
  vehicle: 'MOTORBIKE' | 'TRICYCLE' | 'CAR',
  size: PackageSize,
): boolean {
  return size !== 'BULKY' || vehicle !== 'MOTORBIKE';
}

/** Tarif pro d'une boutique : le palier le plus haut atteint par ses livraisons du mois. */
export function volumeDiscountFor(
  tiers: { fromDeliveries: number; percentBps: number }[],
  deliveriesThisMonth: number,
): number {
  return tiers
    .filter((tier) => deliveriesThisMonth >= tier.fromDeliveries)
    .reduce((best, tier) => Math.max(best, tier.percentBps), 0);
}

/** Prime d'approche : versée quand le vendeur est au-delà du seuil (distance inconnue : rien). */
export function approachBonusFor(
  settings: { approachBonusAmount: number; approachBonusFromMeters: number },
  approachMeters: number | null,
): number {
  if (approachMeters === null || settings.approachBonusAmount <= 0) return 0;
  return approachMeters > settings.approachBonusFromMeters ? settings.approachBonusAmount : 0;
}
