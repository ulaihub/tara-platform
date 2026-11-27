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
  String get riderSpace => 'TARA LIVREUR · DOUALA';

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
  String get legalPrefix => 'Nouveau compte : vous lirez et accepterez les ';

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
  String get guarantor => 'Garant (facultatif)';

  @override
  String get guarantorHelp =>
      'Une personne de confiance qui se porte garante de vous. Vous pouvez laisser ce bloc vide.';

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
  String bonusIncluded(String details) {
    return 'dont $details';
  }

  @override
  String approachBonus(String amount) {
    return 'prime d’approche $amount';
  }

  @override
  String boostBonus(String amount) {
    return 'prime de renfort $amount';
  }

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
  String get packageBulky => 'Gros objet';

  @override
  String get comeWithHelper => 'Venir à deux';

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
  String newTour(int count) {
    return 'Tournée · $count colis';
  }

  @override
  String nextStopTitle(int stop, int total) {
    return 'Arrêt $stop sur $total';
  }

  @override
  String get nextStopGo => 'Partir vers ce client';

  @override
  String tourProgress(int stop, int total, String earned) {
    return 'Tournée · arrêt $stop sur $total · $earned gagnés';
  }

  @override
  String tourToCollect(int checked, int total) {
    return 'COLIS À RÉCUPÉRER · $checked SUR $total COCHÉS';
  }

  @override
  String photoTourHint(int count) {
    return 'Les $count colis ensemble, numéros visibles';
  }

  @override
  String tourStops(int count) {
    return '$count arrêts, dans l’ordre';
  }

  @override
  String parcelNumberShort(int number) {
    return 'N° $number';
  }

  @override
  String get arrivedAction => 'Je suis arrivé';

  @override
  String get senderAbsentAction => 'L’expéditeur ne vient pas';

  @override
  String senderAbsentLater(int minutes, String share) {
    return 'Il ne vient pas ? Dans $minutes min, vous pourrez partir : $share pour vous.';
  }

  @override
  String senderAbsentCallFirst(int count) {
    return 'Appelez d’abord l’expéditeur (encore $count appel(s)) avec le bouton d’appel.';
  }

  @override
  String senderAbsentConfirm(String fee, String share) {
    return 'La course sera annulée. L’expéditeur paiera $fee, dont $share pour vous. Touchez encore pour confirmer.';
  }

  @override
  String get senderAbsentNotice => 'Course annulée : votre attente vous est payée.';

  @override
  String get arrivedSending => 'Envoi…';

  @override
  String waitingRule(int free, String fee, int step, String share, String max) {
    return 'Sur place, touchez « Je suis arrivé » : l’expéditeur est prévenu. Attente gratuite $free min, puis $fee par $step min ($max au plus), dont $share pour vous.';
  }

  @override
  String waitingFree(int minutes, int left) {
    return 'Vous attendez depuis $minutes min · gratuit encore $left min.';
  }

  @override
  String waitingPaid(int minutes, String fee, String share) {
    return 'Vous attendez depuis $minutes min · $fee d’attente pour l’expéditeur, dont $share pour vous.';
  }

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
  String get photoParcelHint => 'Colis entier, bien visible';

  @override
  String photoParcelTaken(String time) {
    return 'Photo du colis · prise à $time';
  }

  @override
  String get retakePhoto => 'Reprendre';

  @override
  String get parcelCollected => 'Colis récupéré';

  @override
  String get parcelNotConforming => 'Colis non conforme ?';

  @override
  String get bulkyNotice => 'Gros objet : vérifiez qu’il tient dans votre véhicule avant de le charger.';

  @override
  String get bulkyWithHelpNotice => 'Gros objet, aide au chargement payée par l’expéditeur : venez à deux.';

  @override
  String get refusalTitle => 'Colis non conforme';

  @override
  String get refusalBody =>
      'Ne prenez pas un colis trop grand, trop lourd, différent de ce qui a été déclaré ou interdit. Signalez-le ici avant de saisir le code.';

  @override
  String get refusalReasonLabel => 'Pourquoi ?';

  @override
  String get refusalTooBig => 'Trop grand pour mon véhicule';

  @override
  String get refusalTooHeavy => 'Trop lourd';

  @override
  String get refusalNotAsDeclared => 'Pas ce qui a été déclaré';

  @override
  String get refusalForbidden => 'Objet interdit';

  @override
  String get refusalNoteLabel => 'Précisez (facultatif)';

  @override
  String get refusalNoteHint => 'Ex. armoire 3 portes au lieu d’un carton';

  @override
  String get refusalPhotoHint => 'Colis entier visible : c’est la preuve';

  @override
  String get refusalNotice =>
      'La course sera annulée et votre déplacement vous sera payé. L’expéditeur voit le motif et la photo. Un refus sans raison valable est signalé à l’équipe.';

  @override
  String get refusalConfirm => 'Refuser le colis';

  @override
  String get parcelRefusedNotice => 'Colis refusé. Votre déplacement vous est payé.';

  @override
  String get refusalQueuedTitle => 'Refus enregistré';

  @override
  String get refusalQueuedBody => 'Il sera envoyé dès le retour du réseau. Vous pouvez repartir.';

  @override
  String get queuedRefuseParcel => 'Colis non conforme refusé';

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

  @override
  String get earningsToday => 'Gains d’aujourd’hui';

  @override
  String get earningsWeek => 'Gains de la semaine';

  @override
  String get earningsMonth => 'Gains du mois';

  @override
  String coursesCount(int count) {
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
  String get weekdaysShort => 'Lun,Mar,Mer,Jeu,Ven,Sam,Dim';

  @override
  String get todayShort => 'Auj.';

  @override
  String weekShort(int number) {
    return 'S$number';
  }

  @override
  String hourShort(int hour) {
    return '${hour}h';
  }

  @override
  String chartSemantics(String caption, String values) {
    return '$caption : $values';
  }

  @override
  String get cashToDeposit => 'Espèces à reverser à Tara';

  @override
  String get depositAction => 'Reverser';

  @override
  String get lastCourses => 'Dernières courses';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get seeLess => 'Voir moins';

  @override
  String get statusDelivered => 'Livrée';

  @override
  String get statusReturned => 'Retour au vendeur';

  @override
  String get statusCancelled => 'Annulée';

  @override
  String cashCollectedAmount(String amount) {
    return '$amount encaissés';
  }

  @override
  String get noCoursesYet => 'Pas encore de course terminée.';

  @override
  String get activityError => 'Impossible de charger l’activité.';

  @override
  String get depositTitle => 'Reverser les espèces';

  @override
  String depositBody(String amount) {
    return 'Une demande de paiement de $amount part sur votre téléphone. Validez-la avec votre code Mobile Money.';
  }

  @override
  String get depositOffice => 'Vous pouvez aussi déposer les espèces au bureau Tara.';

  @override
  String get depositNumber => 'Votre numéro Mobile Money';

  @override
  String get depositSend => 'Envoyer la demande';

  @override
  String get depositWaiting => 'Validez la demande sur votre téléphone…';

  @override
  String depositDone(String amount) {
    return '$amount reversés à Tara.';
  }

  @override
  String get depositFailed => 'Paiement non abouti. Réessayez ou déposez au bureau Tara.';

  @override
  String get depositOperator => 'Opérateur';

  @override
  String cashDueAt(String time) {
    return 'À déposer avant $time';
  }

  @override
  String cashDueTomorrow(String time) {
    return 'À déposer avant demain $time';
  }

  @override
  String get cashOverdueNotice => 'En retard : plus de courses jusqu’au dépôt.';

  @override
  String get blockerCashOverdue =>
      'Espèces non déposées dans les 24 h : déposez-les (onglet Activité) pour recevoir des courses.';

  @override
  String get blockerSuspended => 'Compte suspendu : contactez Tara.';

  @override
  String get blockerPending => 'Compte en cours de validation.';

  @override
  String get pendingActionsTitle => 'Actions en attente';

  @override
  String get autoSend => 'Envoi automatique';

  @override
  String get queuedPickup => 'Enlèvement';

  @override
  String get queuedDepart => 'Départ vers le client';

  @override
  String get queuedCollect => 'Encaissement espèces';

  @override
  String get queuedDeliver => 'Livraison confirmée';

  @override
  String get queuedFail => 'Échec de livraison';

  @override
  String get queuedRetry => 'Nouvelle tentative';

  @override
  String get queuedReturn => 'Retour au vendeur';

  @override
  String get detailCodePhoto => 'code + photo';

  @override
  String get detailNoCodePhoto => 'sans code + photo';

  @override
  String detailPhotoSize(String size) {
    return 'photo $size Mo';
  }

  @override
  String get statusWaiting => 'En attente';

  @override
  String get statusSending => 'Envoi…';

  @override
  String get statusRefused => 'Refusée';

  @override
  String get offlineNote =>
      'Vous pouvez continuer la course : l’itinéraire et les codes restent disponibles hors connexion.';

  @override
  String get retryNow => 'Réessayer maintenant';

  @override
  String get retrying => 'Tentative d’envoi…';

  @override
  String get stillOffline => 'Toujours hors connexion · Réessayer';

  @override
  String get continueCourse => 'Continuer la course';

  @override
  String get allSent => 'Tout est envoyé.';

  @override
  String get refusedBannerTitle => 'Action refusée';

  @override
  String refusedBannerDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions à vérifier',
      one: '1 action à vérifier',
    );
    return '$_temp0';
  }

  @override
  String get refusedHelp =>
      'Refusée par le serveur. Corrigez-la depuis la course, ou appelez le support avant de la retirer.';

  @override
  String get removeAction => 'Retirer l’action';

  @override
  String get confirmRemoveAction => 'Confirmer le retrait';

  @override
  String get offlineNoPending => 'Vos actions sont gardées sur le téléphone';

  @override
  String silentWithdrawIn(int minutes) {
    return 'Course pas encore récupérée : elle vous sera retirée dans $minutes min si le réseau ne revient pas';
  }

  @override
  String get silentWithdrawNow => 'Sans réseau trop longtemps : la course a peut-être été confiée à un autre livreur';

  @override
  String get balanceAvailable => 'Solde disponible';

  @override
  String balanceReserved(String amount) {
    return '$amount mis de côté pour vos courses en cours';
  }

  @override
  String get balanceExplain => 'Couvre l’argent à encaisser sur vos courses';

  @override
  String get topUpAction => 'Recharger';

  @override
  String get topUpTitle => 'Recharger mon solde';

  @override
  String get topUpAmount => 'Montant';

  @override
  String get topUpOther => 'Autre montant (F)';

  @override
  String get topUpOtherHint => 'Ex. 15000';

  @override
  String topUpBody(String amount) {
    return 'Une demande de paiement de $amount part sur votre téléphone. Les frais Mobile Money sont pour Tara : votre solde reçoit $amount.';
  }

  @override
  String topUpWithdrawRule(String min) {
    return 'Ce solde couvre l’argent à encaisser de vos courses. Il se retire vers Mobile Money à partir de $min.';
  }

  @override
  String get topUpOffice => 'Vous pouvez aussi recharger en espèces au bureau Tara.';

  @override
  String topUpDone(String amount) {
    return '$amount ajoutés à votre solde.';
  }

  @override
  String get topUpFailed => 'Paiement non abouti. Réessayez ou rechargez au bureau Tara.';

  @override
  String topUpRange(String min, String max) {
    return 'Montant entre $min et $max.';
  }

  @override
  String get takenFromBalance => 'Pris sur votre solde (déjà mis de côté)';

  @override
  String get balanceShort => 'Solde';

  @override
  String get myDocuments => 'Mes pièces';

  @override
  String get myDocumentsBody => 'Une pièce refusée ou expirée se renvoie ici ; l’équipe Tara la vérifie à nouveau.';

  @override
  String docsToFix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces à renvoyer',
      one: '1 pièce à renvoyer',
    );
    return '$_temp0';
  }

  @override
  String get docsToFixHint => 'Sans elle, vous ne pouvez plus recevoir de courses.';

  @override
  String docsInReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces en vérification',
      one: '1 pièce en vérification',
    );
    return '$_temp0';
  }

  @override
  String get docsAllApproved => 'Toutes vos pièces sont validées';

  @override
  String get emergencyContactTitle => 'Contact d’urgence';

  @override
  String get emergencyNone => 'Aucun contact';

  @override
  String get add => 'Ajouter';

  @override
  String get edit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get removeContact => 'Retirer ce contact';

  @override
  String get displaySection => 'Affichage';

  @override
  String get themeLabel => 'Thème';

  @override
  String get optionAuto => 'Auto';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get languageLabel => 'Langue';

  @override
  String get effectsLabel => 'Animations';

  @override
  String get effectsFull => 'Complètes';

  @override
  String get effectsReduced => 'Réduites';

  @override
  String get effectsHint => 'Réduites : moins d’effets, plus fluide sur un téléphone modeste.';

  @override
  String get glassLabel => 'Transparence des barres';

  @override
  String get glassClear => 'Verre';

  @override
  String get glassBalanced => 'Équilibré';

  @override
  String get glassOpaque => 'Opaque';

  @override
  String get glassHint => 'Change la transparence de la barre du bas et des boutons posés en bas de l’écran.';

  @override
  String get effectsAutoReduced => 'Réduites automatiquement sur ce téléphone.';

  @override
  String get helpSection => 'Aide';

  @override
  String get supportTara => 'Support Tara';

  @override
  String get logoutConfirm => 'Vous ne recevrez plus de courses sur ce téléphone jusqu’à votre prochaine connexion.';

  @override
  String get logoutBlockedCourse => 'Terminez votre course avant de vous déconnecter.';

  @override
  String get logoutBlockedPending =>
      'Des actions attendent le réseau : elles seraient perdues. Reconnectez-vous d’abord.';

  @override
  String appVersion(String version) {
    return 'Tara Livreur · version $version';
  }

  @override
  String get accountActive => 'Compte actif';

  @override
  String get accountPending => 'Dossier en vérification';

  @override
  String get accountSuspended => 'Compte suspendu';

  @override
  String get accountRejected => 'Dossier refusé';

  @override
  String get profileError => 'Impossible de charger votre profil.';

  @override
  String get slideToAccept => 'Glisser pour accepter';

  @override
  String get soundsLabel => 'Sons';

  @override
  String get soundsHint =>
      'Nouvelle course, colis livré, argent encaissé… Le mode silencieux du téléphone est respecté.';

  @override
  String milestoneTitle(int count) {
    return '$count courses aujourd’hui !';
  }

  @override
  String get milestoneBody => 'Bravo, continuez comme ça.';

  @override
  String rateSenderTitle(String name) {
    return 'Notez $name';
  }

  @override
  String get rateSenderBody => 'Expéditeur de votre dernière course';

  @override
  String get rateSenderThanks => 'Merci ! Votre note aide Tara à bien choisir ses clients.';

  @override
  String get senderFallback => 'l’expéditeur';

  @override
  String starsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count étoiles', one: '1 étoile');
    return '$_temp0';
  }

  @override
  String get returnFeesTitle => 'Frais de retour à encaisser';

  @override
  String returnFeesBody(String name, String amount) {
    return '$name règle $amount avant de récupérer son colis : c’est ce que son solde Tara ne couvre pas.';
  }

  @override
  String returnFeesCash(String amount) {
    return 'Espèces reçues · $amount';
  }

  @override
  String get returnFeesCashNote => 'Vous gardez les espèces : le montant est pris sur votre solde.';

  @override
  String get returnFeesMomo => 'Demander par Mobile Money';

  @override
  String get returnFeesSend => 'Envoyer la demande';

  @override
  String get returnFeesWaiting => 'Demande envoyée : l’expéditeur valide sur son téléphone.';

  @override
  String get returnFeesPaid => 'Frais de retour réglés : vous pouvez rendre le colis.';

  @override
  String get returnFeesChecking => 'Vérification des frais de retour…';

  @override
  String get returnFeesOffline => 'Connexion nécessaire pour vérifier les frais de retour.';

  @override
  String get termsTitle => 'Conditions des livreurs';

  @override
  String get termsUpdateTitle => 'Nos conditions ont changé';

  @override
  String get termsSignupIntro =>
      'Avant de créer votre compte, lisez les conditions des livreurs et la politique de confidentialité jusqu’en bas. Elles expliquent votre statut, vos gains, l’encaissement et ce que nous faisons de vos données.';

  @override
  String get termsUpdateIntro =>
      'Lisez la nouvelle version jusqu’en bas, puis acceptez-la. Sans acceptation, vous terminez votre course en cours mais ne recevez plus de nouvelles courses.';

  @override
  String get termsSignupKicker => 'Avant de commencer';

  @override
  String termsReadPercent(int percent) {
    return 'Lu à $percent%';
  }

  @override
  String get termsLater => 'Plus tard';

  @override
  String get termsEnd => 'Vous êtes arrivé au bout des textes.';

  @override
  String get termsScrollFirst => 'Faites défiler jusqu’en bas pour pouvoir accepter.';

  @override
  String get termsCheckPrefix => 'J’ai lu et j’accepte les ';

  @override
  String termsCheckTerms(String version) {
    return 'conditions des livreurs (version $version)';
  }

  @override
  String get termsCheckAnd => ' et la ';

  @override
  String get termsCheckPrivacy => 'politique de confidentialité';

  @override
  String get termsCreateAccount => 'Accepter et créer mon compte';

  @override
  String get termsAcceptUpdate => 'J’accepte la nouvelle version';

  @override
  String termsAcceptedOn(String version, String date) {
    return 'Version $version acceptée le $date';
  }

  @override
  String termsVersionLine(String version) {
    return 'Version $version';
  }

  @override
  String get termsSection => 'Conditions et confidentialité';

  @override
  String get termsPrivacyTitle => 'Politique de confidentialité';

  @override
  String get termsToSign => 'Nouvelle version à lire et accepter';

  @override
  String get blockerTerms => 'Nos conditions ont changé : lisez-les et acceptez-les pour recevoir des courses.';

  @override
  String get readAndSign => 'Lire et accepter';

  @override
  String get addressPhoto => 'Voir la façade';

  @override
  String get addressVoice => 'Écouter la note';

  @override
  String get addressVoiceStop => 'Arrêter la note';

  @override
  String get addressMediaFailed => 'Fichier indisponible pour le moment : réessayez.';

  @override
  String addressPhotoTitle(String name) {
    return 'Façade · $name';
  }

  @override
  String get toCollectByMomo => 'À demander par Mobile Money';

  @override
  String momoFeeIncluded(String amount, String fee) {
    return '$amount de course et de colis, plus $fee de frais Mobile Money payés par le client.';
  }

  @override
  String withdrawalRule(String amount, String rate) {
    return 'Retrait gratuit dès $amount ; en dessous, $rate de frais Mobile Money retenus.';
  }

  @override
  String get supportTitle => 'Aide et service client';

  @override
  String get supportIntro =>
      'Un souci avec une course, vos gains ou l’app ? Écrivez-nous : l’équipe Tara vous répond ici et vous êtes prévenu de sa réponse.';

  @override
  String get supportNewRequest => 'Nouvelle demande';

  @override
  String get supportEmpty => 'Aucune demande pour l’instant.';

  @override
  String supportCallUs(String phone) {
    return 'Urgent ? Appelez le $phone';
  }

  @override
  String get supportCategoryPayment => 'Gains, solde ou retrait';

  @override
  String get supportCategoryLostParcel => 'Colis perdu';

  @override
  String get supportCategoryDamagedParcel => 'Colis abîmé';

  @override
  String get supportCategoryAppBug => 'Problème dans l’app';

  @override
  String get supportCategoryOther => 'Autre';

  @override
  String get supportStatusOpen => 'Envoyée';

  @override
  String get supportStatusInProgress => 'En cours';

  @override
  String get supportStatusResolved => 'Résolue';

  @override
  String get supportStatusClosed => 'Close';

  @override
  String get supportNewTitle => 'Nouvelle demande';

  @override
  String get supportReasonLabel => 'Motif';

  @override
  String get supportSubjectLabel => 'En quelques mots';

  @override
  String get supportSubjectHint => 'Ex. : retrait non reçu';

  @override
  String get supportMessageLabel => 'Expliquez-nous';

  @override
  String get supportMessageHint => 'Ce qui s’est passé, la course concernée si besoin.';

  @override
  String supportOrderLine(String reference) {
    return 'Course $reference';
  }

  @override
  String get supportSend => 'Envoyer la demande';

  @override
  String get supportReplyHint => 'Votre réponse…';

  @override
  String get supportReplySend => 'Envoyer';

  @override
  String get supportClosedNote => 'Cette demande est close. Ouvrez une nouvelle demande si besoin.';

  @override
  String get supportFromTara => 'Service client Tara';

  @override
  String get supportNewAnswer => 'Réponse';

  @override
  String get supportWaitingNote => 'L’équipe Tara vous répond ici ; vous serez prévenu.';

  @override
  String get supportMenuRow => 'Écrire au service client';

  @override
  String get supportMenuRowSubtitle => 'Vos demandes et les réponses de Tara';

  @override
  String get withdrawAction => 'Retirer';

  @override
  String get withdrawTitle => 'Retirer vers Mobile Money';

  @override
  String withdrawAll(String amount) {
    return 'Tout · $amount';
  }

  @override
  String get withdrawOtherHint => 'Ex. 5000';

  @override
  String withdrawTo(String phone) {
    return 'Envoyé sur votre numéro $phone, le seul permis pour un retrait.';
  }

  @override
  String withdrawFeeFull(String fee) {
    return 'Frais Mobile Money : $fee.';
  }

  @override
  String withdrawFreeFrom(String amount) {
    return 'Retrait gratuit dès $amount.';
  }

  @override
  String get withdrawFree => 'Retrait gratuit : Tara paie les frais Mobile Money.';

  @override
  String get withdrawReceive => 'Vous recevez';

  @override
  String withdrawConfirm(String amount) {
    return 'Recevoir $amount';
  }

  @override
  String withdrawBelowMinimum(String min, String missing) {
    return 'Le retrait vers Mobile Money est possible à partir de $min. Il vous manque encore $missing : votre solde reste en sécurité chez Tara en attendant.';
  }

  @override
  String withdrawRange(String min, String max) {
    return 'Entre $min et $max, ou tout le solde.';
  }

  @override
  String withdrawProcessing(String amount) {
    return 'Retrait demandé : $amount arrivent sur votre Mobile Money dans quelques minutes. Une notification vous préviendra.';
  }

  @override
  String withdrawApproval(String amount) {
    return 'Gros montant : l’équipe Tara valide le retrait de $amount avant l’envoi. Une notification vous préviendra.';
  }

  @override
  String withdrawSent(String amount) {
    return '$amount envoyés sur votre Mobile Money.';
  }

  @override
  String get withdrawFailed => 'Le retrait n’a pas abouti : l’argent reste sur votre solde. Réessayez plus tard.';

  @override
  String withdrawOpen(String amount) {
    return 'Retrait de $amount en cours';
  }

  @override
  String get accountDataSection => 'Mon compte et mes données';

  @override
  String get exportDataRow => 'Télécharger mes données';

  @override
  String get exportDataRowSubtitle => 'Une copie de tout ce que Tara garde sur vous';

  @override
  String get exportDataShare => 'Mes données Tara';

  @override
  String get closeAccountRow => 'Fermer mon compte';

  @override
  String get closeAccountRowSubtitle => 'Demande à l’équipe Tara';

  @override
  String get closeAccountTitle => 'Fermer mon compte';

  @override
  String get closeAccountBody =>
      'L’équipe Tara ferme le compte après vérification : aucune course en cours, rien à reverser à Tara et plus d’argent sur votre solde.';

  @override
  String get closeAccountErased =>
      'Vos pièces d’identité, votre garant et votre contact d’urgence sont alors effacés. Vos courses passées restent, sans votre nom, pour la comptabilité.';

  @override
  String closeAccountSmallBalance(String amount, String min) {
    return 'Il vous reste $amount, moins que le plus petit retrait Mobile Money ($min) : appelez le service client de Tara pour les récupérer avant de fermer votre compte.';
  }

  @override
  String closeAccountBalance(String amount) {
    return 'Il vous reste $amount : retirez-les d’abord vers votre Mobile Money (onglet Activité).';
  }

  @override
  String closeAccountDebt(String amount) {
    return 'Vous devez $amount à Tara : rechargez d’abord votre solde (onglet Activité).';
  }

  @override
  String get closeAccountPayout => 'Un retrait vers votre Mobile Money est en cours : attendez qu’il arrive.';

  @override
  String get closeAccountCourse => 'Terminez votre course avant de demander la fermeture.';

  @override
  String get closeAccountSend => 'Demander la fermeture';

  @override
  String get closeAccountSent => 'Demande envoyée. L’équipe Tara vous répond dans « Écrire au service client ».';

  @override
  String get closeAccountTicketSubject => 'Fermeture de mon compte livreur';

  @override
  String get closeAccountTicketMessage => 'Je souhaite fermer mon compte livreur Tara et effacer mes données.';

  @override
  String get reasonDamaged => 'Colis abîmé, refusé';

  @override
  String get photoDamaged => 'Photo du colis abîmé · obligatoire';

  @override
  String get photoDamagedHint => 'Le dommage bien visible';

  @override
  String get damagedNotice =>
      'Le destinataire refuse un colis abîmé : photographiez le dommage et décrivez-le. L’équipe Tara ouvre une réclamation pour l’expéditeur ; ramenez le colis comme un retour.';

  @override
  String get damagedNoteHint => 'Ex. carton écrasé, bouteille cassée';

  @override
  String get pinCreateTitle => 'Choisissez votre code secret';

  @override
  String get pinCreateBody =>
      '4 chiffres, comme pour Orange Money ou MoMo. Il protège votre solde et vos retraits. Ne le donnez à personne, même à Tara.';

  @override
  String get pinConfirmTitle => 'Confirmez votre code secret';

  @override
  String get pinMismatch => 'Les deux codes sont différents. Recommencez.';

  @override
  String get pinEnterTitle => 'Code secret';

  @override
  String get pinCurrentTitle => 'Votre code secret actuel';

  @override
  String get pinNewTitle => 'Nouveau code secret';

  @override
  String get pinForgot => 'Code oublié ?';

  @override
  String get pinUseBiometrics => 'Utiliser aussi mon empreinte';

  @override
  String get pinBiometricButton => 'Utiliser mon empreinte';

  @override
  String get pinBiometricTitle => 'Confirmez avec votre empreinte';

  @override
  String get pinDelete => 'Effacer';

  @override
  String pinDigitsEntered(int count) {
    return '$count chiffre(s) sur 4';
  }

  @override
  String get pinLockedTitle => 'Code secret bloqué';

  @override
  String get pinLockedBody =>
      'Après 5 erreurs, votre code secret est bloqué. Recevez un code sur votre numéro pour en choisir un nouveau.';

  @override
  String get pinResetBody => 'Recevez un code sur votre numéro pour choisir un nouveau code secret.';

  @override
  String get pinSendCode => 'Recevoir un code';

  @override
  String get pinCodeSentSms => 'Entrez le code reçu par SMS.';

  @override
  String get pinCodeSentWhatsApp => 'Entrez le code reçu sur WhatsApp.';

  @override
  String get codeBySms => 'Recevoir par SMS';

  @override
  String codeSentWhatsAppTo(String phone) {
    return 'Code envoyé sur WhatsApp au $phone';
  }

  @override
  String get pinSaved => 'Code secret enregistré.';

  @override
  String get balanceShow => 'Afficher le solde';

  @override
  String get balanceHide => 'Masquer le solde';

  @override
  String get pinReasonBalance => 'Pour voir votre solde';

  @override
  String pinReasonWithdraw(String amount) {
    return 'Pour retirer $amount';
  }

  @override
  String get pinRowTitle => 'Code secret';

  @override
  String get pinRowSet => 'Changer mon code secret';

  @override
  String get pinRowNotSet => 'Choisir mon code secret';

  @override
  String get biometricRowTitle => 'Empreinte digitale';

  @override
  String get biometricRowBody => 'Confirmer avec l\'empreinte au lieu du code';

  @override
  String get securitySection => 'Sécurité';

  @override
  String get parcelToCollect => 'Colis à récupérer';

  @override
  String get parcelToDeliver => 'Colis à remettre';

  @override
  String parcelNumber(int n) {
    return 'n° $n';
  }

  @override
  String parcelFor(String name, String place) {
    return 'Pour $name · $place';
  }

  @override
  String photoParcelHintNumber(int n) {
    return 'Numéro $n bien visible';
  }

  @override
  String get tabCourse => 'Course';

  @override
  String get tabEarnings => 'Gains';

  @override
  String get onlineTodayWord => 'aujourd’hui';

  @override
  String get prepaidTitle => 'Solde prépayé';

  @override
  String get prepaidCovers => 'Couvre les espèces que vous encaissez';

  @override
  String onlineSince(String time) {
    return 'En ligne · $time';
  }

  @override
  String get zoneForbiddenLegend => 'Zone interdite : pas de course';

  @override
  String todayTotal(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'courses', one: 'course', zero: 'course');
    return '$amount · $count $_temp0';
  }

  @override
  String get myEarnings => 'Mes gains';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get todaySuffix => 'aujourd’hui';

  @override
  String get dayNotYet => 'à venir';

  @override
  String get dayNotYetLabel => 'pas encore roulé';

  @override
  String get weekOnline => 'En ligne';

  @override
  String get weekRides => 'Courses';

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get themeAuto => 'Automatique';

  @override
  String get effectsAll => 'Toutes';

  @override
  String get myDocumentsRowSubtitle => 'Une pièce refusée ou expirée se renvoie ici';

  @override
  String termsRowAccepted(String version, String date) {
    return 'Version $version acceptée le $date';
  }

  @override
  String get termsRowToSign => 'Nouvelle version à accepter';

  @override
  String get securityRow => 'Code secret et empreinte';

  @override
  String get securityRowSubtitle => 'Pour voir le solde et retirer';

  @override
  String get displayMoreRow => 'Langue et sons';

  @override
  String secondsToAccept(int seconds) {
    return '$seconds s pour accepter';
  }

  @override
  String stopPickup(String name) {
    return 'Enlèvement · $name';
  }

  @override
  String stopDropoff(String place) {
    return 'Livraison · $place';
  }

  @override
  String approachFromYou(String distance) {
    return 'à $distance de vous';
  }

  @override
  String toCollectLower(String amount) {
    return 'à encaisser $amount';
  }

  @override
  String get alreadyPaid => 'déjà payé';

  @override
  String toCollectChip(String amount) {
    return 'À encaisser $amount';
  }

  @override
  String tourOnePickup(int count) {
    return '$count colis · un seul enlèvement';
  }

  @override
  String tripSummary(String distance, int minutes) {
    return '$distance · ~$minutes min';
  }

  @override
  String tourSummary(String distance, int count) {
    return '$distance · $count arrêts';
  }

  @override
  String pinPickup(String name) {
    return 'A · $name';
  }

  @override
  String pinDropoff(String place) {
    return 'B · $place';
  }

  @override
  String get missingPhoto => 'la photo';

  @override
  String get missingCode => 'le code';

  @override
  String get missingParcels => 'les colis à cocher';

  @override
  String missingItems(String items) {
    return 'Il manque $items.';
  }

  @override
  String get slideParcelCollected => 'Glisser · Colis récupéré';

  @override
  String get parcelNonConforming => 'Colis non conforme';

  @override
  String waitingSince(int minutes) {
    return 'Vous attendez depuis $minutes min · ';
  }

  @override
  String waitingFreeLeft(int left) {
    return 'gratuit encore $left min';
  }

  @override
  String waitingThen(String fee, int step) {
    return '. Ensuite $fee par $step min pour l’expéditeur.';
  }

  @override
  String get slideConfirmDelivery => 'Glisser · Confirmer la livraison';

  @override
  String get cantDeliverShort => 'Livraison impossible';

  @override
  String distanceAway(String distance) {
    return 'À $distance';
  }

  @override
  String towards(String place) {
    return 'Vers $place';
  }

  @override
  String courseReference(String reference) {
    return 'Course $reference';
  }

  @override
  String toCollectFrom(String name) {
    return 'À encaisser auprès de $name';
  }

  @override
  String get exactShort => 'Exact';

  @override
  String cashKeptFromBalance(String amount) {
    return 'Vous gardez les espèces : $amount sont pris sur votre solde prépayé, où ils étaient déjà mis de côté.';
  }

  @override
  String get slideConfirmCollection => 'Glisser · Confirmer l’encaissement';

  @override
  String deliveredAtLabel(String reference, String time) {
    return '$reference · livrée à $time';
  }

  @override
  String todayEarningsPill(String amount) {
    return 'Gains du jour · $amount';
  }

  @override
  String rideOfDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}e course du jour',
      one: '1re course du jour',
    );
    return '$_temp0';
  }

  @override
  String rideOfDayBravo(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}e course du jour · bravo $name',
      one: '1re course du jour · bravo $name',
    );
    return '$_temp0';
  }

  @override
  String get addedToEarnings => 'Ajoutés à vos gains du jour';

  @override
  String dailyGoal(int count) {
    return 'Objectif du jour : $count courses';
  }

  @override
  String ridesToNextCelebration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count courses pour la prochaine célébration.',
      one: 'Encore 1 course pour la prochaine célébration.',
    );
    return '$_temp0';
  }

  @override
  String get continueOnline => 'Continuer · rester en ligne';

  @override
  String get cashToDepositKicker => 'Espèces à reverser';

  @override
  String get prepaidCoversMoney => 'Il couvre l’argent que vous encaissez';

  @override
  String get depositSubtitle => 'Espèces encaissées avant le solde prépayé';

  @override
  String get withdrawSubtitle => 'Vers votre numéro enregistré';

  @override
  String get sosSubtitle => 'Votre contact d’urgence est prévenu aussi';

  @override
  String get onboardingProfileSubtitle => 'Quelques informations sur vous';

  @override
  String get myAccount => 'Mon compte';

  @override
  String get emergencyContactSubtitle => 'Une personne proche, à prévenir si besoin';

  @override
  String get vehicleTitle => 'Ma moto';

  @override
  String get vehicleSubtitle => 'Montrée à l\'expéditeur pour vous reconnaître';

  @override
  String get vehicleHelp =>
      'L\'expéditeur voit votre photo, la marque, la couleur et la plaque : il vous reconnaît tout de suite, même au milieu d\'autres motos.';

  @override
  String get vehicleBrand => 'Marque';

  @override
  String get vehicleColor => 'Couleur';

  @override
  String get vehiclePlate => 'Plaque d\'immatriculation';

  @override
  String get vehicleRowEmpty => 'Marque et couleur à indiquer';

  @override
  String chatWithSender(String name) {
    return 'Écrire à $name';
  }

  @override
  String get chatHint => 'Votre message…';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatEmpty => 'Aucun message. Écrivez à l\'expéditeur, il reçoit une notification.';

  @override
  String get chatClosed => 'La course est terminée : la conversation est fermée.';

  @override
  String get chatRead => 'Lu';

  @override
  String chatSubtitle(String reference) {
    return 'Expéditeur · $reference';
  }

  @override
  String get chatQuick1 => 'J\'arrive';

  @override
  String get chatQuick2 => 'Je suis devant';

  @override
  String get chatQuick3 => 'Je suis en route';

  @override
  String get chatQuick4 => 'Appelez-moi s\'il vous plaît';

  @override
  String get chatNewMessage => 'Nouveau message de l\'expéditeur';

  @override
  String get introBack => 'Écran précédent';

  @override
  String get introSkip => 'Passer';

  @override
  String get introNext => 'Suivant';

  @override
  String get introStart => 'Commencer';

  @override
  String get introJobsKicker => 'Courses · Douala';

  @override
  String get introJobsTitle => 'Des courses près de vous';

  @override
  String get introJobsBody =>
      'Vous voyez le trajet et le gain avant d\'accepter. Un glissement suffit pour prendre la course.';

  @override
  String get introJobsChip => '30 s pour répondre';

  @override
  String get introJobsOffer => 'Nouvelle course';

  @override
  String get introJobsEarning => '1 500 F';

  @override
  String get introJobsRoute => 'Akwa → Bonapriso · 4,2 km';

  @override
  String get introEarningsKicker => 'Vos gains';

  @override
  String get introEarningsTitle => 'Votre argent, chaque jour';

  @override
  String get introEarningsBody =>
      'Chaque course livrée s\'ajoute à votre solde. Vous le retirez sur votre Mobile Money.';

  @override
  String get introEarningsChip => 'Retrait sur Mobile Money';

  @override
  String get introEarningsCard => 'Gains du jour';

  @override
  String get introEarningsFooter => '+1 050 F · course livrée';

  @override
  String get introSafetyKicker => 'Sécurité';

  @override
  String get introSafetyTitle => 'Jamais seul sur la route';

  @override
  String get introSafetyBody =>
      'Un appui long sur SOS prévient l\'équipe Tara et votre proche. Pendant la course, l\'équipe voit où vous êtes.';

  @override
  String get introSafetyTeam => 'Équipe Tara prévenue';

  @override
  String get introSafetyContact => 'Votre proche reçoit un SMS';

  @override
  String get introSafetyPosition => 'Position partagée pendant la course';

  @override
  String get scanTitlePickup => 'Code d’enlèvement';

  @override
  String get scanAimPickup => 'Visez le code d’enlèvement de la boutique';

  @override
  String get scanOk => 'Code bon !';

  @override
  String get scanHelperPickup =>
      'La boutique l’affiche dans son app, sur l’écran « Commande envoyée » ou dans le suivi. Ce n’est pas le code QR du reçu : celui-là sert seulement à vérifier un reçu.';

  @override
  String get scanTypeDigits => 'Taper les 4 chiffres';

  @override
  String get scanVerified => 'Code d’enlèvement vérifié';

  @override
  String scanVerifiedParcels(int count) {
    return 'Code d’enlèvement vérifié · $count colis';
  }

  @override
  String get scanContinue => 'Continuer';

  @override
  String get scanWrongOrder => 'Ce QR est le code d’une autre course. Demandez celui de cette commande.';

  @override
  String get scanNotTara => 'Ce n’est pas un code d’enlèvement Tara (le QR du reçu ne marche pas ici).';

  @override
  String get scanNoCamera =>
      'Caméra indisponible : autorisez-la dans les réglages du téléphone, ou tapez les 4 chiffres.';

  @override
  String get scanTorch => 'Lampe';

  @override
  String scanParcels(String numbers) {
    return 'colis n° $numbers';
  }

  @override
  String get pickupScan => 'Scanner';

  @override
  String get pickupTypeDigits => 'Taper 4 chiffres';

  @override
  String get pickupCodeScanned => 'Code vérifié';

  @override
  String get pickupCodeTyped => 'Code saisi';

  @override
  String get pickupCodeChange => 'Changer';

  @override
  String listAnd(String first, String last) {
    return '$first et $last';
  }

  @override
  String get addressFacade => 'Façade';

  @override
  String enRouteEta(int minutes, String distance, String time) {
    return '$minutes min · $distance · arrivée $time';
  }
}
