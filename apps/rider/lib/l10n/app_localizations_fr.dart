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
}
