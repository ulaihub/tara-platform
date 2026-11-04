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

  @override
  String get goodMorning => 'Bonjour,';

  @override
  String get goodEvening => 'Bonsoir,';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabOrders => 'Commandes';

  @override
  String get tabProfile => 'Profil';

  @override
  String get sendTitle => 'Envoyer un colis';

  @override
  String get sendBody => 'Un livreur vient le chercher et le livre dans Douala, avec suivi en direct.';

  @override
  String get newDelivery => 'Nouvelle livraison';

  @override
  String get askAddress => 'Demander l’adresse au destinataire';

  @override
  String get shopBalance => 'Ventes de la boutique';

  @override
  String get shopBalanceDaily => 'À recevoir · versé chaque nuit sur votre Mobile Money';

  @override
  String get shopBalanceOnDemand => 'À recevoir · versé quand vous le demandez';

  @override
  String get inProgress => 'En cours';

  @override
  String get noOrdersInProgress => 'Aucune livraison en cours. Vos colis apparaissent ici dès leur envoi.';

  @override
  String statusScheduled(String when) {
    return 'Prévue $when';
  }

  @override
  String get statusSearching => 'Recherche d’un livreur';

  @override
  String get statusRiderComing => 'Livreur en route vers l’enlèvement';

  @override
  String get statusInDelivery => 'En livraison';

  @override
  String get statusFailed => 'Livraison impossible · à décider';

  @override
  String todayAt(String time) {
    return 'aujourd’hui à $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'demain à $time';
  }

  @override
  String get ordersError => 'Impossible de charger vos livraisons.';

  @override
  String get finished => 'Terminées';

  @override
  String get noOrdersFinished => 'Aucune livraison terminée pour l’instant.';

  @override
  String statusDelivered(String day) {
    return 'Livrée · $day';
  }

  @override
  String get statusReturned => 'Retournée à l’expéditeur';

  @override
  String get statusCancelled => 'Annulée';

  @override
  String get today => 'aujourd’hui';

  @override
  String get yesterday => 'hier';

  @override
  String get referralTitle => 'Parrainage';

  @override
  String get referralBody =>
      'Partagez votre code : vos amis l’entrent à leur inscription et profitent d’une réduction.';

  @override
  String appVersion(String version) {
    return 'Tara · version $version';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get displaySection => 'Affichage';

  @override
  String get effectsAutoReduced => 'Réduites automatiquement sur ce téléphone.';

  @override
  String get effectsFull => 'Complètes';

  @override
  String get effectsHint => 'Réduites : moins d’effets, plus fluide sur un téléphone modeste.';

  @override
  String get effectsLabel => 'Animations';

  @override
  String get effectsReduced => 'Réduites';

  @override
  String get helpSection => 'Aide';

  @override
  String get languageLabel => 'Langue';

  @override
  String get logoutConfirm => 'Vous ne recevrez plus de courses sur ce téléphone jusqu’à votre prochaine connexion.';

  @override
  String get optionAuto => 'Auto';

  @override
  String get supportTara => 'Support Tara';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLabel => 'Thème';

  @override
  String get themeLight => 'Clair';
}
