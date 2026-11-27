import { interpolate, type AppLocale } from './locale.js';

/**
 * Textes des SMS, en français et en anglais. Courts (moins de 160 caractères une fois
 * remplis, autant que possible) et sans accents superflus pour limiter le coût d'envoi.
 */
const TEMPLATES = {
  // Réponse du service client quand la personne n'a pas l'app (ou pas de compte) (H6).
  SUPPORT_REPLY: {
    fr: 'Tara service client ({reference}) : {message}',
    en: 'Tara customer service ({reference}): {message}',
  },
  OTP: {
    fr: 'Tara : votre code de connexion est {code}. Il expire dans {minutes} min. Ne le partagez avec personne.',
    en: 'Tara: your sign-in code is {code}. It expires in {minutes} min. Do not share it with anyone.',
  },
  ACCOUNT_DELETION_OTP: {
    fr: 'Tara : code de confirmation de SUPPRESSION de votre compte : {code}. Si vous n avez rien demande, ignorez ce message.',
    en: 'Tara: confirmation code to DELETE your account: {code}. If you did not request this, ignore this message.',
  },
  PIN_RESET_OTP: {
    fr: 'Tara : code pour CHANGER votre code secret : {code}. Il expire dans {minutes} min. Ne le donnez a personne, meme a Tara.',
    en: 'Tara: code to CHANGE your secret PIN: {code}. It expires in {minutes} min. Never share it, not even with Tara.',
  },
  TERMS_OTP: {
    fr: 'Tara : code pour SIGNER votre acceptation des nouvelles conditions : {code}. Ne le partagez avec personne.',
    en: 'Tara: code to SIGN your acceptance of the new terms: {code}. Do not share it with anyone.',
  },
  MFA_ENABLED: {
    fr: 'Tara : la double authentification vient d etre activee sur votre compte. Si ce n est pas vous, prevenez immediatement un administrateur.',
    en: 'Tara: two-factor authentication was just enabled on your account. If this was not you, alert an administrator immediately.',
  },
  MFA_RESET: {
    fr: 'Tara : la double authentification de votre compte a ete reinitialisee par un administrateur. Configurez-la a nouveau.',
    en: 'Tara: your two-factor authentication was reset by an administrator. Please set it up again.',
  },
  // Envoi en masse : le client place lui-même son point, son colis part ensuite (C4, B3).
  LOCATION_LINK_REQUEST: {
    fr: '{sender} vous envoie un colis avec Tara. Indiquez ou le livrer : {url}',
    en: '{sender} is sending you a parcel with Tara. Show us where to deliver it: {url}',
  },
  RECIPIENT_CONFIRMATION: {
    fr: '{sender} vous envoie un colis avec Tara (ref {reference}). Confirmez adresse et disponibilite : {url}',
    en: '{sender} is sending you a parcel with Tara (ref {reference}). Confirm address and availability: {url}',
  },
  DELIVERY_CODE: {
    fr: 'Tara : votre colis {reference} est en route. Verifiez-le avant de donner le code au livreur : {code}. Suivi : {url}',
    en: 'Tara: your parcel {reference} is on its way. Check it before giving the rider the code: {code}. Tracking: {url}',
  },
  RETURN_CODE: {
    fr: 'Tara : la livraison {reference} a echoue. En cas de retour, donnez ce code au livreur seulement quand il vous rend le colis : {code}.',
    en: 'Tara: delivery {reference} failed. If it is returned, give this code to the rider only when they hand the parcel back to you: {code}.',
  },
  DELIVERY_RECEIPT: {
    fr: 'Tara : votre colis {reference} a ete livre. Merci de votre confiance !',
    en: 'Tara: your parcel {reference} has been delivered. Thank you!',
  },
  ORDER_CANCELLED_RECIPIENT: {
    fr: 'Tara : la livraison {reference} envoyee par {sender} a ete annulee.',
    en: 'Tara: delivery {reference} sent by {sender} has been cancelled.',
  },
  OPS_DISPATCH_ALERT: {
    fr: 'Tara OPS : la course {reference} attend un livreur depuis {minutes} min. A attribuer.',
    en: 'Tara OPS: order {reference} has been waiting for a rider for {minutes} min. Please assign.',
  },
  OPS_SAFETY_ALERT: {
    fr: 'Tara OPS ALERTE : le livreur {rider} ({phone}), moto {plate}, a declenche une alerte. Quartier : {place}. Position : {map}',
    en: 'Tara OPS ALERT: rider {rider} ({phone}), plate {plate}, triggered an alert. Area: {place}. Location: {map}',
  },
  OPS_CASH_OVERDUE: {
    fr: 'Tara FINANCE : {rider} ({phone}) n a pas depose ses especes depuis {days} j. Compte suspendu, {offset} FCFA retenus sur ses gains, {amount} FCFA encore dus. Garant : {guarantor} ({guarantorPhone}).',
    en: 'Tara FINANCE: {rider} ({phone}) has not paid back cash for {days} d. Account suspended, {offset} XAF taken from earnings, {amount} XAF still due. Guarantor: {guarantor} ({guarantorPhone}).',
  },
  OPS_RIDER_BOOST: {
    fr: 'Tara ADMIN : {author} a cree une prime de renfort de {amount} FCFA par course ({city}), jusqu au {until}. Motif : {reason}. Arret possible dans le back-office, Tarifs.',
    en: 'Tara ADMIN: {author} created a rider boost of {amount} XAF per delivery ({city}) until {until}. Reason: {reason}. It can be stopped in the back-office, Pricing.',
  },
  OPS_SAFETY_ALERT_CANCELLED: {
    fr: 'Tara OPS : le livreur {rider} ({phone}) a annule son alerte. Rappelez-le pour confirmer qu il va bien.',
    en: 'Tara OPS: rider {rider} ({phone}) cancelled the alert. Call back to confirm they are safe.',
  },
  EMERGENCY_CONTACT_ALERT: {
    fr: 'Tara : {rider} a declenche une alerte de securite pendant son travail. Position : {map}. Notre equipe le contacte.',
    en: 'Tara: {rider} triggered a safety alert while working. Location: {map}. Our team is contacting them.',
  },
  EMERGENCY_CONTACT_ALERT_CANCELLED: {
    fr: 'Tara : {rider} a annule son alerte de securite. Notre equipe verifie qu il va bien.',
    en: 'Tara: {rider} cancelled their safety alert. Our team is checking that they are safe.',
  },
  PAYOUT_PHONE_CHANGED: {
    fr: 'Tara : le numero de reversement de {shop} vient d etre change. Reversements suspendus {hours} h. Si ce n est pas vous, contactez vite le support.',
    en: 'Tara: the payout number of {shop} was just changed. Payouts paused for {hours} h. If this was not you, contact support right away.',
  },
  KYC_DOCUMENT_EXPIRING: {
    fr: 'Tara : votre piece "{document}" expire le {date}. Envoyez la nouvelle dans l app pour continuer a recevoir des courses.',
    en: 'Tara: your document "{document}" expires on {date}. Upload the new one in the app to keep receiving jobs.',
  },
  // Retour sans dette : colis non payé gardé au bureau Tara.
  OFFICE_HELD: {
    fr: 'Tara : votre colis {reference} est garde au bureau Tara ({address}, {hours}). Payez {amount} FCFA dans l app ou au bureau pour le recuperer, avant le {until}.',
    en: 'Tara: your parcel {reference} is kept at the Tara office ({address}, {hours}). Pay {amount} XAF in the app or at the office to collect it, before {until}.',
  },
  OFFICE_REMINDER: {
    fr: 'Tara : votre colis {reference} vous attend au bureau Tara ({address}, {hours}). Il vous reste {days} jours pour payer {amount} FCFA et le recuperer.',
    en: 'Tara: your parcel {reference} is waiting at the Tara office ({address}, {hours}). You have {days} days left to pay {amount} XAF and collect it.',
  },
  OFFICE_HOLD_OVER: {
    fr: 'Tara : le delai de garde de votre colis {reference} est fini. Selon nos conditions, Tara peut en disposer. Contactez Tara au plus vite.',
    en: 'Tara: the holding period of your parcel {reference} is over. Under our terms, Tara may now dispose of it. Contact Tara as soon as possible.',
  },
  OFFICE_PICKUP_CODE: {
    fr: 'Tara : frais payes pour {reference}. Au bureau Tara ({address}, {hours}), donnez ce code pour recuperer votre colis : {code}.',
    en: 'Tara: fees paid for {reference}. At the Tara office ({address}, {hours}), give this code to collect your parcel: {code}.',
  },
} as const satisfies Record<string, Record<AppLocale, string>>;

export type SmsTemplate = keyof typeof TEMPLATES;

export function renderSms(
  template: SmsTemplate,
  locale: AppLocale,
  params: Record<string, string | number>,
): string {
  return interpolate(TEMPLATES[template][locale], params);
}

/**
 * Empreinte de l'app Android en dernière ligne d'un SMS de code (SMS Retriever) : le
 * téléphone remet alors le message à l'app, sans permission ni geste de l'utilisateur.
 */
export function withAppHash(text: string, hash: string | null | undefined): string {
  return hash ? `${text}\n\n${hash}` : text;
}
