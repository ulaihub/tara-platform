import { type AppLocale, interpolate } from '../common/i18n/locale.js';

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
  RIDER_FAILURE_DECISION: {
    fr: { title: 'Décision de l’expéditeur', body: '{reference} : {decision}.' },
    en: { title: 'Sender decision', body: '{reference}: {decision}.' },
  },
} as const satisfies Record<string, Record<AppLocale, { title: string; body: string }>>;

export type PushTemplate = keyof typeof TEMPLATES;

export function renderPush(
  template: PushTemplate,
  locale: AppLocale,
  params: Record<string, string | number>,
): { title: string; body: string } {
  const { title, body } = TEMPLATES[template][locale];
  return { title: interpolate(title, params), body: interpolate(body, params) };
}
