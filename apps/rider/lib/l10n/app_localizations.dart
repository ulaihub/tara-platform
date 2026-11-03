import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tara Livreur'**
  String get appTitle;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @recenterMap.
  ///
  /// In fr, this message translates to:
  /// **'Recentrer la carte'**
  String get recenterMap;

  /// No description provided for @safetyAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte de sécurité'**
  String get safetyAlert;

  /// No description provided for @callPerson.
  ///
  /// In fr, this message translates to:
  /// **'Appeler {name}'**
  String callPerson(String name);

  /// No description provided for @digitLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre {index}'**
  String digitLabel(int index);

  /// No description provided for @currencyFcfa.
  ///
  /// In fr, this message translates to:
  /// **'FCFA'**
  String get currencyFcfa;

  /// No description provided for @tabHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabHome;

  /// No description provided for @tabActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get tabActivity;

  /// No description provided for @tabProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offline;

  /// No description provided for @goOnlineLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne. Passer en ligne'**
  String get goOnlineLabel;

  /// No description provided for @goOfflineLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes en ligne. Passer hors ligne'**
  String get goOfflineLabel;

  /// No description provided for @goOnline.
  ///
  /// In fr, this message translates to:
  /// **'Passer en ligne'**
  String get goOnline;

  /// No description provided for @secondsRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Temps restant pour accepter : {seconds} secondes'**
  String secondsRemaining(int seconds);

  /// No description provided for @seconds.
  ///
  /// In fr, this message translates to:
  /// **'secondes'**
  String get seconds;

  /// No description provided for @sosHoldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Maintenir 3 secondes pour envoyer une alerte'**
  String get sosHoldLabel;

  /// No description provided for @sosHold.
  ///
  /// In fr, this message translates to:
  /// **'Maintenir 3 s'**
  String get sosHold;

  /// No description provided for @sosHoldRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Encore {seconds} s…'**
  String sosHoldRemaining(int seconds);

  /// No description provided for @sosSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée'**
  String get sosSent;

  /// No description provided for @offlineBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion'**
  String get offlineBannerTitle;

  /// No description provided for @offlineBannerPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune action en attente} =1{1 action en attente} other{{count} actions en attente}} · enregistrées sur le téléphone'**
  String offlineBannerPending(int count);

  /// No description provided for @catalogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue des composants'**
  String get catalogTitle;

  /// No description provided for @stepPickup.
  ///
  /// In fr, this message translates to:
  /// **'Enlèvement'**
  String get stepPickup;

  /// No description provided for @stepCollect.
  ///
  /// In fr, this message translates to:
  /// **'Encaissement'**
  String get stepCollect;

  /// No description provided for @stepDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get stepDelivery;

  /// No description provided for @cash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get cash;

  /// No description provided for @mobileMoney.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoney;

  /// No description provided for @periodDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In fr, this message translates to:
  /// **'Semaine'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get periodMonth;

  /// No description provided for @searchingJobs.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de courses…'**
  String get searchingJobs;

  /// No description provided for @searchingJobsHint.
  ///
  /// In fr, this message translates to:
  /// **'Restez dans la zone, les propositions arrivent ici.'**
  String get searchingJobsHint;

  /// No description provided for @stepDone.
  ///
  /// In fr, this message translates to:
  /// **'terminée'**
  String get stepDone;

  /// No description provided for @stepActive.
  ///
  /// In fr, this message translates to:
  /// **'en cours'**
  String get stepActive;

  /// No description provided for @stepUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'à venir'**
  String get stepUpcoming;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
