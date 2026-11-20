import type { OrderStatus } from './api.js';

export type Locale = 'fr' | 'en';

/** Langue du visiteur : `?lang=`, sinon son navigateur, sinon le français. */
export function pickLocale(query: string | undefined, acceptLanguage: string | undefined): Locale {
  if (query === 'fr' || query === 'en') return query;
  const first = acceptLanguage?.split(',')[0]?.trim().toLowerCase() ?? '';
  return first.startsWith('en') ? 'en' : 'fr';
}

const fr: Strings = {
  lang: 'fr',
  logoAlt: 'Tara, livraison à la demande',
  title: 'Suivi de votre colis',
  brandLine: 'Tara · livraison à Douala',
  brandSub: 'Lien de suivi envoyé par SMS',
  parcelOf: (sender: string) =>
    `Colis ${/^[aeiouyhàâéèêîïôû]/i.test(sender) ? 'd’' : 'de '}${sender}`,
  yourParcel: 'Votre colis',
  riderComing: (name: string) => `${name} arrive chez vous`,
  minutes: (n: number) => `${n} min`,
  status: {
    CREATED: 'Commande enregistrée',
    SEARCHING_RIDER: 'Recherche d’un livreur',
    ASSIGNED: 'Un livreur va chercher votre colis',
    PICKED_UP: 'Votre colis est en route',
    IN_DELIVERY: 'Votre colis arrive',
    DELIVERY_FAILED: 'Le livreur n’a pas pu vous livrer',
    DELIVERED: 'Colis livré',
    RETURNED: 'Colis rendu à l’expéditeur',
    CANCELLED: 'Livraison annulée',
  },
  retrying: 'Le livreur repasse vous livrer',
  returning: 'Le colis retourne chez l’expéditeur',
  scheduledFor: (when: string) => `Livraison prévue ${when}`,
  today: 'aujourd’hui',
  tomorrow: 'demain',
  on: (day: string) => `le ${day}`,
  at: (day: string, time: string) => `${day} à ${time}`,
  searchingBody: 'Dès qu’un livreur accepte, son nom s’affiche ici.',
  assignedBody: 'Il récupère le colis, puis vient vers vous.',
  etaPending: 'Heure d’arrivée bientôt affichée',
  failedBody: 'Appelez-le vite : il attend la décision de l’expéditeur.',
  deliveredAt: (time: string) => `Remis à ${time}. Merci d’avoir été là !`,
  returnedBody: 'L’expéditeur a récupéré le colis.',
  cancelledBody: 'L’expéditeur a annulé cette livraison.',
  trackTo: 'Vous',
  steps: ['Commande', 'Livreur', 'Récupéré', 'Livré'],
  stepFailed: 'Échec',
  stepReturned: 'Rendu',
  vehicle: { MOTORBIKE: 'Moto', TRICYCLE: 'Tricycle', CAR: 'Voiture' },
  callName: (first: string) => `Appeler ${first}`,
  callLabel: (name: string) => `Appeler ${name}, votre livreur`,
  myPoint: 'Mon point',
  toPay: 'À payer à la livraison',
  parcel: 'Colis',
  delivery: 'Livraison',
  payShort: 'Espèces ou Mobile Money',
  mobileMoneyFee: (fee: string) => `Par Mobile Money, ${fee} de frais de l’opérateur s’ajoutent.`,
  paymentPending: (amount: string) =>
    `Une demande de ${amount} est arrivée sur votre téléphone : validez-la avec votre code secret Mobile Money.`,
  nothingToPay: 'Rien à payer : la livraison est réglée.',
  codeHint:
    'À la remise, vérifiez d’abord l’état du colis, puis donnez au livreur le code à 4 chiffres reçu par SMS. Colis abîmé ? Refusez-le : le livreur le photographie et Tara s’en occupe.',
  address: 'Adresse de livraison',
  available: 'Serez-vous là pour recevoir le colis ?',
  notePlaceholder: 'Précision pour le livreur (facultatif)',
  yes: 'Oui, je serai là',
  no: 'Je ne suis pas disponible',
  thanksAvailable: 'Merci ! L’expéditeur sait que vous serez là.',
  thanksUnavailable: 'Merci ! L’expéditeur est prévenu et vous recontactera.',
  alreadyAnswered: 'Votre réponse était déjà enregistrée.',
  refresh: 'Actualiser',
  liveHint: 'La page se met à jour toute seule.',
  footer: 'Tara · livraison à la demande à Douala',
  switchLang: 'English',
  notFoundTitle: 'Lien introuvable',
  notFoundBody: 'Ce lien de suivi n’existe pas ou a expiré. Vérifiez le SMS reçu.',
  unavailableTitle: 'Suivi momentanément indisponible',
  unavailableBody: 'Nous n’arrivons pas à joindre Tara. Réessayez dans un instant.',
  retry: 'Réessayer',
  place: {
    title: 'Votre point de livraison',
    from: (sender) => `${sender} vous envoie un colis`,
    fromUnknown: 'Un colis va vous être livré',
    bubble: 'Placez votre point pour que le livreur vous trouve.',
    pointTitle: 'Placez votre point',
    pointPlaced: 'Point placé',
    step1Body:
      'Placez-vous à l’endroit où vous voulez recevoir le colis (maison, boutique, bureau), puis touchez le bouton.',
    locate: 'Ma position',
    again: 'Reprendre',
    searching: 'Recherche de votre position…',
    found: 'Position trouvée, à {m} m près.',
    rough:
      'Position peu précise (à {m} m près) : activez la localisation précise ou sortez à découvert, puis reprenez-la.',
    denied:
      'Localisation refusée : autorisez-la pour ce site dans votre navigateur, puis réessayez.',
    failed: 'Position introuvable : vérifiez que la localisation est activée, puis réessayez.',
    unsupported: 'Votre navigateur ne donne pas la position : ouvrez ce lien dans Chrome.',
    noscript:
      'Cette page a besoin de JavaScript et de la localisation de votre téléphone pour trouver votre position.',
    landmarkLabel: 'Un repère pour le livreur',
    landmarkPlaceholder: 'Ex. : portail bleu après la pharmacie du carrefour',
    step3: 'Pour vous joindre (facultatif)',
    nameLabel: 'Votre nom',
    phoneLabel: 'Autre numéro à appeler',
    phonePlaceholder: '6XX XX XX XX',
    send: 'Valider mon point',
    validUntil: (when) => `Lien valable jusqu’au ${when}`,
    privacy: 'Votre position sert uniquement à cette livraison.',
    errorPosition: 'Touchez « Ma position » avant de valider.',
    errorLandmark: 'Décrivez un repère (au moins 3 caractères).',
    errorPhone: 'Numéro invalide : 9 chiffres commençant par 6.',
    errorArea:
      'Ce point est hors de la zone desservie par Tara (Douala). Vérifiez votre position, puis réessayez.',
    errorInvalid: 'Vérifiez les informations saisies, puis réessayez.',
    sentTitle: 'Merci, c’est noté !',
    sentBody: (sender) =>
      `${sender ?? 'L’expéditeur'} l’a reçu. Le livreur viendra directement à ce point : gardez votre téléphone allumé.`,
    usedTitle: 'Point déjà envoyé',
    usedBody: (sender) =>
      `Ce lien a déjà servi. Pour changer de point, contactez ${sender ?? 'l’expéditeur'}.`,
    expiredTitle: 'Ce lien a expiré',
    expiredBody: (sender) => `Demandez un nouveau lien à ${sender ?? 'l’expéditeur'}.`,
  },
};

