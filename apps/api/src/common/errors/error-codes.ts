/**
 * Codes d'erreur stables renvoyés par l'API, avec leur message en français et en anglais.
 * Les applications s'appuient sur `code` ; le message est prêt à afficher.
 * Les paramètres entre accolades sont remplacés à l'exécution.
 */
export const ERROR_MESSAGES = {
  VALIDATION_FAILED: { fr: 'Certaines données sont invalides.', en: 'Some data is invalid.' },
  UNAUTHENTICATED: { fr: 'Connexion requise.', en: 'Sign-in required.' },
  FORBIDDEN: { fr: 'Action non autorisée.', en: 'Action not allowed.' },
  NOT_FOUND: { fr: 'Ressource introuvable.', en: 'Resource not found.' },
  RATE_LIMITED: {
    fr: 'Trop de tentatives. Réessayez dans quelques minutes.',
    en: 'Too many attempts. Please try again in a few minutes.',
  },
  PAYLOAD_TOO_LARGE: {
    fr: 'Fichier ou requête trop volumineux.',
    en: 'File or request too large.',
  },
  INTERNAL_ERROR: {
    fr: 'Une erreur est survenue. Réessayez plus tard.',
    en: 'Something went wrong. Please try again later.',
  },
  IDEMPOTENCY_CONFLICT: {
    fr: 'Cette clé d’idempotence est déjà utilisée par une autre requête.',
    en: 'This idempotency key is already used by another request.',
  },

  // Authentification (A1)
  INVALID_PHONE: {
    fr: 'Numéro de mobile camerounais invalide.',
    en: 'Invalid Cameroonian mobile number.',
  },
  OTP_REQUEST_TOO_SOON: {
    fr: 'Patientez {seconds} s avant de demander un nouveau code.',
    en: 'Please wait {seconds} s before requesting a new code.',
  },
  OTP_REQUEST_LIMIT: {
    fr: 'Trop de codes demandés. Réessayez dans {minutes} min.',
    en: 'Too many codes requested. Try again in {minutes} min.',
  },
  OTP_INVALID: { fr: 'Code incorrect.', en: 'Incorrect code.' },
  OTP_EXPIRED: {
    fr: 'Ce code a expiré. Demandez-en un nouveau.',
    en: 'This code has expired. Please request a new one.',
  },
  OTP_TOO_MANY_ATTEMPTS: {
    fr: 'Trop d’essais. Demandez un nouveau code.',
    en: 'Too many attempts. Please request a new code.',
  },
  OTP_LOCKED: {
    fr: 'Trop de codes incorrects pour ce numéro. Réessayez demain ou contactez le support.',
    en: 'Too many incorrect codes for this number. Try again tomorrow or contact support.',
  },
  SMS_TEMPORARILY_UNAVAILABLE: {
    fr: 'Les inscriptions sont momentanément suspendues. Réessayez plus tard.',
    en: 'Sign-ups are temporarily suspended. Please try again later.',
  },
  MFA_REQUIRED: {
    fr: 'Confirmez votre identité avec votre application d’authentification.',
    en: 'Confirm your identity with your authenticator app.',
  },
  MFA_NOT_SET_UP: {
    fr: 'La double authentification n’est pas encore configurée.',
    en: 'Two-factor authentication is not set up yet.',
  },
  MFA_ALREADY_ENABLED: {
    fr: 'La double authentification est déjà active sur ce compte.',
    en: 'Two-factor authentication is already enabled on this account.',
  },
  MFA_INVALID: { fr: 'Code d’authentification incorrect.', en: 'Incorrect authentication code.' },
  MFA_LOCKED: {
    fr: 'Trop d’essais. Réessayez dans 15 minutes.',
    en: 'Too many attempts. Try again in 15 minutes.',
  },
  ACCOUNT_HAS_ACTIVE_ORDERS: {
    fr: 'Des commandes sont en cours : attendez leur fin pour supprimer le compte.',
    en: 'Some orders are in progress: wait until they are finished to delete the account.',
  },
  ACCOUNT_DELETION_NOT_ALLOWED: {
    fr: 'Ce compte ne peut pas être supprimé depuis l’application. Contactez le support.',
    en: 'This account cannot be deleted from the app. Please contact support.',
  },
  SMS_SEND_FAILED: {
    fr: 'Le SMS n’a pas pu être envoyé. Réessayez.',
    en: 'The SMS could not be sent. Please try again.',
  },
  TERMS_REQUIRED: {
    fr: 'Acceptez les conditions d’utilisation pour créer votre compte.',
    en: 'Accept the terms of use to create your account.',
  },
  ACCOUNT_SUSPENDED: {
    fr: 'Ce compte est suspendu. Contactez le support.',
    en: 'This account is suspended. Please contact support.',
  },
  REFRESH_TOKEN_INVALID: {
    fr: 'Session expirée. Reconnectez-vous.',
    en: 'Session expired. Please sign in again.',
  },

  // Profils et livreurs (A2, A3, A5)
  RIDER_ALREADY_APPLIED: {
    fr: 'Une candidature livreur existe déjà pour ce compte.',
    en: 'A rider application already exists for this account.',
  },
  RIDER_NOT_FOUND: { fr: 'Livreur introuvable.', en: 'Rider not found.' },
  RIDER_DOCUMENTS_INCOMPLETE: {
    fr: 'Pièces manquantes ou non validées : {missing}.',
    en: 'Missing or unapproved documents: {missing}.',
  },
  RIDER_DECISION_INVALID: {
    fr: 'Cette décision n’est pas possible pour un livreur au statut {status}.',
    en: 'This decision is not possible for a rider with status {status}.',
  },
  KYC_DOCUMENT_NOT_FOUND: { fr: 'Pièce introuvable.', en: 'Document not found.' },
  KYC_DOCUMENT_ALREADY_REVIEWED: {
    fr: 'Cette pièce a déjà été examinée.',
    en: 'This document has already been reviewed.',
  },

  // Fichiers (B2, A3)
  MEDIA_TYPE_NOT_ALLOWED: {
    fr: 'Type de fichier non accepté.',
    en: 'File type not accepted.',
  },
  MEDIA_TOO_LARGE: {
    fr: 'Fichier trop volumineux (maximum {maxKb} Ko).',
    en: 'File too large (maximum {maxKb} KB).',
  },
  MEDIA_NOT_FOUND: { fr: 'Fichier introuvable.', en: 'File not found.' },

  // Adresses et zones (B1 à B6)
  OUT_OF_SERVICE_AREA: {
    fr: 'Cette adresse est hors de notre zone de livraison.',
    en: 'This address is outside our delivery area.',
  },
  ZONE_GEOMETRY_INVALID: {
    fr: 'Géométrie de zone invalide.',
    en: 'Invalid zone geometry.',
  },
  ADDRESS_NOT_FOUND: { fr: 'Adresse introuvable.', en: 'Address not found.' },
  LOCATION_LINK_NOT_FOUND: { fr: 'Lien introuvable.', en: 'Link not found.' },
  LOCATION_LINK_EXPIRED: { fr: 'Ce lien a expiré.', en: 'This link has expired.' },
  LOCATION_LINK_ALREADY_USED: {
    fr: 'Une adresse a déjà été envoyée avec ce lien.',
    en: 'An address has already been sent with this link.',
  },

  // Tarification (C2, C6, C7)
  PRICING_UNAVAILABLE: {
    fr: 'Aucun tarif n’est actif pour {city}.',
    en: 'No active pricing for {city}.',
  },
  PRICING_GRID_NOT_FOUND: { fr: 'Grille tarifaire introuvable.', en: 'Pricing grid not found.' },
  PROMO_INVALID: { fr: 'Code promo inconnu.', en: 'Unknown promo code.' },
  PROMO_EXPIRED: {
    fr: 'Ce code promo n’est plus valable.',
    en: 'This promo code is no longer valid.',
  },
  PROMO_EXHAUSTED: {
    fr: 'Ce code promo a atteint sa limite d’utilisation.',
    en: 'This promo code has reached its usage limit.',
  },
  PROMO_NOT_ELIGIBLE: {
    fr: 'Ce code promo ne s’applique pas à votre compte.',
    en: 'This promo code does not apply to your account.',
  },
  PROMO_ALREADY_EXISTS: {
    fr: 'Ce code promo existe déjà.',
    en: 'This promo code already exists.',
  },

  // Commandes (C1 à C5)
  ORDER_NOT_FOUND: { fr: 'Commande introuvable.', en: 'Order not found.' },
  ORDER_TRANSITION_INVALID: {
    fr: 'Passage de « {from} » à « {to} » impossible.',
    en: 'Cannot move from "{from}" to "{to}".',
  },
  ORDER_CONFLICT: {
    fr: 'La commande vient d’être modifiée. Rechargez et réessayez.',
    en: 'The order was just changed. Reload and try again.',
  },
  ORDER_NOT_CANCELLABLE: {
    fr: 'Cette commande ne peut plus être annulée.',
    en: 'This order can no longer be cancelled.',
  },
  SAME_PICKUP_AND_DROPOFF: {
    fr: 'Les adresses d’enlèvement et de livraison sont identiques.',
    en: 'Pickup and drop-off addresses are the same.',
  },
  SCHEDULE_INVALID: {
    fr: 'Le créneau doit commencer dans au moins 30 minutes et au plus 7 jours.',
    en: 'The time slot must start between 30 minutes and 7 days from now.',
  },
  MERCHANT_REQUIRED_FOR_COD: {
    fr: 'L’encaissement à la livraison est réservé aux comptes marchands.',
    en: 'Cash on delivery is only available to merchant accounts.',
  },
  COD_AMOUNT_TOO_HIGH: {
    fr: 'Montant à encaisser trop élevé (maximum {max} FCFA).',
    en: 'Amount to collect is too high (maximum {max} FCFA).',
  },
  PAYMENT_METHOD_NOT_ALLOWED: {
    fr: 'Moyen de paiement non autorisé pour ce cas.',
    en: 'Payment method not allowed in this case.',
  },
  PICKUP_ALREADY_DONE: {
    fr: 'Le colis a déjà été enlevé.',
    en: 'The parcel has already been picked up.',
  },
  RECIPIENT_ALREADY_RESPONDED: {
    fr: 'Vous avez déjà répondu pour cette livraison.',
    en: 'You have already responded for this delivery.',
  },
} as const satisfies Record<string, { fr: string; en: string }>;

export type ErrorCode = keyof typeof ERROR_MESSAGES;
