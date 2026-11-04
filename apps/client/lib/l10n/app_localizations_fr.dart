// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get addLegalIds => 'Ajouter RCCM et NIU (facultatif)';

  @override
  String get back => 'Retour';

  @override
  String get categoryBeauty => 'Beauté';

  @override
  String get categoryElectronics => 'Électronique';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFood => 'Alimentation';

  @override
  String get categoryHome => 'Maison';

  @override
  String get categoryOther => 'Autre';

  @override
  String get change => 'Modifier';

  @override
  String codeSentTo(String phone) {
    return 'Envoyé par SMS au $phone';
  }

  @override
  String get codeTitle => 'Entrez le code reçu';

  @override
  String get continueLabel => 'Continuer';

  @override
  String countryCodeLabel(String code) {
    return 'Indicatif du pays $code';
  }

  @override
  String digitLabel(int index) {
    return 'Chiffre $index';
  }

  @override
  String get firstName => 'Prénom';

  @override
  String get genericError => 'Une erreur est survenue. Réessayez.';

  @override
  String get getCode => 'Recevoir le code';

  @override
  String get haveReferral => 'J’ai un code de parrainage';

  @override
  String hello(String name) {
    return 'Bonjour $name';
  }

  @override
  String get kindPerson => 'Pour moi';

  @override
  String get kindPersonHelp => 'Vous pourrez passer en mode boutique plus tard, depuis votre profil.';

  @override
  String get kindQuestion => 'Vous envoyez des colis…';

  @override
  String get kindShop => 'Pour ma boutique';

  @override
  String get kindShopHelp => 'L’argent encaissé à la livraison vous est reversé par Mobile Money.';

  @override
  String get lastName => 'Nom';

  @override
  String get legalAnd => ' et la ';

  @override
  String get legalPrefix => 'En continuant, vous acceptez les ';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get networkError => 'Pas de connexion internet. Vérifiez le réseau et réessayez.';

  @override
  String get niu => 'NIU';

  @override
  String get niuHint => 'Ex. M012345678901A';

  @override
  String get noSms => 'Pas reçu de SMS ? Contacter le support';

  @override
  String get payoutHelp => 'Numéro Mobile Money qui reçoit vos ventes encaissées.';

  @override
  String get payoutNumber => 'Numéro Mobile Money';

  @override
  String get payoutTitle => 'Reversements';

  @override
  String get phoneHelp => 'Un SMS gratuit vous est envoyé. Aucun e-mail n’est demandé.';

  @override
  String get phoneHint => '6XX XX XX XX';

  @override
  String get phoneInvalid => 'Numéro de mobile camerounais à 9 chiffres, commençant par 6.';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get privacy => 'politique de confidentialité';

  @override
  String get rccm => 'RCCM';

  @override
  String get rccmHint => 'Ex. RC/DLA/2024/B/1234';

  @override
  String get referralHint => 'Ex. TARA-7KQ2PM';

  @override
  String get referralLabel => 'Code de parrainage';

  @override
  String get requiredField => 'Obligatoire';

  @override
  String get resend => 'Renvoyer';

  @override
  String resendIn(String time) {
    return 'Renvoyer le code dans $time';
  }

  @override
  String get resendNow => 'Vous n’avez rien reçu ?';

  @override
  String get retry => 'Réessayer';

  @override
  String get senderSpace => 'Envoyez vos colis';

  @override
  String get shopCategory => 'Catégorie (facultatif)';

  @override
  String get shopName => 'Nom de la boutique';

  @override
  String get shopNameHint => 'Ex. Awa Fashion';

  @override
  String get signInBody =>
      'Connectez-vous avec votre numéro, ou créez votre compte. Nous vous envoyons un code par SMS.';

  @override
  String get signInTitle => 'Vos colis livrés à Douala';

  @override
  String get terms => 'conditions d’utilisation';

  @override
  String get validate => 'Valider';

  @override
  String get welcomeBody => 'Votre nom figure dans les messages envoyés à vos destinataires.';

  @override
  String get welcomeTitle => 'Bienvenue sur Tara';

  @override
  String get appTitle => 'Tara';
}