const en: Strings = {
  lang: 'en',
  logoAlt: 'Tara, on-demand delivery',
  title: 'Track your parcel',
  brandLine: 'Tara · delivery in Douala',
  brandSub: 'Tracking link sent by SMS',
  parcelOf: (sender: string) => `Parcel from ${sender}`,
  yourParcel: 'Your parcel',
  riderComing: (name: string) => `${name} is on the way to you`,
  minutes: (n: number) => `${n} min`,
  status: {
    CREATED: 'Order received',
    SEARCHING_RIDER: 'Finding a rider',
    ASSIGNED: 'A rider is picking up your parcel',
    PICKED_UP: 'Your parcel is on its way',
    IN_DELIVERY: 'Your parcel is arriving',
    DELIVERY_FAILED: 'The rider couldn’t deliver',
    DELIVERED: 'Parcel delivered',
    RETURNED: 'Parcel returned to the sender',
    CANCELLED: 'Delivery cancelled',
  },
  retrying: 'The rider is coming back to deliver',
  returning: 'The parcel is going back to the sender',
  scheduledFor: (when: string) => `Delivery planned ${when}`,
  today: 'today',
  tomorrow: 'tomorrow',
  on: (day: string) => `on ${day}`,
  at: (day: string, time: string) => `${day} at ${time}`,
  searchingBody: 'As soon as a rider accepts, their name shows here.',
  assignedBody: 'They pick up the parcel, then head to you.',
  etaPending: 'Arrival time shown soon',
  failedBody: 'Call them quickly: they are waiting for the sender’s decision.',
  deliveredAt: (time: string) => `Handed over at ${time}. Thanks for being there!`,
  returnedBody: 'The sender got the parcel back.',
  cancelledBody: 'The sender cancelled this delivery.',
  trackTo: 'You',
  steps: ['Ordered', 'Rider', 'Picked up', 'Delivered'],
  stepFailed: 'Failed',
  stepReturned: 'Returned',
  vehicle: { MOTORBIKE: 'Motorbike', TRICYCLE: 'Tricycle', CAR: 'Car' },
  callName: (first: string) => `Call ${first}`,
  callLabel: (name: string) => `Call ${name}, your rider`,
  myPoint: 'My spot',
  toPay: 'To pay on delivery',
  parcel: 'Parcel',
  delivery: 'Delivery',
  payShort: 'Cash or Mobile Money',
  mobileMoneyFee: (fee: string) => `By Mobile Money, an operator fee of ${fee} is added.`,
  paymentPending: (amount: string) =>
    `A payment request of ${amount} reached your phone: approve it with your Mobile Money PIN.`,
  nothingToPay: 'Nothing to pay: the delivery is settled.',
  codeHint:
    'At handover, first check the parcel, then give the rider the 4-digit code you got by SMS. Damaged parcel? Refuse it: the rider photographs it and Tara handles it.',
  address: 'Delivery address',
  available: 'Will you be there to receive the parcel?',
  notePlaceholder: 'Note for the rider (optional)',
  yes: 'Yes, I’ll be there',
  no: 'I’m not available',
  thanksAvailable: 'Thanks! The sender knows you’ll be there.',
  thanksUnavailable: 'Thanks! The sender has been told and will contact you.',
  alreadyAnswered: 'Your answer was already recorded.',
  refresh: 'Refresh',
  liveHint: 'This page updates by itself.',
  footer: 'Tara · on-demand delivery in Douala',
  switchLang: 'Français',
  notFoundTitle: 'Link not found',
  notFoundBody: 'This tracking link doesn’t exist or has expired. Check the SMS you received.',
  unavailableTitle: 'Tracking temporarily unavailable',
  unavailableBody: 'We can’t reach Tara right now. Try again in a moment.',
  retry: 'Try again',
  place: {
    title: 'Your delivery point',
    from: (sender) => `${sender} is sending you a parcel`,
    fromUnknown: 'A parcel is coming your way',
    bubble: 'Place your spot so the rider finds you.',
    pointTitle: 'Place your spot',
    pointPlaced: 'Spot placed',
    step1Body:
      'Stand where you want to receive the parcel (home, shop, office), then tap the button.',
    locate: 'My location',
    again: 'Locate again',
    searching: 'Finding your location…',
    found: 'Location found, accurate to {m} m.',
    rough: 'Imprecise location ({m} m): turn on precise location or step outside, then try again.',
    denied: 'Location refused: allow it for this site in your browser, then try again.',
    failed: 'Location not found: check that location is turned on, then try again.',
    unsupported: 'Your browser does not share your location: open this link in Chrome.',
    noscript: 'This page needs JavaScript and your phone’s location to find where you are.',
    landmarkLabel: 'A landmark for the rider',
    landmarkPlaceholder: 'E.g. blue gate after the pharmacy at the junction',
    step3: 'How to reach you (optional)',
    nameLabel: 'Your name',
    phoneLabel: 'Other number to call',
    phonePlaceholder: '6XX XX XX XX',
    send: 'Confirm my spot',
    validUntil: (when) => `Link valid until ${when}`,
    privacy: 'Your location is used for this delivery only.',
    errorPosition: 'Tap “My location” before confirming.',
    errorLandmark: 'Describe a landmark (at least 3 characters).',
    errorPhone: 'Invalid number: 9 digits starting with 6.',
    errorArea:
      'This point is outside the area Tara serves (Douala). Check your location, then try again.',
    errorInvalid: 'Check what you entered, then try again.',
    sentTitle: 'Thanks, all noted!',
    sentBody: (sender) =>
      `${sender ?? 'The sender'} has received it. The rider will come straight to this point: keep your phone on.`,
    usedTitle: 'Location already sent',
    usedBody: (sender) =>
      `This link was already used. To change the point, contact ${sender ?? 'the sender'}.`,
    expiredTitle: 'This link has expired',
    expiredBody: (sender) => `Ask ${sender ?? 'the sender'} for a new link.`,
  },
};

