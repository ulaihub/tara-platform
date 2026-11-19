/**
 * Choix du livreur à qui proposer une course (D1, D4). Fonctions pures, testées seules.
 *
 * Le score s'exprime en « mètres équivalents » : plus il est bas, mieux le livreur est
 * placé. La distance d'approche domine ; les autres critères la corrigent.
 */

/** Courses simultanées maximum (attribuées, enlevées ou en livraison). */
export const MAX_ACTIVE_ORDERS = 2;
/** Pénalité par course déjà en cours : le livreur arrivera plus tard. */
export const ACTIVE_ORDER_PENALTY_METERS = 2_000;
/** Bonus ou malus par point de note au-dessus ou en dessous de 4/5. */
export const RATING_WEIGHT_METERS = 500;
/** En dessous de ce nombre d'avis, la note n'est pas prise en compte. */
export const MIN_RATINGS = 5;

export interface RiderSnapshot {
  riderId: string;
  /** Véhicule déclaré : un gros objet ne monte pas sur une moto. */
  vehicleType: 'MOTORBIKE' | 'TRICYCLE' | 'CAR';
  /** Alerte de sécurité pas encore close par l'équipe : pas de nouvelle course. */
  safetyAlertOpen: boolean;
  /** Distance d'approche jusqu'au point d'enlèvement, en mètres. */
  distanceMeters: number;
  activeOrders: number;
  hasPendingOffer: boolean;
  /** Pièces obligatoires validées et non expirées (D4). */
  documentsValid: boolean;
  /** Conditions des livreurs en vigueur acceptées (nouvelle version : plus de courses avant). */
  termsAccepted: boolean;
  /** Solde prépayé disponible : doit couvrir l'argent à encaisser sur la course (G5). */
  availableBalance: number;
  /** Espèces non déposées dans le délai (ancien fonctionnement, G5). */
  cashOverdue: boolean;
  ratingSum: number;
  ratingCount: number;
  /** Courses livrées depuis l'inscription : la confiance se gagne course après course. */
  deliveredCount: number;
}

export type Ineligibility =
  | 'DOCUMENTS'
  | 'TERMS'
  | 'BALANCE_TOO_LOW'
  | 'CASH_OVERDUE'
  | 'TOO_MANY_ORDERS'
  | 'PENDING_OFFER'
  | 'VEHICLE'
  | 'SAFETY_ALERT'
  | 'PARCEL_VALUE';

/** Ce que la course demande au livreur : argent à encaisser, véhicule pour le colis. */
export interface CourseNeeds {
  cash: number;
  packageSize: 'S' | 'M' | 'L' | 'XL' | 'BULKY';
  /** Valeur déclarée par l'expéditeur (jamais montrée au livreur) ; null si non déclarée. */
  declaredValue?: number | null;
  /** Tournée : nombre de colis proposés ensemble ; seul un livreur libre la reçoit. */
  tourSize?: number;
}

/**
 * Confiance progressive selon la valeur déclarée du colis : un nouveau livreur ne transporte
 * que des colis modestes ; les colis de grande valeur vont aux livreurs confirmés et bien notés.
 */
export interface ValueRules {
  /** Livraisons à faire avant de transporter un colis de plus de `newRiderMaxValue`. */
  newRiderDeliveries: number;
  newRiderMaxValue: number;
  /** Au-delà de cette valeur : livreur confirmé (`highValueMinDeliveries`) et bien noté. */
  highValueFrom: number;
  highValueMinDeliveries: number;
  highValueMinRating: number;
}

export const DEFAULT_VALUE_RULES: ValueRules = {
  newRiderDeliveries: 20,
  newRiderMaxValue: 25_000,
  highValueFrom: 100_000,
  highValueMinDeliveries: 50,
  highValueMinRating: 4.5,
};

/** Le livreur peut-il transporter un colis de cette valeur ? */
export function trustedForValue(
  rider: Pick<RiderSnapshot, 'deliveredCount' | 'ratingSum' | 'ratingCount'>,
  value: number | null | undefined,
  rules: ValueRules = DEFAULT_VALUE_RULES,
): boolean {
  if (!value) return true;
  if (value > rules.newRiderMaxValue && rider.deliveredCount < rules.newRiderDeliveries) {
    return false;
  }
  if (value > rules.highValueFrom) {
    if (rider.deliveredCount < rules.highValueMinDeliveries) return false;
    // Une note se juge sur assez d'avis.
    if (rider.ratingCount < MIN_RATINGS) return false;
    if (rider.ratingSum / rider.ratingCount < rules.highValueMinRating) return false;
  }
  return true;
}

/** Raisons pour lesquelles le livreur ne peut pas recevoir cette course (vide si éligible). */
export function ineligibilities(
  rider: RiderSnapshot,
  needs: CourseNeeds,
  rules: ValueRules = DEFAULT_VALUE_RULES,
): Ineligibility[] {
  const reasons: Ineligibility[] = [];
  const orderCash = needs.cash;
  if (rider.safetyAlertOpen) reasons.push('SAFETY_ALERT');
  if (needs.packageSize === 'BULKY' && rider.vehicleType === 'MOTORBIKE') reasons.push('VEHICLE');
  if (!rider.documentsValid) reasons.push('DOCUMENTS');
  if (!rider.termsAccepted) reasons.push('TERMS');
  // Solde prépayé : l'argent encaissé est pris sur le solde, qui doit donc le couvrir.
  if (orderCash > 0 && rider.availableBalance < orderCash) reasons.push('BALANCE_TOO_LOW');
  if (rider.cashOverdue) reasons.push('CASH_OVERDUE');
  if (rider.activeOrders >= MAX_ACTIVE_ORDERS) reasons.push('TOO_MANY_ORDERS');
  else if ((needs.tourSize ?? 1) > 1 && rider.activeOrders > 0) reasons.push('TOO_MANY_ORDERS');
  if (rider.hasPendingOffer) reasons.push('PENDING_OFFER');
  if (!trustedForValue(rider, needs.declaredValue, rules)) reasons.push('PARCEL_VALUE');
  return reasons;
}

export function score(rider: RiderSnapshot): number {
  let value = rider.distanceMeters + rider.activeOrders * ACTIVE_ORDER_PENALTY_METERS;
  if (rider.ratingCount >= MIN_RATINGS) {
    value -= (rider.ratingSum / rider.ratingCount - 4) * RATING_WEIGHT_METERS;
  }
  return Math.round(value);
}

/** Espèces que le livreur aura en main avec cette course (frais payés en espèces, COD). */
export function cashCarried(order: {
  codAmount: number;
  totalPrice: number;
  feePaymentMethod: string;
}): number {
  return order.codAmount + (order.feePaymentMethod === 'CASH' ? order.totalPrice : 0);
}

/** Nombre de livreurs sollicités à un tour : un seul, puis plusieurs après N refus (D2). */
export function offersForRound(
  searchRound: number,
  singleRounds: number,
  broadcast: number,
): number {
  return searchRound <= singleRounds ? 1 : broadcast;
}
