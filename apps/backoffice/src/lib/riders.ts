import type { StaffRole } from './session';
import type { AdminRider, KycDocument, RiderReliability, Schemas } from './schemas';

type View = Schemas['AdminRiderView'];
type RiderStatus = AdminRider['status'];
type DocumentType = KycDocument['type'];
type HistoryAction = RiderReliability['history'][number]['action'];

/** Vues de la liste des livreurs (H3), dans l'ordre des onglets. */
export const RIDER_VIEWS: readonly { value: View; label: string }[] = [
  { value: 'TO_REVIEW', label: 'À examiner' },
  { value: 'PENDING', label: 'Candidatures' },
  { value: 'ACTIVE', label: 'Actifs' },
  { value: 'SUSPENDED', label: 'Suspendus' },
  { value: 'REJECTED', label: 'Refusés' },
  { value: 'ALL', label: 'Tous' },
];

/** Vue demandée dans l'adresse ; « à examiner » par défaut, c'est le travail du jour. */
export function riderView(value: string | undefined): View {
  const upper = value?.toUpperCase();
  return RIDER_VIEWS.some((view) => view.value === upper) ? (upper as View) : 'TO_REVIEW';
}

export const RIDER_STATUS_LABELS: Record<RiderStatus, string> = {
  PENDING: 'Candidature',
  ACTIVE: 'Actif',
  SUSPENDED: 'Suspendu',
  REJECTED: 'Refusé',
};

export const RIDER_STATUS_TONE: Record<RiderStatus, string> = {
  PENDING: 'bg-warn-bg text-warn',
  ACTIVE: 'bg-ok-bg text-ok',
  SUSPENDED: 'bg-danger-bg text-danger',
  REJECTED: 'bg-track text-muted',
};

export const VEHICLE_LABELS: Record<AdminRider['vehicleType'], string> = {
  MOTORBIKE: 'Moto',
  TRICYCLE: 'Tricycle',
  CAR: 'Voiture',
};

export const DOCUMENT_LABELS: Record<DocumentType, string> = {
  NATIONAL_ID_FRONT: 'CNI (recto)',
  NATIONAL_ID_BACK: 'CNI (verso)',
  DRIVING_LICENSE: 'Permis de conduire',
  VEHICLE_REGISTRATION: 'Carte grise',
  VEHICLE_RENTAL_CONTRACT: 'Contrat de location',
  INSURANCE: 'Assurance',
  SELFIE: 'Photo du visage',
  CRIMINAL_RECORD: 'Casier judiciaire',
  GUARANTOR_ID: 'CNI du garant',
};

/**
 * Pièces exigées, dans l'ordre de la fiche (comme l'API) : pour le véhicule, la carte grise
 * ou le contrat de location suffit. La CNI du garant reste facultative.
 */
export const REQUIRED_GROUPS: readonly (readonly DocumentType[])[] = [
  ['NATIONAL_ID_FRONT'],
  ['NATIONAL_ID_BACK'],
  ['DRIVING_LICENSE'],
  ['VEHICLE_REGISTRATION', 'VEHICLE_RENTAL_CONTRACT'],
  ['INSURANCE'],
  ['SELFIE'],
  ['CRIMINAL_RECORD'],
];

/** Pièces dont la date d'expiration compte (rappel avant échéance, A5). */
export const EXPIRING_TYPES: readonly DocumentType[] = [
  'NATIONAL_ID_FRONT',
  'DRIVING_LICENSE',
  'INSURANCE',
  'VEHICLE_RENTAL_CONTRACT',
];

export const DOCUMENT_STATUS_LABELS: Record<KycDocument['status'] | 'MISSING', string> = {
  PENDING: 'À examiner',
  APPROVED: 'Validée',
  REJECTED: 'Refusée',
  EXPIRED: 'Expirée',
  MISSING: 'Pas envoyée',
};

export const DOCUMENT_STATUS_TONE: Record<KycDocument['status'] | 'MISSING', string> = {
  PENDING: 'bg-warn-bg text-warn',
  APPROVED: 'bg-ok-bg text-ok',
  REJECTED: 'bg-danger-bg text-danger',
  EXPIRED: 'bg-danger-bg text-danger',
  MISSING: 'bg-track text-muted',
};

/** Une ligne de la liste des pièces : le groupe exigé et la pièce qui le représente. */
export interface DocumentLine {
  types: readonly DocumentType[];
  label: string;
  document: KycDocument | null;
  required: boolean;
}

/**
 * Pièces de la fiche : chaque groupe exigé avec sa dernière pièce (celle qui attend
 * l'examen d'abord, puis la validée, puis la plus récente), puis la CNI du garant si envoyée.
 */
export function documentLines(documents: readonly KycDocument[]): DocumentLine[] {
  const rank = (doc: KycDocument): number =>
    doc.status === 'PENDING' ? 0 : doc.status === 'APPROVED' ? 1 : 2;
  const pick = (types: readonly DocumentType[]): KycDocument | null =>
    documents
      .filter((doc) => types.includes(doc.type))
      .sort((a, b) => rank(a) - rank(b) || b.createdAt.localeCompare(a.createdAt))[0] ?? null;
  const lines: DocumentLine[] = REQUIRED_GROUPS.map((types) => ({
    types,
    label: types.map((type) => DOCUMENT_LABELS[type]).join(' ou '),
    document: pick(types),
    required: true,
  }));
  const guarantor = pick(['GUARANTOR_ID']);
  if (guarantor) {
    lines.push({
      types: ['GUARANTOR_ID'],
      label: DOCUMENT_LABELS.GUARANTOR_ID,
      document: guarantor,
      required: false,
    });
  }
  return lines;
}