export function strings(locale: Locale): Strings {
  return locale === 'en' ? en : fr;
}

type Text = string;
type Template = (...args: string[]) => string;

/** Textes de la page, dans chaque langue. */
export interface Strings {
  lang: Locale;
  logoAlt: Text;
  title: Text;
  brandLine: Text;
  brandSub: Text;
  parcelOf: Template;
  yourParcel: Text;
  riderComing: Template;
  minutes: (n: number) => string;
  status: Record<OrderStatus, Text>;
  retrying: Text;
  returning: Text;
  scheduledFor: Template;
  today: Text;
  tomorrow: Text;
  on: Template;
  at: Template;
  searchingBody: Text;
  assignedBody: Text;
  etaPending: Text;
  failedBody: Text;
  deliveredAt: Template;
  returnedBody: Text;
  cancelledBody: Text;
  trackTo: Text;
  steps: [Text, Text, Text, Text];
  stepFailed: Text;
  stepReturned: Text;
  vehicle: Record<'MOTORBIKE' | 'TRICYCLE' | 'CAR', Text>;
  callName: Template;
  callLabel: Template;
  myPoint: Text;
  toPay: Text;
  parcel: Text;
  delivery: Text;
  payShort: Text;
  mobileMoneyFee: Template;
  paymentPending: Template;
  nothingToPay: Text;
  codeHint: Text;
  address: Text;
  available: Text;
  notePlaceholder: Text;
  yes: Text;
  no: Text;
  thanksAvailable: Text;
  thanksUnavailable: Text;
  alreadyAnswered: Text;
  refresh: Text;
  liveHint: Text;
  footer: Text;
  switchLang: Text;
  notFoundTitle: Text;
  notFoundBody: Text;
  unavailableTitle: Text;
  unavailableBody: Text;
  retry: Text;
  place: PlaceStrings;
}

type Sender = (sender: string | null) => string;

/** Textes de la page du lien de localisation (B3). */
export interface PlaceStrings {
  title: Text;
  from: Template;
  fromUnknown: Text;
  bubble: Text;
  pointTitle: Text;
  pointPlaced: Text;
  step1Body: Text;
  locate: Text;
  again: Text;
  searching: Text;
  /** « {m} » : précision en mètres, remplie par le script. */
  found: Text;
  rough: Text;
  denied: Text;
  failed: Text;
  unsupported: Text;
  noscript: Text;
  landmarkLabel: Text;
  landmarkPlaceholder: Text;
  step3: Text;
  nameLabel: Text;
  phoneLabel: Text;
  phonePlaceholder: Text;
  send: Text;
  validUntil: Template;
  privacy: Text;
  errorPosition: Text;
  errorLandmark: Text;
  errorPhone: Text;
  errorArea: Text;
  errorInvalid: Text;
  sentTitle: Text;
  sentBody: Sender;
  usedTitle: Text;
  usedBody: Sender;
  expiredTitle: Text;
  expiredBody: Sender;
}
