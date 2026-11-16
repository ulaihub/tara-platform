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
  TERMS_ACCEPTANCE_REQUIRED: {
    fr: 'Les conditions d’utilisation ont changé : lisez-les et acceptez-les pour continuer.',
    en: 'The terms of use have changed: read and accept them to continue.',
  },
  // Code secret du compte (comme Orange Money et MTN MoMo)
  PIN_REQUIRED: {
    fr: 'Entrez votre code secret.',
    en: 'Enter your secret PIN.',
  },
  PIN_INVALID: {
    fr: 'Code secret incorrect. Encore {remaining} essai(s) avant blocage.',
    en: 'Incorrect secret PIN. {remaining} attempt(s) left before it is blocked.',
  },
  PIN_LOCKED: {
    fr: 'Code secret bloqué après 5 erreurs. Choisissez-en un nouveau avec le code reçu par SMS.',
    en: 'Secret PIN blocked after 5 errors. Choose a new one with the code sent by SMS.',
  },
  PIN_NOT_SET: {
    fr: 'Choisissez d’abord votre code secret.',
    en: 'Choose your secret PIN first.',
  },
  PIN_TOO_SIMPLE: {
    fr: 'Code trop facile à deviner (ex. 1111 ou 1234). Choisissez-en un autre.',
    en: 'This PIN is too easy to guess (e.g. 1111 or 1234). Choose another one.',
  },
  BIOMETRIC_INVALID: {
    fr: 'Empreinte à réactiver : entrez votre code secret.',
    en: 'Fingerprint needs to be set up again: enter your secret PIN.',
  },
  TERMS_OUTDATED: {
    fr: 'Une nouvelle version des conditions vient de paraître : relisez-la avant d’accepter.',
    en: 'A new version of the terms was just published: read it again before accepting.',
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
  // Service client (H6)
  TICKET_NOT_FOUND: { fr: 'Demande introuvable.', en: 'Request not found.' },
  TICKET_LIMIT_REACHED: {
    fr: 'Vous avez déjà 5 demandes en cours. Attendez une réponse avant d’en ouvrir une autre.',
    en: 'You already have 5 open requests. Wait for an answer before opening another one.',
  },
  TICKET_CLOSED: {
    fr: 'Cette demande est close. Ouvrez une nouvelle demande si besoin.',
    en: 'This request is closed. Open a new request if needed.',
  },
  TICKET_ASSIGNEE_INVALID: {
    fr: 'La demande ne peut être confiée qu’à un membre de l’équipe Tara.',
    en: 'The request can only be assigned to a Tara team member.',
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
  PARCEL_ANALYSIS_UNAVAILABLE: {
    fr: 'L’analyse de la photo est momentanément indisponible. Choisissez la taille et la nature vous-même.',
    en: 'Photo analysis is temporarily unavailable. Choose the size and contents yourself.',
  },
  PARCEL_ANALYSIS_LIMIT: {
    fr: 'Trop de photos analysées en une heure. Choisissez la taille et la nature vous-même.',
    en: 'Too many photos analysed within an hour. Choose the size and contents yourself.',
  },
  BULKY_UNAVAILABLE: {
    fr: 'Les gros objets (électroménager, meubles) ne sont pas encore livrés à {city}.',
    en: 'Bulky items (appliances, furniture) are not delivered in {city} yet.',
  },
  PRICING_GRID_NOT_FOUND: { fr: 'Grille tarifaire introuvable.', en: 'Pricing grid not found.' },
  TEAM_MEMBER_NOT_FOUND: { fr: 'Membre de l’équipe introuvable.', en: 'Team member not found.' },
  TEAM_MEMBER_UNAVAILABLE: {
    fr: 'Ce numéro appartient à un compte supprimé.',
    en: 'This number belongs to a deleted account.',
  },
  TEAM_LAST_ADMIN: {
    fr: 'Il doit rester au moins un administrateur.',
    en: 'At least one administrator must remain.',
  },
  TEAM_SELF_DEMOTION: {
    fr: 'Vous ne pouvez pas retirer vos propres droits d’administrateur.',
    en: 'You cannot remove your own administrator rights.',
  },
  MERCHANT_NOT_FOUND: { fr: 'Boutique introuvable.', en: 'Shop not found.' },
  RIDER_BOOST_NOT_FOUND: { fr: 'Prime de renfort introuvable.', en: 'Rider boost not found.' },
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
  COURSE_ALERT_NOT_FOUND: { fr: 'Alerte introuvable.', en: 'Alert not found.' },
  ORDER_NOT_IN_PROGRESS: {
    fr: 'Cette course n’est plus en cours.',
    en: 'This job is no longer in progress.',
  },
  ORDER_TRANSITION_INVALID: {
    fr: 'Passage de « {from} » à « {to} » impossible.',
    en: 'Cannot move from "{from}" to "{to}".',
  },
  ORDER_CONFLICT: {
    fr: 'La commande vient d’être modifiée. Rechargez et réessayez.',
    en: 'The order was just changed. Reload and try again.',
  },
  PARCEL_REFUSAL_NOT_ALLOWED: {
    fr: 'Le colis ne peut être refusé qu’à l’enlèvement, avant de le prendre.',
    en: 'A parcel can only be refused at pickup, before taking it.',
  },
  VEHICLE_NOT_SUITABLE: {
    fr: 'Ce livreur roule à moto : un gros objet demande un tricycle ou une camionnette.',
    en: 'This rider is on a motorbike: a bulky item needs a tricycle or a van.',
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

  // Attribution et exécution des courses (D, E)
  RIDER_NOT_ACTIVE: {
    fr: 'Votre compte livreur n’est pas actif.',
    en: 'Your rider account is not active.',
  },
  RIDER_NOT_ELIGIBLE: {
    fr: 'Vous ne pouvez pas recevoir de courses pour le moment : {reasons}.',
    en: 'You cannot receive jobs for now: {reasons}.',
  },
  OFFER_NOT_FOUND: { fr: 'Proposition introuvable.', en: 'Job offer not found.' },
  OFFER_NO_LONGER_AVAILABLE: {
    fr: 'Cette course n’est plus disponible.',
    en: 'This job is no longer available.',
  },
  OFFER_EXPIRED: {
    fr: 'Le délai pour accepter cette course est dépassé.',
    en: 'The time to accept this job has passed.',
  },
  ORDER_ALREADY_ASSIGNED_TO_RIDER: {
    fr: 'La course est déjà confiée à ce livreur.',
    en: 'The job is already assigned to this rider.',
  },
  ACTION_TIME_INVALID: {
    fr: 'Heure de l’action invalide : vérifiez l’heure du téléphone.',
    en: 'Invalid action time: check the phone clock.',
  },
  PICKUP_CODE_INVALID: {
    fr: 'Code de l’expéditeur incorrect. Essais restants : {remaining}.',
    en: 'Incorrect sender code. Attempts left: {remaining}.',
  },
  PICKUP_CODE_LOCKED: {
    fr: 'Trop de codes incorrects. L’expéditeur doit générer un nouveau code.',
    en: 'Too many incorrect codes. The sender must generate a new code.',
  },
  DELIVERY_CODE_INVALID: {
    fr: 'Code du destinataire incorrect. Essais restants : {remaining}.',
    en: 'Incorrect recipient code. Attempts left: {remaining}.',
  },
  DELIVERY_CODE_LOCKED: {
    fr: 'Trop de codes incorrects. Demandez la validation du support.',
    en: 'Too many incorrect codes. Ask support to validate.',
  },
  NO_DELIVERY_VALIDATION_REQUEST: {
    fr: 'Aucune demande de validation de livraison en attente pour cette commande.',
    en: 'No pending delivery validation request for this order.',
  },
  DELIVERY_VALIDATION_ADMIN_REQUIRED: {
    fr: 'Au-delà de {limit} FCFA à encaisser, la validation revient à un administrateur.',
    en: 'Above {limit} XAF to collect, validation requires an administrator.',
  },
  RIDER_BALANCE_TOO_LOW: {
    fr: 'Solde Tara insuffisant pour cette course : {required} FCFA à encaisser, {available} FCFA disponibles. Rechargez votre solde.',
    en: 'Not enough Tara balance for this job: {required} XAF to collect, {available} XAF available. Top up your balance.',
  },
  FAILURE_CALL_REQUIRED: {
    fr: 'Appelez le destinataire depuis l’app avant de déclarer l’échec.',
    en: 'Call the recipient from the app before reporting the failure.',
  },
  FAILURE_CALLS_REQUIRED: {
    fr: 'Appelez le destinataire au moins {required} fois depuis l’app, à {spacingMinutes} min d’écart, avant de déclarer l’échec.',
    en: 'Call the recipient at least {required} times from the app, {spacingMinutes} min apart, before reporting the failure.',
  },
  RATING_NOT_OPEN: {
    fr: 'Cette course ne peut pas ou plus être notée.',
    en: 'This delivery can’t be rated (anymore).',
  },
  RATING_ALREADY_GIVEN: {
    fr: 'Vous avez déjà noté cette course.',
    en: 'You already rated this delivery.',
  },
  FAILURE_DECISION_NOT_EXPECTED: {
    fr: 'Aucune décision n’est attendue pour cette commande.',
    en: 'No decision is expected for this order.',
  },
  SAFETY_ALERT_NOT_FOUND: { fr: 'Alerte introuvable.', en: 'Alert not found.' },
  SAFETY_ALERT_CLOSED: {
    fr: 'Cette alerte est déjà close ou annulée.',
    en: 'This alert is already closed or cancelled.',
  },
  EMERGENCY_CONTACT_IS_SELF: {
    fr: 'Le contact d’urgence doit être un proche, pas votre propre numéro.',
    en: 'The emergency contact must be someone close to you, not your own number.',
  },

  // Argent (G)
  PAYMENT_ALREADY_PENDING: {
    fr: 'Une demande de paiement attend déjà la validation sur le téléphone.',
    en: 'A payment request is already waiting for approval on the phone.',
  },
  PAYMENT_NOT_FOUND: { fr: 'Paiement introuvable.', en: 'Payment not found.' },
  PAYMENT_NOT_EXPECTED: {
    fr: 'Aucun paiement n’est attendu pour cette commande.',
    en: 'No payment is expected for this order.',
  },
  INSUFFICIENT_BALANCE: {
    fr: 'Solde insuffisant ({balance} FCFA disponibles).',
    en: 'Insufficient balance ({balance} XAF available).',
  },
  RETRY_PAYMENT_REQUIRED: {
    fr: 'Solde insuffisant pour la nouvelle tentative ({fee} FCFA) : rechargez au moins {amount} FCFA, ou choisissez le retour.',
    en: 'Not enough balance for another attempt ({fee} XAF): top up at least {amount} XAF, or choose the return.',
  },
  RETRY_LIMIT_REACHED: {
    fr: 'Une seule nouvelle tentative est possible : le colis vous sera rapporté.',
    en: 'Only one more attempt is possible: the parcel will be brought back to you.',
  },
  MERCHANT_DEBT_LIMIT: {
    fr: 'Votre boutique doit {debt} FCFA à Tara (plafond {limit} FCFA) : rechargez votre solde pour commander de nouveau.',
    en: 'Your shop owes Tara {debt} XAF (limit {limit} XAF): top up your balance to order again.',
  },
  ACCOUNT_HAS_DEBT: {
    fr: 'Votre solde Tara est négatif ({debt} FCFA dus) : réglez-le avant de supprimer le compte.',
    en: 'Your Tara balance is negative ({debt} XAF due): settle it before deleting the account.',
  },
  ACCOUNT_HAS_BALANCE: {
    fr: 'Il vous reste {balance} FCFA chez Tara : retirez-les vers votre Mobile Money avant de supprimer le compte.',
    en: 'You still have {balance} XAF with Tara: withdraw it to your Mobile Money before deleting the account.',
  },
  ACCOUNT_HAS_PAYOUT_IN_PROGRESS: {
    fr: 'Un retrait vers votre Mobile Money est en cours : attendez qu’il arrive avant de supprimer le compte.',
    en: 'A withdrawal to your Mobile Money is in progress: wait until it arrives before deleting the account.',
  },
  WALLET_IN_DEBT: {
    fr: 'Votre solde Tara est négatif : réglez-le avant une nouvelle commande.',
    en: 'Your Tara balance is negative: settle it before placing a new order.',
  },
  COLLECTION_REQUIRED: {
    fr: 'Encaissez d’abord {amount} FCFA auprès du destinataire.',
    en: 'Collect {amount} XAF from the recipient first.',
  },
  RETURN_COLLECTION_REQUIRED: {
    fr: 'Encaissez d’abord {amount} FCFA auprès de l’expéditeur : le colis n’est rendu qu’une fois les frais réglés.',
    en: 'Collect {amount} XAF from the sender first: the parcel is handed back only once the fees are paid.',
  },
  COLLECTION_NOT_EXPECTED: {
    fr: 'Rien à encaisser pour cette commande.',
    en: 'Nothing to collect for this order.',
  },
  ALREADY_COLLECTED: {
    fr: 'Le montant a déjà été encaissé.',
    en: 'The amount has already been collected.',
  },
  PAYOUT_TOO_SMALL: {
    fr: 'Montant minimal d’un reversement : {min} FCFA.',
    en: 'Minimum payout amount: {min} XAF.',
  },
  PAYOUT_IN_PROGRESS: {
    fr: 'Un reversement est déjà en cours.',
    en: 'A payout is already in progress.',
  },
  DAMAGE_CLAIM_TOO_LATE: {
    fr: 'Le délai pour signaler un colis abîmé est dépassé : 7 jours après la livraison, dimanches et jours fériés non compris. Contactez le service client par téléphone.',
    en: 'The deadline to report a damaged parcel has passed: 7 days after delivery, Sundays and public holidays excluded. Please call customer service.',
  },
  PAYOUT_FROZEN: {
    fr: 'Votre compte est suspendu : les retraits sont bloqués jusqu’à la décision de l’équipe Tara. Contactez le support.',
    en: 'Your account is suspended: withdrawals are blocked until the Tara team decides. Please contact support.',
  },
  PAYOUT_NOT_ALLOWED: {
    fr: 'Le reversement à la demande est réservé aux offres Pro et Business : vos ventes vous sont versées chaque jour à 18 h.',
    en: 'On-demand payouts are for Pro and Business plans: your sales are paid out every day at 6 pm.',
  },
  PAYOUT_NOT_FOUND: { fr: 'Reversement introuvable.', en: 'Payout not found.' },
  PAYOUT_NOT_AWAITING_APPROVAL: {
    fr: 'Ce reversement n’attend pas de validation.',
    en: 'This payout is not awaiting approval.',
  },
  DEPOSIT_TOO_LARGE: {
    fr: 'Vous ne détenez que {cashHeld} FCFA d’espèces.',
    en: 'You only hold {cashHeld} XAF in cash.',
  },
  PAYOUT_ON_HOLD: {
    fr: 'Numéro de reversement modifié récemment : reversements possibles à partir du {until}.',
    en: 'Payout number changed recently: payouts possible from {until}.',
  },
  PAYOUT_PHONE_NOT_ALLOWED: {
    fr: 'L’argent ne peut partir que vers le numéro de votre compte. Pour un autre numéro, contactez le support.',
    en: 'Money can only be sent to your account number. For another number, contact support.',
  },
  SELF_APPROVAL_FORBIDDEN: {
    fr: 'Opération interdite sur votre propre compte : un autre membre de l’équipe doit la faire.',
    en: 'Not allowed on your own account: another team member must do it.',
  },
  STATEMENT_PERIOD_INVALID: {
    fr: 'Mois invalide : utilisez le format AAAA-MM, mois terminé ou en cours.',
    en: 'Invalid month: use YYYY-MM, past or current month.',
  },
} as const satisfies Record<string, { fr: string; en: string }>;

export type ErrorCode = keyof typeof ERROR_MESSAGES;
