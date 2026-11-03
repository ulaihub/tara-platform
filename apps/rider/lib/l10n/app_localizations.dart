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

  /// No description provided for @riderSpace.
  ///
  /// In fr, this message translates to:
  /// **'ESPACE LIVREUR'**
  String get riderSpace;

  /// No description provided for @signInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prêt à prendre la route ?'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec votre numéro. Nous vous envoyons un code par SMS.'**
  String get signInBody;

  /// No description provided for @phoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'6XX XX XX XX'**
  String get phoneHint;

  /// No description provided for @countryCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif du pays {code}'**
  String countryCodeLabel(String code);

  /// No description provided for @phoneHelp.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez le numéro lié à votre compte Mobile Money : vos gains y seront versés.'**
  String get phoneHelp;

  /// No description provided for @phoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de mobile camerounais à 9 chiffres, commençant par 6.'**
  String get phoneInvalid;

  /// No description provided for @getCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le code'**
  String get getCode;

  /// No description provided for @legalPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En continuant, vous acceptez les '**
  String get legalPrefix;

  /// No description provided for @terms.
  ///
  /// In fr, this message translates to:
  /// **'conditions d’utilisation'**
  String get terms;

  /// No description provided for @legalAnd.
  ///
  /// In fr, this message translates to:
  /// **' et la '**
  String get legalAnd;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get privacy;

  /// No description provided for @codeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code reçu'**
  String get codeTitle;

  /// No description provided for @codeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé par SMS au {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @change.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get change;

  /// No description provided for @resendIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code dans {time}'**
  String resendIn(String time);

  /// No description provided for @resendNow.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez rien reçu ?'**
  String get resendNow;

  /// No description provided for @resend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get resend;

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @noSms.
  ///
  /// In fr, this message translates to:
  /// **'Pas reçu de SMS ? Contacter le support'**
  String get noSms;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @stepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {step} sur {total} · {name}'**
  String stepOf(int step, int total, String name);

  /// No description provided for @stepProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get stepProfile;

  /// No description provided for @stepDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Pièces'**
  String get stepDocuments;

  /// No description provided for @becomeRider.
  ///
  /// In fr, this message translates to:
  /// **'Devenez livreur Tara'**
  String get becomeRider;

  /// No description provided for @becomeRiderBody.
  ///
  /// In fr, this message translates to:
  /// **'Quelques infos pour créer votre profil. Tout est vérifié avant votre première course.'**
  String get becomeRiderBody;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @vehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get vehicle;

  /// No description provided for @vehicleMotorbike.
  ///
  /// In fr, this message translates to:
  /// **'Moto'**
  String get vehicleMotorbike;

  /// No description provided for @vehicleCar.
  ///
  /// In fr, this message translates to:
  /// **'Voiture'**
  String get vehicleCar;

  /// No description provided for @vehicleTricycle.
  ///
  /// In fr, this message translates to:
  /// **'Tricycle'**
  String get vehicleTricycle;

  /// No description provided for @plateNumber.
  ///
  /// In fr, this message translates to:
  /// **'Immatriculation'**
  String get plateNumber;

  /// No description provided for @plateHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. LT 123 AB'**
  String get plateHint;

  /// No description provided for @guarantor.
  ///
  /// In fr, this message translates to:
  /// **'Garant'**
  String get guarantor;

  /// No description provided for @guarantorHelp.
  ///
  /// In fr, this message translates to:
  /// **'Une personne de confiance qui se porte garante de vous. Sa pièce d’identité sera demandée.'**
  String get guarantorHelp;

  /// No description provided for @guarantorName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du garant'**
  String get guarantorName;

  /// No description provided for @guarantorPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone du garant'**
  String get guarantorPhone;

  /// No description provided for @emergencyContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact d’urgence (facultatif)'**
  String get emergencyContact;

  /// No description provided for @emergencyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Prévenu automatiquement si vous déclenchez une alerte.'**
  String get emergencyHelp;

  /// No description provided for @emergencyName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du contact'**
  String get emergencyName;

  /// No description provided for @emergencyPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone du contact'**
  String get emergencyPhone;

  /// No description provided for @requiredField.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire'**
  String get requiredField;

  /// No description provided for @documentsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos pièces justificatives'**
  String get documentsTitle;

  /// No description provided for @documentsBody.
  ///
  /// In fr, this message translates to:
  /// **'Prenez chaque pièce en photo, bien à plat et lisible.'**
  String get documentsBody;

  /// No description provided for @docSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée'**
  String get docSent;

  /// No description provided for @docToDo.
  ///
  /// In fr, this message translates to:
  /// **'À envoyer'**
  String get docToDo;

  /// No description provided for @docUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours… {percent} %'**
  String docUploading(int percent);

  /// No description provided for @docRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusée'**
  String get docRejected;

  /// No description provided for @docApproved.
  ///
  /// In fr, this message translates to:
  /// **'Validée'**
  String get docApproved;

  /// No description provided for @docExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expirée'**
  String get docExpired;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre'**
  String get takePhoto;

  /// No description provided for @sendAgain.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get sendAgain;

  /// No description provided for @docAlternative.
  ///
  /// In fr, this message translates to:
  /// **'ou {name}'**
  String docAlternative(String name);

  /// No description provided for @documentsNote.
  ///
  /// In fr, this message translates to:
  /// **'Vos documents sont chiffrés et vérifiés par l’équipe Tara. Vous êtes prévenu par SMS à la validation.'**
  String get documentsNote;

  /// No description provided for @sendFile.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer mon dossier'**
  String get sendFile;

  /// No description provided for @progressCount.
  ///
  /// In fr, this message translates to:
  /// **'{done} / {total}'**
  String progressCount(int done, int total);

  /// No description provided for @pendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dossier en cours de vérification'**
  String get pendingTitle;

  /// No description provided for @pendingBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous vérifions vos pièces, en général sous 48 h. Vous recevrez un SMS dès que vous pourrez prendre des courses.'**
  String get pendingBody;

  /// No description provided for @goodMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour,'**
  String get goodMorning;

  /// No description provided for @goodEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir,'**
  String get goodEvening;

  /// No description provided for @todayEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Gains du jour'**
  String get todayEarnings;

  /// No description provided for @details.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get details;

  /// No description provided for @jobsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune course} =1{1 course} other{{count} courses}}'**
  String jobsCount(int count);

  /// No description provided for @onlineTime.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get onlineTime;

  /// No description provided for @cashInHand.
  ///
  /// In fr, this message translates to:
  /// **'Espèces en main'**
  String get cashInHand;

  /// No description provided for @youAreOffline.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne'**
  String get youAreOffline;

  /// No description provided for @offlineHint.
  ///
  /// In fr, this message translates to:
  /// **'Passez en ligne pour recevoir les propositions de course autour de vous.'**
  String get offlineHint;

  /// No description provided for @locationNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Activez la localisation pour passer en ligne.'**
  String get locationNeeded;

  /// No description provided for @blockersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pièces à renouveler avant de passer en ligne'**
  String get blockersTitle;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @genericError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get genericError;

  /// No description provided for @networkError.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion internet. Vérifiez le réseau et réessayez.'**
  String get networkError;

  /// No description provided for @jobsWord.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{course} =1{course} other{courses}}'**
  String jobsWord(int count);

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @suspendedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte suspendu'**
  String get suspendedTitle;

  /// No description provided for @suspendedBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte ne peut pas prendre de courses pour le moment. Contactez le support Tara pour en savoir plus.'**
  String get suspendedBody;

  /// No description provided for @goOffline.
  ///
  /// In fr, this message translates to:
  /// **'Passer hors ligne'**
  String get goOffline;

  /// No description provided for @callSupport.
  ///
  /// In fr, this message translates to:
  /// **'Appeler le support'**
  String get callSupport;

  /// No description provided for @noMotoZone.
  ///
  /// In fr, this message translates to:
  /// **'Interdit aux motos'**
  String get noMotoZone;

  /// No description provided for @searchingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de courses…'**
  String get searchingTitle;

  /// No description provided for @todayPill.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui {amount}'**
  String todayPill(String amount);

  /// No description provided for @newJob.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle course'**
  String get newJob;

  /// No description provided for @yourEarning.
  ///
  /// In fr, this message translates to:
  /// **'Votre gain'**
  String get yourEarning;

  /// No description provided for @pickupLabel.
  ///
  /// In fr, this message translates to:
  /// **'ENLÈVEMENT · {distance}'**
  String pickupLabel(String distance);

  /// No description provided for @dropoffLabel.
  ///
  /// In fr, this message translates to:
  /// **'LIVRAISON · {distance} · ~{minutes} min'**
  String dropoffLabel(String distance, int minutes);

  /// No description provided for @toCollect.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser : {amount}'**
  String toCollect(String amount);

  /// No description provided for @decline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get accept;

  /// No description provided for @packageSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit colis'**
  String get packageSmall;

  /// No description provided for @packageMedium.
  ///
  /// In fr, this message translates to:
  /// **'Colis moyen'**
  String get packageMedium;

  /// No description provided for @packageLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grand colis'**
  String get packageLarge;

  /// No description provided for @fragile.
  ///
  /// In fr, this message translates to:
  /// **'Fragile'**
  String get fragile;

  /// No description provided for @express.
  ///
  /// In fr, this message translates to:
  /// **'Express'**
  String get express;

  /// No description provided for @offerTaken.
  ///
  /// In fr, this message translates to:
  /// **'Course attribuée à un autre livreur'**
  String get offerTaken;

  /// No description provided for @offerExpired.
  ///
  /// In fr, this message translates to:
  /// **'Temps écoulé : la course est proposée à un autre livreur'**
  String get offerExpired;

  /// No description provided for @vehicleShort.
  ///
  /// In fr, this message translates to:
  /// **'Moto'**
  String get vehicleShort;
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
