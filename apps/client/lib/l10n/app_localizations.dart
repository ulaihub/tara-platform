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

  /// No description provided for @hello.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String hello(String name);

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
