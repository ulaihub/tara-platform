import { z } from 'zod';
import { PinProofFields } from '../pin/pin.schemas.js';
import { CameroonMobile } from '../common/phone.js';
import { PageQuery } from '../common/pagination.js';

const Fcfa = z.int().min(1).max(5_000_000);
const Operator = z.enum(['MTN', 'ORANGE']).meta({ id: 'MobileMoneyOperator' });

export const MobileMoneyPayer = z.object({
  phone: CameroonMobile,
  operator: Operator,
});

export const PaymentDto = z
  .object({
    id: z.uuid(),
    purpose: z.enum([
      'DELIVERY_FEE',
      'COD',
      'RIDER_CASH_DEPOSIT',
      'SUBSCRIPTION',
      'WALLET_TOPUP',
      'RIDER_TOPUP',
    ]),
    status: z.enum(['PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED']),
    /** Montant dû à Tara (course, recharge, encaissement). */
    amount: z.int(),
    /** Frais Mobile Money payés en plus par le client (0 sinon). */
    mobileMoneyFee: z.int(),
    /** Total demandé sur le téléphone : montant + frais Mobile Money. */
    total: z.int(),
    orderId: z.uuid().nullable(),
    /** Lot de livraisons payé en une fois (C4). */
    batchId: z.uuid().nullable(),
    failureReason: z.string().nullable(),
    createdAt: z.iso.datetime(),
    confirmedAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'Payment' });

export const TopUpBody = MobileMoneyPayer.extend({ amount: Fcfa });

/** Réserve la plus haute qu'une boutique peut garder chaque soir pour ses livraisons. */
export const MAX_PAYOUT_RESERVE = 100_000;

/** Réserve pour les livraisons, gardée des ventes au reversement du soir (0 : aucune). */
export const PayoutReserveBody = z.object({ amount: z.int().min(0).max(MAX_PAYOUT_RESERVE) });
export const DepositBody = MobileMoneyPayer.extend({ amount: Fcfa });
/** Recharge du solde prépayé du livreur : 500 FCFA au moins (frais payés par Tara). */
export const RiderTopUpBody = MobileMoneyPayer.extend({ amount: Fcfa.min(500).max(500_000) });
export const PayoutBody = z.object({
  /** Par défaut, tout le disponible. */
  amount: Fcfa.optional(),
  phone: CameroonMobile,
  operator: Operator,
  /** Code secret ou empreinte, exigé une fois le code secret choisi. */
  ...PinProofFields,
});

/**
 * Champs de l'app hors connexion (facultatifs) : un encaissement en espèces fait sans réseau
 * part avec l'heure et la position du moment ; renvoyé, il est sans effet.
 */
const OfflineContext = {
  clientEventId: z
    .string()
    .regex(/^[A-Za-z0-9_-]{8,100}$/)
    .optional(),
  occurredAt: z.iso.datetime().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
};

export const CollectBody = z.discriminatedUnion('method', [
  z.object({ method: z.literal('CASH'), ...OfflineContext }),
  z.object({
    method: z.literal('MOBILE_MONEY'),
    phone: CameroonMobile,
    operator: Operator,
    ...OfflineContext,
  }),
]);

export const CollectionDto = z
  .object({
    due: z.object({ fee: z.int(), cod: z.int(), total: z.int() }),
    /** Payé par Mobile Money, le client paie en plus ces frais (en espèces : rien de plus). */
    mobileMoneyFee: z.int(),
    /** DELIVERY : auprès du destinataire ; RETURN : frais de retour, auprès de l'expéditeur. */
    reason: z.enum(['DELIVERY', 'RETURN']),
    complete: z.boolean(),
    /** Demande Mobile Money en attente ; `total` : montant demandé au téléphone, frais compris. */
    payment: z
      .object({ id: z.uuid(), status: z.string(), amount: z.int(), total: z.int() })
      .nullable(),
  })
  .meta({ id: 'Collection' });

