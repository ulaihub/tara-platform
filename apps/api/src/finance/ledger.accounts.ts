import type { LedgerAccountType, LedgerOwnerType } from '../generated/prisma/enums.js';

/**
 * Plan de comptes de Tara. Convention : montant positif = débit, négatif = crédit. Un actif
 * ou une charge augmente au débit ; un passif ou un produit augmente au crédit.
 */
export interface AccountSpec {
  code: string;
  name: string;
  type: LedgerAccountType;
  ownerType: LedgerOwnerType;
  ownerId?: string | null;
}

const platform = (code: string, name: string, type: LedgerAccountType): AccountSpec => ({
  code: `platform:${code}`,
  name,
  type,
  ownerType: 'PLATFORM',
});

export const PLATFORM_ACCOUNTS = {
  mobileMoney: platform('mobile_money', 'Mobile Money détenu chez l’agrégateur', 'ASSET'),
  officeCash: platform('office_cash', 'Espèces déposées au bureau', 'ASSET'),
  /** Retour sans dette : frais des colis gardés au bureau Tara, payés pour les récupérer. */
  officeReceivables: platform(
    'office_receivables',
    'Frais de retour des colis gardés au bureau',
    'ASSET',
  ),
  ordersPrepaid: platform(
    'orders_prepaid',
    'Livraisons payées, pas encore effectuées',
    'LIABILITY',
  ),
  payoutsInTransit: platform('payouts_in_transit', 'Reversements en cours d’envoi', 'LIABILITY'),
  commission: platform('revenue:commission', 'Commission sur les livraisons', 'REVENUE'),
  codFees: platform('revenue:cod_fees', 'Frais d’encaissement', 'REVENUE'),
  /** Frais Mobile Money payés par les clients et retenus sur les retraits : ils couvrent providerFees. */
  mobileMoneyFeesCharged: platform(
    'revenue:mobile_money_fees',
    'Frais Mobile Money facturés',
    'REVENUE',
  ),
  providerFees: platform('expense:provider_fees', 'Frais Mobile Money', 'EXPENSE'),
  promotions: platform('expense:promotions', 'Remises financées par Tara', 'EXPENSE'),
  goodwill: platform('expense:goodwill', 'Avoirs commerciaux', 'EXPENSE'),
  /** Colis jamais réclamé au bureau : frais de retour abandonnés (jamais une dette). */
  unpaidReturns: platform('expense:unpaid_returns', 'Frais de retour non payés', 'EXPENSE'),
  /** Primes d'approche et de renfort versées aux livreurs (H4), en plus de leur part. */
  riderBonuses: platform('expense:rider_bonuses', 'Primes des livreurs', 'EXPENSE'),
  /** Paiement reçu sans emploi (doublon, commande déjà réglée) : à rembourser ou affecter. */
  unallocated: platform('unallocated', 'Encaissements à affecter', 'LIABILITY'),
} as const;

export const riderCashHeld = (riderId: string): AccountSpec => ({
  code: `rider:${riderId}:cash_held`,
  name: 'Espèces détenues par le livreur',
  type: 'ASSET',
  ownerType: 'RIDER',
  ownerId: riderId,
});

export const riderPayable = (riderId: string): AccountSpec => ({
  code: `rider:${riderId}:payable`,
  name: 'Gains dus au livreur',
  type: 'LIABILITY',
  ownerType: 'RIDER',
  ownerId: riderId,
});

export const merchantPayable = (merchantId: string): AccountSpec => ({
  code: `merchant:${merchantId}:payable`,
  name: 'Portefeuille du marchand',
  type: 'LIABILITY',
  ownerType: 'MERCHANT',
  ownerId: merchantId,
});

export const customerWallet = (userId: string): AccountSpec => ({
  code: `customer:${userId}:wallet`,
  name: 'Solde Tara du client',
  type: 'LIABILITY',
  ownerType: 'CUSTOMER',
  ownerId: userId,
});

/** Solde « naturel » d'un compte : positif quand il est dans son sens normal. */
export function naturalBalance(type: LedgerAccountType, signedSum: number): number {
  // « 0 - x » plutôt que « -x » : jamais de -0 dans les réponses.
  return type === 'ASSET' || type === 'EXPENSE' ? signedSum : 0 - signedSum;
}

/** Frais d'encaissement (contre-remboursement) : 2 %, minimum 250 FCFA, jamais plus que le montant. */
export function codFee(amount: number): number {
  if (amount <= 0) return 0;
  return Math.min(amount, Math.max(250, Math.round(amount * 0.02)));
}
