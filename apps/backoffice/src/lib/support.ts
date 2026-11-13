import type { StaffRole } from './session';
import type { AdminTicket, AdminTicketRow, Schemas } from './schemas';

type View = Schemas['AdminTicketView'];

/** Service client : support et administrateurs (comme l'API). */
export const SUPPORT_ROLES: readonly StaffRole[] = ['ADMIN', 'SUPPORT'];

/** Vues de la file des demandes (H6), dans l'ordre des onglets. */
export const TICKET_VIEWS: readonly { value: View; label: string }[] = [
  { value: 'TO_HANDLE', label: 'À traiter' },
  { value: 'MINE', label: 'Mes demandes' },
  { value: 'URGENT', label: 'Urgentes' },
  { value: 'RESOLVED', label: 'Résolues' },
  { value: 'ALL', label: 'Toutes' },
];

/** Vue demandée dans l'adresse ; « à traiter » par défaut. */
export function ticketView(value: string | undefined): View {
  const upper = value?.toUpperCase().replace(/-/g, '_');
  return TICKET_VIEWS.some((view) => view.value === upper) ? (upper as View) : 'TO_HANDLE';
}

export const CATEGORY_LABELS: Record<AdminTicketRow['category'], string> = {
  LOST_PARCEL: 'Colis perdu ou non reçu',
  DAMAGED_PARCEL: 'Colis abîmé',
  LATE_DELIVERY: 'Retard',
  PAYMENT: 'Paiement',
  RIDER_BEHAVIOR: 'Comportement du livreur',
  APP_BUG: 'Problème dans l’app',
  OTHER: 'Autre',
};

export const PRIORITY_LABELS: Record<AdminTicketRow['priority'], string> = {
  LOW: 'Basse',
  NORMAL: 'Normale',
  HIGH: 'Haute',
  URGENT: 'Urgente',
};

export const PRIORITY_TONE: Record<AdminTicketRow['priority'], string> = {
  LOW: 'bg-track text-muted',
  NORMAL: 'bg-track text-text',
  HIGH: 'bg-warn-bg text-warn',
  URGENT: 'bg-danger-bg text-danger',
};

export const STATUS_LABELS: Record<AdminTicketRow['status'], string> = {
  OPEN: 'Nouvelle',
  IN_PROGRESS: 'En cours',
  RESOLVED: 'Résolue',
  CLOSED: 'Close',
};

export const STATUS_TONE: Record<AdminTicketRow['status'], string> = {
  OPEN: 'bg-accent-bg text-accent',
  IN_PROGRESS: 'bg-warn-bg text-warn',
  RESOLVED: 'bg-ok-bg text-ok',
  CLOSED: 'bg-track text-muted',
};

export const PERSON_LABELS: Record<AdminTicketRow['requester']['kind'], string> = {
  CUSTOMER: 'Expéditeur',
  MERCHANT: 'Boutique',
  RIDER: 'Livreur',
  STAFF: 'Équipe Tara',
  NO_ACCOUNT: 'Sans compte',
};

export const PROOF_KIND_LABELS: Record<string, string> = {
  PICKUP: 'Enlèvement',
  DELIVERY: 'Livraison',
  FAILED_ATTEMPT: 'Échec de livraison',
  RETURN: 'Retour à l’expéditeur',
  PICKUP_REFUSED: 'Colis refusé à l’enlèvement',
};

/** « 0 s » (pas de réponse), « 45 s », « 2 min 05 ». */
export function callDuration(seconds: number): string {
  if (seconds === 0) return 'pas de réponse';
  if (seconds < 60) return `${seconds} s`;
  return `${Math.floor(seconds / 60)} min ${String(seconds % 60).padStart(2, '0')}`;
}

/** Actions de statut proposées selon l'état de la demande. */
export function statusActions(
  status: AdminTicket['status'],
): { status: AdminTicket['status']; label: string }[] {
  switch (status) {
    case 'OPEN':
    case 'IN_PROGRESS':
      return [
        { status: 'RESOLVED', label: 'Marquer résolue' },
        { status: 'CLOSED', label: 'Clore sans suite' },
      ];
    case 'RESOLVED':
      return [
        { status: 'CLOSED', label: 'Clore' },
        { status: 'IN_PROGRESS', label: 'Rouvrir' },
      ];
    case 'CLOSED':
      return [{ status: 'IN_PROGRESS', label: 'Rouvrir' }];
  }
}

/** Lien OpenStreetMap vers la position d'une preuve. */
export function mapLink(latitude: number, longitude: number): string {
  return `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=18/${latitude}/${longitude}`;
}
