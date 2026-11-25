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
  /// **'Nouveau compte : vous lirez et accepterez les '**
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

  /// No description provided for @ordersSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Client, repère ou TR-…'**
  String get ordersSearchHint;

  /// No description provided for @ordersActiveTab.
  ///
  /// In fr, this message translates to:
  /// **'En cours · {count}'**
  String ordersActiveTab(int count);

  /// No description provided for @ordersSummaryActive.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Rien en cours} =1{1 en cours} other{{count} en cours}}{decide, plural, =0{} other{ · {decide} à décider}}'**
  String ordersSummaryActive(int count, int decide);

  /// No description provided for @ordersSummaryHistory.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune livraison terminée} =1{1 livraison terminée} other{{count} livraisons terminées}}'**
  String ordersSummaryHistory(int count);

  /// No description provided for @ordersNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucune livraison ne correspond à votre recherche.'**
  String get ordersNoMatch;

  /// No description provided for @ordersTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'demain'**
  String get ordersTomorrow;

  /// No description provided for @ordersReceiptOf.
  ///
  /// In fr, this message translates to:
  /// **'Reçu de {reference}'**
  String ordersReceiptOf(String reference);

  /// No description provided for @heroTonight.
  ///
  /// In fr, this message translates to:
  /// **'Ce soir à {hour} h'**
  String heroTonight(String hour);

  /// No description provided for @heroPaidOut.
  ///
  /// In fr, this message translates to:
  /// **'{amount} reversés'**
  String heroPaidOut(String amount);

  /// No description provided for @heroOnDemand.
  ///
  /// In fr, this message translates to:
  /// **'À votre demande'**
  String get heroOnDemand;

  /// No description provided for @heroToReceive.
  ///
  /// In fr, this message translates to:
  /// **'{amount} à recevoir'**
  String heroToReceive(String amount);

  /// No description provided for @whereToDeliver.
  ///
  /// In fr, this message translates to:
  /// **'Où livrer ?'**
  String get whereToDeliver;

  /// No description provided for @whereToDeliverHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom, numéro ou quartier du client'**
  String get whereToDeliverHint;

  /// No description provided for @quickBulk.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs colis'**
  String get quickBulk;

  /// No description provided for @quickAskAddress.
  ///
  /// In fr, this message translates to:
  /// **'Demander l’adresse'**
  String get quickAskAddress;

  /// No description provided for @quickReceipts.
  ///
  /// In fr, this message translates to:
  /// **'Mes reçus'**
  String get quickReceipts;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get seeAll;

  /// No description provided for @chipDecide.
  ///
  /// In fr, this message translates to:
  /// **'Décider'**
  String get chipDecide;

  /// No description provided for @chipPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get chipPay;

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

  /// No description provided for @profileSecurityValue.
  ///
  /// In fr, this message translates to:
  /// **'Code secret, empreinte'**
  String get profileSecurityValue;

  /// No description provided for @profileDisplayRow.
  ///
  /// In fr, this message translates to:
  /// **'Affichage et sons'**
  String get profileDisplayRow;

  /// No description provided for @profileTermsRow.
  ///
  /// In fr, this message translates to:
  /// **'Conditions et mes données'**
  String get profileTermsRow;

  /// No description provided for @profilePlanChip.
  ///
  /// In fr, this message translates to:
  /// **'Offre Pro'**
  String get profilePlanChip;

  /// No description provided for @profileReferShop.
  ///
  /// In fr, this message translates to:
  /// **'Parrainez une boutique'**
  String get profileReferShop;

  /// No description provided for @profileReferBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle profite d’une réduction sur ses premières livraisons.'**
  String get profileReferBody;

  /// No description provided for @profileShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get profileShare;

  /// No description provided for @profileSupportRow.
  ///
  /// In fr, this message translates to:
  /// **'Service client'**
  String get profileSupportRow;

  /// No description provided for @profileReferralShare.
  ///
  /// In fr, this message translates to:
  /// **'Livrez avec Tara à Douala : à l’inscription, entrez mon code {code} pour une réduction sur vos premières livraisons.'**
  String profileReferralShare(String code);

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

  /// No description provided for @glassLabel.
  ///
  /// In fr, this message translates to:
  /// **'Transparence des barres'**
  String get glassLabel;

  /// No description provided for @glassClear.
  ///
  /// In fr, this message translates to:
  /// **'Verre'**
  String get glassClear;

  /// No description provided for @glassBalanced.
  ///
  /// In fr, this message translates to:
  /// **'Équilibré'**
  String get glassBalanced;

  /// No description provided for @glassOpaque.
  ///
  /// In fr, this message translates to:
  /// **'Opaque'**
  String get glassOpaque;

  /// No description provided for @glassHint.
  ///
  /// In fr, this message translates to:
  /// **'Change la transparence de la barre du bas et des boutons posés en bas de l’écran.'**
  String get glassHint;

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
  /// **'Faites glisser la carte : l’épingle au centre marque l’entrée exacte. Le quartier s’affiche dès qu’elle est posée.'**
  String get pinHint;

  /// No description provided for @pinPlaced.
  ///
  /// In fr, this message translates to:
  /// **'Point placé'**
  String get pinPlaced;

  /// No description provided for @pinOutOfArea.
  ///
  /// In fr, this message translates to:
  /// **'Hors de la zone desservie'**
  String get pinOutOfArea;

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

  /// No description provided for @parcelPhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photographier le colis'**
  String get parcelPhotoTitle;

  /// No description provided for @parcelPhotoBody.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif · nous proposons la taille et la nature, vous vérifiez.'**
  String get parcelPhotoBody;

  /// No description provided for @parcelPhotoAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de la photo…'**
  String get parcelPhotoAnalyzing;

  /// No description provided for @parcelPhotoAnalyzingBody.
  ///
  /// In fr, this message translates to:
  /// **'Quelques secondes.'**
  String get parcelPhotoAnalyzingBody;

  /// No description provided for @parcelPhotoApplied.
  ///
  /// In fr, this message translates to:
  /// **'Proposition appliquée'**
  String get parcelPhotoApplied;

  /// No description provided for @parcelPhotoAppliedBody.
  ///
  /// In fr, this message translates to:
  /// **'{summary}. Vérifiez ci-dessous.'**
  String parcelPhotoAppliedBody(String summary);

  /// No description provided for @parcelPhotoNotParcel.
  ///
  /// In fr, this message translates to:
  /// **'Pas de colis reconnu'**
  String get parcelPhotoNotParcel;

  /// No description provided for @parcelPhotoNotParcelBody.
  ///
  /// In fr, this message translates to:
  /// **'Reprenez la photo en cadrant le colis seul.'**
  String get parcelPhotoNotParcelBody;

  /// No description provided for @parcelPhotoAttached.
  ///
  /// In fr, this message translates to:
  /// **'Photo jointe'**
  String get parcelPhotoAttached;

  /// No description provided for @parcelPhotoAttachedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur la verra. Choisissez la taille et la nature ci-dessous.'**
  String get parcelPhotoAttachedBody;

  /// No description provided for @parcelPhotoProhibited.
  ///
  /// In fr, this message translates to:
  /// **'La photo semble montrer : {items}. Ces objets sont interdits. Si c’est une erreur, vous pouvez continuer : l’équipe Tara et le livreur en seront informés.'**
  String parcelPhotoProhibited(String items);

  /// No description provided for @sizeShort.
  ///
  /// In fr, this message translates to:
  /// **'Taille {size}'**
  String sizeShort(String size);

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

  /// No description provided for @sizeBulky.
  ///
  /// In fr, this message translates to:
  /// **'Gros objet'**
  String get sizeBulky;

  /// No description provided for @sizeBulkyBody.
  ///
  /// In fr, this message translates to:
  /// **'Frigo, cuisinière, matelas, meuble · livré en tricycle'**
  String get sizeBulkyBody;

  /// No description provided for @sizeHelpBulky.
  ///
  /// In fr, this message translates to:
  /// **'Trop grand ou trop lourd pour une moto. Tarif tricycle, affiché avant de commander.'**
  String get sizeHelpBulky;

  /// No description provided for @loadingHelpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide pour charger'**
  String get loadingHelpTitle;

  /// No description provided for @loadingHelpBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur vient à deux. Supplément de manutention affiché avant de commander.'**
  String get loadingHelpBody;

  /// No description provided for @loadingHelpShort.
  ///
  /// In fr, this message translates to:
  /// **'chargement à deux'**
  String get loadingHelpShort;

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
  /// **'Le livreur encaisse ce montant à la livraison ; il rejoint vos ventes, moins 2 % de frais d’encaissement (250 F au moins), et vous est reversé sur votre Mobile Money.'**
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
  /// **'En FCFA. Jamais montrée au livreur. Fixe ce que Tara vous rembourse en cas de perte ou de dommage : gratuit jusqu’à 25 000 F, puis 1 % de la valeur au-delà.'**
  String get valueHelp;

  /// No description provided for @valueFeeHint.
  ///
  /// In fr, this message translates to:
  /// **'Garantie : +{amount} sur le prix de la livraison.'**
  String valueFeeHint(String amount);

  /// No description provided for @valueFeeLine.
  ///
  /// In fr, this message translates to:
  /// **'Garantie de la valeur'**
  String get valueFeeLine;

  /// No description provided for @valueTooHigh.
  ///
  /// In fr, this message translates to:
  /// **'500 000 F au plus. Pour un colis de plus grande valeur, appelez le service client avant d\'envoyer.'**
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

  /// No description provided for @soundsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sons'**
  String get soundsLabel;

  /// No description provided for @soundsHint.
  ///
  /// In fr, this message translates to:
  /// **'Commande envoyée, adresse reçue, colis livré… Le mode silencieux du téléphone est respecté.'**
  String get soundsHint;

  /// No description provided for @whenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quand le livreur doit-il passer ?'**
  String get whenTitle;

  /// No description provided for @whenBody.
  ///
  /// In fr, this message translates to:
  /// **'Il récupère le colis, puis le livre aussitôt.'**
  String get whenBody;

  /// No description provided for @whenNow.
  ///
  /// In fr, this message translates to:
  /// **'Maintenant'**
  String get whenNow;

  /// No description provided for @whenNowBody.
  ///
  /// In fr, this message translates to:
  /// **'Un livreur part dès que possible.'**
  String get whenNowBody;

  /// No description provided for @whenLater.
  ///
  /// In fr, this message translates to:
  /// **'Programmer'**
  String get whenLater;

  /// No description provided for @whenLaterBody.
  ///
  /// In fr, this message translates to:
  /// **'Un jour et une heure, jusqu’à 7 jours à l’avance.'**
  String get whenLaterBody;

  /// No description provided for @dayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get dayLabel;

  /// No description provided for @timeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Heure de passage'**
  String get timeLabel;

  /// No description provided for @dayToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get dayToday;

  /// No description provided for @dayTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get dayTomorrow;

  /// No description provided for @dateAt.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String dateAt(String date, String time);

  /// No description provided for @scheduledSummary.
  ///
  /// In fr, this message translates to:
  /// **'Enlèvement prévu {when}.'**
  String scheduledSummary(String when);

  /// No description provided for @nightSurcharge.
  ///
  /// In fr, this message translates to:
  /// **'Entre 20 h et 6 h, un supplément de nuit s’applique.'**
  String get nightSurcharge;

  /// No description provided for @slotRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une heure de passage.'**
  String get slotRequired;

  /// No description provided for @salesToday.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé aujourd’hui'**
  String get salesToday;

  /// No description provided for @salesDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune livraison} =1{1 livraison} other{{count} livraisons}}'**
  String salesDeliveries(int count);

  /// No description provided for @toReceiveDaily.
  ///
  /// In fr, this message translates to:
  /// **'{amount} à recevoir cette nuit'**
  String toReceiveDaily(String amount);

  /// No description provided for @toReceiveOnDemand.
  ///
  /// In fr, this message translates to:
  /// **'{amount} à recevoir'**
  String toReceiveOnDemand(String amount);

  /// No description provided for @payoutSent.
  ///
  /// In fr, this message translates to:
  /// **'{amount} envoyés sur votre Mobile Money'**
  String payoutSent(String amount);

  /// No description provided for @summaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez et commandez'**
  String get summaryTitle;

  /// No description provided for @summaryBody.
  ///
  /// In fr, this message translates to:
  /// **'Le prix est calculé pour ce trajet et cette heure.'**
  String get summaryBody;

  /// No description provided for @whenNowShort.
  ///
  /// In fr, this message translates to:
  /// **'Dès que possible'**
  String get whenNowShort;

  /// No description provided for @deliveryNumber.
  ///
  /// In fr, this message translates to:
  /// **'Colis n° {n}'**
  String deliveryNumber(int n);

  /// No description provided for @waitingPoint.
  ///
  /// In fr, this message translates to:
  /// **'En attente du point de {name}'**
  String waitingPoint(String name);

  /// No description provided for @removeDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get removeDelivery;

  /// No description provided for @addDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une livraison'**
  String get addDelivery;

  /// No description provided for @addDeliveryHint.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 10 colis depuis le même enlèvement : un seul code, un seul paiement. Chaque colis part avec un livreur adapté à sa taille.'**
  String get addDeliveryHint;

  /// No description provided for @priceBase.
  ///
  /// In fr, this message translates to:
  /// **'Course'**
  String get priceBase;

  /// No description provided for @mobileMoneyFeeLine.
  ///
  /// In fr, this message translates to:
  /// **'Frais Mobile Money'**
  String get mobileMoneyFeeLine;

  /// No description provided for @priceBaseTricycle.
  ///
  /// In fr, this message translates to:
  /// **'Course en tricycle'**
  String get priceBaseTricycle;

  /// No description provided for @surchargeExpress.
  ///
  /// In fr, this message translates to:
  /// **'Express'**
  String get surchargeExpress;

  /// No description provided for @surchargeHeavy.
  ///
  /// In fr, this message translates to:
  /// **'Colis XL'**
  String get surchargeHeavy;

  /// No description provided for @surchargeHandling.
  ///
  /// In fr, this message translates to:
  /// **'Manutention (chargement à deux)'**
  String get surchargeHandling;

  /// No description provided for @surchargeNight.
  ///
  /// In fr, this message translates to:
  /// **'Supplément de nuit'**
  String get surchargeNight;

  /// No description provided for @surchargeWeather.
  ///
  /// In fr, this message translates to:
  /// **'Supplément météo'**
  String get surchargeWeather;

  /// No description provided for @surchargeOther.
  ///
  /// In fr, this message translates to:
  /// **'Supplément'**
  String get surchargeOther;

  /// No description provided for @discount.
  ///
  /// In fr, this message translates to:
  /// **'Réduction'**
  String get discount;

  /// Ligne du récapitulatif : remise du tarif pro des boutiques.
  ///
  /// In fr, this message translates to:
  /// **'Tarif pro ({percent})'**
  String proDiscountLine(String percent);

  /// No description provided for @promoBeatenByPro.
  ///
  /// In fr, this message translates to:
  /// **'Votre tarif pro (−{percent}) est plus avantageux : ce code n’est pas utilisé.'**
  String promoBeatenByPro(String percent);

  /// No description provided for @totalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @quoting.
  ///
  /// In fr, this message translates to:
  /// **'Calcul du prix…'**
  String get quoting;

  /// No description provided for @promoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code promo'**
  String get promoLabel;

  /// No description provided for @promoHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. BIENVENUE'**
  String get promoHint;

  /// No description provided for @applyPromo.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get applyPromo;

  /// No description provided for @promoApplied.
  ///
  /// In fr, this message translates to:
  /// **'Code {code} appliqué'**
  String promoApplied(String code);

  /// No description provided for @whoPays.
  ///
  /// In fr, this message translates to:
  /// **'Qui paie la course ?'**
  String get whoPays;

  /// No description provided for @payerMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get payerMe;

  /// No description provided for @payerRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire'**
  String get payerRecipient;

  /// No description provided for @recipientPaysBody.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire paie la course à la livraison, en espèces ou par Mobile Money.'**
  String get recipientPaysBody;

  /// No description provided for @paymentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement'**
  String get paymentLabel;

  /// No description provided for @payMtn.
  ///
  /// In fr, this message translates to:
  /// **'MTN Mobile Money'**
  String get payMtn;

  /// No description provided for @payOrange.
  ///
  /// In fr, this message translates to:
  /// **'Orange Money'**
  String get payOrange;

  /// No description provided for @payMomoBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous validez le paiement sur votre téléphone.'**
  String get payMomoBody;

  /// No description provided for @payWallet.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara'**
  String get payWallet;

  /// No description provided for @payWalletShop.
  ///
  /// In fr, this message translates to:
  /// **'Mes ventes'**
  String get payWalletShop;

  /// No description provided for @payWalletBody.
  ///
  /// In fr, this message translates to:
  /// **'Disponible : {amount}'**
  String payWalletBody(String amount);

  /// No description provided for @walletTooLow.
  ///
  /// In fr, this message translates to:
  /// **'Disponible : {amount}, pas assez pour cette commande.'**
  String walletTooLow(String amount);

  /// No description provided for @payCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces à l’enlèvement'**
  String get payCash;

  /// No description provided for @payCashBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous payez le livreur quand il récupère le colis.'**
  String get payCashBody;

  /// No description provided for @payerPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro qui paie'**
  String get payerPhoneLabel;

  /// No description provided for @orderFor.
  ///
  /// In fr, this message translates to:
  /// **'Commander · {amount}'**
  String orderFor(String amount);

  /// No description provided for @orderSlide.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour commander'**
  String get orderSlide;

  /// No description provided for @paymentRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez comment payer.'**
  String get paymentRequired;

  /// No description provided for @linkPendingBlock.
  ///
  /// In fr, this message translates to:
  /// **'Attendez que {name} place son point, ou placez-le vous-même.'**
  String linkPendingBlock(String name);

  /// No description provided for @payingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Validez le paiement sur votre téléphone'**
  String get payingTitle;

  /// No description provided for @payingBody.
  ///
  /// In fr, this message translates to:
  /// **'Une demande de {amount} arrive sur le {phone} : entrez votre code secret Mobile Money pour la valider.'**
  String payingBody(String amount, String phone);

  /// No description provided for @paymentFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement n’a pas abouti.'**
  String get paymentFailed;

  /// No description provided for @retryPayment.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer la demande'**
  String get retryPayment;

  /// No description provided for @cancelOrder.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get cancelOrder;

  /// No description provided for @cancelReasonUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'Paiement Mobile Money non abouti'**
  String get cancelReasonUnpaid;

  /// No description provided for @placedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commande envoyée !'**
  String get placedTitle;

  /// No description provided for @placedScheduledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison programmée !'**
  String get placedScheduledTitle;

  /// No description provided for @pickupCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code d’enlèvement'**
  String get pickupCodeLabel;

  /// No description provided for @pickupCodeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Donnez-le au livreur quand il récupère le colis. Notez-le : il ne sera plus affiché.'**
  String get pickupCodeHelp;

  /// No description provided for @searchingRider.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d’un livreur…'**
  String get searchingRider;

  /// No description provided for @riderFound.
  ///
  /// In fr, this message translates to:
  /// **'Livreur trouvé ! Il vient chercher le colis.'**
  String get riderFound;

  /// No description provided for @scheduledPickup.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur passera {when}.'**
  String scheduledPickup(String when);

  /// No description provided for @backHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l’accueil'**
  String get backHome;

  /// No description provided for @payWalletShopBody.
  ///
  /// In fr, this message translates to:
  /// **'Pris sur vos ventes : il vous restera {amount} à recevoir.'**
  String payWalletShopBody(String amount);

  /// No description provided for @trackAwaitingPayment.
  ///
  /// In fr, this message translates to:
  /// **'En attente du paiement'**
  String get trackAwaitingPayment;

  /// No description provided for @trackAwaitingPaymentBody.
  ///
  /// In fr, this message translates to:
  /// **'Validez le paiement Mobile Money pour lancer la recherche d’un livreur.'**
  String get trackAwaitingPaymentBody;

  /// No description provided for @trackScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Livraison programmée'**
  String get trackScheduled;

  /// No description provided for @trackSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d’un livreur…'**
  String get trackSearching;

  /// No description provided for @trackSearchingBody.
  ///
  /// In fr, this message translates to:
  /// **'Les livreurs proches de l’enlèvement reçoivent la course.'**
  String get trackSearchingBody;

  /// No description provided for @trackAssigned.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vient chercher le colis'**
  String trackAssigned(String rider);

  /// No description provided for @trackAssignedBody.
  ///
  /// In fr, this message translates to:
  /// **'Donnez-lui le code d’enlèvement à son arrivée.'**
  String get trackAssignedBody;

  /// No description provided for @trackSenderAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur est reparti'**
  String get trackSenderAbsent;

  /// No description provided for @trackSenderAbsentBody.
  ///
  /// In fr, this message translates to:
  /// **'Il vous a attendu {minutes} min et vous a appelé. La course est annulée ; annulation et attente vous sont facturées : {fee}.'**
  String trackSenderAbsentBody(int minutes, String fee);

  /// No description provided for @trackRiderWaiting.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vous attend'**
  String trackRiderWaiting(String rider);

  /// No description provided for @trackRiderWaitingBody.
  ///
  /// In fr, this message translates to:
  /// **'Donnez-lui le colis et le code d’enlèvement. Attente gratuite jusqu’à {until}, puis {fee} par {step} min commencées, {max} au plus.'**
  String trackRiderWaitingBody(String until, String fee, int step, String max);

  /// No description provided for @trackOnTheWay.
  ///
  /// In fr, this message translates to:
  /// **'En route vers {recipient}'**
  String trackOnTheWay(String recipient);

  /// No description provided for @trackOnTheWayBody.
  ///
  /// In fr, this message translates to:
  /// **'Colis récupéré à {time}.'**
  String trackOnTheWayBody(String time);

  /// No description provided for @trackFailed.
  ///
  /// In fr, this message translates to:
  /// **'Livraison impossible'**
  String get trackFailed;

  /// No description provided for @trackFailedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur n’a pas pu livrer. Choisissez la suite : nouvelle tentative ou retour.'**
  String get trackFailedBody;

  /// No description provided for @trackDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Colis livré !'**
  String get trackDelivered;

  /// No description provided for @trackDeliveredBody.
  ///
  /// In fr, this message translates to:
  /// **'Remis à {recipient} à {time}.'**
  String trackDeliveredBody(String recipient, String time);

  /// No description provided for @trackReturned.
  ///
  /// In fr, this message translates to:
  /// **'Colis retourné'**
  String get trackReturned;

  /// No description provided for @trackCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Livraison annulée'**
  String get trackCancelled;

  /// No description provided for @trackRefused.
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé à l’enlèvement'**
  String get trackRefused;

  /// No description provided for @trackRefusedBody.
  ///
  /// In fr, this message translates to:
  /// **'{reason}. La commande est annulée ; le déplacement du livreur ({fee}) est à votre charge. Un désaccord ? Appelez le service client.'**
  String trackRefusedBody(String reason, String fee);

  /// No description provided for @trackEta.
  ///
  /// In fr, this message translates to:
  /// **'Environ {minutes} min'**
  String trackEta(int minutes);

  /// No description provided for @stepOrdered.
  ///
  /// In fr, this message translates to:
  /// **'Commande'**
  String get stepOrdered;

  /// No description provided for @stepRiderFound.
  ///
  /// In fr, this message translates to:
  /// **'Livreur'**
  String get stepRiderFound;

  /// No description provided for @stepPickedUp.
  ///
  /// In fr, this message translates to:
  /// **'Récupéré'**
  String get stepPickedUp;

  /// No description provided for @stepDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get stepDelivered;

  /// No description provided for @vehicleMotorbike.
  ///
  /// In fr, this message translates to:
  /// **'Moto'**
  String get vehicleMotorbike;

  /// No description provided for @vehicleTricycle.
  ///
  /// In fr, this message translates to:
  /// **'Tricycle'**
  String get vehicleTricycle;

  /// No description provided for @vehicleCar.
  ///
  /// In fr, this message translates to:
  /// **'Voiture'**
  String get vehicleCar;

  /// No description provided for @callRider.
  ///
  /// In fr, this message translates to:
  /// **'Appeler {name}'**
  String callRider(String name);

  /// No description provided for @forRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Pour {name}'**
  String forRecipient(String name);

  /// No description provided for @newPickupCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code d’enlèvement'**
  String get newPickupCode;

  /// No description provided for @pickupCodeShown.
  ///
  /// In fr, this message translates to:
  /// **'Code d’enlèvement : {code}'**
  String pickupCodeShown(String code);

  /// No description provided for @cancelDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la livraison'**
  String get cancelDelivery;

  /// No description provided for @cancelConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Touchez encore pour confirmer l’annulation.'**
  String get cancelConfirm;

  /// No description provided for @cancelConfirmFee.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur est déjà en route : annuler coûte {amount}, pour son déplacement. Touchez encore pour confirmer.'**
  String cancelConfirmFee(String amount);

  /// No description provided for @cancelReasonSender.
  ///
  /// In fr, this message translates to:
  /// **'Annulée par l’expéditeur'**
  String get cancelReasonSender;

  /// No description provided for @deliveredBy.
  ///
  /// In fr, this message translates to:
  /// **'Livré par {rider}'**
  String deliveredBy(String rider);

  /// No description provided for @deliveredIn.
  ///
  /// In fr, this message translates to:
  /// **'en {minutes} min'**
  String deliveredIn(int minutes);

  /// No description provided for @collectedAmount.
  ///
  /// In fr, this message translates to:
  /// **'{amount} encaissés'**
  String collectedAmount(String amount);

  /// No description provided for @shareRecap.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get shareRecap;

  /// No description provided for @recapShareText.
  ///
  /// In fr, this message translates to:
  /// **'Colis livré par Tara · {reference} · {recipient} · {time}'**
  String recapShareText(String reference, String recipient, String time);

  /// No description provided for @trackOrderError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le suivi.'**
  String get trackOrderError;

  /// No description provided for @trackDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Suivre la livraison'**
  String get trackDelivery;

  /// No description provided for @statusRetrying.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative en cours'**
  String get statusRetrying;

  /// No description provided for @statusReturning.
  ///
  /// In fr, this message translates to:
  /// **'Retour en cours'**
  String get statusReturning;

  /// No description provided for @failureReasonRecipientAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire absent'**
  String get failureReasonRecipientAbsent;

  /// No description provided for @failureReasonRecipientUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire injoignable'**
  String get failureReasonRecipientUnreachable;

  /// No description provided for @failureReasonRefused.
  ///
  /// In fr, this message translates to:
  /// **'Colis refusé par le destinataire'**
  String get failureReasonRefused;

  /// No description provided for @failureReasonAddressNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse introuvable'**
  String get failureReasonAddressNotFound;

  /// No description provided for @failureReasonPaymentRefused.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire a refusé de payer'**
  String get failureReasonPaymentRefused;

  /// No description provided for @failureReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre motif'**
  String get failureReasonOther;

  /// No description provided for @failureReported.
  ///
  /// In fr, this message translates to:
  /// **'{reason} · signalé par {rider} à {time}'**
  String failureReported(String reason, String rider, String time);

  /// No description provided for @failureDue.
  ///
  /// In fr, this message translates to:
  /// **'Avant {time}'**
  String failureDue(String time);

  /// No description provided for @failureDueBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse d’ici là, le colis vous est rapporté.'**
  String get failureDueBody;

  /// No description provided for @failureRetryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative'**
  String get failureRetryTitle;

  /// No description provided for @failureRetryBody.
  ///
  /// In fr, this message translates to:
  /// **'{rider} repasse chez {recipient}. Appelez d’abord pour convenir du moment.'**
  String failureRetryBody(String rider, String recipient);

  /// No description provided for @failureReturnTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retour du colis'**
  String get failureReturnTitle;

  /// No description provided for @failureReturnBody.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vous rapporte le colis : {place}.'**
  String failureReturnBody(String rider, String place);

  /// No description provided for @failureChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une option'**
  String get failureChoose;

  /// No description provided for @failureConfirmRetry.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la tentative'**
  String get failureConfirmRetry;

  /// No description provided for @failureConfirmReturn.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retour'**
  String get failureConfirmReturn;

  /// No description provided for @failureConfirmRetrySemantics.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour demander une nouvelle tentative'**
  String get failureConfirmRetrySemantics;

  /// No description provided for @failureConfirmReturnSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour demander le retour du colis'**
  String get failureConfirmReturnSemantics;

  /// No description provided for @callRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Appeler {name}'**
  String callRecipient(String name);

  /// No description provided for @trackRetrying.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative'**
  String get trackRetrying;

  /// No description provided for @trackRetryingBody.
  ///
  /// In fr, this message translates to:
  /// **'{rider} repart livrer {recipient}.'**
  String trackRetryingBody(String rider, String recipient);

  /// No description provided for @trackReturning.
  ///
  /// In fr, this message translates to:
  /// **'Retour du colis'**
  String get trackReturning;

  /// No description provided for @trackReturningBody.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vous rapporte le colis.'**
  String trackReturningBody(String rider);

  /// No description provided for @returnCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Quand le livreur vous rend le colis, donnez-lui le code de retour reçu par SMS : c’est la preuve que vous l’avez récupéré.'**
  String get returnCodeHint;

  /// No description provided for @newReturnCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code de retour'**
  String get newReturnCode;

  /// No description provided for @returnCodeShown.
  ///
  /// In fr, this message translates to:
  /// **'Code de retour : {code}'**
  String returnCodeShown(String code);

  /// No description provided for @trackReturnedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le colis vous a été rendu à {time}.'**
  String trackReturnedBody(String time);

  /// No description provided for @stepFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get stepFailed;

  /// No description provided for @stepReturned.
  ///
  /// In fr, this message translates to:
  /// **'Retourné'**
  String get stepReturned;

  /// No description provided for @riderNoteQuoted.
  ///
  /// In fr, this message translates to:
  /// **'« {note} »'**
  String riderNoteQuoted(String note);

  /// No description provided for @returnToPickup.
  ///
  /// In fr, this message translates to:
  /// **'Retour au point d’enlèvement'**
  String get returnToPickup;

  /// No description provided for @failureBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison impossible · {reference}'**
  String failureBannerTitle(String reference);

  /// No description provided for @failureBannerBody.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour choisir : nouvelle tentative ou retour.'**
  String get failureBannerBody;

  /// No description provided for @rateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comment s’est passée la livraison ?'**
  String get rateTitle;

  /// No description provided for @rateBody.
  ///
  /// In fr, this message translates to:
  /// **'Notez {rider} : les livreurs les mieux notés reçoivent plus de courses.'**
  String rateBody(String rider);

  /// No description provided for @starsLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 étoile} other{{count} étoiles}}'**
  String starsLabel(int count);

  /// No description provided for @starWord1.
  ///
  /// In fr, this message translates to:
  /// **'Très décevant'**
  String get starWord1;

  /// No description provided for @starWord2.
  ///
  /// In fr, this message translates to:
  /// **'Décevant'**
  String get starWord2;

  /// No description provided for @starWord3.
  ///
  /// In fr, this message translates to:
  /// **'Correct'**
  String get starWord3;

  /// No description provided for @starWord4.
  ///
  /// In fr, this message translates to:
  /// **'Bien'**
  String get starWord4;

  /// No description provided for @starWord5.
  ///
  /// In fr, this message translates to:
  /// **'Parfait !'**
  String get starWord5;

  /// No description provided for @rateCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Un mot pour l’équipe Tara (facultatif)'**
  String get rateCommentHint;

  /// No description provided for @rateSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma note'**
  String get rateSend;

  /// No description provided for @rateThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre note !'**
  String get rateThanks;

  /// No description provided for @rateThanksBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis reste entre vous et Tara.'**
  String get rateThanksBody;

  /// No description provided for @failureFeesNote.
  ///
  /// In fr, this message translates to:
  /// **'En cas d’échec de livraison : nouvelle tentative {retry}, retour du colis {ret}, à votre charge. Le colis retourné vous est rendu contre paiement de ce que votre solde Tara ne couvre pas.'**
  String failureFeesNote(String retry, String ret);

  /// No description provided for @refusalFeeNote.
  ///
  /// In fr, this message translates to:
  /// **'Colis différent de ce que vous déclarez (trop grand, trop lourd, interdit) : le livreur peut le refuser, et son déplacement ({fee}) reste à votre charge.'**
  String refusalFeeNote(String fee);

  /// No description provided for @retryUsed.
  ///
  /// In fr, this message translates to:
  /// **'Une seule nouvelle tentative est possible : le colis vous sera rapporté.'**
  String get retryUsed;

  /// No description provided for @returnFeeHint.
  ///
  /// In fr, this message translates to:
  /// **'Frais de retour : {amount}, pris sur votre solde Tara. S’il ne suffit pas, vous réglez le reste au livreur à la remise du colis (espèces ou Mobile Money).'**
  String returnFeeHint(String amount);

  /// No description provided for @topUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechargez {amount} pour la nouvelle tentative'**
  String topUpTitle(String amount);

  /// No description provided for @topUpBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre solde Tara ne couvre pas les frais. Payez par Mobile Money : la nouvelle tentative est confirmée dès le paiement validé.'**
  String get topUpBody;

  /// No description provided for @topUpPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount}'**
  String topUpPay(String amount);

  /// No description provided for @topUpPending.
  ///
  /// In fr, this message translates to:
  /// **'Validez le paiement de {amount} sur votre téléphone avec votre code secret Mobile Money.'**
  String topUpPending(String amount);

  /// No description provided for @topUpFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement n’a pas abouti. Réessayez, ou choisissez le retour du colis.'**
  String get topUpFailed;

  /// No description provided for @topUpCancel.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le retour à la place'**
  String get topUpCancel;

  /// No description provided for @termsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d’utilisation'**
  String get termsTitle;

  /// No description provided for @termsUpdateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nos conditions ont changé'**
  String get termsUpdateTitle;

  /// No description provided for @termsSignupIntro.
  ///
  /// In fr, this message translates to:
  /// **'Avant de créer votre compte, lisez les conditions et la politique de confidentialité jusqu’en bas. Elles expliquent les prix, les frais quand une livraison échoue et ce que nous faisons de vos données.'**
  String get termsSignupIntro;

  /// No description provided for @termsUpdateIntro.
  ///
  /// In fr, this message translates to:
  /// **'Lisez la nouvelle version jusqu’en bas, puis acceptez-la. Sans acceptation, vous suivez vos livraisons en cours mais ne pouvez plus en commander de nouvelles.'**
  String get termsUpdateIntro;

  /// No description provided for @termsLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get termsLater;

  /// No description provided for @termsEnd.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes arrivé au bout des textes.'**
  String get termsEnd;

  /// No description provided for @termsScrollFirst.
  ///
  /// In fr, this message translates to:
  /// **'Faites défiler les textes jusqu’en bas pour pouvoir les accepter.'**
  String get termsScrollFirst;

  /// No description provided for @termsCheckPrefix.
  ///
  /// In fr, this message translates to:
  /// **'J’ai lu et j’accepte les '**
  String get termsCheckPrefix;

  /// No description provided for @termsCheckTerms.
  ///
  /// In fr, this message translates to:
  /// **'conditions d’utilisation (version {version})'**
  String termsCheckTerms(String version);

  /// No description provided for @termsCheckAnd.
  ///
  /// In fr, this message translates to:
  /// **' et la '**
  String get termsCheckAnd;

  /// No description provided for @termsCheckPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'politique de confidentialité'**
  String get termsCheckPrivacy;

  /// No description provided for @termsCreateAccount.
  ///
  /// In fr, this message translates to:
  /// **'Accepter et créer mon compte'**
  String get termsCreateAccount;

  /// No description provided for @termsAcceptUpdate.
  ///
  /// In fr, this message translates to:
  /// **'J’accepte la nouvelle version'**
  String get termsAcceptUpdate;

  /// No description provided for @termsAcceptedOn.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} acceptée le {date}'**
  String termsAcceptedOn(String version, String date);

  /// No description provided for @termsVersionLine.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String termsVersionLine(String version);

  /// No description provided for @termsSection.
  ///
  /// In fr, this message translates to:
  /// **'Conditions et confidentialité'**
  String get termsSection;

  /// No description provided for @termsToSign.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle version à lire et accepter'**
  String get termsToSign;

  /// No description provided for @termsSigned.
  ///
  /// In fr, this message translates to:
  /// **'Conditions acceptées. Merci !'**
  String get termsSigned;

  /// No description provided for @termsPrivacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get termsPrivacyTitle;

  /// No description provided for @walletTitle.
  ///
  /// In fr, this message translates to:
  /// **'Portefeuille'**
  String get walletTitle;

  /// No description provided for @shopToReceive.
  ///
  /// In fr, this message translates to:
  /// **'Ventes à recevoir'**
  String get shopToReceive;

  /// No description provided for @shopPayoutWaitsMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money n’envoie pas moins de {min} : vos ventes restent sur votre solde et partent le soir où elles atteignent ce montant.'**
  String shopPayoutWaitsMinimum(String min);

  /// No description provided for @shopPayoutFromMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Reversement possible à partir de {min} (minimum de Mobile Money).'**
  String shopPayoutFromMinimum(String min);

  /// No description provided for @taraWithdrawFromMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Retrait vers Mobile Money possible à partir de {min}. En attendant, ce solde paie vos livraisons.'**
  String taraWithdrawFromMinimum(String min);

  /// No description provided for @deleteAccountSmallBalance.
  ///
  /// In fr, this message translates to:
  /// **'Il vous reste {amount} chez Tara, moins que le plus petit envoi Mobile Money ({min}). Utilisez-les pour vos livraisons, ou appelez le service client de Tara.'**
  String deleteAccountSmallBalance(String amount, String min);

  /// No description provided for @shopPayoutDaily.
  ///
  /// In fr, this message translates to:
  /// **'Reversées chaque jour à {hour} h sur le {phone}.'**
  String shopPayoutDaily(String hour, String phone);

  /// No description provided for @shopPayoutOnDemand.
  ///
  /// In fr, this message translates to:
  /// **'Reversées à votre demande sur le {phone}.'**
  String shopPayoutOnDemand(String phone);

  /// No description provided for @shopToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui : {amount} encaissés · {count, plural, =0{aucune livraison} =1{1 livraison} other{{count} livraisons}}'**
  String shopToday(String amount, int count);

  /// No description provided for @shopWithdrawalRule.
  ///
  /// In fr, this message translates to:
  /// **'Reversement et retrait gratuits dès {amount} ; en dessous, {rate} de frais Mobile Money retenus.'**
  String shopWithdrawalRule(String amount, String rate);

  /// No description provided for @shopDebt.
  ///
  /// In fr, this message translates to:
  /// **'Frais d’échec à régler : {amount}. Ils seront pris sur vos prochaines ventes ; au-delà de 3 000 F, vos nouvelles commandes attendent le règlement.'**
  String shopDebt(String amount);

  /// No description provided for @payoutOpen.
  ///
  /// In fr, this message translates to:
  /// **'Reversement en cours : {amount}'**
  String payoutOpen(String amount);

  /// No description provided for @payoutNow.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir {amount} maintenant'**
  String payoutNow(String amount);

  /// No description provided for @payoutRequested.
  ///
  /// In fr, this message translates to:
  /// **'Reversement demandé : l’argent arrive sur votre Mobile Money.'**
  String get payoutRequested;

  /// No description provided for @taraBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara'**
  String get taraBalance;

  /// No description provided for @taraBalanceBody.
  ///
  /// In fr, this message translates to:
  /// **'Sert à payer vos livraisons et, s’il y en a, les frais d’échec.'**
  String get taraBalanceBody;

  /// No description provided for @topUpAction.
  ///
  /// In fr, this message translates to:
  /// **'Recharger'**
  String get topUpAction;

  /// No description provided for @withdrawAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get withdrawAction;

  /// No description provided for @topUpWithdrawRule.
  ///
  /// In fr, this message translates to:
  /// **'Ce solde paie vos livraisons. Il se retire vers Mobile Money à partir de {min}.'**
  String topUpWithdrawRule(String min);

  /// No description provided for @topUpHowMuch.
  ///
  /// In fr, this message translates to:
  /// **'Combien voulez-vous ajouter ?'**
  String get topUpHowMuch;

  /// No description provided for @topUpFeeNote.
  ///
  /// In fr, this message translates to:
  /// **'+ {fee} de frais Mobile Money (frais de l’opérateur).'**
  String topUpFeeNote(String fee);

  /// No description provided for @topUpDone.
  ///
  /// In fr, this message translates to:
  /// **'Solde rechargé de {amount}.'**
  String topUpDone(String amount);

  /// No description provided for @withdrawBody.
  ///
  /// In fr, this message translates to:
  /// **'Tout votre solde ({amount}) part sur votre numéro {phone}.'**
  String withdrawBody(String amount, String phone);

  /// No description provided for @withdrawConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {amount}'**
  String withdrawConfirm(String amount);

  /// No description provided for @withdrawDone.
  ///
  /// In fr, this message translates to:
  /// **'Retrait demandé : l’argent arrive sur votre Mobile Money.'**
  String get withdrawDone;

  /// No description provided for @movements.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements'**
  String get movements;

  /// No description provided for @walletSalesFront.
  ///
  /// In fr, this message translates to:
  /// **'Ventes à recevoir, au premier plan'**
  String get walletSalesFront;

  /// No description provided for @walletSalesShow.
  ///
  /// In fr, this message translates to:
  /// **'Mettre les ventes à recevoir au premier plan'**
  String get walletSalesShow;

  /// No description provided for @walletTaraFront.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara, au premier plan'**
  String get walletTaraFront;

  /// No description provided for @walletTaraShow.
  ///
  /// In fr, this message translates to:
  /// **'Mettre le Solde Tara au premier plan'**
  String get walletTaraShow;

  /// No description provided for @walletReceive.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir'**
  String get walletReceive;

  /// No description provided for @walletReserve.
  ///
  /// In fr, this message translates to:
  /// **'Réserve'**
  String get walletReserve;

  /// No description provided for @walletStatement.
  ///
  /// In fr, this message translates to:
  /// **'Relevé'**
  String get walletStatement;

  /// No description provided for @walletStatements.
  ///
  /// In fr, this message translates to:
  /// **'Relevés du mois'**
  String get walletStatements;

  /// No description provided for @shopTodayChip.
  ///
  /// In fr, this message translates to:
  /// **'+{amount} aujourd’hui'**
  String shopTodayChip(String amount);

  /// No description provided for @shopPayoutTonight.
  ///
  /// In fr, this message translates to:
  /// **'Reversées ce soir à {hour} h'**
  String shopPayoutTonight(String hour);

  /// No description provided for @shopPayoutWhenAsked.
  ///
  /// In fr, this message translates to:
  /// **'Reversées à votre demande'**
  String get shopPayoutWhenAsked;

  /// No description provided for @taraCardLine.
  ///
  /// In fr, this message translates to:
  /// **'Paie vos livraisons'**
  String get taraCardLine;

  /// No description provided for @taraCardShopLine.
  ///
  /// In fr, this message translates to:
  /// **'Paie vos livraisons en premier'**
  String get taraCardShopLine;

  /// No description provided for @taraCardWithdrawFrom.
  ///
  /// In fr, this message translates to:
  /// **'retrait dès {amount}'**
  String taraCardWithdrawFrom(String amount);

  /// No description provided for @movementsShop.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get movementsShop;

  /// No description provided for @movementsBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara'**
  String get movementsBalance;

  /// No description provided for @movementsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement pour l’instant.'**
  String get movementsEmpty;

  /// No description provided for @seeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get seeMore;

  /// No description provided for @lineCodCollected.
  ///
  /// In fr, this message translates to:
  /// **'Vente encaissée'**
  String get lineCodCollected;

  /// No description provided for @lineOrderCharged.
  ///
  /// In fr, this message translates to:
  /// **'Livraison payée'**
  String get lineOrderCharged;

  /// No description provided for @lineOrderReleased.
  ///
  /// In fr, this message translates to:
  /// **'Frais rendus (annulation)'**
  String get lineOrderReleased;

  /// No description provided for @lineFailureFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais d’échec'**
  String get lineFailureFee;

  /// No description provided for @lineCredit.
  ///
  /// In fr, this message translates to:
  /// **'Avoir de Tara'**
  String get lineCredit;

  /// No description provided for @lineTopUp.
  ///
  /// In fr, this message translates to:
  /// **'Recharge'**
  String get lineTopUp;

  /// No description provided for @lineReserve.
  ///
  /// In fr, this message translates to:
  /// **'Réserve pour vos livraisons'**
  String get lineReserve;

  /// No description provided for @lineCancellationFee.
  ///
  /// In fr, this message translates to:
  /// **'Annulation, livreur en route'**
  String get lineCancellationFee;

  /// No description provided for @lineWaitingFee.
  ///
  /// In fr, this message translates to:
  /// **'Attente du livreur'**
  String get lineWaitingFee;

  /// No description provided for @linePayout.
  ///
  /// In fr, this message translates to:
  /// **'Reversement'**
  String get linePayout;

  /// No description provided for @lineWithdrawal.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get lineWithdrawal;

  /// No description provided for @linePayoutFailed.
  ///
  /// In fr, this message translates to:
  /// **'Reversement échoué, montant rendu'**
  String get linePayoutFailed;

  /// No description provided for @lineRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get lineRefund;

  /// No description provided for @payoutsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reversements'**
  String get payoutsTitle;

  /// No description provided for @payoutStatusDone.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get payoutStatusDone;

  /// No description provided for @payoutStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get payoutStatusOpen;

  /// No description provided for @payoutStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué, montant rendu'**
  String get payoutStatusFailed;

  /// No description provided for @statementsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relevés mensuels'**
  String get statementsTitle;

  /// No description provided for @statementsBody.
  ///
  /// In fr, this message translates to:
  /// **'Le relevé PDF de chaque mois : encaissements, frais, reversements, soldes.'**
  String get statementsBody;

  /// No description provided for @statementCurrent.
  ///
  /// In fr, this message translates to:
  /// **'{month} (en cours)'**
  String statementCurrent(String month);

  /// No description provided for @statementShare.
  ///
  /// In fr, this message translates to:
  /// **'Relevé Tara de {month}'**
  String statementShare(String month);

  /// No description provided for @walletBalanceTile.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara : {amount}'**
  String walletBalanceTile(String amount);

  /// No description provided for @askTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demander l’adresse'**
  String get askTitle;

  /// No description provided for @askIntro.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez un lien à votre client : il place lui-même son point et écrit un repère. Vous êtes prévenu dès que c’est fait, et la livraison se crée avec son adresse.'**
  String get askIntro;

  /// No description provided for @askSendWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer par WhatsApp'**
  String get askSendWhatsapp;

  /// No description provided for @askSendSms.
  ///
  /// In fr, this message translates to:
  /// **'Par SMS'**
  String get askSendSms;

  /// No description provided for @askSent.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé à {name}. Vous serez prévenu dès qu’il aura placé son point.'**
  String askSent(String name);

  /// No description provided for @askRequested.
  ///
  /// In fr, this message translates to:
  /// **'Adresses demandées'**
  String get askRequested;

  /// No description provided for @askNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse demandée pour l’instant.'**
  String get askNone;

  /// No description provided for @askPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente · lien valable jusqu’au {date}'**
  String askPending(String date);

  /// No description provided for @askReceived.
  ///
  /// In fr, this message translates to:
  /// **'Point reçu · {landmark}'**
  String askReceived(String landmark);

  /// No description provided for @askExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expiré sans réponse'**
  String get askExpired;

  /// No description provided for @askCreateOrder.
  ///
  /// In fr, this message translates to:
  /// **'Créer la livraison'**
  String get askCreateOrder;

  /// No description provided for @askResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get askResend;

  /// No description provided for @askArrived.
  ///
  /// In fr, this message translates to:
  /// **'{name} a placé son point : vous pouvez créer la livraison.'**
  String askArrived(String name);

  /// No description provided for @myAddresses.
  ///
  /// In fr, this message translates to:
  /// **'Mes adresses'**
  String get myAddresses;

  /// No description provided for @myAddressesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez votre boutique ou votre maison : elles vous seront proposées pour l’enlèvement.'**
  String get myAddressesEmpty;

  /// No description provided for @addAddress.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une adresse'**
  String get addAddress;

  /// No description provided for @newAddressTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle adresse'**
  String get newAddressTitle;

  /// No description provided for @removeAddress.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {label}'**
  String removeAddress(String label);

  /// No description provided for @removeAddressConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer « {label} » de vos adresses ? Les livraisons passées ne changent pas.'**
  String removeAddressConfirm(String label);

  /// No description provided for @removeYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui, retirer'**
  String get removeYes;

  /// No description provided for @mediaSection.
  ///
  /// In fr, this message translates to:
  /// **'Pour aider le livreur (facultatif)'**
  String get mediaSection;

  /// No description provided for @facadePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la façade'**
  String get facadePhoto;

  /// No description provided for @facadePhotoHint.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur reconnaît l’entrée au premier coup d’œil.'**
  String get facadePhotoHint;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre la photo'**
  String get takePhoto;

  /// No description provided for @retake.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get retake;

  /// No description provided for @removeMedia.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get removeMedia;

  /// No description provided for @voiceNote.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale'**
  String get voiceNote;

  /// No description provided for @voiceNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'30 secondes pour expliquer le chemin, dans la langue de votre choix.'**
  String get voiceNoteHint;

  /// No description provided for @recordNote.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get recordNote;

  /// No description provided for @recordingNote.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement… {elapsed} / 0:30'**
  String recordingNote(String elapsed);

  /// No description provided for @stopRecording.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get stopRecording;

  /// No description provided for @listenNote.
  ///
  /// In fr, this message translates to:
  /// **'Écouter ({length})'**
  String listenNote(String length);

  /// No description provided for @stopListening.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter l’écoute'**
  String get stopListening;

  /// No description provided for @redoNote.
  ///
  /// In fr, this message translates to:
  /// **'Refaire'**
  String get redoNote;

  /// No description provided for @micDenied.
  ///
  /// In fr, this message translates to:
  /// **'Micro refusé : autorisez-le pour Tara dans les réglages du téléphone.'**
  String get micDenied;

  /// No description provided for @facadePhotoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la façade prise'**
  String get facadePhotoLabel;

  /// No description provided for @supportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide et service client'**
  String get supportTitle;

  /// No description provided for @supportIntro.
  ///
  /// In fr, this message translates to:
  /// **'Une question, un souci avec une livraison ? Écrivez-nous : l’équipe Tara vous répond ici et vous êtes prévenu de sa réponse.'**
  String get supportIntro;

  /// No description provided for @supportNewRequest.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get supportNewRequest;

  /// No description provided for @supportEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande pour l’instant. Pour un souci avec une livraison, vous pouvez aussi la signaler depuis son suivi.'**
  String get supportEmpty;

  /// No description provided for @supportCallUs.
  ///
  /// In fr, this message translates to:
  /// **'Urgent ? Appelez le {phone}'**
  String supportCallUs(String phone);

  /// No description provided for @supportCategoryLostParcel.
  ///
  /// In fr, this message translates to:
  /// **'Colis perdu ou non reçu'**
  String get supportCategoryLostParcel;

  /// No description provided for @supportCategoryDamagedParcel.
  ///
  /// In fr, this message translates to:
  /// **'Colis abîmé'**
  String get supportCategoryDamagedParcel;

  /// No description provided for @supportCategoryLateDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Retard'**
  String get supportCategoryLateDelivery;

  /// No description provided for @supportCategoryPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get supportCategoryPayment;

  /// No description provided for @supportCategoryRiderBehavior.
  ///
  /// In fr, this message translates to:
  /// **'Comportement du livreur'**
  String get supportCategoryRiderBehavior;

  /// No description provided for @supportCategoryAppBug.
  ///
  /// In fr, this message translates to:
  /// **'Problème dans l’app'**
  String get supportCategoryAppBug;

  /// No description provided for @supportCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get supportCategoryOther;

  /// No description provided for @supportStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolue'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In fr, this message translates to:
  /// **'Close'**
  String get supportStatusClosed;

  /// No description provided for @supportNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get supportNewTitle;

  /// No description provided for @supportReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get supportReasonLabel;

  /// No description provided for @supportSubjectLabel.
  ///
  /// In fr, this message translates to:
  /// **'En quelques mots'**
  String get supportSubjectLabel;

  /// No description provided for @supportSubjectHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : colis non reçu par ma cliente'**
  String get supportSubjectHint;

  /// No description provided for @supportMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Expliquez-nous'**
  String get supportMessageLabel;

  /// No description provided for @supportMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui s’est passé et ce que vous attendez de Tara.'**
  String get supportMessageHint;

  /// No description provided for @supportOrderLine.
  ///
  /// In fr, this message translates to:
  /// **'Commande {reference}'**
  String supportOrderLine(String reference);

  /// No description provided for @supportSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get supportSend;

  /// No description provided for @supportReplyHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse…'**
  String get supportReplyHint;

  /// No description provided for @supportReplySend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get supportReplySend;

  /// No description provided for @supportClosedNote.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande est close. Ouvrez une nouvelle demande si besoin.'**
  String get supportClosedNote;

  /// No description provided for @supportFromTara.
  ///
  /// In fr, this message translates to:
  /// **'Service client Tara'**
  String get supportFromTara;

  /// No description provided for @supportNewAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Réponse'**
  String get supportNewAnswer;

  /// No description provided for @supportWaitingNote.
  ///
  /// In fr, this message translates to:
  /// **'L’équipe Tara vous répond ici ; vous serez prévenu.'**
  String get supportWaitingNote;

  /// No description provided for @supportMenuRow.
  ///
  /// In fr, this message translates to:
  /// **'Écrire au service client'**
  String get supportMenuRow;

  /// No description provided for @supportMenuRowSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos demandes et les réponses de Tara'**
  String get supportMenuRowSubtitle;

  /// No description provided for @reportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get reportProblem;

  /// No description provided for @accountDataSection.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte et mes données'**
  String get accountDataSection;

  /// No description provided for @exportDataRow.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger mes données'**
  String get exportDataRow;

  /// No description provided for @exportDataRowSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Une copie de tout ce que Tara garde sur vous'**
  String get exportDataRowSubtitle;

  /// No description provided for @exportDataShare.
  ///
  /// In fr, this message translates to:
  /// **'Mes données Tara'**
  String get exportDataShare;

  /// No description provided for @deleteAccountRow.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountRow;

  /// No description provided for @deleteAccountRowSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Définitif, confirmé par votre code secret'**
  String get deleteAccountRowSubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom, votre numéro, vos adresses, photos et notes vocales sont effacés, et l’app se déconnecte. Vos livraisons passées restent, sans votre nom, pour la comptabilité.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountFinal.
  ///
  /// In fr, this message translates to:
  /// **'C’est définitif : avec le même numéro, vous repartirez d’un compte vide.'**
  String get deleteAccountFinal;

  /// No description provided for @deleteAccountBalance.
  ///
  /// In fr, this message translates to:
  /// **'Il vous reste {amount} chez Tara : retirez-les d’abord vers votre Mobile Money.'**
  String deleteAccountBalance(String amount);

  /// No description provided for @deleteAccountDebt.
  ///
  /// In fr, this message translates to:
  /// **'Votre boutique doit {amount} à Tara : ils doivent être réglés avant la suppression.'**
  String deleteAccountDebt(String amount);

  /// No description provided for @deleteAccountPayout.
  ///
  /// In fr, this message translates to:
  /// **'Un retrait vers votre Mobile Money est en cours : attendez qu’il arrive.'**
  String get deleteAccountPayout;

  /// No description provided for @openWallet.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir mon portefeuille'**
  String get openWallet;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteAccountConfirm;

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

  /// No description provided for @topUpRange.
  ///
  /// In fr, this message translates to:
  /// **'Montant entre {min} et {max}.'**
  String topUpRange(String min, String max);

  /// No description provided for @failureReasonDamaged.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire a refusé le colis : il était abîmé. Une réclamation est ouverte, l’équipe Tara vous contacte.'**
  String get failureReasonDamaged;

  /// No description provided for @pinCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre code secret'**
  String get pinCreateTitle;

  /// No description provided for @pinCreateBody.
  ///
  /// In fr, this message translates to:
  /// **'4 chiffres, comme pour Orange Money ou MoMo. Il protège votre solde et vos retraits. Ne le donnez à personne, même à Tara.'**
  String get pinCreateBody;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre code secret'**
  String get pinConfirmTitle;

  /// No description provided for @pinMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux codes sont différents. Recommencez.'**
  String get pinMismatch;

  /// No description provided for @pinEnterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code secret'**
  String get pinEnterTitle;

  /// No description provided for @pinCurrentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre code secret actuel'**
  String get pinCurrentTitle;

  /// No description provided for @pinNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code secret'**
  String get pinNewTitle;

  /// No description provided for @pinForgot.
  ///
  /// In fr, this message translates to:
  /// **'Code oublié ?'**
  String get pinForgot;

  /// No description provided for @pinUseBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser aussi mon empreinte'**
  String get pinUseBiometrics;

  /// No description provided for @pinBiometricButton.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser mon empreinte'**
  String get pinBiometricButton;

  /// No description provided for @pinBiometricTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez avec votre empreinte'**
  String get pinBiometricTitle;

  /// No description provided for @pinDelete.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get pinDelete;

  /// No description provided for @pinDigitsEntered.
  ///
  /// In fr, this message translates to:
  /// **'{count} chiffre(s) sur 4'**
  String pinDigitsEntered(int count);

  /// No description provided for @pinLockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code secret bloqué'**
  String get pinLockedTitle;

  /// No description provided for @pinLockedBody.
  ///
  /// In fr, this message translates to:
  /// **'Après 5 erreurs, votre code secret est bloqué. Recevez un code sur votre numéro pour en choisir un nouveau.'**
  String get pinLockedBody;

  /// No description provided for @pinResetBody.
  ///
  /// In fr, this message translates to:
  /// **'Recevez un code sur votre numéro pour choisir un nouveau code secret.'**
  String get pinResetBody;

  /// No description provided for @pinSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un code'**
  String get pinSendCode;

  /// No description provided for @pinCodeSentSms.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code reçu par SMS.'**
  String get pinCodeSentSms;

  /// No description provided for @pinCodeSentWhatsApp.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code reçu sur WhatsApp.'**
  String get pinCodeSentWhatsApp;

  /// No description provided for @codeBySms.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir par SMS'**
  String get codeBySms;

  /// No description provided for @codeSentWhatsAppTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé sur WhatsApp au {phone}'**
  String codeSentWhatsAppTo(String phone);

  /// No description provided for @pinSaved.
  ///
  /// In fr, this message translates to:
  /// **'Code secret enregistré.'**
  String get pinSaved;

  /// No description provided for @balanceShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le solde'**
  String get balanceShow;

  /// No description provided for @balanceHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le solde'**
  String get balanceHide;

  /// No description provided for @pinReasonBalance.
  ///
  /// In fr, this message translates to:
  /// **'Pour voir votre solde'**
  String get pinReasonBalance;

  /// No description provided for @pinReasonWithdraw.
  ///
  /// In fr, this message translates to:
  /// **'Pour retirer {amount}'**
  String pinReasonWithdraw(String amount);

  /// No description provided for @pinRowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code secret'**
  String get pinRowTitle;

  /// No description provided for @pinRowSet.
  ///
  /// In fr, this message translates to:
  /// **'Changer mon code secret'**
  String get pinRowSet;

  /// No description provided for @pinRowNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Choisir mon code secret'**
  String get pinRowNotSet;

  /// No description provided for @biometricRowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte digitale'**
  String get biometricRowTitle;

  /// No description provided for @biometricRowBody.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer avec l\'empreinte au lieu du code'**
  String get biometricRowBody;

  /// No description provided for @pinReasonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Pour supprimer votre compte'**
  String get pinReasonDelete;

  /// No description provided for @deleteAccountConfirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer avec mon code secret'**
  String get deleteAccountConfirmPin;

  /// No description provided for @securitySection.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get securitySection;

  /// No description provided for @trackPayNow.
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount} par Mobile Money'**
  String trackPayNow(String amount);

  /// No description provided for @trackPayPending.
  ///
  /// In fr, this message translates to:
  /// **'Validez la demande de paiement sur votre téléphone…'**
  String get trackPayPending;

  /// No description provided for @trackPayFailed.
  ///
  /// In fr, this message translates to:
  /// **'Paiement non abouti. Réessayez, ou annulez la livraison.'**
  String get trackPayFailed;

  /// No description provided for @trackPayVia.
  ///
  /// In fr, this message translates to:
  /// **'La demande de paiement part vers ce numéro {operator}.'**
  String trackPayVia(String operator);

  /// No description provided for @cardFailureFees.
  ///
  /// In fr, this message translates to:
  /// **'Si la livraison échoue : nouvelle tentative {retry}, retour {ret}'**
  String cardFailureFees(String retry, String ret);

  /// No description provided for @batchFailureFeesNote.
  ///
  /// In fr, this message translates to:
  /// **'En cas d’échec de livraison, les frais indiqués sur chaque colis sont à votre charge. Le colis retourné vous est rendu contre paiement de ce que votre solde Tara ne couvre pas.'**
  String get batchFailureFeesNote;

  /// No description provided for @batchRefusalFeeNote.
  ///
  /// In fr, this message translates to:
  /// **'Colis différent de ce que vous déclarez (trop grand, trop lourd, interdit) : le livreur peut le refuser, et son déplacement (le prix d’une nouvelle tentative) reste à votre charge.'**
  String get batchRefusalFeeNote;

  /// No description provided for @pickupCodeHelpBatch.
  ///
  /// In fr, this message translates to:
  /// **'Le même code pour chaque livreur qui vient chercher un colis. Notez-le : il ne sera plus affiché.'**
  String get pickupCodeHelpBatch;

  /// No description provided for @writeNumbersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez son numéro sur chaque colis'**
  String get writeNumbersTitle;

  /// No description provided for @writeNumbersBody.
  ///
  /// In fr, this message translates to:
  /// **'Au marqueur, bien visible. Chaque livreur vient chercher un numéro précis : vous saurez lequel lui donner.'**
  String get writeNumbersBody;

  /// No description provided for @parcelNumberSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Colis numéro {n}'**
  String parcelNumberSemantics(int n);

  /// No description provided for @riderFoundShort.
  ///
  /// In fr, this message translates to:
  /// **'Livreur trouvé'**
  String get riderFoundShort;

  /// No description provided for @riderSearchingShort.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get riderSearchingShort;

  /// No description provided for @ridersFound.
  ///
  /// In fr, this message translates to:
  /// **'Livreurs trouvés : {found} sur {total}'**
  String ridersFound(int found, int total);

  /// No description provided for @allRidersFound.
  ///
  /// In fr, this message translates to:
  /// **'Tous les livreurs sont trouvés : ils viennent chercher les colis.'**
  String get allRidersFound;

  /// No description provided for @parcelNumberShort.
  ///
  /// In fr, this message translates to:
  /// **'n° {n}'**
  String parcelNumberShort(int n);

  /// No description provided for @trackAssignedParcel.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vient chercher le colis n° {n}'**
  String trackAssignedParcel(String rider, int n);

  /// No description provided for @trackAssignedParcelBody.
  ///
  /// In fr, this message translates to:
  /// **'Donnez-lui le colis n° {n} et le code d’enlèvement à son arrivée.'**
  String trackAssignedParcelBody(int n);

  /// No description provided for @trackAssignedTour.
  ///
  /// In fr, this message translates to:
  /// **'{rider} vient chercher les colis n° {numbers}'**
  String trackAssignedTour(String rider, String numbers);

  /// No description provided for @trackAssignedTourBody.
  ///
  /// In fr, this message translates to:
  /// **'Tous partent en une seule tournée. Donnez-lui ces {count} colis et le code d’enlèvement à son arrivée.'**
  String trackAssignedTourBody(int count);

  /// No description provided for @listAnd.
  ///
  /// In fr, this message translates to:
  /// **'{head} et {last}'**
  String listAnd(String head, String last);

  /// No description provided for @bulkEntry.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer plusieurs colis'**
  String get bulkEntry;

  /// No description provided for @bulkEntryBody.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à 100 clients d’un coup : collez votre liste ou cochez vos contacts.'**
  String get bulkEntryBody;

  /// No description provided for @bulkResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre ma liste · {count, plural, =1{1 client} other{{count} clients}}'**
  String bulkResume(num count);

  /// No description provided for @bulkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Liste d’envoi'**
  String get bulkTitle;

  /// No description provided for @bulkCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun client} =1{1 client} other{{count} clients}}'**
  String bulkCount(num count);

  /// No description provided for @bulkSettings.
  ///
  /// In fr, this message translates to:
  /// **'Pour tous les colis'**
  String get bulkSettings;

  /// No description provided for @bulkPickupMissing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez d’où partent les colis'**
  String get bulkPickupMissing;

  /// No description provided for @bulkWhenNow.
  ///
  /// In fr, this message translates to:
  /// **'Dès que possible'**
  String get bulkWhenNow;

  /// No description provided for @bulkDefaultSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille des colis'**
  String get bulkDefaultSize;

  /// No description provided for @bulkAddPaste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get bulkAddPaste;

  /// No description provided for @bulkAddContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get bulkAddContacts;

  /// No description provided for @bulkAddManual.
  ///
  /// In fr, this message translates to:
  /// **'Saisir'**
  String get bulkAddManual;

  /// No description provided for @bulkEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos clients du jour'**
  String get bulkEmptyTitle;

  /// No description provided for @bulkEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Collez votre liste WhatsApp, cochez vos clients ou vos contacts, ou saisissez-les un par un. La liste reste sur votre téléphone jusqu’à l’envoi.'**
  String get bulkEmptyBody;

  /// No description provided for @bulkLineWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Tara lui enverra un lien pour placer son point'**
  String get bulkLineWaiting;

  /// No description provided for @bulkLineIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'À compléter'**
  String get bulkLineIncomplete;

  /// No description provided for @bulkPhoneIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'numéro incomplet ({digits})'**
  String bulkPhoneIncomplete(Object digits);

  /// No description provided for @bulkPhoneMissing.
  ///
  /// In fr, this message translates to:
  /// **'numéro manquant'**
  String get bulkPhoneMissing;

  /// No description provided for @bulkNameMissing.
  ///
  /// In fr, this message translates to:
  /// **'nom manquant'**
  String get bulkNameMissing;

  /// No description provided for @bulkFull.
  ///
  /// In fr, this message translates to:
  /// **'100 clients au plus par envoi : envoyez cette liste, puis commencez-en une autre.'**
  String get bulkFull;

  /// No description provided for @bulkReview.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier et envoyer · {count, plural, =1{1 colis} other{{count} colis}}'**
  String bulkReview(num count);

  /// No description provided for @bulkAdded.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun client ajouté} =1{1 client ajouté} other{{count} clients ajoutés}}'**
  String bulkAdded(num count);

  /// No description provided for @bulkClear.
  ///
  /// In fr, this message translates to:
  /// **'Vider la liste'**
  String get bulkClear;

  /// No description provided for @bulkClearConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer les {count} clients de la liste ?'**
  String bulkClearConfirm(int count);

  /// No description provided for @bulkClearAction.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get bulkClearAction;

  /// No description provided for @bulkAddCount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter {count, plural, =0{} =1{1 client} other{{count} clients}}'**
  String bulkAddCount(num count);

  /// No description provided for @pasteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Coller une liste'**
  String get pasteTitle;

  /// No description provided for @pasteBody.
  ///
  /// In fr, this message translates to:
  /// **'Copiez vos commandes du jour depuis WhatsApp ou vos notes : une ligne par client, avec son numéro.'**
  String get pasteBody;

  /// No description provided for @pasteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Votre liste'**
  String get pasteLabel;

  /// No description provided for @pasteHint.
  ///
  /// In fr, this message translates to:
  /// **'Marie 690 11 22 33 Bonapriso 12500'**
  String get pasteHint;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Coller ce que j’ai copié'**
  String get pasteFromClipboard;

  /// No description provided for @pasteUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Tara a compris'**
  String get pasteUnderstood;

  /// No description provided for @pasteScore.
  ///
  /// In fr, this message translates to:
  /// **'{ok} sur {total}'**
  String pasteScore(int ok, int total);

  /// No description provided for @pasteNote.
  ///
  /// In fr, this message translates to:
  /// **'Les montants sont ceux à encaisser auprès du client. Sans adresse connue, Tara envoie au client le lien pour placer son point.'**
  String get pasteNote;

  /// No description provided for @pastePrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Lu sur votre téléphone : rien ne part avant « Ajouter ».'**
  String get pastePrivacy;

  /// No description provided for @pasteKnownAddress.
  ///
  /// In fr, this message translates to:
  /// **'adresse connue'**
  String get pasteKnownAddress;

  /// No description provided for @contactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir des clients'**
  String get contactsTitle;

  /// No description provided for @contactsSearch.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou numéro'**
  String get contactsSearch;

  /// No description provided for @contactsKnown.
  ///
  /// In fr, this message translates to:
  /// **'Vos clients · adresse déjà connue'**
  String get contactsKnown;

  /// No description provided for @contactsOrders.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 commande} other{{count} commandes}}'**
  String contactsOrders(num count);

  /// No description provided for @contactsPhone.
  ///
  /// In fr, this message translates to:
  /// **'Contacts du téléphone'**
  String get contactsPhone;

  /// No description provided for @contactsAllow.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes contacts'**
  String get contactsAllow;

  /// No description provided for @contactsAllowBody.
  ///
  /// In fr, this message translates to:
  /// **'Tara lit vos contacts sur ce téléphone pour vous laisser cocher vos clients. Rien n’est envoyé tant que vous ne les ajoutez pas.'**
  String get contactsAllowBody;

  /// No description provided for @contactsDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux contacts refusé. Vous pouvez l’autoriser dans les réglages du téléphone.'**
  String get contactsDenied;

  /// No description provided for @contactsOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get contactsOpenSettings;

  /// No description provided for @contactsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact avec un numéro de mobile camerounais.'**
  String get contactsEmpty;

  /// No description provided for @contactsNote.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les clients cochés quittent votre téléphone. Pour ceux sans adresse, Tara leur envoie le lien pour placer leur point.'**
  String get contactsNote;

  /// No description provided for @lineNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau client'**
  String get lineNew;

  /// No description provided for @lineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Client n° {number}'**
  String lineTitle(int number);

  /// No description provided for @lineHintNoted.
  ///
  /// In fr, this message translates to:
  /// **'Noté dans votre liste : {hint}'**
  String lineHintNoted(Object hint);

  /// No description provided for @lineAskLink.
  ///
  /// In fr, this message translates to:
  /// **'Le client place son point'**
  String get lineAskLink;

  /// No description provided for @lineAskLinkBody.
  ///
  /// In fr, this message translates to:
  /// **'Tara lui envoie un lien par SMS à l’envoi ; son colis part dès qu’il a placé son point.'**
  String get lineAskLinkBody;

  /// No description provided for @lineLastAddress.
  ///
  /// In fr, this message translates to:
  /// **'Sa dernière adresse'**
  String get lineLastAddress;

  /// No description provided for @linePlaceOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Placer sur la carte'**
  String get linePlaceOnMap;

  /// No description provided for @lineSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille du colis'**
  String get lineSize;

  /// No description provided for @lineSizeDefault.
  ///
  /// In fr, this message translates to:
  /// **'Comme la liste ({size})'**
  String lineSizeDefault(Object size);

  /// No description provided for @lineDescription.
  ///
  /// In fr, this message translates to:
  /// **'Contenu du colis (facultatif)'**
  String get lineDescription;

  /// No description provided for @lineDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'2 paires de chaussures'**
  String get lineDescriptionHint;

  /// No description provided for @lineSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get lineSave;

  /// No description provided for @lineRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la liste'**
  String get lineRemove;

  /// No description provided for @bulkSendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier et envoyer'**
  String get bulkSendTitle;

  /// No description provided for @bulkReadyLine.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 colis prêt : il part tout de suite.} other{{count} colis prêts : ils partent tout de suite.}}'**
  String bulkReadyLine(num count);

  /// No description provided for @bulkWaitingLine.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 client n’a pas encore placé son point : son colis partira dès qu’il le fera.} other{{count} clients n’ont pas encore placé leur point : leurs colis partiront dès qu’ils le feront.}}'**
  String bulkWaitingLine(num count);

  /// No description provided for @bulkIncompleteLine.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 client à compléter : il reste dans la liste et ne part pas.} other{{count} clients à compléter : ils restent dans la liste et ne partent pas.}}'**
  String bulkIncompleteLine(num count);

  /// No description provided for @bulkFix.
  ///
  /// In fr, this message translates to:
  /// **'Corriger'**
  String get bulkFix;

  /// No description provided for @bulkCourses.
  ///
  /// In fr, this message translates to:
  /// **'Courses · {count, plural, =1{1 colis} other{{count} colis}}'**
  String bulkCourses(num count);

  /// No description provided for @bulkCollect.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser pour vous'**
  String get bulkCollect;

  /// No description provided for @bulkPayNow.
  ///
  /// In fr, this message translates to:
  /// **'À payer maintenant'**
  String get bulkPayNow;

  /// No description provided for @bulkWaitingPaidLater.
  ///
  /// In fr, this message translates to:
  /// **'Un colis qui attend son point est payé quand il part : par vos ventes s’il y en a assez, sinon on vous demande de payer.'**
  String get bulkWaitingPaidLater;

  /// No description provided for @bulkQuoteError.
  ///
  /// In fr, this message translates to:
  /// **'Client n° {number} ({name}) : {error}'**
  String bulkQuoteError(int number, String name, String error);

  /// No description provided for @bulkSend.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour envoyer {count, plural, =1{1 colis} other{{count} colis}}'**
  String bulkSend(num count);

  /// No description provided for @bulkSendSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour envoyer la liste'**
  String get bulkSendSemantics;

  /// No description provided for @bulkNothingToSend.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins un client complet.'**
  String get bulkNothingToSend;

  /// No description provided for @bulkSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoi parti !'**
  String get bulkSentTitle;

  /// No description provided for @bulkSentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 colis} other{{count} colis}}'**
  String bulkSentSubtitle(num count);

  /// No description provided for @bulkSentWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Attend son point'**
  String get bulkSentWaiting;

  /// No description provided for @bulkSentWaitingNote.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Le client sans adresse a reçu un SMS. Son colis partira dès qu’il aura placé son point : on vous préviendra.} other{Les {count} clients sans adresse ont reçu un SMS. Chaque colis partira dès que son client aura placé son point : on vous préviendra.}}'**
  String bulkSentWaitingNote(num count);

  /// No description provided for @bulkSentIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 client à compléter reste dans votre liste.} other{{count} clients à compléter restent dans votre liste.}}'**
  String bulkSentIncomplete(num count);

  /// No description provided for @pendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'En attente de l’adresse'**
  String get pendingTitle;

  /// No description provided for @pendingWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé · son colis part dès qu’il a placé son point'**
  String get pendingWaiting;

  /// No description provided for @pendingExpired.
  ///
  /// In fr, this message translates to:
  /// **'Lien expiré sans réponse'**
  String get pendingExpired;

  /// No description provided for @pendingBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Point reçu, colis pas encore parti'**
  String get pendingBlocked;

  /// No description provided for @pendingBlockedBalance.
  ///
  /// In fr, this message translates to:
  /// **'Point reçu, mais vos ventes ne suffisent pas pour payer la course.'**
  String get pendingBlockedBalance;

  /// No description provided for @pendingResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le lien'**
  String get pendingResend;

  /// No description provided for @pendingShare.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien par WhatsApp'**
  String get pendingShare;

  /// No description provided for @pendingShareText.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}, pour recevoir votre colis, indiquez où vous livrer : {url}'**
  String pendingShareText(String name, String url);

  /// No description provided for @pendingRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de l’envoi'**
  String get pendingRemove;

  /// No description provided for @pendingRemoveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le colis n° {number} ({name}) ? Rien ne vous sera facturé.'**
  String pendingRemoveConfirm(int number, String name);

  /// No description provided for @pendingPayMomo.
  ///
  /// In fr, this message translates to:
  /// **'Payer par Mobile Money'**
  String get pendingPayMomo;

  /// No description provided for @pendingRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer avec mes ventes'**
  String get pendingRetry;

  /// No description provided for @pendingResent.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau lien envoyé à {name}.'**
  String pendingResent(Object name);

  /// No description provided for @pendingParcel.
  ///
  /// In fr, this message translates to:
  /// **'Colis n° {number} · {name}'**
  String pendingParcel(int number, String name);

  /// No description provided for @taraBalanceShopBody.
  ///
  /// In fr, this message translates to:
  /// **'Paie vos livraisons et frais avant vos ventes. Jamais reversé tout seul : retirez-le quand vous voulez.'**
  String get taraBalanceShopBody;

  /// No description provided for @shopPaysDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'Vos livraisons se paient d’abord avec votre solde Tara, puis avec vos ventes.'**
  String get shopPaysDeliveries;

  /// No description provided for @payWalletTaraAndSales.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara et ventes'**
  String get payWalletTaraAndSales;

  /// No description provided for @payWalletTaraBody.
  ///
  /// In fr, this message translates to:
  /// **'Pris sur votre solde Tara : il vous restera {amount}.'**
  String payWalletTaraBody(Object amount);

  /// No description provided for @payWalletBothBody.
  ///
  /// In fr, this message translates to:
  /// **'Pris sur votre solde Tara, puis vos ventes : il vous restera {amount} à recevoir.'**
  String payWalletBothBody(Object amount);

  /// No description provided for @reserveLine.
  ///
  /// In fr, this message translates to:
  /// **'Réserve gardée chaque soir : {amount}'**
  String reserveLine(Object amount);

  /// No description provided for @reserveNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réserve : toutes vos ventes vous sont reversées.'**
  String get reserveNone;

  /// No description provided for @reserveChange.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get reserveChange;

  /// No description provided for @reserveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réserve pour vos livraisons'**
  String get reserveTitle;

  /// No description provided for @reserveBody.
  ///
  /// In fr, this message translates to:
  /// **'Au reversement de {hour} h, Tara garde ce montant de vos ventes sur votre solde Tara : vos livraisons du lendemain sont déjà payées. Le reste vous est reversé, comme d’habitude.'**
  String reserveBody(Object hour);

  /// No description provided for @reserveZero.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get reserveZero;

  /// No description provided for @reserveSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get reserveSave;

  /// No description provided for @reserveSaved.
  ///
  /// In fr, this message translates to:
  /// **'Réserve enregistrée.'**
  String get reserveSaved;

  /// No description provided for @chatWithRider.
  ///
  /// In fr, this message translates to:
  /// **'Écrire à {name}'**
  String chatWithRider(String name);

  /// No description provided for @chatHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre message…'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message. Écrivez au livreur, il reçoit une notification.'**
  String get chatEmpty;

  /// No description provided for @chatClosed.
  ///
  /// In fr, this message translates to:
  /// **'La course est terminée : la conversation est fermée.'**
  String get chatClosed;

  /// No description provided for @chatRead.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get chatRead;

  /// No description provided for @chatSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Livreur · {reference}'**
  String chatSubtitle(String reference);

  /// No description provided for @chatQuick1.
  ///
  /// In fr, this message translates to:
  /// **'Le colis est prêt'**
  String get chatQuick1;

  /// No description provided for @chatQuick2.
  ///
  /// In fr, this message translates to:
  /// **'Je descends'**
  String get chatQuick2;

  /// No description provided for @chatQuick3.
  ///
  /// In fr, this message translates to:
  /// **'Appelez-moi en arrivant'**
  String get chatQuick3;

  /// No description provided for @chatQuick4.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes où ?'**
  String get chatQuick4;

  /// No description provided for @chatNewMessage.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau message du livreur'**
  String get chatNewMessage;

  /// No description provided for @introSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get introSkip;

  /// No description provided for @introNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get introNext;

  /// No description provided for @introStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get introStart;

  /// No description provided for @introSendKicker.
  ///
  /// In fr, this message translates to:
  /// **'Livraison à la demande · Douala'**
  String get introSendKicker;

  /// No description provided for @introSendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez un colis en une minute'**
  String get introSendTitle;

  /// No description provided for @introSendBody.
  ///
  /// In fr, this message translates to:
  /// **'Un livreur vient le chercher chez vous et le livre partout dans Douala.'**
  String get introSendBody;

  /// No description provided for @introSendChip.
  ///
  /// In fr, this message translates to:
  /// **'1 minute pour commander'**
  String get introSendChip;

  /// No description provided for @introSendFrom.
  ///
  /// In fr, this message translates to:
  /// **'Boutique Awa'**
  String get introSendFrom;

  /// No description provided for @introSendFromAddress.
  ///
  /// In fr, this message translates to:
  /// **'Bd de la Liberté, Akwa'**
  String get introSendFromAddress;

  /// No description provided for @introSendTo.
  ///
  /// In fr, this message translates to:
  /// **'Marie · Collège des Nations'**
  String get introSendTo;

  /// No description provided for @introSendDelivered.
  ///
  /// In fr, this message translates to:
  /// **'livrée en 38 min'**
  String get introSendDelivered;

  /// No description provided for @introTrackKicker.
  ///
  /// In fr, this message translates to:
  /// **'Suivi en direct'**
  String get introTrackKicker;

  /// No description provided for @introTrackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivez votre colis jusqu\'à la porte'**
  String get introTrackTitle;

  /// No description provided for @introTrackBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous voyez le livreur avancer. Votre client reçoit un lien pour le suivre aussi.'**
  String get introTrackBody;

  /// No description provided for @introTrackRider.
  ///
  /// In fr, this message translates to:
  /// **'Jean M. arrive'**
  String get introTrackRider;

  /// No description provided for @introTrackPlate.
  ///
  /// In fr, this message translates to:
  /// **'Moto · LT 482 KA'**
  String get introTrackPlate;

  /// No description provided for @introTrackEta.
  ///
  /// In fr, this message translates to:
  /// **'4 min'**
  String get introTrackEta;

  /// No description provided for @introCollectKicker.
  ///
  /// In fr, this message translates to:
  /// **'Paiement à la livraison'**
  String get introCollectKicker;

  /// No description provided for @introCollectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur encaisse pour vous'**
  String get introCollectTitle;

  /// No description provided for @introCollectBody.
  ///
  /// In fr, this message translates to:
  /// **'En espèces ou par Mobile Money. Vos ventes s\'ajoutent à votre compte et vous sont reversées sur votre Mobile Money.'**
  String get introCollectBody;

  /// No description provided for @introCollectDoor.
  ///
  /// In fr, this message translates to:
  /// **'À la porte · TR-48211'**
  String get introCollectDoor;

  /// No description provided for @introCollectRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Marie Ngo · Collège des Nations'**
  String get introCollectRecipient;

  /// No description provided for @introCollectAmount.
  ///
  /// In fr, this message translates to:
  /// **'15 000 F'**
  String get introCollectAmount;

  /// No description provided for @introCollectCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get introCollectCash;

  /// No description provided for @introCollectMomo.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get introCollectMomo;

  /// No description provided for @introCollectFooter.
  ///
  /// In fr, this message translates to:
  /// **'+15 000 F · à l\'instant'**
  String get introCollectFooter;

  /// No description provided for @introSalesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ventes à recevoir'**
  String get introSalesLabel;

  /// No description provided for @introAccountsKicker.
  ///
  /// In fr, this message translates to:
  /// **'Votre argent'**
  String get introAccountsKicker;

  /// No description provided for @introAccountsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Deux comptes, d\'un coup d\'œil'**
  String get introAccountsTitle;

  /// No description provided for @introAccountsBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos ventes à recevoir et votre Solde Tara, qui paie vos livraisons. Tout est masqué tant que vous ne l\'affichez pas.'**
  String get introAccountsBody;

  /// No description provided for @introAccountsShopTag.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get introAccountsShopTag;

  /// No description provided for @introAccountsSalesFooter.
  ///
  /// In fr, this message translates to:
  /// **'Reversées ce soir à 18 h'**
  String get introAccountsSalesFooter;

  /// No description provided for @introAccountsTaraLabel.
  ///
  /// In fr, this message translates to:
  /// **'Solde Tara'**
  String get introAccountsTaraLabel;

  /// No description provided for @introAccountsTaraFooter.
  ///
  /// In fr, this message translates to:
  /// **'Paie vos livraisons en premier'**
  String get introAccountsTaraFooter;

  /// No description provided for @introAccountsSwipe.
  ///
  /// In fr, this message translates to:
  /// **'Glissez pour changer de compte'**
  String get introAccountsSwipe;
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
