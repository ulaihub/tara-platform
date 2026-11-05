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
  /// **'Garant (facultatif)'**
  String get guarantor;

  /// No description provided for @guarantorHelp.
  ///
  /// In fr, this message translates to:
  /// **'Une personne de confiance qui se porte garante de vous. Vous pouvez laisser ce bloc vide.'**
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

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get today;

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

  /// No description provided for @toPickup.
  ///
  /// In fr, this message translates to:
  /// **'Vers l’enlèvement'**
  String get toPickup;

  /// No description provided for @toPickupMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Vers l’enlèvement · {minutes} min'**
  String toPickupMinutes(int minutes);

  /// No description provided for @directions.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get directions;

  /// No description provided for @openWith.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir l’itinéraire avec'**
  String get openWith;

  /// No description provided for @collectAtPickupTitle.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser à l’enlèvement'**
  String get collectAtPickupTitle;

  /// No description provided for @collectAtPickupBody.
  ///
  /// In fr, this message translates to:
  /// **'En espèces, avant de prendre le colis.'**
  String get collectAtPickupBody;

  /// No description provided for @noMotoAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse en zone interdite aux motos : garez-vous à l’extérieur et finissez à pied.'**
  String get noMotoAddress;

  /// No description provided for @pickupCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code d’enlèvement'**
  String get pickupCodeLabel;

  /// No description provided for @pickupCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'donné par le vendeur'**
  String get pickupCodeHint;

  /// No description provided for @photoParcel.
  ///
  /// In fr, this message translates to:
  /// **'Photographier le colis'**
  String get photoParcel;

  /// No description provided for @photoParcelHint.
  ///
  /// In fr, this message translates to:
  /// **'Étiquette Tara visible'**
  String get photoParcelHint;

  /// No description provided for @photoParcelTaken.
  ///
  /// In fr, this message translates to:
  /// **'Photo du colis · prise à {time}'**
  String photoParcelTaken(String time);

  /// No description provided for @retakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get retakePhoto;

  /// No description provided for @parcelCollected.
  ///
  /// In fr, this message translates to:
  /// **'Colis récupéré'**
  String get parcelCollected;

  /// No description provided for @actionSavedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré sur le téléphone : envoi automatique au retour du réseau.'**
  String get actionSavedOffline;

  /// No description provided for @noPositionYet.
  ///
  /// In fr, this message translates to:
  /// **'Position en cours de recherche : patientez quelques secondes à l’extérieur.'**
  String get noPositionYet;

  /// No description provided for @orderCancelledNotice.
  ///
  /// In fr, this message translates to:
  /// **'Course annulée par l’expéditeur.'**
  String get orderCancelledNotice;

  /// No description provided for @orderReassignedNotice.
  ///
  /// In fr, this message translates to:
  /// **'Course confiée à un autre livreur.'**
  String get orderReassignedNotice;

  /// No description provided for @courseInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Course {reference} en cours'**
  String courseInProgress(String reference);

  /// No description provided for @courseResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get courseResume;

  /// En-tête des écrans de course : le livreur sait que son trajet est enregistré pendant la course.
  ///
  /// In fr, this message translates to:
  /// **'Course {reference} · trajet enregistré'**
  String courseRefRecorded(String reference);

  /// No description provided for @toDropoff.
  ///
  /// In fr, this message translates to:
  /// **'Vers le client'**
  String get toDropoff;

  /// No description provided for @toDropoffMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Vers le client · {minutes} min'**
  String toDropoffMinutes(int minutes);

  /// No description provided for @arrivedAtDestination.
  ///
  /// In fr, this message translates to:
  /// **'Arrivé à destination'**
  String get arrivedAtDestination;

  /// No description provided for @collectAtDeliveryTitle.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser à la remise'**
  String get collectAtDeliveryTitle;

  /// No description provided for @collectAtDeliveryBody.
  ///
  /// In fr, this message translates to:
  /// **'Espèces ou Mobile Money, avant la remise.'**
  String get collectAtDeliveryBody;

  /// No description provided for @farFromAddress.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à {distance} de l’adresse : une livraison confirmée d’ici sera signalée au support.'**
  String farFromAddress(String distance);

  /// No description provided for @deliveryCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code du destinataire'**
  String get deliveryCodeLabel;

  /// No description provided for @deliveryCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'reçu par SMS'**
  String get deliveryCodeHint;

  /// No description provided for @noCodeLink.
  ///
  /// In fr, this message translates to:
  /// **'Le client n’a pas de code'**
  String get noCodeLink;

  /// No description provided for @hasCodeLink.
  ///
  /// In fr, this message translates to:
  /// **'Le client a un code'**
  String get hasCodeLink;

  /// No description provided for @noCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison sans code'**
  String get noCodeTitle;

  /// No description provided for @noCodeBody.
  ///
  /// In fr, this message translates to:
  /// **'La photo de remise est obligatoire. Le support appelle le client pour confirmer avant de clôturer la course.'**
  String get noCodeBody;

  /// No description provided for @receivedByLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la personne qui reçoit'**
  String get receivedByLabel;

  /// No description provided for @receivedByHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. sa sœur, le gardien…'**
  String get receivedByHint;

  /// No description provided for @photoHandover.
  ///
  /// In fr, this message translates to:
  /// **'Photographier la remise'**
  String get photoHandover;

  /// No description provided for @photoHandoverHint.
  ///
  /// In fr, this message translates to:
  /// **'Colis et lieu de remise visibles'**
  String get photoHandoverHint;

  /// No description provided for @photoHandoverTaken.
  ///
  /// In fr, this message translates to:
  /// **'Photo de remise · prise à {time}'**
  String photoHandoverTaken(String time);

  /// No description provided for @confirmDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la livraison'**
  String get confirmDelivery;

  /// No description provided for @deliveryQueuedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison enregistrée'**
  String get deliveryQueuedTitle;

  /// No description provided for @deliveryQueuedBody.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau : la livraison part automatiquement dès son retour.'**
  String get deliveryQueuedBody;

  /// No description provided for @awaitingSupportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison déclarée'**
  String get awaitingSupportTitle;

  /// No description provided for @awaitingSupportBody.
  ///
  /// In fr, this message translates to:
  /// **'Le support appelle le client pour confirmer la remise. Vous serez prévenu dès la validation.'**
  String get awaitingSupportBody;

  /// No description provided for @orderDeliveredNotice.
  ///
  /// In fr, this message translates to:
  /// **'Course livrée. Merci !'**
  String get orderDeliveredNotice;

  /// No description provided for @backHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l’accueil'**
  String get backHome;

  /// No description provided for @collectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Encaissement'**
  String get collectionTitle;

  /// No description provided for @collectionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Course {reference} · {name}'**
  String collectionSubtitle(String reference, String name);

  /// No description provided for @toCollectFromCustomer.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser auprès du client'**
  String get toCollectFromCustomer;

  /// No description provided for @methodCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get methodCash;

  /// No description provided for @methodMomo.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get methodMomo;

  /// No description provided for @amountReceived.
  ///
  /// In fr, this message translates to:
  /// **'Montant reçu'**
  String get amountReceived;

  /// No description provided for @exactAmount.
  ///
  /// In fr, this message translates to:
  /// **'{amount} (exact)'**
  String exactAmount(String amount);

  /// No description provided for @changeToGive.
  ///
  /// In fr, this message translates to:
  /// **'Monnaie à rendre'**
  String get changeToGive;

  /// No description provided for @customerOperator.
  ///
  /// In fr, this message translates to:
  /// **'Opérateur du client'**
  String get customerOperator;

  /// No description provided for @customerMomoNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Mobile Money du client'**
  String get customerMomoNumber;

  /// No description provided for @momoHint.
  ///
  /// In fr, this message translates to:
  /// **'Le client valide le paiement sur son téléphone, puis la course se clôture.'**
  String get momoHint;

  /// No description provided for @momoWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de la validation du client…'**
  String get momoWaiting;

  /// No description provided for @momoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Paiement non abouti (refusé, annulé ou expiré). Renvoyez la demande ou encaissez en espèces.'**
  String get momoFailed;

  /// No description provided for @momoNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Toujours pas de réponse du client. Vous pouvez renvoyer la demande.'**
  String get momoNoAnswer;

  /// No description provided for @momoNeedsNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money demande du réseau : encaissez en espèces ou réessayez.'**
  String get momoNeedsNetwork;

  /// No description provided for @confirmCollection.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l’encaissement'**
  String get confirmCollection;

  /// No description provided for @sendPaymentRequest.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande de paiement'**
  String get sendPaymentRequest;

  /// No description provided for @resendPaymentRequest.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer la demande'**
  String get resendPaymentRequest;

  /// No description provided for @paymentRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée au client'**
  String get paymentRequestSent;

  /// No description provided for @sosBadge.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get sosBadge;

  /// No description provided for @sosIdleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d’aide ?'**
  String get sosIdleTitle;

  /// No description provided for @sosIdleBody.
  ///
  /// In fr, this message translates to:
  /// **'Maintenez le bouton 3 secondes. L’équipe Tara et votre contact d’urgence reçoivent votre position en direct.'**
  String get sosIdleBody;

  /// No description provided for @sosSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte envoyée'**
  String get sosSentTitle;

  /// No description provided for @sosSentBody.
  ///
  /// In fr, this message translates to:
  /// **'Restez en lieu sûr si possible. Un agent Tara vous rappelle.'**
  String get sosSentBody;

  /// No description provided for @sosAcknowledgedBody.
  ///
  /// In fr, this message translates to:
  /// **'Un agent Tara a pris en charge votre alerte et vous rappelle. Restez en lieu sûr si possible.'**
  String get sosAcknowledgedBody;

  /// No description provided for @sosPoliceCalledBody.
  ///
  /// In fr, this message translates to:
  /// **'L’équipe Tara a prévenu la police. Restez en lieu sûr si possible.'**
  String get sosPoliceCalledBody;

  /// No description provided for @sosPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas d’internet'**
  String get sosPendingTitle;

  /// No description provided for @sosPendingBody.
  ///
  /// In fr, this message translates to:
  /// **'L’alerte partira dès le retour du réseau. Envoyez-la aussi par SMS : il passe souvent sans internet.'**
  String get sosPendingBody;

  /// No description provided for @sosFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte non envoyée'**
  String get sosFailedTitle;

  /// No description provided for @sosFailedBody.
  ///
  /// In fr, this message translates to:
  /// **'Appelez Tara ou la police, ou envoyez l’alerte par SMS.'**
  String get sosFailedBody;

  /// No description provided for @sosClosedBody.
  ///
  /// In fr, this message translates to:
  /// **'L’équipe Tara a clos votre alerte. Maintenez le bouton si vous avez encore besoin d’aide.'**
  String get sosClosedBody;

  /// No description provided for @sosPendingHint.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get sosPendingHint;

  /// No description provided for @sosSendingHint.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get sosSendingHint;

  /// No description provided for @sosYourPosition.
  ///
  /// In fr, this message translates to:
  /// **'Votre position'**
  String get sosYourPosition;

  /// No description provided for @sosPositionCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Position actuelle · précision {meters} m'**
  String sosPositionCurrent(int meters);

  /// No description provided for @sosPositionShared.
  ///
  /// In fr, this message translates to:
  /// **'Partagée en direct avec Tara · précision {meters} m'**
  String sosPositionShared(int meters);

  /// No description provided for @sosPositionSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de la position…'**
  String get sosPositionSearching;

  /// No description provided for @sosPositionUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable'**
  String get sosPositionUnknown;

  /// No description provided for @sosPlate.
  ///
  /// In fr, this message translates to:
  /// **'Moto {plate}'**
  String sosPlate(String plate);

  /// No description provided for @sosCallTara.
  ///
  /// In fr, this message translates to:
  /// **'Support Tara'**
  String get sosCallTara;

  /// No description provided for @sosCallPolice.
  ///
  /// In fr, this message translates to:
  /// **'Police · {number}'**
  String sosCallPolice(String number);

  /// No description provided for @sosAccident.
  ///
  /// In fr, this message translates to:
  /// **'Accident :'**
  String get sosAccident;

  /// No description provided for @sosFire.
  ///
  /// In fr, this message translates to:
  /// **'Pompiers {number}'**
  String sosFire(String number);

  /// No description provided for @sosMedical.
  ///
  /// In fr, this message translates to:
  /// **'SAMU {number}'**
  String sosMedical(String number);

  /// No description provided for @sosSendSms.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l’alerte par SMS'**
  String get sosSendSms;

  /// No description provided for @sosCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l’alerte'**
  String get sosCancel;

  /// No description provided for @sosCancelNeedsNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Annulation impossible sans réseau. Appelez Tara pour la confirmer.'**
  String get sosCancelNeedsNetwork;

  /// No description provided for @sosSmsBody.
  ///
  /// In fr, this message translates to:
  /// **'SOS Tara : j\'ai besoin d\'aide. Position : {map}'**
  String sosSmsBody(String map);

  /// No description provided for @sosSmsNoPosition.
  ///
  /// In fr, this message translates to:
  /// **'SOS Tara : j\'ai besoin d\'aide. Position inconnue.'**
  String get sosSmsNoPosition;

  /// No description provided for @sosSmsCourse.
  ///
  /// In fr, this message translates to:
  /// **' Course {reference}.'**
  String sosSmsCourse(String reference);

  /// No description provided for @sosPositionCurrentPlain.
  ///
  /// In fr, this message translates to:
  /// **'Position actuelle'**
  String get sosPositionCurrentPlain;

  /// No description provided for @sosPositionSharedPlain.
  ///
  /// In fr, this message translates to:
  /// **'Partagée en direct avec Tara'**
  String get sosPositionSharedPlain;

  /// No description provided for @failureTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison impossible'**
  String get failureTitle;

  /// No description provided for @failureReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get failureReasonLabel;

  /// No description provided for @reasonRecipientAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Client absent'**
  String get reasonRecipientAbsent;

  /// No description provided for @reasonRecipientUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Injoignable'**
  String get reasonRecipientUnreachable;

  /// No description provided for @reasonAddressNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse introuvable'**
  String get reasonAddressNotFound;

  /// No description provided for @reasonRefused.
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé'**
  String get reasonRefused;

  /// No description provided for @reasonPaymentRefused.
  ///
  /// In fr, this message translates to:
  /// **'Refus de payer'**
  String get reasonPaymentRefused;

  /// No description provided for @reasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre motif'**
  String get reasonOther;

  /// No description provided for @failureNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Précisez le motif'**
  String get failureNoteLabel;

  /// No description provided for @failureNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. portail fermé, chien dangereux'**
  String get failureNoteHint;

  /// No description provided for @callsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appels au destinataire'**
  String get callsTitle;

  /// No description provided for @callsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun appel} =1{1 tentative} other{{count} tentatives}}'**
  String callsCount(int count);

  /// No description provided for @callMade.
  ///
  /// In fr, this message translates to:
  /// **'Appel passé'**
  String get callMade;

  /// No description provided for @callMeta.
  ///
  /// In fr, this message translates to:
  /// **'{time} · {duration}'**
  String callMeta(String time, String duration);

  /// No description provided for @callsNotRequired.
  ///
  /// In fr, this message translates to:
  /// **'Pas d’appel exigé pour ce motif.'**
  String get callsNotRequired;

  /// No description provided for @callsDone.
  ///
  /// In fr, this message translates to:
  /// **'Appels suffisants.'**
  String get callsDone;

  /// No description provided for @callsMissing.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Encore 1 appel à passer.} other{Encore {count} appels à passer.}}'**
  String callsMissing(int count);

  /// No description provided for @callsMissingAt.
  ///
  /// In fr, this message translates to:
  /// **'Encore 1 appel, à partir de {time}.'**
  String callsMissingAt(String time);

  /// No description provided for @callRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get callRecipient;

  /// No description provided for @callAgain.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler'**
  String get callAgain;

  /// No description provided for @photoPlace.
  ///
  /// In fr, this message translates to:
  /// **'Photo du lieu · obligatoire'**
  String get photoPlace;

  /// No description provided for @photoPlaceHint.
  ///
  /// In fr, this message translates to:
  /// **'Porte, portail ou devanture visible'**
  String get photoPlaceHint;

  /// No description provided for @photoPlaceTaken.
  ///
  /// In fr, this message translates to:
  /// **'Photo du lieu · prise à {time}'**
  String photoPlaceTaken(String time);

  /// No description provided for @failureNotice.
  ///
  /// In fr, this message translates to:
  /// **'L’expéditeur est prévenu tout de suite et choisit : nouvelle tentative ou retour. Sans réponse sous {minutes} min, vous lui rapportez le colis.'**
  String failureNotice(int minutes);

  /// No description provided for @validateFailure.
  ///
  /// In fr, this message translates to:
  /// **'Valider l’échec'**
  String get validateFailure;

  /// No description provided for @cantDeliver.
  ///
  /// In fr, this message translates to:
  /// **'Livraison impossible ?'**
  String get cantDeliver;

  /// No description provided for @failureWaitingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Échec enregistré'**
  String get failureWaitingTitle;

  /// No description provided for @failureWaitingBody.
  ///
  /// In fr, this message translates to:
  /// **'L’expéditeur choisit : nouvelle tentative ou retour. Sans réponse, le retour sera décidé à {time}. Gardez le colis avec vous.'**
  String failureWaitingBody(String time);

  /// No description provided for @failureWaitingBodyQueued.
  ///
  /// In fr, this message translates to:
  /// **'L’échec partira dès le retour du réseau. Gardez le colis avec vous.'**
  String get failureWaitingBodyQueued;

  /// No description provided for @retryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative'**
  String get retryTitle;

  /// No description provided for @retryBody.
  ///
  /// In fr, this message translates to:
  /// **'L’expéditeur demande une nouvelle tentative. Repartez vers le destinataire.'**
  String get retryBody;

  /// No description provided for @retryAction.
  ///
  /// In fr, this message translates to:
  /// **'Repartir vers le destinataire'**
  String get retryAction;

  /// No description provided for @returnTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retour du colis'**
  String get returnTitle;

  /// No description provided for @returnMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Retour du colis · {minutes} min'**
  String returnMinutes(int minutes);

  /// No description provided for @failureChip.
  ///
  /// In fr, this message translates to:
  /// **'Échec · {reason}'**
  String failureChip(String reason);

  /// No description provided for @returnTo.
  ///
  /// In fr, this message translates to:
  /// **'Rapporter le colis à'**
  String get returnTo;

  /// No description provided for @returnStepJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le vendeur'**
  String get returnStepJoin;

  /// No description provided for @returnStepCode.
  ///
  /// In fr, this message translates to:
  /// **'Saisir le code de retour du vendeur'**
  String get returnStepCode;

  /// No description provided for @returnStepPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photographier le colis rendu'**
  String get returnStepPhoto;

  /// No description provided for @stepInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get stepInProgress;

  /// No description provided for @atSender.
  ///
  /// In fr, this message translates to:
  /// **'Je suis chez le vendeur'**
  String get atSender;

  /// No description provided for @returnCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de retour'**
  String get returnCodeLabel;

  /// No description provided for @returnCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'reçu par SMS par le vendeur'**
  String get returnCodeHint;

  /// No description provided for @photoReturned.
  ///
  /// In fr, this message translates to:
  /// **'Photographier le colis rendu'**
  String get photoReturned;

  /// No description provided for @photoReturnedHint.
  ///
  /// In fr, this message translates to:
  /// **'Colis entre les mains du vendeur'**
  String get photoReturnedHint;

  /// No description provided for @photoReturnedTaken.
  ///
  /// In fr, this message translates to:
  /// **'Photo du retour · prise à {time}'**
  String photoReturnedTaken(String time);

  /// No description provided for @parcelReturned.
  ///
  /// In fr, this message translates to:
  /// **'Colis rendu'**
  String get parcelReturned;

  /// No description provided for @returnQueuedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retour enregistré'**
  String get returnQueuedTitle;

  /// No description provided for @returnQueuedBody.
  ///
  /// In fr, this message translates to:
  /// **'Il sera envoyé dès le retour du réseau.'**
  String get returnQueuedBody;

  /// No description provided for @orderReturnedNotice.
  ///
  /// In fr, this message translates to:
  /// **'Colis rendu au vendeur : course terminée.'**
  String get orderReturnedNotice;

  /// No description provided for @earningsToday.
  ///
  /// In fr, this message translates to:
  /// **'Gains d’aujourd’hui'**
  String get earningsToday;

  /// No description provided for @earningsWeek.
  ///
  /// In fr, this message translates to:
  /// **'Gains de la semaine'**
  String get earningsWeek;

  /// No description provided for @earningsMonth.
  ///
  /// In fr, this message translates to:
  /// **'Gains du mois'**
  String get earningsMonth;

  /// No description provided for @coursesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune course} =1{1 course} other{{count} courses}}'**
  String coursesCount(int count);

  /// No description provided for @weekdaysShort.
  ///
  /// In fr, this message translates to:
  /// **'Lun,Mar,Mer,Jeu,Ven,Sam,Dim'**
  String get weekdaysShort;

  /// No description provided for @todayShort.
  ///
  /// In fr, this message translates to:
  /// **'Auj.'**
  String get todayShort;

  /// No description provided for @weekShort.
  ///
  /// In fr, this message translates to:
  /// **'S{number}'**
  String weekShort(int number);

  /// No description provided for @hourShort.
  ///
  /// In fr, this message translates to:
  /// **'{hour}h'**
  String hourShort(int hour);

  /// No description provided for @chartSemantics.
  ///
  /// In fr, this message translates to:
  /// **'{caption} : {values}'**
  String chartSemantics(String caption, String values);

  /// No description provided for @cashToDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Espèces à reverser à Tara'**
  String get cashToDeposit;

  /// No description provided for @depositAction.
  ///
  /// In fr, this message translates to:
  /// **'Reverser'**
  String get depositAction;

  /// No description provided for @lastCourses.
  ///
  /// In fr, this message translates to:
  /// **'Dernières courses'**
  String get lastCourses;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get seeAll;

  /// No description provided for @seeLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get seeLess;

  /// No description provided for @statusDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livrée'**
  String get statusDelivered;

  /// No description provided for @statusReturned.
  ///
  /// In fr, this message translates to:
  /// **'Retour au vendeur'**
  String get statusReturned;

  /// No description provided for @statusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get statusCancelled;

  /// No description provided for @cashCollectedAmount.
  ///
  /// In fr, this message translates to:
  /// **'{amount} encaissés'**
  String cashCollectedAmount(String amount);

  /// No description provided for @noCoursesYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de course terminée.'**
  String get noCoursesYet;

  /// No description provided for @activityError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l’activité.'**
  String get activityError;

  /// No description provided for @depositTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reverser les espèces'**
  String get depositTitle;

  /// No description provided for @depositBody.
  ///
  /// In fr, this message translates to:
  /// **'Une demande de paiement de {amount} part sur votre téléphone. Validez-la avec votre code Mobile Money.'**
  String depositBody(String amount);

  /// No description provided for @depositOffice.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez aussi déposer les espèces au bureau Tara.'**
  String get depositOffice;

  /// No description provided for @depositNumber.
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro Mobile Money'**
  String get depositNumber;

  /// No description provided for @depositSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get depositSend;

  /// No description provided for @depositWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Validez la demande sur votre téléphone…'**
  String get depositWaiting;

  /// No description provided for @depositDone.
  ///
  /// In fr, this message translates to:
  /// **'{amount} reversés à Tara.'**
  String depositDone(String amount);

  /// No description provided for @depositFailed.
  ///
  /// In fr, this message translates to:
  /// **'Paiement non abouti. Réessayez ou déposez au bureau Tara.'**
  String get depositFailed;

  /// No description provided for @depositOperator.
  ///
  /// In fr, this message translates to:
  /// **'Opérateur'**
  String get depositOperator;

  /// No description provided for @cashDueAt.
  ///
  /// In fr, this message translates to:
  /// **'À déposer avant {time}'**
  String cashDueAt(String time);

  /// No description provided for @cashDueTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'À déposer avant demain {time}'**
  String cashDueTomorrow(String time);

  /// No description provided for @cashOverdueNotice.
  ///
  /// In fr, this message translates to:
  /// **'En retard : plus de courses jusqu’au dépôt.'**
  String get cashOverdueNotice;

  /// No description provided for @blockerCashOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Espèces non déposées dans les 24 h : déposez-les (onglet Activité) pour recevoir des courses.'**
  String get blockerCashOverdue;

  /// No description provided for @blockerSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Compte suspendu : contactez Tara.'**
  String get blockerSuspended;

  /// No description provided for @blockerPending.
  ///
  /// In fr, this message translates to:
  /// **'Compte en cours de validation.'**
  String get blockerPending;

  /// No description provided for @pendingActionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Actions en attente'**
  String get pendingActionsTitle;

  /// No description provided for @autoSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoi automatique'**
  String get autoSend;

  /// No description provided for @queuedPickup.
  ///
  /// In fr, this message translates to:
  /// **'Enlèvement'**
  String get queuedPickup;

  /// No description provided for @queuedDepart.
  ///
  /// In fr, this message translates to:
  /// **'Départ vers le client'**
  String get queuedDepart;

  /// No description provided for @queuedCollect.
  ///
  /// In fr, this message translates to:
  /// **'Encaissement espèces'**
  String get queuedCollect;

  /// No description provided for @queuedDeliver.
  ///
  /// In fr, this message translates to:
  /// **'Livraison confirmée'**
  String get queuedDeliver;

  /// No description provided for @queuedFail.
  ///
  /// In fr, this message translates to:
  /// **'Échec de livraison'**
  String get queuedFail;

  /// No description provided for @queuedRetry.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative'**
  String get queuedRetry;

  /// No description provided for @queuedReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour au vendeur'**
  String get queuedReturn;

  /// No description provided for @detailCodePhoto.
  ///
  /// In fr, this message translates to:
  /// **'code + photo'**
  String get detailCodePhoto;

  /// No description provided for @detailNoCodePhoto.
  ///
  /// In fr, this message translates to:
  /// **'sans code + photo'**
  String get detailNoCodePhoto;

  /// No description provided for @detailPhotoSize.
  ///
  /// In fr, this message translates to:
  /// **'photo {size} Mo'**
  String detailPhotoSize(String size);

  /// No description provided for @statusWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statusWaiting;

  /// No description provided for @statusSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get statusSending;

  /// No description provided for @statusRefused.
  ///
  /// In fr, this message translates to:
  /// **'Refusée'**
  String get statusRefused;

  /// No description provided for @offlineNote.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez continuer la course : l’itinéraire et les codes restent disponibles hors connexion.'**
  String get offlineNote;

  /// No description provided for @retryNow.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer maintenant'**
  String get retryNow;

  /// No description provided for @retrying.
  ///
  /// In fr, this message translates to:
  /// **'Tentative d’envoi…'**
  String get retrying;

  /// No description provided for @stillOffline.
  ///
  /// In fr, this message translates to:
  /// **'Toujours hors connexion · Réessayer'**
  String get stillOffline;

  /// No description provided for @continueCourse.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la course'**
  String get continueCourse;

  /// No description provided for @allSent.
  ///
  /// In fr, this message translates to:
  /// **'Tout est envoyé.'**
  String get allSent;

  /// No description provided for @refusedBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action refusée'**
  String get refusedBannerTitle;

  /// No description provided for @refusedBannerDetail.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 action à vérifier} other{{count} actions à vérifier}}'**
  String refusedBannerDetail(int count);

  /// No description provided for @refusedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Refusée par le serveur. Corrigez-la depuis la course, ou appelez le support avant de la retirer.'**
  String get refusedHelp;

  /// No description provided for @removeAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l’action'**
  String get removeAction;

  /// No description provided for @confirmRemoveAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retrait'**
  String get confirmRemoveAction;

  /// No description provided for @offlineNoPending.
  ///
  /// In fr, this message translates to:
  /// **'Vos actions sont gardées sur le téléphone'**
  String get offlineNoPending;

  /// No description provided for @balanceAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Solde disponible'**
  String get balanceAvailable;

  /// No description provided for @balanceReserved.
  ///
  /// In fr, this message translates to:
  /// **'{amount} mis de côté pour vos courses en cours'**
  String balanceReserved(String amount);

  /// No description provided for @balanceExplain.
  ///
  /// In fr, this message translates to:
  /// **'Couvre l’argent à encaisser sur vos courses'**
  String get balanceExplain;

  /// No description provided for @topUpAction.
  ///
  /// In fr, this message translates to:
  /// **'Recharger'**
  String get topUpAction;

  /// No description provided for @topUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recharger mon solde'**
  String get topUpTitle;

  /// No description provided for @topUpAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get topUpAmount;

  /// No description provided for @topUpOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre montant (F)'**
  String get topUpOther;

  /// No description provided for @topUpOtherHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 15000'**
  String get topUpOtherHint;

  /// No description provided for @topUpBody.
  ///
  /// In fr, this message translates to:
  /// **'Une demande de paiement de {amount} part sur votre téléphone. Les frais Mobile Money sont pour Tara : votre solde reçoit {amount}.'**
  String topUpBody(String amount);

  /// No description provided for @topUpOffice.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez aussi recharger en espèces au bureau Tara.'**
  String get topUpOffice;

  /// No description provided for @topUpDone.
  ///
  /// In fr, this message translates to:
  /// **'{amount} ajoutés à votre solde.'**
  String topUpDone(String amount);

  /// No description provided for @topUpFailed.
  ///
  /// In fr, this message translates to:
  /// **'Paiement non abouti. Réessayez ou rechargez au bureau Tara.'**
  String get topUpFailed;

  /// No description provided for @topUpRange.
  ///
  /// In fr, this message translates to:
  /// **'Montant entre {min} et {max}.'**
  String topUpRange(String min, String max);

  /// No description provided for @takenFromBalance.
  ///
  /// In fr, this message translates to:
  /// **'Pris sur votre solde (déjà mis de côté)'**
  String get takenFromBalance;

  /// No description provided for @balanceShort.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get balanceShort;

  /// No description provided for @myDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Mes pièces'**
  String get myDocuments;

  /// No description provided for @myDocumentsBody.
  ///
  /// In fr, this message translates to:
  /// **'Une pièce refusée ou expirée se renvoie ici ; l’équipe Tara la vérifie à nouveau.'**
  String get myDocumentsBody;

  /// No description provided for @docsToFix.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 pièce à renvoyer} other{{count} pièces à renvoyer}}'**
  String docsToFix(int count);

  /// No description provided for @docsToFixHint.
  ///
  /// In fr, this message translates to:
  /// **'Sans elle, vous ne pouvez plus recevoir de courses.'**
  String get docsToFixHint;

  /// No description provided for @docsInReview.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 pièce en vérification} other{{count} pièces en vérification}}'**
  String docsInReview(int count);

  /// No description provided for @docsAllApproved.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos pièces sont validées'**
  String get docsAllApproved;

  /// No description provided for @emergencyContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contact d’urgence'**
  String get emergencyContactTitle;

  /// No description provided for @emergencyNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact'**
  String get emergencyNone;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @removeContact.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce contact'**
  String get removeContact;

  /// No description provided for @displaySection.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get displaySection;

  /// No description provided for @themeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get themeLabel;

  /// No description provided for @optionAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get optionAuto;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @languageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageLabel;

  /// No description provided for @effectsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Animations'**
  String get effectsLabel;

  /// No description provided for @effectsFull.
  ///
  /// In fr, this message translates to:
  /// **'Complètes'**
  String get effectsFull;

  /// No description provided for @effectsReduced.
  ///
  /// In fr, this message translates to:
  /// **'Réduites'**
  String get effectsReduced;

  /// No description provided for @effectsHint.
  ///
  /// In fr, this message translates to:
  /// **'Réduites : moins d’effets, plus fluide sur un téléphone modeste.'**
  String get effectsHint;

  /// No description provided for @effectsAutoReduced.
  ///
  /// In fr, this message translates to:
  /// **'Réduites automatiquement sur ce téléphone.'**
  String get effectsAutoReduced;

  /// No description provided for @helpSection.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get helpSection;

  /// No description provided for @supportTara.
  ///
  /// In fr, this message translates to:
  /// **'Support Tara'**
  String get supportTara;

  /// No description provided for @logoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne recevrez plus de courses sur ce téléphone jusqu’à votre prochaine connexion.'**
  String get logoutConfirm;

  /// No description provided for @logoutBlockedCourse.
  ///
  /// In fr, this message translates to:
  /// **'Terminez votre course avant de vous déconnecter.'**
  String get logoutBlockedCourse;

  /// No description provided for @logoutBlockedPending.
  ///
  /// In fr, this message translates to:
  /// **'Des actions attendent le réseau : elles seraient perdues. Reconnectez-vous d’abord.'**
  String get logoutBlockedPending;

  /// No description provided for @appVersion.
  ///
  /// In fr, this message translates to:
  /// **'Tara Livreur · version {version}'**
  String appVersion(String version);

  /// No description provided for @accountActive.
  ///
  /// In fr, this message translates to:
  /// **'Compte actif'**
  String get accountActive;

  /// No description provided for @accountPending.
  ///
  /// In fr, this message translates to:
  /// **'Dossier en vérification'**
  String get accountPending;

  /// No description provided for @accountSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Compte suspendu'**
  String get accountSuspended;

  /// No description provided for @accountRejected.
  ///
  /// In fr, this message translates to:
  /// **'Dossier refusé'**
  String get accountRejected;

  /// No description provided for @profileError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre profil.'**
  String get profileError;

  /// No description provided for @slideToAccept.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour accepter'**
  String get slideToAccept;

  /// No description provided for @soundsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sons'**
  String get soundsLabel;

  /// No description provided for @soundsHint.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle course, colis livré, argent encaissé… Le mode silencieux du téléphone est respecté.'**
  String get soundsHint;
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
