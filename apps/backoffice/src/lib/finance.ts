import type { StaffRole } from './session';
import type { AdminPayout, Reconciliation, Schemas } from './schemas';

type View = Schemas['AdminPayoutView'];

/** Finance : administrateurs et finance (comme l'API). */
export const FINANCE_ROLES: readonly StaffRole[] = ['ADMIN', 'FINANCE'];

/** Vues des reversements (H5), dans l'ordre des onglets. */
export const PAYOUT_VIEWS: readonly { value: View; label: string }[] = [
  { value: 'TO_APPROVE', label: 'À valider' },
  { value: 'IN_PROGRESS', label: 'En cours' },
  { value: 'FAILED', label: 'Échoués' },
  { value: 'SENT', label: 'Versés' },
  { value: 'ALL', label: 'Tous' },
];

/** Vue demandée dans l'adresse ; « à valider » par défaut. */
export function payoutView(value: string | undefined): View {
  const upper = value?.toUpperCase().replace(/-/g, '_');
  return PAYOUT_VIEWS.some((view) => view.value === upper) ? (upper as View) : 'TO_APPROVE';
}

export const PAYOUT_STATUS_LABELS: Record<AdminPayout['status'], string> = {
  PENDING: 'En attente d’envoi',
  AWAITING_APPROVAL: 'À valider',
  PROCESSING: 'Envoi en cours',
  SUCCEEDED: 'Versé',
  FAILED: 'Échoué',
  CANCELLED: 'Refusé',
};

export const PAYOUT_STATUS_TONE: Record<AdminPayout['status'], string> = {
  PENDING: 'bg-track text-muted',
  AWAITING_APPROVAL: 'bg-warn-bg text-warn',
  PROCESSING: 'bg-accent-bg text-accent',
  SUCCEEDED: 'bg-ok-bg text-ok',
  FAILED: 'bg-danger-bg text-danger',
  CANCELLED: 'bg-track text-muted',
};

export const BENEFICIARY_LABELS: Record<AdminPayout['beneficiary'], string> = {
  MERCHANT: 'Boutique',
  RIDER: 'Livreur',
  CUSTOMER: 'Client remboursé',
};

/** Lien vers la fiche du bénéficiaire quand le back-office en a une. */
export function ownerHref(payout: AdminPayout): string | null {
  if (!payout.owner) return null;
  return payout.beneficiary === 'RIDER' ? `/livreurs/${payout.owner.id}` : null;
}

/** Écarts du contrôle quotidien, dits simplement. */
export const DISCREPANCY_LABELS: Record<string, string> = {
  LEDGER_UNBALANCED: 'Écriture déséquilibrée dans les comptes',
  PAYMENT_NOT_RECORDED: 'Paiement reçu mais pas inscrit dans les comptes',
  PAYMENT_AMOUNT_MISMATCH: 'Montant du paiement différent dans les comptes',
  PAYMENT_STUCK: 'Paiement resté en attente',
  PAYOUT_NOT_RECORDED: 'Reversement envoyé mais pas inscrit dans les comptes',
  PAYOUT_AMOUNT_MISMATCH: 'Montant du reversement différent dans les comptes',
  PAYOUT_STUCK: 'Reversement resté en attente',
  COD_NOT_RECORDED: 'Encaissement à la livraison pas inscrit',
  ORDER_NOT_CLEARED: 'Commande terminée dont l’argent n’est pas soldé',
  PROVIDER_STATUS_MISMATCH: 'État différent chez l’agrégateur',
  PROVIDER_AMOUNT_MISMATCH: 'Montant différent chez l’agrégateur',
  LEDGER_ONLY: 'Inscrit dans les comptes, inconnu de l’agrégateur',
  PROVIDER_ONLY: 'Connu de l’agrégateur, absent des comptes',
};

export function discrepancyLabel(type: string): string {
  return DISCREPANCY_LABELS[type] ?? type;
}

/** Chiffres de la journée contrôlée, dans l'ordre d'affichage. */
export const TOTAL_LABELS: readonly [string, string, 'money' | 'count'][] = [
  ['mobileMoneyCollected', 'Encaissé par Mobile Money', 'money'],
  ['cashCollected', 'Encaissé en espèces par les livreurs', 'money'],
  ['codCollected', 'Argent encaissé pour les boutiques', 'money'],
  ['payoutsSent', 'Reversé (boutiques, livreurs, remboursements)', 'money'],
  ['commission', 'Commission Tara', 'money'],
  ['codFees', 'Frais d’encaissement', 'money'],
  ['providerFees', 'Frais payés à l’agrégateur', 'money'],
  ['cashDepositedOffice', 'Espèces déposées au bureau', 'money'],
  ['cashDepositedMobileMoney', 'Espèces déposées par Mobile Money', 'money'],
  ['ordersCompleted', 'Commandes terminées', 'count'],
  ['mobileMoneyBalance', 'Solde chez l’agrégateur (fin de journée)', 'money'],
  ['ordersPrepaidBalance', 'Livraisons payées pas encore faites', 'money'],
  ['payoutsInTransitBalance', 'Reversements en cours d’envoi', 'money'],
];

/** Dernier contrôle connu et nombre d'écarts. */
export function lastCheck(reports: readonly Reconciliation[]): {
  report: Reconciliation | null;
  issues: number;
} {
  const report = reports[0] ?? null;
  return { report, issues: report?.discrepancies.length ?? 0 };
}

const DAY = /^\d{4}-\d{2}-\d{2}$/;

/** Période d'export valide : deux dates dans l'ordre, 92 jours au plus (limite de l'API). */
export function exportRange(from: string, to: string): string | null {
  if (!DAY.test(from) || !DAY.test(to)) return 'Choisissez les deux dates.';
  if (from > to) return 'La date de début doit précéder la date de fin.';
  const days = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000;
  if (days + 1 > 92) return 'Trois mois au plus par export (92 jours).';
  return null;
}
