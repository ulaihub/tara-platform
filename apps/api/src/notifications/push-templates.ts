import { type AppLocale, interpolate } from '../common/i18n/locale.js';
import type { PushChannel } from './push.provider.js';

/** Titres et textes des notifications push, en français et en anglais. */
const TEMPLATES = {
  OFFER_NEW: {
    fr: {
      title: 'Nouvelle course',
      body: '{pickup} → {dropoff} · {earning} FCFA. Répondez vite !',
    },
    en: { title: 'New job', body: '{pickup} → {dropoff} · {earning} FCFA. Answer quickly!' },
  },
  ORDER_ASSIGNED: {
    fr: { title: 'Livreur trouvé', body: '{rider} récupère votre colis {reference}.' },
    en: { title: 'Rider found', body: '{rider} is picking up your parcel {reference}.' },
  },
  /** Envoi de plusieurs colis : quel colis donner à ce livreur. */
  ORDER_ASSIGNED_BATCH: {
    fr: {
      title: 'Livreur trouvé · colis n° {number}',
      body: '{rider} vient chercher le colis n° {number} (pour {recipient}).',
    },
    en: {
      title: 'Rider found · parcel no. {number}',
      body: '{rider} is coming for parcel no. {number} (for {recipient}).',
    },
  },
  ORDER_PICKED_UP: {
    fr: { title: 'Colis enlevé', body: 'Votre colis {reference} est entre les mains du livreur.' },
    en: { title: 'Parcel picked up', body: 'Your parcel {reference} is with the rider.' },
  },
  ORDER_IN_DELIVERY: {
    fr: { title: 'En route', body: 'Le livreur part livrer {reference}.' },
    en: { title: 'On the way', body: 'The rider is delivering {reference}.' },
  },
  ORDER_DELIVERED: {
    fr: { title: 'Colis livré', body: 'Votre colis {reference} a été livré.' },
    en: { title: 'Parcel delivered', body: 'Your parcel {reference} has been delivered.' },
  },
  ORDER_DELIVERY_FAILED: {
    fr: {
      title: 'Livraison impossible',
      body: '{reference} n’a pas pu être livré. Choisissez vite : nouvelle tentative ou retour. Sans réponse, le colis vous est rapporté.',
    },
    en: {
      title: 'Delivery failed',
      body: '{reference} could not be delivered. Choose quickly: try again or return. Without an answer, the parcel is brought back to you.',
    },
  },
  ORDER_RETURNED: {
    fr: { title: 'Colis retourné', body: 'Votre colis {reference} vous a été rendu.' },
    en: { title: 'Parcel returned', body: 'Your parcel {reference} has been returned to you.' },
  },
  ORDER_CANCELLED: {
    fr: { title: 'Commande annulée', body: 'La commande {reference} a été annulée.' },
    en: { title: 'Order cancelled', body: 'Order {reference} has been cancelled.' },
  },
  ORDER_PARCEL_REFUSED: {
    fr: {
      title: 'Colis refusé à l’enlèvement',
      body: '{reference} · {reason}. La commande est annulée et le déplacement du livreur ({fee} FCFA) est à votre charge.',
    },
    en: {
      title: 'Parcel refused at pickup',
      body: '{reference} · {reason}. The order is cancelled and the rider’s trip ({fee} FCFA) is charged to you.',
    },
  },
  RIDER_ORDER_CANCELLED: {
    fr: {
      title: 'Course annulée',
      body: 'La course {reference} a été annulée. Ne vous déplacez pas.',
    },
    en: { title: 'Job cancelled', body: 'Job {reference} has been cancelled. Do not go.' },
  },
  RIDER_ORDER_REASSIGNED: {
    fr: {
      title: 'Course retirée',
      body: 'La course {reference} a été confiée à un autre livreur.',
    },
    en: { title: 'Job withdrawn', body: 'Job {reference} has been given to another rider.' },
  },
  PAYOUT_SENT: {
    fr: { title: 'Argent envoyé', body: '{amount} FCFA envoyés sur votre Mobile Money.' },
    en: { title: 'Money sent', body: '{amount} XAF sent to your Mobile Money.' },
  },
  PAYOUT_FAILED: {
    fr: {
      title: 'Envoi impossible',
      body: 'L’envoi de {amount} FCFA a échoué : le montant reste sur votre solde Tara.',
    },
    en: {
      title: 'Payout failed',
      body: 'Sending {amount} XAF failed: the amount stays on your Tara balance.',
    },
  },
  RIDER_CASH_REMINDER: {
    fr: {
      title: 'Espèces à déposer',
      body: 'Déposez vos {amount} FCFA avant {time} (Mobile Money ou bureau Tara).',
    },
    en: {
      title: 'Cash to pay back',
      body: 'Pay back your {amount} XAF before {time} (Mobile Money or Tara office).',
    },
  },
  RIDER_CASH_OVERDUE: {
    fr: {
      title: 'Dépôt en retard',
      body: 'Plus de courses tant que vos {amount} FCFA ne sont pas déposés.',
    },
    en: {
      title: 'Cash overdue',
      body: 'No more jobs until your {amount} XAF are paid back.',
    },
  },
  RIDER_CASH_SUSPENDED: {
    fr: {
      title: 'Compte suspendu',
      body: 'Espèces non déposées : compte suspendu, {amount} FCFA restent dus. Contactez Tara.',
    },
    en: {
      title: 'Account suspended',
      body: 'Cash not paid back: account suspended, {amount} XAF still due. Contact Tara.',
    },
  },
  SENDER_FAILURE_DECISION: {
    fr: { title: 'Suite de votre livraison', body: '{reference} : {decision}.' },
    en: { title: 'Your delivery', body: '{reference}: {decision}.' },
  },
  // Le nom de la pièce est passé dans les deux langues ; le motif est celui de l'équipe.
  RIDER_DOCUMENT_REJECTED: {
    fr: {
      title: 'Pièce refusée',
      body: '{documentFr} — motif : {reason}. Renvoyez-la depuis votre profil.',
    },
    en: {
      title: 'Document rejected',
      body: '{documentEn} — reason: {reason}. Send it again from your profile.',
    },
  },
  // Le destinataire a placé son point depuis le lien de localisation (B3).
  /** Envoi en masse : le client a placé son point, son colis part tout seul. */
  PENDING_DELIVERY_RELEASED: {
    fr: {
      title: 'Colis n° {number} : il part',
      body: '{name} a placé son point. On cherche un livreur pour son colis.',
    },
    en: {
      title: 'Parcel no. {number} is leaving',
      body: '{name} placed their point. We are finding a rider for their parcel.',
    },
  },
  /** Point arrivé, mais la course se paie par Mobile Money : l'expéditeur valide le paiement. */
  PENDING_DELIVERY_TO_PAY: {
    fr: {
      title: 'Colis n° {number} : à payer',
      body: '{name} a placé son point. Payez {amount} FCFA pour que son colis parte.',
    },
    en: {
      title: 'Parcel no. {number}: payment needed',
      body: '{name} placed their point. Pay {amount} XAF so their parcel can leave.',
    },
  },
  /** Point arrivé, départ impossible (solde insuffisant…) : l'expéditeur choisit quoi faire. */
  PENDING_DELIVERY_BLOCKED: {
    fr: {
      title: 'Colis n° {number} : en attente',
      body: '{name} a placé son point, mais le colis ne peut pas partir : {reason}',
    },
    en: {
      title: 'Parcel no. {number} on hold',
      body: '{name} placed their point, but the parcel cannot leave: {reason}',
    },
  },
  LOCATION_LINK_SUBMITTED: {
    fr: {
      title: 'Adresse reçue',
      body: '{name} a placé son point : « {landmark} ». Vous pouvez valider la livraison.',
    },
    en: {
      title: 'Address received',
      body: '{name} placed their point: “{landmark}”. You can confirm the delivery.',
    },
  },
  LOCATION_LINK_SUBMITTED_ANONYMOUS: {
    fr: {
      title: 'Adresse reçue',
      body: 'Votre destinataire a placé son point : « {landmark} ». Vous pouvez valider la livraison.',
    },
    en: {
      title: 'Address received',
      body: 'Your recipient placed their point: “{landmark}”. You can confirm the delivery.',
    },
  },
  // Réponse du service client à une demande (H6).
  SUPPORT_REPLY: {
    fr: { title: 'Service client Tara', body: 'Demande {reference} : {excerpt}' },
    en: { title: 'Tara customer service', body: 'Request {reference}: {excerpt}' },
  },
  RIDER_FAILURE_DECISION: {
    fr: { title: 'Décision de l’expéditeur', body: '{reference} : {decision}.' },
    en: { title: 'Sender decision', body: '{reference}: {decision}.' },
  },
} as const satisfies Record<string, Record<AppLocale, { title: string; body: string }>>;

export type PushTemplate = keyof typeof TEMPLATES;

/** Notifications d'argent : canal Android au son de pièce (créé par les apps). */
const MONEY_TEMPLATES = new Set<PushTemplate>(['PAYOUT_SENT']);

export function pushChannel(template: PushTemplate, urgent: boolean): PushChannel {
  if (urgent) return 'offers';
  return MONEY_TEMPLATES.has(template) ? 'money' : 'orders';
}

export function renderPush(
  template: PushTemplate,
  locale: AppLocale,
  params: Record<string, string | number>,
): { title: string; body: string } {
  const { title, body } = TEMPLATES[template][locale];
  return { title: interpolate(title, params), body: interpolate(body, params) };
}