const OpenPayout = z.object({ id: z.uuid(), amount: z.int(), status: z.string() }).nullable();

/**
 * Retrait gratuit à partir de `freeFrom` ; en dessous, frais Mobile Money de `feeBps`, dont le
 * bénéficiaire paie `feeSharePercent` % (Tara le reste). Rien ne part sous `minimum`, le plus
 * petit envoi que le prestataire accepte (0 : pas de minimum).
 */
const Withdrawal = z.object({
  freeFrom: z.int(),
  feeBps: z.int(),
  feeSharePercent: z.int(),
  minimum: z.int(),
});

/** Retrait gratuit d'une boutique ou d'un livreur : seuil propre, seuil général, repère. */
export const FreePayoutDto = z
  .object({
    /** Seuil en vigueur : un retrait de ce montant ou plus est gratuit. */
    freeFrom: z.int(),
    /** Seuil fixé par l'équipe pour ce bénéficiaire ; null : seuil général. */
    custom: z.int().nullable(),
    default: z.int(),
    /** Moyenne mensuelle des retraits réussis sur les 3 derniers mois, pour fixer le seuil. */
    averageMonthlyPayouts: z.int(),
    /** Taux des frais de retrait sous le seuil, en points de base. */
    feeBps: z.int(),
    /** Part de ces frais payée par le bénéficiaire, en % (Tara le reste). */
    feeSharePercent: z.int(),
  })
  .meta({ id: 'FreePayout' });

export const FreePayoutBody = z.object({
  /** Montant à partir duquel le retrait est gratuit ; null : revenir au seuil général. */
  freeFrom: z.int().min(0).max(10_000_000).nullable(),
});

export const WalletDto = z
  .object({
    currency: z.literal('XAF'),
    /** Solde Tara ; retrait possible à partir de `withdrawalMinimum` (minimum du prestataire). */
    customer: z.object({ balance: z.int(), withdrawalMinimum: z.int() }),
    merchant: z
      .object({
        balance: z.int(),
        payoutSchedule: z.enum(['DAILY', 'ON_DEMAND']),
        plan: z.enum(['FREE', 'PRO', 'BUSINESS']),
        payoutPhone: z.string(),
        /** Heure du reversement quotidien (heure du Cameroun), 18 par défaut. */
        payoutHour: z.int(),
        /** Gardé chaque soir des ventes sur le solde Tara, pour les livraisons (0 : rien). */
        payoutReserve: z.int(),
        /** Encaissé à la livraison aujourd'hui (heure du Cameroun) et livraisons du jour. */
        todaySales: z.int(),
        todayDeliveries: z.int(),
        withdrawal: Withdrawal,
      })
      .nullable(),
    openPayout: OpenPayout,
  })
  .meta({ id: 'Wallet' });

export const RiderWalletDto = z
  .object({
    currency: z.literal('XAF'),
    /** Solde prépayé du livreur : ses gains et ses recharges, moins l'argent encaissé. */
    earnings: z.int(),
    /** Mis de côté pour ses courses avec encaissement en cours. */
    reserved: z.int(),
    /** Espèces encaissées et pas encore déposées (dues à Tara). */
    cashHeld: z.int(),
    cashLimit: z.int(),
    /** Heure limite de dépôt des espèces détenues (24 h après l'encaissement le plus ancien). */
    cashDueBy: z.iso.datetime().nullable(),
    /** Délai dépassé : plus de courses tant que les espèces ne sont pas déposées. */
    cashOverdue: z.boolean(),
    /** Disponible : solde moins l'argent mis de côté et les anciennes espèces dues. */
    available: z.int(),
    withdrawal: Withdrawal,
    openPayout: OpenPayout,
  })
  .meta({ id: 'RiderWallet' });

