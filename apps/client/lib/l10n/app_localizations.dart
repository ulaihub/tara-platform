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

  /// No description provided for @addLegalIds.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter RCCM et NIU (facultatif)'**
  String get addLegalIds;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @categoryBeauty.
  ///
  /// In fr, this message translates to:
  /// **'Beauté'**
  String get categoryBeauty;

  /// No description provided for @categoryElectronics.
  ///
  /// In fr, this message translates to:
  /// **'Électronique'**
  String get categoryElectronics;

  /// No description provided for @categoryFashion.
  ///
  /// In fr, this message translates to:
  /// **'Mode'**
  String get categoryFashion;

  /// No description provided for @categoryFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get categoryFood;

  /// No description provided for @categoryHome.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get categoryHome;

  /// No description provided for @categoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get categoryOther;

  /// No description provided for @change.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get change;

  /// No description provided for @codeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé par SMS au {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @codeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code reçu'**
  String get codeTitle;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @countryCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif du pays {code}'**
  String countryCodeLabel(String code);

  /// No description provided for @digitLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre {index}'**
  String digitLabel(int index);

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @genericError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get genericError;

  /// No description provided for @getCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le code'**
  String get getCode;

  /// No description provided for @haveReferral.
  ///
  /// In fr, this message translates to:
  /// **'J’ai un code de parrainage'**
  String get haveReferral;

  /// No description provided for @kindPerson.
  ///
  /// In fr, this message translates to:
  /// **'Pour moi'**
  String get kindPerson;

  /// No description provided for @kindPersonHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez passer en mode boutique plus tard, depuis votre profil.'**
  String get kindPersonHelp;

  /// No description provided for @kindQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Vous envoyez des colis…'**
  String get kindQuestion;

  /// No description provided for @kindShop.
  ///
  /// In fr, this message translates to:
  /// **'Pour ma boutique'**
  String get kindShop;

  /// No description provided for @kindShopHelp.
  ///
  /// In fr, this message translates to:
  /// **'L’argent encaissé à la livraison vous est reversé par Mobile Money.'**
  String get kindShopHelp;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @legalAnd.
  ///
  /// In fr, this message translates to:
  /// **' et la '**
  String get legalAnd;

  /// No description provided for @legalPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En continuant, vous acceptez les '**
  String get legalPrefix;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @networkError.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion internet. Vérifiez le réseau et réessayez.'**
  String get networkError;

  /// No description provided for @niu.
  ///
  /// In fr, this message translates to:
  /// **'NIU'**
  String get niu;

  /// No description provided for @niuHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. M012345678901A'**
  String get niuHint;

  /// No description provided for @noSms.
  ///
  /// In fr, this message translates to:
  /// **'Pas reçu de SMS ? Contacter le support'**
  String get noSms;

  /// No description provided for @payoutHelp.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Mobile Money qui reçoit vos ventes encaissées.'**
  String get payoutHelp;

  /// No description provided for @payoutNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Mobile Money'**
  String get payoutNumber;

  /// No description provided for @payoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reversements'**
  String get payoutTitle;

  /// No description provided for @phoneHelp.
  ///
  /// In fr, this message translates to:
  /// **'Un SMS gratuit vous est envoyé. Aucun e-mail n’est demandé.'**
  String get phoneHelp;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'6XX XX XX XX'**
  String get phoneHint;

  /// No description provided for @phoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de mobile camerounais à 9 chiffres, commençant par 6.'**
  String get phoneInvalid;

  /// No description provided for @phoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneLabel;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get privacy;

  /// No description provided for @rccm.
  ///
  /// In fr, this message translates to:
  /// **'RCCM'**
  String get rccm;

  /// No description provided for @rccmHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. RC/DLA/2024/B/1234'**
  String get rccmHint;

  /// No description provided for @referralHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. TARA-7KQ2PM'**
  String get referralHint;

  /// No description provided for @referralLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de parrainage'**
  String get referralLabel;

  /// No description provided for @requiredField.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire'**
  String get requiredField;

  /// No description provided for @resend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get resend;

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

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @senderSpace.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez vos colis'**
  String get senderSpace;

  /// No description provided for @shopCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie (facultatif)'**
  String get shopCategory;

  /// No description provided for @shopName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la boutique'**
  String get shopName;

  /// No description provided for @shopNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Awa Fashion'**
  String get shopNameHint;

  /// No description provided for @signInBody.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec votre numéro, ou créez votre compte. Nous vous envoyons un code par SMS.'**
  String get signInBody;

  /// No description provided for @signInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos colis livrés à Douala'**
  String get signInTitle;

  /// No description provided for @terms.
  ///
  /// In fr, this message translates to:
  /// **'conditions d’utilisation'**
  String get terms;

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @welcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom figure dans les messages envoyés à vos destinataires.'**
  String get welcomeBody;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur Tara'**
  String get welcomeTitle;

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tara'**
  String get appTitle;

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

  /// No description provided for @tabHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabHome;

  /// No description provided for @tabOrders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get tabOrders;

  /// No description provided for @tabProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @sendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un colis'**
  String get sendTitle;

  /// No description provided for @sendBody.
  ///
  /// In fr, this message translates to:
  /// **'Un livreur vient le chercher et le livre dans Douala, avec suivi en direct.'**
  String get sendBody;

  /// No description provided for @newDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle livraison'**
  String get newDelivery;

  /// No description provided for @askAddress.
  ///
  /// In fr, this message translates to:
  /// **'Demander l’adresse au destinataire'**
  String get askAddress;

  /// No description provided for @shopBalance.
  ///
  /// In fr, this message translates to:
  /// **'Ventes de la boutique'**
  String get shopBalance;

  /// No description provided for @shopBalanceDaily.
  ///
  /// In fr, this message translates to:
  /// **'À recevoir · versé chaque nuit sur votre Mobile Money'**
  String get shopBalanceDaily;

  /// No description provided for @shopBalanceOnDemand.
  ///
  /// In fr, this message translates to:
  /// **'À recevoir · versé quand vous le demandez'**
  String get shopBalanceOnDemand;

  /// No description provided for @inProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get inProgress;

  /// No description provided for @noOrdersInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Aucune livraison en cours. Vos colis apparaissent ici dès leur envoi.'**
  String get noOrdersInProgress;

  /// No description provided for @statusScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Prévue {when}'**
  String statusScheduled(String when);

  /// No description provided for @statusSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d’un livreur'**
  String get statusSearching;

  /// No description provided for @statusRiderComing.
  ///
  /// In fr, this message translates to:
  /// **'Livreur en route vers l’enlèvement'**
  String get statusRiderComing;

  /// No description provided for @statusInDelivery.
  ///
  /// In fr, this message translates to:
  /// **'En livraison'**
  String get statusInDelivery;

  /// No description provided for @statusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Livraison impossible · à décider'**
  String get statusFailed;

  /// No description provided for @todayAt.
  ///
  /// In fr, this message translates to:
  /// **'aujourd’hui à {time}'**
  String todayAt(String time);

  /// No description provided for @tomorrowAt.
  ///
  /// In fr, this message translates to:
  /// **'demain à {time}'**
  String tomorrowAt(String time);

  /// No description provided for @ordersError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos livraisons.'**
  String get ordersError;

  /// No description provided for @finished.
  ///
  /// In fr, this message translates to:
  /// **'Terminées'**
  String get finished;

  /// No description provided for @noOrdersFinished.
  ///
  /// In fr, this message translates to:
  /// **'Aucune livraison terminée pour l’instant.'**
  String get noOrdersFinished;

  /// No description provided for @statusDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livrée · {day}'**
  String statusDelivered(String day);

  /// No description provided for @statusReturned.
  ///
  /// In fr, this message translates to:
  /// **'Retournée à l’expéditeur'**
  String get statusReturned;

  /// No description provided for @statusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get statusCancelled;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'aujourd’hui'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'hier'**
  String get yesterday;

  /// No description provided for @referralTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parrainage'**
  String get referralTitle;

  /// No description provided for @referralBody.
  ///
  /// In fr, this message translates to:
  /// **'Partagez votre code : vos amis l’entrent à leur inscription et profitent d’une réduction.'**
  String get referralBody;

  /// No description provided for @appVersion.
  ///
  /// In fr, this message translates to:
  /// **'Tara · version {version}'**
  String appVersion(String version);

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @displaySection.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get displaySection;

  /// No description provided for @effectsAutoReduced.
  ///
  /// In fr, this message translates to:
  /// **'Réduites automatiquement sur ce téléphone.'**
  String get effectsAutoReduced;

  /// No description provided for @effectsFull.
  ///
  /// In fr, this message translates to:
  /// **'Complètes'**
  String get effectsFull;

  /// No description provided for @effectsHint.
  ///
  /// In fr, this message translates to:
  /// **'Réduites : moins d’effets, plus fluide sur un téléphone modeste.'**
  String get effectsHint;

  /// No description provided for @effectsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Animations'**
  String get effectsLabel;

  /// No description provided for @effectsReduced.
  ///
  /// In fr, this message translates to:
  /// **'Réduites'**
  String get effectsReduced;

  /// No description provided for @helpSection.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get helpSection;

  /// No description provided for @languageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageLabel;

  /// No description provided for @logoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne recevrez plus de notifications sur ce téléphone jusqu’à votre prochaine connexion.'**
  String get logoutConfirm;

  /// No description provided for @optionAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get optionAuto;

  /// No description provided for @supportTara.
  ///
  /// In fr, this message translates to:
  /// **'Support Tara'**
  String get supportTara;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get themeLabel;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @prohibitedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Objets interdits'**
  String get prohibitedTitle;

  /// No description provided for @prohibitedWeapons.
  ///
  /// In fr, this message translates to:
  /// **'Armes, y compris armes blanches, et munitions'**
  String get prohibitedWeapons;

  /// No description provided for @prohibitedIllegal.
  ///
  /// In fr, this message translates to:
  /// **'Produits illicites : drogues, contrefaçons'**
  String get prohibitedIllegal;

  /// No description provided for @prohibitedDangerous.
  ///
  /// In fr, this message translates to:
  /// **'Matières dangereuses : gaz, carburant, produits inflammables, explosifs ou corrosifs'**
  String get prohibitedDangerous;

  /// No description provided for @prohibitedAnimals.
  ///
  /// In fr, this message translates to:
  /// **'Animaux vivants'**
  String get prohibitedAnimals;

  /// No description provided for @prohibitedCash.
  ///
  /// In fr, this message translates to:
  /// **'Liasses d’argent liquide'**
  String get prohibitedCash;

  /// No description provided for @prohibitedPledge.
  ///
  /// In fr, this message translates to:
  /// **'En envoyant le colis, vous confirmez qu’il n’en contient aucun.'**
  String get prohibitedPledge;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @stepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total} · {title}'**
  String stepOf(int current, int total, String title);

  /// No description provided for @stepPickup.
  ///
  /// In fr, this message translates to:
  /// **'Enlèvement'**
  String get stepPickup;

  /// No description provided for @stepRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire'**
  String get stepRecipient;

  /// No description provided for @stepPackage.
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get stepPackage;

  /// No description provided for @stepWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand'**
  String get stepWhen;

  /// No description provided for @stepSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get stepSummary;

  /// No description provided for @pickupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Où récupérer le colis ?'**
  String get pickupTitle;

  /// No description provided for @pickupBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur passe le prendre à cette adresse.'**
  String get pickupBody;

  /// No description provided for @noPickupYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse enregistrée. Placez votre boutique ou votre domicile sur la carte : vous la retrouverez la prochaine fois.'**
  String get noPickupYet;

  /// No description provided for @addressesError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos adresses.'**
  String get addressesError;

  /// No description provided for @newAddress.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle adresse'**
  String get newAddress;

  /// No description provided for @pickupRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ou ajoutez l’adresse d’enlèvement.'**
  String get pickupRequired;

  /// No description provided for @pickupAddressTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse d’enlèvement'**
  String get pickupAddressTitle;

  /// No description provided for @locationUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable : déplacez la carte jusqu’au bon endroit.'**
  String get locationUnavailable;

  /// No description provided for @myPosition.
  ///
  /// In fr, this message translates to:
  /// **'Ma position'**
  String get myPosition;

  /// No description provided for @pinHint.
  ///
  /// In fr, this message translates to:
  /// **'Déplacez la carte pour placer l’épingle sur l’entrée exacte.'**
  String get pinHint;

  /// No description provided for @neighborhoodLabel.
  ///
  /// In fr, this message translates to:
  /// **'Quartier'**
  String get neighborhoodLabel;

  /// No description provided for @neighborhoodAuto.
  ///
  /// In fr, this message translates to:
  /// **'Déduit du point sur la carte'**
  String get neighborhoodAuto;

  /// No description provided for @neighborhoodSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un quartier'**
  String get neighborhoodSearch;

  /// No description provided for @landmarkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Repère'**
  String get landmarkLabel;

  /// No description provided for @landmarkHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Portail bleu après la pharmacie du carrefour'**
  String get landmarkHint;

  /// No description provided for @landmarkRequired.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez un repère visible (3 caractères au moins).'**
  String get landmarkRequired;

  /// No description provided for @addressLabel.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get addressLabel;

  /// No description provided for @labelShop.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get labelShop;

  /// No description provided for @labelHome.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get labelHome;

  /// No description provided for @labelOffice.
  ///
  /// In fr, this message translates to:
  /// **'Bureau'**
  String get labelOffice;

  /// No description provided for @saveAddress.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l’adresse'**
  String get saveAddress;

  /// No description provided for @recipientTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui reçoit le colis ?'**
  String get recipientTitle;

  /// No description provided for @recipientBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous lui envoyons le suivi de la livraison par SMS.'**
  String get recipientBody;

  /// No description provided for @recipientName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du destinataire'**
  String get recipientName;

  /// No description provided for @recipientNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Marie Ngo'**
  String get recipientNameHint;

  /// No description provided for @recipientPhone.
  ///
  /// In fr, this message translates to:
  /// **'Son numéro'**
  String get recipientPhone;

  /// No description provided for @recipientNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le nom du destinataire.'**
  String get recipientNameRequired;

  /// No description provided for @recentRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get recentRecipients;

  /// No description provided for @deliveriesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 livraison} other{{count} livraisons}}'**
  String deliveriesCount(int count);

  /// No description provided for @deliveryAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de livraison'**
  String get deliveryAddress;

  /// No description provided for @placeOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Placer sur la carte'**
  String get placeOnMap;

  /// No description provided for @placeOnMapBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous savez où livrer : placez l’épingle vous-même.'**
  String get placeOnMapBody;

  /// No description provided for @askRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Demander au destinataire'**
  String get askRecipient;

  /// No description provided for @askRecipientBody.
  ///
  /// In fr, this message translates to:
  /// **'Il reçoit un lien et place lui-même son point sur la carte.'**
  String get askRecipientBody;

  /// No description provided for @viaWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get viaWhatsapp;

  /// No description provided for @viaSms.
  ///
  /// In fr, this message translates to:
  /// **'SMS'**
  String get viaSms;

  /// No description provided for @recipientFirst.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez d’abord le nom et le numéro du destinataire.'**
  String get recipientFirst;

  /// No description provided for @linkSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé à {name}'**
  String linkSentTitle(String name);

  /// No description provided for @linkWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de son point : l’adresse s’affiche ici dès qu’il l’a placé. Vous pouvez continuer en attendant.'**
  String get linkWaiting;

  /// No description provided for @linkExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le lien a expiré sans réponse.'**
  String get linkExpired;

  /// No description provided for @resendLink.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le lien'**
  String get resendLink;

  /// No description provided for @placeMyself.
  ///
  /// In fr, this message translates to:
  /// **'Placer moi-même'**
  String get placeMyself;

  /// No description provided for @changeAddress.
  ///
  /// In fr, this message translates to:
  /// **'Changer d’adresse'**
  String get changeAddress;

  /// No description provided for @addressVerified.
  ///
  /// In fr, this message translates to:
  /// **'Adresse confirmée par une livraison'**
  String get addressVerified;

  /// No description provided for @addressFromRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Placée par le destinataire'**
  String get addressFromRecipient;

  /// No description provided for @addressRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez où livrer le colis.'**
  String get addressRequired;

  /// No description provided for @whatsappUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp ne s’est pas ouvert. Essayez par SMS.'**
  String get whatsappUnavailable;

  /// No description provided for @smsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Les SMS ne se sont pas ouverts sur ce téléphone.'**
  String get smsUnavailable;

  /// No description provided for @locationLinkMessage.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}, {sender} vous envoie un colis avec Tara. Indiquez où vous le livrer : {url}'**
  String locationLinkMessage(String name, String sender, String url);

  /// No description provided for @packageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qu’y a-t-il dans le colis ?'**
  String get packageTitle;

  /// No description provided for @packageBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur sait ainsi comment le transporter.'**
  String get packageBody;

  /// No description provided for @contentsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nature du contenu'**
  String get contentsLabel;

  /// No description provided for @contentsDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get contentsDocuments;

  /// No description provided for @contentsClothing.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements, chaussures'**
  String get contentsClothing;

  /// No description provided for @contentsMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Médicaments'**
  String get contentsMedicine;

  /// No description provided for @contentsLaundry.
  ///
  /// In fr, this message translates to:
  /// **'Linge'**
  String get contentsLaundry;

  /// No description provided for @contentsHousehold.
  ///
  /// In fr, this message translates to:
  /// **'Cuisine, maison'**
  String get contentsHousehold;

  /// No description provided for @contentsElectronics.
  ///
  /// In fr, this message translates to:
  /// **'Électronique'**
  String get contentsElectronics;

  /// No description provided for @contentsFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get contentsFood;

  /// No description provided for @contentsBeauty.
  ///
  /// In fr, this message translates to:
  /// **'Beauté'**
  String get contentsBeauty;

  /// No description provided for @contentsSecondhand.
  ///
  /// In fr, this message translates to:
  /// **'Brocante'**
  String get contentsSecondhand;

  /// No description provided for @contentsOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get contentsOther;

  /// No description provided for @contentsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la nature du contenu.'**
  String get contentsRequired;

  /// No description provided for @descriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Précisez (facultatif)'**
  String get descriptionLabel;

  /// No description provided for @descriptionLabelRequired.
  ///
  /// In fr, this message translates to:
  /// **'Précisez le contenu'**
  String get descriptionLabelRequired;

  /// No description provided for @descriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez ce que contient le colis.'**
  String get descriptionRequired;

  /// No description provided for @descriptionHintDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Contrat signé, dossier'**
  String get descriptionHintDocuments;

  /// No description provided for @descriptionHintClothing.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 2 paires de chaussures'**
  String get descriptionHintClothing;

  /// No description provided for @descriptionHintMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Ordonnance de la pharmacie'**
  String get descriptionHintMedicine;

  /// No description provided for @descriptionHintLaundry.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 1 sac de linge repassé'**
  String get descriptionHintLaundry;

  /// No description provided for @descriptionHintHousehold.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Marmite et 6 verres'**
  String get descriptionHintHousehold;

  /// No description provided for @descriptionHintElectronics.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Téléphone et chargeur'**
  String get descriptionHintElectronics;

  /// No description provided for @descriptionHintFood.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Gâteau d’anniversaire'**
  String get descriptionHintFood;

  /// No description provided for @descriptionHintBeauty.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Perruque, crèmes'**
  String get descriptionHintBeauty;

  /// No description provided for @descriptionHintSecondhand.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Lampe ancienne'**
  String get descriptionHintSecondhand;

  /// No description provided for @descriptionHintOther.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Pièce de moto'**
  String get descriptionHintOther;

  /// No description provided for @sizeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get sizeLabel;

  /// No description provided for @sizeMax.
  ///
  /// In fr, this message translates to:
  /// **'≤ {kg} kg'**
  String sizeMax(int kg);

  /// No description provided for @sizeHelpS.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 2 kg · tient dans une main : enveloppe, téléphone, médicaments.'**
  String get sizeHelpS;

  /// No description provided for @sizeHelpM.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 5 kg · boîte à chaussures, petit sac de vêtements.'**
  String get sizeHelpM;

  /// No description provided for @sizeHelpL.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 10 kg · carton moyen, sac de linge.'**
  String get sizeHelpL;

  /// No description provided for @sizeHelpXL.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 20 kg · gros carton, petit électroménager. Supplément colis XL.'**
  String get sizeHelpXL;

  /// No description provided for @fragileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fragile'**
  String get fragileTitle;

  /// No description provided for @fragileBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur le transporte avec soin.'**
  String get fragileBody;

  /// No description provided for @codLabel.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser auprès du destinataire'**
  String get codLabel;

  /// No description provided for @codHint.
  ///
  /// In fr, this message translates to:
  /// **'0 si rien à encaisser'**
  String get codHint;

  /// No description provided for @codHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur encaisse ce montant à la livraison ; il rejoint vos ventes, reversées sur votre Mobile Money.'**
  String get codHelp;

  /// No description provided for @codTooHigh.
  ///
  /// In fr, this message translates to:
  /// **'500 000 F au plus par livraison.'**
  String get codTooHigh;

  /// No description provided for @valueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Valeur du contenu (facultatif)'**
  String get valueLabel;

  /// No description provided for @valueHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 25 000'**
  String get valueHint;

  /// No description provided for @valueHelp.
  ///
  /// In fr, this message translates to:
  /// **'En FCFA. Indiquée au livreur, utile en cas de litige.'**
  String get valueHelp;

  /// No description provided for @valueTooHigh.
  ///
  /// In fr, this message translates to:
  /// **'10 000 000 F au plus.'**
  String get valueTooHigh;

  /// No description provided for @instructionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Instructions pour le livreur (facultatif)'**
  String get instructionsLabel;

  /// No description provided for @instructionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Appeler en arrivant, sonner au portail vert'**
  String get instructionsHint;
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
