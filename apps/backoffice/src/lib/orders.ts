import { STATUS_LABELS } from './live';
import type { AdminOrder, DispatchCandidate, OrderStatus } from './schemas';

/** Vues de la liste des commandes (H2), dans l'ordre des onglets. */
export const ORDER_VIEWS = [
  { value: 'all', label: 'Toutes' },
  { value: 'active', label: 'En cours' },
  { value: 'problems', label: 'À traiter' },
  { value: 'delivered', label: 'Livrées' },
  { value: 'cancelled', label: 'Annulées ou retournées' },
] as const;
export type OrderView = (typeof ORDER_VIEWS)[number]['value'];

export function orderView(value: string | undefined): OrderView {
  return ORDER_VIEWS.some((view) => view.value === value) ? (value as OrderView) : 'all';
}

/** Couleur de la pastille de statut. */
export const STATUS_TONE: Record<OrderStatus, string> = {
  CREATED: 'bg-track text-muted',
  SEARCHING_RIDER: 'bg-warn-bg text-warn',
  ASSIGNED: 'bg-accent-bg text-accent',
  PICKED_UP: 'bg-accent-bg text-accent',
  IN_DELIVERY: 'bg-accent-bg text-accent',
  DELIVERED: 'bg-ok-bg text-ok',
  DELIVERY_FAILED: 'bg-danger-bg text-danger',
  RETURNED: 'bg-track text-muted',
  CANCELLED: 'bg-track text-muted',
};

export const PAYMENT_LABELS: Record<AdminOrder['price']['feePaymentMethod'], string> = {
  MOMO_MTN: 'MTN Mobile Money',
  MOMO_ORANGE: 'Orange Money',
  CASH: 'Espèces',
  WALLET: 'Solde Tara',
};

export const ACTOR_LABELS: Record<string, string> = {
  SENDER: 'Expéditeur',
  RECIPIENT: 'Destinataire',
  RIDER: 'Livreur',
  DISPATCHER: 'Équipe Tara',
  SUPPORT: 'Support Tara',
  SYSTEM: 'Automatique',
};

export const FAILURE_LABELS: Record<string, string> = {
  RECIPIENT_ABSENT: 'Destinataire absent',
  RECIPIENT_UNREACHABLE: 'Destinataire injoignable',
  REFUSED: 'Colis refusé',
  ADDRESS_NOT_FOUND: 'Adresse introuvable',
  PAYMENT_REFUSED: 'Refus de payer',
  OTHER: 'Autre raison',
};

export const SIZE_LABELS: Record<AdminOrder['parcel']['size'], string> = {
  S: 'S · jusqu’à 2 kg',
  M: 'M · jusqu’à 5 kg',
  L: 'L · jusqu’à 10 kg',
  XL: 'XL · jusqu’à 20 kg',
};

export const CONTENTS_LABELS: Record<NonNullable<AdminOrder['parcel']['contents']>, string> = {
  DOCUMENTS: 'Documents',
  CLOTHING: 'Vêtements et chaussures',
  MEDICINE: 'Médicaments',
  LAUNDRY: 'Linge',
  HOUSEHOLD: 'Cuisine et maison',
  ELECTRONICS: 'Électronique',
  FOOD: 'Alimentation',
  BEAUTY: 'Beauté',
  SECONDHAND: 'Brocante',
  OTHER: 'Autre',
};

export const PROOF_LABELS: Record<string, string> = {
  PICKUP: 'Enlèvement',
  DELIVERY: 'Remise',
  FAILED_ATTEMPT: 'Tentative échouée',
  RETURN: 'Retour à l’expéditeur',
};

export const INELIGIBLE_LABELS: Record<DispatchCandidate['ineligibleBecause'][number], string> = {
  DOCUMENTS: 'pièces manquantes ou expirées',
  TERMS: 'conditions non acceptées',
  BALANCE_TOO_LOW: 'solde trop bas pour l’encaissement',
  CASH_OVERDUE: 'espèces non déposées',
  TOO_MANY_ORDERS: 'déjà trop de courses',
  PENDING_OFFER: 'proposition en attente',
};

/** Ce que cette personne de l'équipe peut faire sur une commande. */
export function orderPermissions(roles: readonly string[], order: Pick<AdminOrder, 'can'>) {
  const dispatch = roles.includes('ADMIN') || roles.includes('DISPATCHER');
  return { cancel: dispatch && order.can.cancel, reassign: dispatch && order.can.reassign };
}

/** Étapes de l'historique d'une commande, au passé. */
export const EVENT_LABELS: Record<OrderStatus, string> = {
  CREATED: 'Commande créée',
  SEARCHING_RIDER: 'Recherche de livreur',
  ASSIGNED: 'Livreur attribué',
  PICKED_UP: 'Colis récupéré chez le vendeur',
  IN_DELIVERY: 'En route vers le client',
  DELIVERED: 'Livrée',
  DELIVERY_FAILED: 'Échec de livraison',
  RETURNED: 'Rendue à l’expéditeur',
  CANCELLED: 'Annulée',
};

/** Statut d'une commande dans la liste et la fiche (« créée » sans heure programmée). */
export function statusLabel(status: OrderStatus, scheduledFor: string | null): string {
  if (status === 'CREATED') return scheduledFor ? 'Programmée' : 'En attente de départ';
  return STATUS_LABELS[status];
}