export const WalletLineDto = z
  .object({
    id: z.uuid(),
    at: z.iso.datetime(),
    kind: z.string(),
    description: z.string(),
    amount: z.int().meta({ description: 'Positif : le solde augmente' }),
    orderReference: z.string().nullable(),
  })
  .meta({ id: 'WalletLine' });

export const WalletHistoryQuery = PageQuery.extend({
  account: z.enum(['customer', 'merchant']).default('customer'),
});
export const RiderHistoryQuery = PageQuery.extend({
  account: z.enum(['earnings', 'cash']).default('earnings'),
});

export const PayoutDto = z
  .object({
    id: z.uuid(),
    beneficiary: z.enum(['MERCHANT', 'RIDER', 'CUSTOMER']),
    /** Montant retiré du solde. */
    amount: z.int(),
    /** Frais de retrait retenus (0 au-delà du seuil de retrait gratuit). */
    withdrawalFee: z.int(),
    /** Montant reçu sur le téléphone : montant − frais de retrait. */
    received: z.int(),
    fee: z.int(),
    phone: z.string(),
    status: z.enum([
      'PENDING',
      'AWAITING_APPROVAL',
      'PROCESSING',
      'SUCCEEDED',
      'FAILED',
      'CANCELLED',
    ]),
    failureReason: z.string().nullable(),
    requestedAt: z.iso.datetime(),
    completedAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'Payout' });

export const PayoutListQuery = PageQuery.extend({
  status: z
    .enum(['PENDING', 'AWAITING_APPROVAL', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'CANCELLED'])
    .optional(),
});

/** Vues des reversements au back-office (H5) : à valider, en cours, échoués, versés. */
export const AdminPayoutViewEnum = z
  .enum(['TO_APPROVE', 'IN_PROGRESS', 'FAILED', 'SENT', 'ALL'])
  .meta({ id: 'AdminPayoutView' });

export const AdminPayoutListQuery = PayoutListQuery.extend({
  view: AdminPayoutViewEnum.default('ALL'),
});

/** Reversement vu par la finance : qui le reçoit, et qui l'a validé. */
export const AdminPayoutDto = PayoutDto.extend({
  /** Boutique, livreur ou client remboursé ; lien vers sa fiche par son identifiant. */
  owner: z
    .object({
      id: z.uuid(),
      name: z.string().nullable(),
      phone: z.string(),
      shopName: z.string().nullable(),
    })
    .nullable(),
  approvedBy: z.string().nullable(),
  approvedAt: z.iso.datetime().nullable(),
}).meta({ id: 'AdminPayout' });

export const AdminPayoutPageDto = z
  .object({
    items: z.array(AdminPayoutDto),
    nextCursor: z.uuid().nullable(),
    counts: z.object({
      TO_APPROVE: z.int(),
      IN_PROGRESS: z.int(),
      FAILED: z.int(),
      SENT: z.int(),
      ALL: z.int(),
    }),
  })
  .meta({ id: 'AdminPayoutPage' });

export const RejectPayoutBody = z.object({ reason: z.string().trim().min(3).max(300) });
export const OfficeDepositBody = z.object({
  amount: Fcfa,
  note: z.string().trim().min(3).max(300),
});
export const CreditBody = z.object({
  amount: Fcfa.max(500_000),
  reason: z.string().trim().min(3).max(300),
});

export const TreasuryTransferBody = z.object({
  /** Sens du virement entre les espèces du bureau et le compte de l'agrégateur. */
  direction: z.enum(['OFFICE_TO_MOBILE_MONEY', 'MOBILE_MONEY_TO_OFFICE']),
  amount: z.int().min(1).max(50_000_000),
  note: z.string().trim().min(3).max(300),
});

export const FinanceOverviewDto = z
  .object({
    currency: z.literal('XAF'),
    accounts: z.array(z.object({ code: z.string(), name: z.string(), balance: z.int() })),
    payoutsAwaitingApproval: z.int(),
    paymentsPending: z.int(),
  })
  .meta({ id: 'FinanceOverview' });
