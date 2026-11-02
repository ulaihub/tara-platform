import { interpolate, type AppLocale } from './locale.js';

/**
 * Textes des SMS, en français et en anglais. Courts (moins de 160 caractères une fois
 * remplis, autant que possible) et sans accents superflus pour limiter le coût d'envoi.
 */
const TEMPLATES = {
  OTP: {
    fr: 'Tara : votre code de connexion est {code}. Il expire dans {minutes} min. Ne le partagez avec personne.',
    en: 'Tara: your sign-in code is {code}. It expires in {minutes} min. Do not share it with anyone.',
  },
  ACCOUNT_DELETION_OTP: {
    fr: 'Tara : code de confirmation de SUPPRESSION de votre compte : {code}. Si vous n avez rien demande, ignorez ce message.',
    en: 'Tara: confirmation code to DELETE your account: {code}. If you did not request this, ignore this message.',
  },
  MFA_ENABLED: {
    fr: 'Tara : la double authentification vient d etre activee sur votre compte. Si ce n est pas vous, prevenez immediatement un administrateur.',
    en: 'Tara: two-factor authentication was just enabled on your account. If this was not you, alert an administrator immediately.',
  },
  MFA_RESET: {
    fr: 'Tara : la double authentification de votre compte a ete reinitialisee par un administrateur. Configurez-la a nouveau.',
    en: 'Tara: your two-factor authentication was reset by an administrator. Please set it up again.',
  },
  RECIPIENT_CONFIRMATION: {
    fr: '{sender} vous envoie un colis avec Tara (ref {reference}). Confirmez adresse et disponibilite : {url}',
    en: '{sender} is sending you a parcel with Tara (ref {reference}). Confirm address and availability: {url}',
  },
  DELIVERY_CODE: {
    fr: 'Tara : votre colis {reference} est en route. Code a donner au livreur : {code}. Suivi : {url}',
    en: 'Tara: your parcel {reference} is on its way. Code to give the rider: {code}. Tracking: {url}',
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
    fr: 'Tara OPS ALERTE : le livreur {rider} ({phone}) a declenche une alerte. Position : {map}',
    en: 'Tara OPS ALERT: rider {rider} ({phone}) triggered an alert. Location: {map}',
  },
  KYC_DOCUMENT_EXPIRING: {
    fr: 'Tara : votre piece "{document}" expire le {date}. Envoyez la nouvelle dans l app pour continuer a recevoir des courses.',
    en: 'Tara: your document "{document}" expires on {date}. Upload the new one in the app to keep receiving jobs.',
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
