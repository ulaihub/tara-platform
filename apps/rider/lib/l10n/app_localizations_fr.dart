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
  String todayPill(String amount) {
    return 'Aujourd’hui $amount';
  }

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
}
