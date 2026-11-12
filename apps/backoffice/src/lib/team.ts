import type { StaffRole } from './session';

/** Équipe et audit : administrateurs seulement, comme l'API. */
export const TEAM_ROLES: readonly StaffRole[] = ['ADMIN'];

export const ROLE_HINTS: Record<StaffRole, string> = {
  ADMIN: 'Tout, y compris tarifs, équipe et journal.',
  DISPATCHER: 'Carte en direct, commandes, livreurs.',
  SUPPORT: 'Demandes des clients, commandes, litiges.',
  FINANCE: 'Reversements, contrôle des comptes, export.',
};

/** Actions du journal, en mots simples. */
export const ACTION_LABELS: Record<string, string> = {
  'course_alert.acknowledged': 'Alerte de course prise en compte',
  'delivery_proof.photo_viewed': 'Photo de remise consultée',
  'finance.free_payout_set': 'Seuil de retrait gratuit modifié',
  'finance.journal_exported': 'Journal comptable exporté',
  'finance.treasury_transfer': 'Virement de trésorerie',
  'kyc_document.viewed': 'Pièce d’un livreur consultée',
  'order.assign': 'Course attribuée par le dispatch',
  'order.parcel_photo_viewed': 'Photo de colis consultée',
  'order.track_viewed': 'Trajet d’une course consulté',
  'order.transition': 'Statut d’une commande changé',
  'payout.approved': 'Reversement validé',
  'payout.rejected': 'Reversement refusé',
  'pricing_grid.activated': 'Grille tarifaire mise en vigueur',
  'pricing_grid.created': 'Grille tarifaire créée',
  'pricing_settings.updated': 'Tarif pro ou prime d’approche modifié',
  'pricing_surcharge.toggled': 'Supplément activé ou coupé',
  'promo_code.created': 'Code promo créé',
  'promo_code.updated': 'Code promo modifié',
  'rider.applied': 'Candidature de livreur',
  'rider.balance_topped_up': 'Solde d’un livreur rechargé',
  'rider.cash_deposited': 'Espèces déposées au bureau',
  'rider.cash_overdue': 'Espèces non versées à temps',
  'rider.cash_suspended': 'Livreur suspendu (espèces)',
  'rider.emergency_contact_changed': 'Contact d’urgence modifié',
  'rider_boost.cancelled': 'Prime de renfort arrêtée',
  'rider_boost.created': 'Prime de renfort lancée',
  'security.mfa_enabled': 'Double authentification activée',
  'security.mfa_locked': 'Double authentification bloquée (essais)',
  'security.mfa_reset': 'Double authentification remise à zéro',
  'security.mfa_setup': 'Double authentification en cours de configuration',
  'security.otp_locked': 'Codes SMS bloqués (essais)',
  'team.member_added': 'Membre ajouté à l’équipe',
  'team.member_removed': 'Accès au back-office retiré',
  'team.roles_changed': 'Rôles modifiés',
  'terms.accepted': 'Conditions acceptées',
  'ticket.updated': 'Demande de support mise à jour',
  'user.data_exported': 'Données personnelles exportées',
  'user.deleted': 'Compte supprimé',
  'wallet.credit_granted': 'Avoir accordé',
  'zone.created': 'Zone créée',
  'zone.updated': 'Zone modifiée',
};

export const ENTITY_LABELS: Record<string, string> = {
  order: 'Commandes',
  delivery_proof: 'Preuves de livraison',
  journal: 'Export comptable',
  merchant_profile: 'Boutiques',
  rider_profile: 'Livreurs',
  safety_alert: 'Alertes SOS',
  course_alert: 'Alertes de course',
  rider: 'Candidatures de livreurs',
  user: 'Comptes',
  payout: 'Reversements',
  pricing_grid: 'Grilles tarifaires',
  pricing_settings: 'Tarif pro et primes',
  promo_code: 'Codes promo',
  rider_boost: 'Primes de renfort',
  ticket: 'Support',
  zone: 'Zones',
  kyc_document: 'Pièces des livreurs',
};

export function actionLabel(action: string): string {
  return ACTION_LABELS[action] ?? action;
}

export function entityLabel(type: string): string {
  return ENTITY_LABELS[type] ?? type;
}

/** Valeur JSON lisible et courte (détail avant / après d'une action). */
export function preview(value: unknown): string {
  if (value === null || value === undefined) return '—';
  const text = JSON.stringify(value, null, 1).replace(/\n\s*/g, ' ');
  return text.length > 400 ? `${text.slice(0, 400)}…` : text;
}
