import type { PaymentPurpose } from '../generated/prisma/enums.js';

/**
 * Frais Mobile Money (prestataire) répercutés sur les clients, validés par le fondateur :
 * - à l'encaissement, une ligne « Frais Mobile Money » s'ajoute au montant payé par le client,
 *   pour que Tara reçoive le montant entier une fois les frais du prestataire retenus ;
 * - au reversement (boutiques, livreurs), les frais sont retenus sur le montant envoyé, sauf
 *   au-delà du seuil de retrait gratuit du bénéficiaire.
 * Taux en points de base (600 = 6 %), réglés par MOBILE_MONEY_FEE_BPS et PAYOUT_FEE_BPS.
 */

/** Paiements des clients : les recharges et dépôts des livreurs restent à la charge de Tara. */
export const SURCHARGED_PURPOSES: ReadonlySet<PaymentPurpose> = new Set<PaymentPurpose>([
  'DELIVERY_FEE',
  'COD',
  'WALLET_TOPUP',
]);

/**
 * Frais ajoutés au montant : le prestataire retient `bps` du montant encaissé
 * (montant + frais), il reste au moins `amount` à Tara.
 */
export function mobileMoneySurcharge(amount: number, bps: number): number {
  if (bps <= 0 || amount <= 0) return 0;
  return Math.ceil((amount * bps) / (10_000 - bps));
}

/**
 * Frais retenus sur un reversement : le prestataire ajoute `bps` du montant envoyé
 * (montant − frais) ; Tara ne paie rien de plus que ce que le bénéficiaire a demandé.
 */
export function payoutCharge(amount: number, bps: number): number {
  if (bps <= 0 || amount <= 0) return 0;
  return Math.ceil((amount * bps) / (10_000 + bps));
}
