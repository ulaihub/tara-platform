// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Tara Livreur';

  @override
  String get back => 'Retour';

  @override
  String get close => 'Fermer';

  @override
  String get notifications => 'Notifications';

  @override
  String get recenterMap => 'Recentrer la carte';

  @override
  String get safetyAlert => 'Alerte de sécurité';

  @override
  String callPerson(String name) {
    return 'Appeler $name';
  }

  @override
  String digitLabel(int index) {
    return 'Chiffre $index';
  }

  @override
  String get currencyFcfa => 'FCFA';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabActivity => 'Activité';

  @override
  String get tabProfile => 'Profil';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String get goOnlineLabel => 'Vous êtes hors ligne. Passer en ligne';

  @override
  String get goOfflineLabel => 'Vous êtes en ligne. Passer hors ligne';

  @override
  String get goOnline => 'Passer en ligne';

  @override
  String secondsRemaining(int seconds) {
    return 'Temps restant pour accepter : $seconds secondes';
  }

  @override
  String get seconds => 'secondes';

  @override
  String get sosHoldLabel => 'Maintenir 3 secondes pour envoyer une alerte';

  @override
  String get sosHold => 'Maintenir 3 s';

  @override
  String sosHoldRemaining(int seconds) {
    return 'Encore $seconds s…';
  }

  @override
  String get sosSent => 'Envoyée';

  @override
  String get offlineBannerTitle => 'Hors connexion';

  @override
  String offlineBannerPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions en attente',
      one: '1 action en attente',
      zero: 'Aucune action en attente',
    );
    return '$_temp0 · enregistrées sur le téléphone';
  }

  @override
  String get catalogTitle => 'Catalogue des composants';

  @override
  String get stepPickup => 'Enlèvement';

  @override
  String get stepCollect => 'Encaissement';

  @override
  String get stepDelivery => 'Livraison';

  @override
  String get cash => 'Espèces';

  @override
  String get mobileMoney => 'Mobile Money';

  @override
  String get periodDay => 'Jour';

  @override
  String get periodWeek => 'Semaine';

  @override
  String get periodMonth => 'Mois';

  @override
  String get searchingJobs => 'Recherche de courses…';

  @override
  String get searchingJobsHint => 'Restez dans la zone, les propositions arrivent ici.';

  @override
  String get stepDone => 'terminée';

  @override
  String get stepActive => 'en cours';

  @override
  String get stepUpcoming => 'à venir';

  @override
  String get riderSpace => 'ESPACE LIVREUR';

  @override
  String get signInTitle => 'Prêt à prendre la route ?';

  @override
  String get signInBody => 'Connectez-vous avec votre numéro. Nous vous envoyons un code par SMS.';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get phoneHint => '6XX XX XX XX';

  @override
  String countryCodeLabel(String code) {
    return 'Indicatif du pays $code';
  }

  @override
  String get phoneHelp => 'Utilisez le numéro lié à votre compte Mobile Money : vos gains y seront versés.';

  @override
  String get phoneInvalid => 'Numéro de mobile camerounais à 9 chiffres, commençant par 6.';

  @override
  String get getCode => 'Recevoir le code';

  @override
  String get legalPrefix => 'En continuant, vous acceptez les ';

  @override
  String get terms => 'conditions d’utilisation';

  @override
  String get legalAnd => ' et la ';

  @override
  String get privacy => 'politique de confidentialité';

  @override
  String get codeTitle => 'Entrez le code reçu';

  @override
  String codeSentTo(String phone) {
    return 'Envoyé par SMS au $phone';
  }

  @override
  String get change => 'Modifier';

  @override
  String resendIn(String time) {
    return 'Renvoyer le code dans $time';
  }

  @override
  String get resendNow => 'Vous n’avez rien reçu ?';

  @override
  String get resend => 'Renvoyer';

  @override
  String get validate => 'Valider';

  @override
  String get noSms => 'Pas reçu de SMS ? Contacter le support';

  @override
  String get continueLabel => 'Continuer';

  @override
  String stepOf(int step, int total, String name) {
    return 'Étape $step sur $total · $name';
  }

  @override
  String get stepProfile => 'Profil';

  @override
  String get stepDocuments => 'Pièces';

  @override
  String get becomeRider => 'Devenez livreur Tara';

  @override
  String get becomeRiderBody => 'Quelques infos pour créer votre profil. Tout est vérifié avant votre première course.';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get vehicle => 'Véhicule';

  @override
  String get vehicleMotorbike => 'Moto';

  @override
  String get vehicleCar => 'Voiture';

  @override
  String get vehicleTricycle => 'Tricycle';

  @override
  String get plateNumber => 'Immatriculation';

  @override
  String get plateHint => 'Ex. LT 123 AB';

  @override
  String get guarantor => 'Garant';

  @override
  String get guarantorHelp =>
      'Une personne de confiance qui se porte garante de vous. Sa pièce d’identité sera demandée.';

  @override
  String get guarantorName => 'Nom du garant';

  @override
  String get guarantorPhone => 'Téléphone du garant';

  @override
  String get emergencyContact => 'Contact d’urgence (facultatif)';

  @override
  String get emergencyHelp => 'Prévenu automatiquement si vous déclenchez une alerte.';

  @override
  String get emergencyName => 'Nom du contact';

  @override
  String get emergencyPhone => 'Téléphone du contact';

  @override
  String get requiredField => 'Obligatoire';

  @override
  String get documentsTitle => 'Vos pièces justificatives';

  @override
  String get documentsBody => 'Prenez chaque pièce en photo, bien à plat et lisible.';

  @override
  String get docSent => 'Envoyée';

  @override
  String get docToDo => 'À envoyer';

  @override
  String docUploading(int percent) {
    return 'Envoi en cours… $percent %';
  }

  @override
  String get docRejected => 'Refusée';

  @override
  String get docApproved => 'Validée';

  @override
  String get docExpired => 'Expirée';

  @override
  String get takePhoto => 'Prendre';

  @override
  String get sendAgain => 'Renvoyer';

  @override
  String docAlternative(String name) {
    return 'ou $name';
  }

  @override
  String get documentsNote =>
      'Vos documents sont chiffrés et vérifiés par l’équipe Tara. Vous êtes prévenu par SMS à la validation.';

  @override
  String get sendFile => 'Envoyer mon dossier';

  @override
  String progressCount(int done, int total) {
    return '$done / $total';
  }

  @override
  String get pendingTitle => 'Dossier en cours de vérification';

  @override
  String get pendingBody =>
      'Nous vérifions vos pièces, en général sous 48 h. Vous recevrez un SMS dès que vous pourrez prendre des courses.';

  @override
  String get goodMorning => 'Bonjour,';

  @override
  String get goodEvening => 'Bonsoir,';

  @override
  String get todayEarnings => 'Gains du jour';

  @override
  String get details => 'Détails';

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
      zero: 'Aucune course',
    );
    return '$_temp0';
  }

  @override
  String get onlineTime => 'En ligne';

  @override
  String get cashInHand => 'Espèces en main';

  @override
  String get youAreOffline => 'Vous êtes hors ligne';

  @override
  String get offlineHint => 'Passez en ligne pour recevoir les propositions de course autour de vous.';

  @override
  String get locationNeeded => 'Activez la localisation pour passer en ligne.';

  @override
  String get blockersTitle => 'Pièces à renouveler avant de passer en ligne';

  @override
  String get retry => 'Réessayer';

  @override
  String get genericError => 'Une erreur est survenue. Réessayez.';

  @override
  String get networkError => 'Pas de connexion internet. Vérifiez le réseau et réessayez.';

  @override
  String jobsWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'courses', one: 'course', zero: 'course');
    return '$_temp0';
  }

  @override
  String get logout => 'Se déconnecter';

  @override
  String get suspendedTitle => 'Compte suspendu';

  @override
  String get suspendedBody =>
      'Votre compte ne peut pas prendre de courses pour le moment. Contactez le support Tara pour en savoir plus.';

  @override
  String get goOffline => 'Passer hors ligne';

  @override
  String get callSupport => 'Appeler le support';

  @override
  String get noMotoZone => 'Interdit aux motos';

  @override
  String get searchingTitle => 'Recherche de courses…';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get newJob => 'Nouvelle course';

  @override
  String get yourEarning => 'Votre gain';

  @override
  String pickupLabel(String distance) {
    return 'ENLÈVEMENT · $distance';
  }

  @override
  String dropoffLabel(String distance, int minutes) {
    return 'LIVRAISON · $distance · ~$minutes min';
  }

  @override
  String toCollect(String amount) {
    return 'À encaisser : $amount';
  }

  @override
  String get decline => 'Refuser';

  @override
  String get accept => 'Accepter';

  @override
  String get packageSmall => 'Petit colis';

  @override
  String get packageMedium => 'Colis moyen';

  @override
  String get packageLarge => 'Grand colis';

  @override
  String get fragile => 'Fragile';

  @override
  String get express => 'Express';

  @override
  String get offerTaken => 'Course attribuée à un autre livreur';

  @override
  String get offerExpired => 'Temps écoulé : la course est proposée à un autre livreur';

  @override
  String get vehicleShort => 'Moto';

  @override
  String get toPickup => 'Vers l’enlèvement';

  @override
  String toPickupMinutes(int minutes) {
    return 'Vers l’enlèvement · $minutes min';
  }

  @override
  String get directions => 'Itinéraire';

  @override
  String get openWith => 'Ouvrir l’itinéraire avec';

  @override
  String get collectAtPickupTitle => 'À encaisser à l’enlèvement';

  @override
  String get collectAtPickupBody => 'En espèces, avant de prendre le colis.';

  @override
  String get noMotoAddress => 'Adresse en zone interdite aux motos : garez-vous à l’extérieur et finissez à pied.';

  @override
  String get pickupCodeLabel => 'Code d’enlèvement';

  @override
  String get pickupCodeHint => 'donné par le vendeur';

  @override
  String get photoParcel => 'Photographier le colis';

  @override
  String get photoParcelHint => 'Étiquette Tara visible';

  @override
  String photoParcelTaken(String time) {
    return 'Photo du colis · prise à $time';
  }

  @override
  String get retakePhoto => 'Reprendre';

  @override
  String get parcelCollected => 'Colis récupéré';

  @override
  String get actionSavedOffline => 'Enregistré sur le téléphone : envoi automatique au retour du réseau.';

  @override
  String get noPositionYet => 'Position en cours de recherche : patientez quelques secondes à l’extérieur.';

  @override
  String get orderCancelledNotice => 'Course annulée par l’expéditeur.';

  @override
  String get orderReassignedNotice => 'Course confiée à un autre livreur.';

  @override
  String courseInProgress(String reference) {
    return 'Course $reference en cours';
  }

  @override
  String get courseResume => 'Reprendre';

  @override
  String courseRefRecorded(String reference) {
    return 'Course $reference · trajet enregistré';
  }

  @override
  String get toDropoff => 'Vers le client';

  @override
  String toDropoffMinutes(int minutes) {
    return 'Vers le client · $minutes min';
  }

  @override
  String get arrivedAtDestination => 'Arrivé à destination';

  @override
  String get collectAtDeliveryTitle => 'À encaisser à la remise';

  @override
  String get collectAtDeliveryBody => 'Espèces ou Mobile Money, avant la remise.';

  @override
  String farFromAddress(String distance) {
    return 'Vous êtes à $distance de l’adresse : une livraison confirmée d’ici sera signalée au support.';
  }

  @override
  String get deliveryCodeLabel => 'Code du destinataire';

  @override
  String get deliveryCodeHint => 'reçu par SMS';

  @override
  String get noCodeLink => 'Le client n’a pas de code';

  @override
  String get hasCodeLink => 'Le client a un code';

  @override
  String get noCodeTitle => 'Livraison sans code';

  @override
  String get noCodeBody =>
      'La photo de remise est obligatoire. Le support appelle le client pour confirmer avant de clôturer la course.';

  @override
  String get receivedByLabel => 'Nom de la personne qui reçoit';

  @override
  String get receivedByHint => 'Ex. sa sœur, le gardien…';

  @override
  String get photoHandover => 'Photographier la remise';

  @override
  String get photoHandoverHint => 'Colis et lieu de remise visibles';

  @override
  String photoHandoverTaken(String time) {
    return 'Photo de remise · prise à $time';
  }

  @override
  String get confirmDelivery => 'Confirmer la livraison';

  @override
  String get deliveryQueuedTitle => 'Livraison enregistrée';

  @override
  String get deliveryQueuedBody => 'Pas de réseau : la livraison part automatiquement dès son retour.';

  @override
  String get awaitingSupportTitle => 'Livraison déclarée';

  @override
  String get awaitingSupportBody =>
      'Le support appelle le client pour confirmer la remise. Vous serez prévenu dès la validation.';

  @override
  String get orderDeliveredNotice => 'Course livrée. Merci !';

  @override
  String get backHome => 'Retour à l’accueil';

  @override
  String get collectionTitle => 'Encaissement';

  @override
  String collectionSubtitle(String reference, String name) {
    return 'Course $reference · $name';
  }

  @override
  String get toCollectFromCustomer => 'À encaisser auprès du client';

  @override
  String get methodCash => 'Espèces';

  @override
  String get methodMomo => 'Mobile Money';

  @override
  String get amountReceived => 'Montant reçu';

  @override
  String exactAmount(String amount) {
    return '$amount (exact)';
  }

  @override
  String get changeToGive => 'Monnaie à rendre';

  @override
  String get customerOperator => 'Opérateur du client';

  @override
  String get customerMomoNumber => 'Numéro Mobile Money du client';

  @override
  String get momoHint => 'Le client valide le paiement sur son téléphone, puis la course se clôture.';

  @override
  String get momoWaiting => 'En attente de la validation du client…';

  @override
  String get momoFailed =>
      'Paiement non abouti (refusé, annulé ou expiré). Renvoyez la demande ou encaissez en espèces.';

  @override
  String get momoNoAnswer => 'Toujours pas de réponse du client. Vous pouvez renvoyer la demande.';

  @override
  String get momoNeedsNetwork => 'Mobile Money demande du réseau : encaissez en espèces ou réessayez.';

  @override
  String get cashAfterCourse => 'Espèces en main après cette course';

  @override
  String cashLimitReached(String limit) {
    return 'Au-delà de votre plafond ($limit) : déposez des espèces au bureau Tara pour recevoir de nouvelles courses.';
  }

  @override
  String get confirmCollection => 'Confirmer l’encaissement';

  @override
  String get sendPaymentRequest => 'Envoyer la demande de paiement';

  @override
  String get resendPaymentRequest => 'Renvoyer la demande';

  @override
  String get paymentRequestSent => 'Demande envoyée au client';

  @override
  String get sosBadge => 'Sécurité';

  @override
  String get sosIdleTitle => 'Besoin d’aide ?';

  @override
  String get sosIdleBody =>
      'Maintenez le bouton 3 secondes. L’équipe Tara et votre contact d’urgence reçoivent votre position en direct.';

  @override
  String get sosSentTitle => 'Alerte envoyée';

  @override
  String get sosSentBody => 'Restez en lieu sûr si possible. Un agent Tara vous rappelle.';

  @override
  String get sosAcknowledgedBody =>
      'Un agent Tara a pris en charge votre alerte et vous rappelle. Restez en lieu sûr si possible.';

  @override
  String get sosPoliceCalledBody => 'L’équipe Tara a prévenu la police. Restez en lieu sûr si possible.';

  @override
  String get sosPendingTitle => 'Pas d’internet';

  @override
  String get sosPendingBody =>
      'L’alerte partira dès le retour du réseau. Envoyez-la aussi par SMS : il passe souvent sans internet.';

  @override
  String get sosFailedTitle => 'Alerte non envoyée';

  @override
  String get sosFailedBody => 'Appelez Tara ou la police, ou envoyez l’alerte par SMS.';

  @override
  String get sosClosedBody =>
      'L’équipe Tara a clos votre alerte. Maintenez le bouton si vous avez encore besoin d’aide.';

  @override
  String get sosPendingHint => 'En attente';

  @override
  String get sosSendingHint => 'Envoi…';

  @override
  String get sosYourPosition => 'Votre position';

  @override
  String sosPositionCurrent(int meters) {
    return 'Position actuelle · précision $meters m';
  }

  @override
  String sosPositionShared(int meters) {
    return 'Partagée en direct avec Tara · précision $meters m';
  }

  @override
  String get sosPositionSearching => 'Recherche de la position…';

  @override
  String get sosPositionUnknown => 'Position introuvable';

  @override
  String sosPlate(String plate) {
    return 'Moto $plate';
  }

  @override
  String get sosCallTara => 'Support Tara';

  @override
  String sosCallPolice(String number) {
    return 'Police · $number';
  }

  @override
  String get sosAccident => 'Accident :';

  @override
  String sosFire(String number) {
    return 'Pompiers $number';
  }

  @override
  String sosMedical(String number) {
    return 'SAMU $number';
  }

  @override
  String get sosSendSms => 'Envoyer l’alerte par SMS';

  @override
  String get sosCancel => 'Annuler l’alerte';

  @override
  String get sosCancelNeedsNetwork => 'Annulation impossible sans réseau. Appelez Tara pour la confirmer.';

  @override
  String sosSmsBody(String map) {
    return 'SOS Tara : j\'ai besoin d\'aide. Position : $map';
  }

  @override
  String get sosSmsNoPosition => 'SOS Tara : j\'ai besoin d\'aide. Position inconnue.';

  @override
  String sosSmsCourse(String reference) {
    return ' Course $reference.';
  }

  @override
  String get sosPositionCurrentPlain => 'Position actuelle';

  @override
  String get sosPositionSharedPlain => 'Partagée en direct avec Tara';

  @override
  String get failureTitle => 'Livraison impossible';

  @override
  String get failureReasonLabel => 'Motif';

  @override
  String get reasonRecipientAbsent => 'Client absent';

  @override
  String get reasonRecipientUnreachable => 'Injoignable';

  @override
  String get reasonAddressNotFound => 'Adresse introuvable';

  @override
  String get reasonRefused => 'Colis refusé';

  @override
  String get reasonPaymentRefused => 'Refus de payer';

  @override
  String get reasonOther => 'Autre motif';

  @override
  String get failureNoteLabel => 'Précisez le motif';

  @override
  String get failureNoteHint => 'Ex. portail fermé, chien dangereux';

  @override
  String get callsTitle => 'Appels au destinataire';

  @override
  String callsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentatives',
      one: '1 tentative',
      zero: 'Aucun appel',
    );
    return '$_temp0';
  }

  @override
  String get callMade => 'Appel passé';

  @override
  String callMeta(String time, String duration) {
    return '$time · $duration';
  }

  @override
  String get callsNotRequired => 'Pas d’appel exigé pour ce motif.';

  @override
  String get callsDone => 'Appels suffisants.';

  @override
  String callsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count appels à passer.',
      one: 'Encore 1 appel à passer.',
    );
    return '$_temp0';
  }

  @override
  String callsMissingAt(String time) {
    return 'Encore 1 appel, à partir de $time.';
  }

  @override
  String get callRecipient => 'Appeler';

  @override
  String get callAgain => 'Rappeler';

  @override
  String get photoPlace => 'Photo du lieu · obligatoire';

  @override
  String get photoPlaceHint => 'Porte, portail ou devanture visible';

  @override
  String photoPlaceTaken(String time) {
    return 'Photo du lieu · prise à $time';
  }

  @override
  String failureNotice(int minutes) {
    return 'L’expéditeur est prévenu tout de suite et choisit : nouvelle tentative ou retour. Sans réponse sous $minutes min, vous lui rapportez le colis.';
  }

  @override
  String get validateFailure => 'Valider l’échec';

  @override
  String get cantDeliver => 'Livraison impossible ?';

  @override
  String get failureWaitingTitle => 'Échec enregistré';

  @override
  String failureWaitingBody(String time) {
    return 'L’expéditeur choisit : nouvelle tentative ou retour. Sans réponse, le retour sera décidé à $time. Gardez le colis avec vous.';
  }

  @override
  String get failureWaitingBodyQueued => 'L’échec partira dès le retour du réseau. Gardez le colis avec vous.';

  @override
  String get retryTitle => 'Nouvelle tentative';

  @override
  String get retryBody => 'L’expéditeur demande une nouvelle tentative. Repartez vers le destinataire.';

  @override
  String get retryAction => 'Repartir vers le destinataire';

  @override
  String get returnTitle => 'Retour du colis';

  @override
  String returnMinutes(int minutes) {
    return 'Retour du colis · $minutes min';
  }

  @override
  String failureChip(String reason) {
    return 'Échec · $reason';
  }

  @override
  String get returnTo => 'Rapporter le colis à';

  @override
  String get returnStepJoin => 'Rejoindre le vendeur';

  @override
  String get returnStepCode => 'Saisir le code de retour du vendeur';

  @override
  String get returnStepPhoto => 'Photographier le colis rendu';

  @override
  String get stepInProgress => 'En cours';

  @override
  String get atSender => 'Je suis chez le vendeur';

  @override
  String get returnCodeLabel => 'Code de retour';

  @override
  String get returnCodeHint => 'reçu par SMS par le vendeur';

  @override
  String get photoReturned => 'Photographier le colis rendu';

  @override
  String get photoReturnedHint => 'Colis entre les mains du vendeur';

  @override
  String photoReturnedTaken(String time) {
    return 'Photo du retour · prise à $time';
  }

  @override
  String get parcelReturned => 'Colis rendu';

  @override
  String get returnQueuedTitle => 'Retour enregistré';

  @override
  String get returnQueuedBody => 'Il sera envoyé dès le retour du réseau.';

  @override
  String get orderReturnedNotice => 'Colis rendu au vendeur : course terminée.';
}