/** Ce qui manque encore pour valider un candidat ; vide : la validation est possible. */
export function approvalBlockers(rider: AdminRider): string[] {
  const blockers: string[] = [];
  const lines = documentLines(rider.documents).filter((line) => line.required);
  const approved = lines.filter((line) => line.document?.status === 'APPROVED').length;
  if (approved < lines.length) {
    blockers.push(`Pièces validées : ${approved} sur ${lines.length}`);
  }
  if (!rider.interview) blockers.push('Entretien au bureau à faire');
  else if (!rider.interview.passed)
    blockers.push('Entretien échoué : un nouvel entretien est exigé');
  return blockers;
}

/** Réactivation : les pièces doivent être valides (l'entretien a déjà été passé). */
export function reactivationBlockers(rider: AdminRider): string[] {
  const lines = documentLines(rider.documents).filter((line) => line.required);
  const approved = lines.filter((line) => line.document?.status === 'APPROVED').length;
  return approved < lines.length ? [`Pièces validées : ${approved} sur ${lines.length}`] : [];
}

/** Part en pour cent, arrondie ; null sans dénominateur. */
export function percent(part: number, total: number): number | null {
  return total > 0 ? Math.round((part / total) * 100) : null;
}

/** Taux d'une période : acceptation, réussite, ponctualité. */
export function rates(window: RiderReliability['allTime']): {
  acceptance: number | null;
  success: number | null;
  onTime: number | null;
} {
  const { offers, deliveries } = window;
  return {
    acceptance: percent(offers.accepted, offers.accepted + offers.declined + offers.expired),
    success: percent(deliveries.delivered, deliveries.delivered + deliveries.failed),
    onTime: percent(deliveries.onTime, deliveries.delivered),
  };
}

export const HISTORY_LABELS: Record<HistoryAction, string> = {
  APPLIED: 'Candidature envoyée',
  DOCUMENT_APPROVED: 'Pièce validée',
  DOCUMENT_REJECTED: 'Pièce refusée',
  INTERVIEW_PASSED: 'Entretien réussi',
  INTERVIEW_FAILED: 'Entretien échoué',
  APPROVED: 'Livreur validé',
  REJECTED: 'Candidature refusée',
  SUSPENDED: 'Livreur suspendu',
  REACTIVATED: 'Livreur réactivé',
  CASH_OVERDUE: 'Espèces non déposées à temps',
  CASH_SUSPENDED: 'Suspendu faute de dépôt des espèces',
  FREE_PAYOUT_SET: 'Seuil de retrait gratuit modifié',
};

export const HISTORY_TONE: Record<HistoryAction, string> = {
  APPLIED: 'bg-faint',
  DOCUMENT_APPROVED: 'bg-ok',
  DOCUMENT_REJECTED: 'bg-danger',
  INTERVIEW_PASSED: 'bg-ok',
  INTERVIEW_FAILED: 'bg-danger',
  APPROVED: 'bg-ok',
  REJECTED: 'bg-danger',
  SUSPENDED: 'bg-danger',
  REACTIVATED: 'bg-ok',
  CASH_OVERDUE: 'bg-warn',
  CASH_SUSPENDED: 'bg-danger',
  FREE_PAYOUT_SET: 'bg-accent',
};

/** Valider, refuser, suspendre, réactiver : dispatch et administrateurs (comme l'API). */
export const RIDER_ROLES: readonly StaffRole[] = ['ADMIN', 'DISPATCHER'];

/** Le seuil de retrait gratuit relève de la finance : administrateurs et finance. */
export function canSetFreePayout(roles: readonly string[]): boolean {
  return roles.includes('ADMIN') || roles.includes('FINANCE');
}

const shortDate = new Intl.DateTimeFormat('fr-FR', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: 'UTC',
});

/** « 3 déc. 2026 » pour une date du calendrier (AAAA-MM-JJ). */
export function calendarDate(day: string): string {
  return shortDate.format(new Date(`${day}T00:00:00Z`));
}

/** Résumé des pièces pour la liste : à examiner, manquantes, bientôt expirées, complètes. */
export function documentSummary(rider: AdminRider): { text: string; tone: string } {
  if (rider.pendingDocuments > 0) {
    return {
      text: `${rider.pendingDocuments} à examiner`,
      tone: 'text-warn',
    };
  }
  if (rider.missingDocuments.length > 0) {
    const count = rider.missingDocuments.length;
    return { text: `${count} manquante${count > 1 ? 's' : ''}`, tone: 'text-danger' };
  }
  const soon = rider.expiringSoon[0];
  if (soon) {
    return {
      text: `${DOCUMENT_LABELS[soon.type]} expire le ${calendarDate(soon.expiresOn)}`,
      tone: 'text-warn',
    };
  }
  return { text: 'Complètes', tone: 'text-ok' };
}

/** « Réussi », « Échoué » ou « À faire ». */
export function interviewSummary(rider: AdminRider): { text: string; tone: string } {
  if (!rider.interview) return { text: 'À faire', tone: 'text-muted' };
  return rider.interview.passed
    ? { text: 'Réussi', tone: 'text-ok' }
    : { text: 'Échoué', tone: 'text-danger' };
}

/** « 4,6 » ; null sans note. */
export function ratingText(average: number | null): string | null {
  return average === null ? null : average.toFixed(1).replace('.', ',');
}
