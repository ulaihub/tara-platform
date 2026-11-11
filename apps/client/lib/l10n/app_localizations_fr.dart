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
  String get legalPrefix => 'Nouveau compte : vous lirez et accepterez les ';

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
  String get logoutConfirm =>
      'Vous ne recevrez plus de notifications sur ce téléphone jusqu’à votre prochaine connexion.';

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

  @override
  String get prohibitedTitle => 'Objets interdits';

  @override
  String get prohibitedWeapons => 'Armes, y compris armes blanches, et munitions';

  @override
  String get prohibitedIllegal => 'Produits illicites : drogues, contrefaçons';

  @override
  String get prohibitedDangerous =>
      'Matières dangereuses : gaz, carburant, produits inflammables, explosifs ou corrosifs';

  @override
  String get prohibitedAnimals => 'Animaux vivants';

  @override
  String get prohibitedCash => 'Liasses d’argent liquide';

  @override
  String get prohibitedPledge => 'En envoyant le colis, vous confirmez qu’il n’en contient aucun.';

  @override
  String get close => 'Fermer';

  @override
  String stepOf(int current, int total, String title) {
    return 'Étape $current sur $total · $title';
  }

  @override
  String get stepPickup => 'Enlèvement';

  @override
  String get stepRecipient => 'Destinataire';

  @override
  String get stepPackage => 'Colis';

  @override
  String get stepWhen => 'Quand';

  @override
  String get stepSummary => 'Récapitulatif';

  @override
  String get pickupTitle => 'Où récupérer le colis ?';

  @override
  String get pickupBody => 'Le livreur passe le prendre à cette adresse.';

  @override
  String get noPickupYet =>
      'Aucune adresse enregistrée. Placez votre boutique ou votre domicile sur la carte : vous la retrouverez la prochaine fois.';

  @override
  String get addressesError => 'Impossible de charger vos adresses.';

  @override
  String get newAddress => 'Nouvelle adresse';

  @override
  String get pickupRequired => 'Choisissez ou ajoutez l’adresse d’enlèvement.';

  @override
  String get pickupAddressTitle => 'Adresse d’enlèvement';

  @override
  String get locationUnavailable => 'Position introuvable : déplacez la carte jusqu’au bon endroit.';

  @override
  String get myPosition => 'Ma position';

  @override
  String get pinHint => 'Déplacez la carte pour placer l’épingle sur l’entrée exacte.';

  @override
  String get neighborhoodLabel => 'Quartier';

  @override
  String get neighborhoodAuto => 'Déduit du point sur la carte';

  @override
  String get neighborhoodSearch => 'Rechercher un quartier';

  @override
  String get landmarkLabel => 'Repère';

  @override
  String get landmarkHint => 'Ex. Portail bleu après la pharmacie du carrefour';

  @override
  String get landmarkRequired => 'Décrivez un repère visible (3 caractères au moins).';

  @override
  String get addressLabel => 'Libellé';

  @override
  String get labelShop => 'Boutique';

  @override
  String get labelHome => 'Maison';

  @override
  String get labelOffice => 'Bureau';

  @override
  String get saveAddress => 'Enregistrer l’adresse';

  @override
  String get recipientTitle => 'Qui reçoit le colis ?';

  @override
  String get recipientBody => 'Nous lui envoyons le suivi de la livraison par SMS.';

  @override
  String get recipientName => 'Nom du destinataire';

  @override
  String get recipientNameHint => 'Ex. Marie Ngo';

  @override
  String get recipientPhone => 'Son numéro';

  @override
  String get recipientNameRequired => 'Saisissez le nom du destinataire.';

  @override
  String get recentRecipients => 'Récents';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count livraisons', one: '1 livraison');
    return '$_temp0';
  }

  @override
  String get deliveryAddress => 'Adresse de livraison';

  @override
  String get placeOnMap => 'Placer sur la carte';

  @override
  String get placeOnMapBody => 'Vous savez où livrer : placez l’épingle vous-même.';

  @override
  String get askRecipient => 'Demander au destinataire';

  @override
  String get askRecipientBody => 'Il reçoit un lien et place lui-même son point sur la carte.';

  @override
  String get viaWhatsapp => 'WhatsApp';

  @override
  String get viaSms => 'SMS';

  @override
  String get recipientFirst => 'Saisissez d’abord le nom et le numéro du destinataire.';

  @override
  String linkSentTitle(String name) {
    return 'Lien envoyé à $name';
  }

  @override
  String get linkWaiting =>
      'En attente de son point : l’adresse s’affiche ici dès qu’il l’a placé. Vous pouvez continuer en attendant.';

  @override
  String get linkExpired => 'Le lien a expiré sans réponse.';

  @override
  String get resendLink => 'Renvoyer le lien';

  @override
  String get placeMyself => 'Placer moi-même';

  @override
  String get changeAddress => 'Changer d’adresse';

  @override
  String get addressVerified => 'Adresse confirmée par une livraison';

  @override
  String get addressFromRecipient => 'Placée par le destinataire';

  @override
  String get addressRequired => 'Indiquez où livrer le colis.';

  @override
  String get whatsappUnavailable => 'WhatsApp ne s’est pas ouvert. Essayez par SMS.';

  @override
  String get smsUnavailable => 'Les SMS ne se sont pas ouverts sur ce téléphone.';

  @override
  String locationLinkMessage(String name, String sender, String url) {
    return 'Bonjour $name, $sender vous envoie un colis avec Tara. Indiquez où vous le livrer : $url';
  }

  @override
  String get packageTitle => 'Qu’y a-t-il dans le colis ?';

  @override
  String get packageBody => 'Le livreur sait ainsi comment le transporter.';

  @override
  String get contentsLabel => 'Nature du contenu';

  @override
  String get contentsDocuments => 'Documents';

  @override
  String get contentsClothing => 'Vêtements, chaussures';

  @override
  String get contentsMedicine => 'Médicaments';

  @override
  String get contentsLaundry => 'Linge';

  @override
  String get contentsHousehold => 'Cuisine, maison';

  @override
  String get contentsElectronics => 'Électronique';

  @override
  String get contentsFood => 'Alimentation';

  @override
  String get contentsBeauty => 'Beauté';

  @override
  String get contentsSecondhand => 'Brocante';

  @override
  String get contentsOther => 'Autre';

  @override
  String get contentsRequired => 'Choisissez la nature du contenu.';

  @override
  String get descriptionLabel => 'Précisez (facultatif)';

  @override
  String get descriptionLabelRequired => 'Précisez le contenu';

  @override
  String get descriptionRequired => 'Décrivez ce que contient le colis.';

  @override
  String get descriptionHintDocuments => 'Ex. Contrat signé, dossier';

  @override
  String get descriptionHintClothing => 'Ex. 2 paires de chaussures';

  @override
  String get descriptionHintMedicine => 'Ex. Ordonnance de la pharmacie';

  @override
  String get descriptionHintLaundry => 'Ex. 1 sac de linge repassé';

  @override
  String get descriptionHintHousehold => 'Ex. Marmite et 6 verres';

  @override
  String get descriptionHintElectronics => 'Ex. Téléphone et chargeur';

  @override
  String get descriptionHintFood => 'Ex. Gâteau d’anniversaire';

  @override
  String get descriptionHintBeauty => 'Ex. Perruque, crèmes';

  @override
  String get descriptionHintSecondhand => 'Ex. Lampe ancienne';

  @override
  String get descriptionHintOther => 'Ex. Pièce de moto';

  @override
  String get sizeLabel => 'Taille';

  @override
  String sizeMax(int kg) {
    return '≤ $kg kg';
  }

  @override
  String get sizeHelpS => 'Jusqu’à 2 kg · tient dans une main : enveloppe, téléphone, médicaments.';

  @override
  String get sizeHelpM => 'Jusqu’à 5 kg · boîte à chaussures, petit sac de vêtements.';

  @override
  String get sizeHelpL => 'Jusqu’à 10 kg · carton moyen, sac de linge.';

  @override
  String get sizeHelpXL => 'Jusqu’à 20 kg · gros carton, petit électroménager. Supplément colis XL.';

  @override
  String get sizeBulky => 'Gros objet';

  @override
  String get sizeBulkyBody => 'Frigo, cuisinière, matelas, meuble · livré en tricycle';

  @override
  String get sizeHelpBulky => 'Trop grand ou trop lourd pour une moto. Tarif tricycle, affiché avant de commander.';

  @override
  String get loadingHelpTitle => 'Aide pour charger';

  @override
  String get loadingHelpBody => 'Le livreur vient à deux. Supplément de manutention affiché avant de commander.';

  @override
  String get loadingHelpShort => 'chargement à deux';

  @override
  String get fragileTitle => 'Fragile';

  @override
  String get fragileBody => 'Le livreur le transporte avec soin.';

  @override
  String get codLabel => 'À encaisser auprès du destinataire';

  @override
  String get codHint => '0 si rien à encaisser';

  @override
  String get codHelp =>
      'Le livreur encaisse ce montant à la livraison ; il rejoint vos ventes, reversées sur votre Mobile Money.';

  @override
  String get codTooHigh => '500 000 F au plus par livraison.';

  @override
  String get valueLabel => 'Valeur du contenu (facultatif)';

  @override
  String get valueHint => 'Ex. 25 000';

  @override
  String get valueHelp => 'En FCFA. Indiquée au livreur, utile en cas de litige.';

  @override
  String get valueTooHigh => '10 000 000 F au plus.';

  @override
  String get instructionsLabel => 'Instructions pour le livreur (facultatif)';

  @override
  String get instructionsHint => 'Ex. Appeler en arrivant, sonner au portail vert';

  @override
  String get soundsLabel => 'Sons';

  @override
  String get soundsHint =>
      'Commande envoyée, adresse reçue, colis livré… Le mode silencieux du téléphone est respecté.';

  @override
  String get whenTitle => 'Quand le livreur doit-il passer ?';

  @override
  String get whenBody => 'Il récupère le colis, puis le livre aussitôt.';

  @override
  String get whenNow => 'Maintenant';

  @override
  String get whenNowBody => 'Un livreur part dès que possible.';

  @override
  String get whenLater => 'Programmer';

  @override
  String get whenLaterBody => 'Un jour et une heure, jusqu’à 7 jours à l’avance.';

  @override
  String get dayLabel => 'Jour';

  @override
  String get timeLabel => 'Heure de passage';

  @override
  String get dayToday => 'Aujourd’hui';

  @override
  String get dayTomorrow => 'Demain';

  @override
  String dateAt(String date, String time) {
    return '$date à $time';
  }

  @override
  String scheduledSummary(String when) {
    return 'Enlèvement prévu $when.';
  }

  @override
  String get nightSurcharge => 'Entre 20 h et 6 h, un supplément de nuit s’applique.';

  @override
  String get slotRequired => 'Choisissez une heure de passage.';

  @override
  String get salesToday => 'Encaissé aujourd’hui';

  @override
  String salesDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livraisons',
      one: '1 livraison',
      zero: 'Aucune livraison',
    );
    return '$_temp0';
  }

  @override
  String toReceiveDaily(String amount) {
    return '$amount à recevoir cette nuit';
  }

  @override
  String toReceiveOnDemand(String amount) {
    return '$amount à recevoir';
  }

  @override
  String payoutSent(String amount) {
    return '$amount envoyés sur votre Mobile Money';
  }

  @override
  String get summaryTitle => 'Vérifiez et commandez';

  @override
  String get summaryBody => 'Le prix est calculé pour ce trajet et cette heure.';

  @override
  String get whenNowShort => 'Dès que possible';

  @override
  String deliveryNumber(int n) {
    return 'Livraison $n';
  }

  @override
  String waitingPoint(String name) {
    return 'En attente du point de $name';
  }

  @override
  String get removeDelivery => 'Retirer';

  @override
  String get addDelivery => 'Ajouter une livraison';

  @override
  String get addDeliveryHint => 'Jusqu’à 10 livraisons depuis le même enlèvement : un seul passage du livreur.';

  @override
  String get priceBase => 'Course';

  @override
  String get priceBaseTricycle => 'Course en tricycle';

  @override
  String get surchargeExpress => 'Express';

  @override
  String get surchargeHeavy => 'Colis XL';

  @override
  String get surchargeHandling => 'Manutention (chargement à deux)';

  @override
  String get surchargeNight => 'Supplément de nuit';

  @override
  String get surchargeWeather => 'Supplément météo';

  @override
  String get surchargeOther => 'Supplément';

  @override
  String get discount => 'Réduction';

  @override
  String get totalLabel => 'Total';

  @override
  String get quoting => 'Calcul du prix…';

  @override
  String get promoLabel => 'Code promo';

  @override
  String get promoHint => 'Ex. BIENVENUE';

  @override
  String get applyPromo => 'Appliquer';

  @override
  String promoApplied(String code) {
    return 'Code $code appliqué';
  }

  @override
  String get whoPays => 'Qui paie la course ?';

  @override
  String get payerMe => 'Moi';

  @override
  String get payerRecipient => 'Le destinataire';

  @override
  String get recipientPaysBody => 'Le destinataire paie la course à la livraison, en espèces ou par Mobile Money.';

  @override
  String get paymentLabel => 'Moyen de paiement';

  @override
  String get payMtn => 'MTN Mobile Money';

  @override
  String get payOrange => 'Orange Money';

  @override
  String get payMomoBody => 'Vous validez le paiement sur votre téléphone.';

  @override
  String get payWallet => 'Solde Tara';

  @override
  String get payWalletShop => 'Mes ventes';

  @override
  String payWalletBody(String amount) {
    return 'Disponible : $amount';
  }

  @override
  String walletTooLow(String amount) {
    return 'Disponible : $amount, pas assez pour cette commande.';
  }

  @override
  String get payCash => 'Espèces à l’enlèvement';

  @override
  String get payCashBody => 'Vous payez le livreur quand il récupère le colis.';

  @override
  String get payerPhoneLabel => 'Numéro qui paie';

  @override
  String orderFor(String amount) {
    return 'Commander · $amount';
  }

  @override
  String get orderSlide => 'Glisser pour commander';

  @override
  String get paymentRequired => 'Choisissez comment payer.';

  @override
  String linkPendingBlock(String name) {
    return 'Attendez que $name place son point, ou placez-le vous-même.';
  }

  @override
  String get payingTitle => 'Validez le paiement sur votre téléphone';

  @override
  String payingBody(String amount, String phone) {
    return 'Une demande de $amount arrive sur le $phone : entrez votre code secret Mobile Money pour la valider.';
  }

  @override
  String get paymentFailed => 'Le paiement n’a pas abouti.';

  @override
  String get retryPayment => 'Renvoyer la demande';

  @override
  String get cancelOrder => 'Annuler la commande';

  @override
  String get cancelReasonUnpaid => 'Paiement Mobile Money non abouti';

  @override
  String get placedTitle => 'Commande envoyée !';

  @override
  String get placedScheduledTitle => 'Livraison programmée !';

  @override
  String get pickupCodeLabel => 'Code d’enlèvement';

  @override
  String get pickupCodeHelp => 'Donnez-le au livreur quand il récupère le colis. Notez-le : il ne sera plus affiché.';

  @override
  String get searchingRider => 'Recherche d’un livreur…';

  @override
  String get riderFound => 'Livreur trouvé ! Il vient chercher le colis.';

  @override
  String scheduledPickup(String when) {
    return 'Le livreur passera $when.';
  }

  @override
  String get backHome => 'Retour à l’accueil';

  @override
  String payWalletShopBody(String amount) {
    return 'Pris sur vos ventes : il vous restera $amount à recevoir.';
  }

  @override
  String get trackAwaitingPayment => 'En attente du paiement';

  @override
  String get trackAwaitingPaymentBody => 'Validez le paiement Mobile Money pour lancer la recherche d’un livreur.';

  @override
  String get trackScheduled => 'Livraison programmée';

  @override
  String get trackSearching => 'Recherche d’un livreur…';

  @override
  String get trackSearchingBody => 'Les livreurs proches de l’enlèvement reçoivent la course.';

  @override
  String trackAssigned(String rider) {
    return '$rider vient chercher le colis';
  }

  @override
  String get trackAssignedBody => 'Donnez-lui le code d’enlèvement à son arrivée.';

  @override
  String trackOnTheWay(String recipient) {
    return 'En route vers $recipient';
  }

  @override
  String trackOnTheWayBody(String time) {
    return 'Colis récupéré à $time.';
  }

  @override
  String get trackFailed => 'Livraison impossible';

  @override
  String get trackFailedBody => 'Le livreur n’a pas pu livrer. Choisissez la suite : nouvelle tentative ou retour.';

  @override
  String get trackDelivered => 'Colis livré !';

  @override
  String trackDeliveredBody(String recipient, String time) {
    return 'Remis à $recipient à $time.';
  }

  @override
  String get trackReturned => 'Colis retourné';

  @override
  String get trackCancelled => 'Livraison annulée';

  @override
  String get trackRefused => 'Colis refusé à l’enlèvement';

  @override
  String trackRefusedBody(String reason, String fee) {
    return '$reason. La commande est annulée ; le déplacement du livreur ($fee) est à votre charge. Un désaccord ? Appelez le service client.';
  }

  @override
  String trackEta(int minutes) {
    return 'Environ $minutes min';
  }

  @override
  String get stepOrdered => 'Commande';

  @override
  String get stepRiderFound => 'Livreur';

  @override
  String get stepPickedUp => 'Récupéré';

  @override
  String get stepDelivered => 'Livré';

  @override
  String get vehicleMotorbike => 'Moto';

  @override
  String get vehicleTricycle => 'Tricycle';

  @override
  String get vehicleCar => 'Voiture';

  @override
  String callRider(String name) {
    return 'Appeler $name';
  }

  @override
  String forRecipient(String name) {
    return 'Pour $name';
  }

  @override
  String get newPickupCode => 'Nouveau code d’enlèvement';

  @override
  String pickupCodeShown(String code) {
    return 'Code d’enlèvement : $code';
  }

  @override
  String get cancelDelivery => 'Annuler la livraison';

  @override
  String get cancelConfirm => 'Touchez encore pour confirmer l’annulation.';

  @override
  String get cancelReasonSender => 'Annulée par l’expéditeur';

  @override
  String deliveredBy(String rider) {
    return 'Livré par $rider';
  }

  @override
  String deliveredIn(int minutes) {
    return 'en $minutes min';
  }

  @override
  String collectedAmount(String amount) {
    return '$amount encaissés';
  }

  @override
  String get shareRecap => 'Partager';

  @override
  String recapShareText(String reference, String recipient, String time) {
    return 'Colis livré par Tara · $reference · $recipient · $time';
  }

  @override
  String get trackOrderError => 'Impossible de charger le suivi.';

  @override
  String get trackDelivery => 'Suivre la livraison';

  @override
  String get statusRetrying => 'Nouvelle tentative en cours';

  @override
  String get statusReturning => 'Retour en cours';

  @override
  String get failureReasonRecipientAbsent => 'Destinataire absent';

  @override
  String get failureReasonRecipientUnreachable => 'Destinataire injoignable';

  @override
  String get failureReasonRefused => 'Colis refusé par le destinataire';

  @override
  String get failureReasonAddressNotFound => 'Adresse introuvable';

  @override
  String get failureReasonPaymentRefused => 'Le destinataire a refusé de payer';

  @override
  String get failureReasonOther => 'Autre motif';

  @override
  String failureReported(String reason, String rider, String time) {
    return '$reason · signalé par $rider à $time';
  }

  @override
  String failureDue(String time) {
    return 'Avant $time';
  }

  @override
  String get failureDueBody => 'Sans réponse d’ici là, le colis vous est rapporté.';

  @override
  String get failureRetryTitle => 'Nouvelle tentative';

  @override
  String failureRetryBody(String rider, String recipient) {
    return '$rider repasse chez $recipient. Appelez d’abord pour convenir du moment.';
  }

  @override
  String get failureReturnTitle => 'Retour du colis';

  @override
  String failureReturnBody(String rider, String place) {
    return '$rider vous rapporte le colis : $place.';
  }

  @override
  String get failureChoose => 'Choisissez une option';

  @override
  String get failureConfirmRetry => 'Confirmer la tentative';

  @override
  String get failureConfirmReturn => 'Confirmer le retour';

  @override
  String get failureConfirmRetrySemantics => 'Glisser pour demander une nouvelle tentative';

  @override
  String get failureConfirmReturnSemantics => 'Glisser pour demander le retour du colis';

  @override
  String callRecipient(String name) {
    return 'Appeler $name';
  }

  @override
  String get trackRetrying => 'Nouvelle tentative';

  @override
  String trackRetryingBody(String rider, String recipient) {
    return '$rider repart livrer $recipient.';
  }

  @override
  String get trackReturning => 'Retour du colis';

  @override
  String trackReturningBody(String rider) {
    return '$rider vous rapporte le colis.';
  }

  @override
  String get returnCodeHint =>
      'Quand le livreur vous rend le colis, donnez-lui le code de retour reçu par SMS : c’est la preuve que vous l’avez récupéré.';

  @override
  String get newReturnCode => 'Nouveau code de retour';

  @override
  String returnCodeShown(String code) {
    return 'Code de retour : $code';
  }

  @override
  String trackReturnedBody(String time) {
    return 'Le colis vous a été rendu à $time.';
  }

  @override
  String get stepFailed => 'Échec';

  @override
  String get stepReturned => 'Retourné';

  @override
  String riderNoteQuoted(String note) {
    return '« $note »';
  }

  @override
  String get returnToPickup => 'Retour au point d’enlèvement';

  @override
  String failureBannerTitle(String reference) {
    return 'Livraison impossible · $reference';
  }

  @override
  String get failureBannerBody => 'Touchez pour choisir : nouvelle tentative ou retour.';

  @override
  String get rateTitle => 'Comment s’est passée la livraison ?';

  @override
  String rateBody(String rider) {
    return 'Notez $rider : les livreurs les mieux notés reçoivent plus de courses.';
  }

  @override
  String starsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count étoiles', one: '1 étoile');
    return '$_temp0';
  }

  @override
  String get starWord1 => 'Très décevant';

  @override
  String get starWord2 => 'Décevant';

  @override
  String get starWord3 => 'Correct';

  @override
  String get starWord4 => 'Bien';

  @override
  String get starWord5 => 'Parfait !';

  @override
  String get rateCommentHint => 'Un mot pour l’équipe Tara (facultatif)';

  @override
  String get rateSend => 'Envoyer ma note';

  @override
  String get rateThanks => 'Merci pour votre note !';

  @override
  String get rateThanksBody => 'Votre avis reste entre vous et Tara.';

  @override
  String failureFeesNote(String retry, String ret) {
    return 'En cas d’échec de livraison : nouvelle tentative $retry, retour du colis $ret, à votre charge. Le colis retourné vous est rendu contre paiement de ce que votre solde Tara ne couvre pas.';
  }

  @override
  String refusalFeeNote(String fee) {
    return 'Colis différent de ce que vous déclarez (trop grand, trop lourd, interdit) : le livreur peut le refuser, et son déplacement ($fee) reste à votre charge.';
  }

  @override
  String get retryUsed => 'Une seule nouvelle tentative est possible : le colis vous sera rapporté.';

  @override
  String returnFeeHint(String amount) {
    return 'Frais de retour : $amount, pris sur votre solde Tara. S’il ne suffit pas, vous réglez le reste au livreur à la remise du colis (espèces ou Mobile Money).';
  }

  @override
  String topUpTitle(String amount) {
    return 'Rechargez $amount pour la nouvelle tentative';
  }

  @override
  String get topUpBody =>
      'Votre solde Tara ne couvre pas les frais. Payez par Mobile Money : la nouvelle tentative est confirmée dès le paiement validé.';

  @override
  String topUpPay(String amount) {
    return 'Payer $amount';
  }

  @override
  String topUpPending(String amount) {
    return 'Validez le paiement de $amount sur votre téléphone avec votre code secret Mobile Money.';
  }

  @override
  String get topUpFailed => 'Le paiement n’a pas abouti. Réessayez, ou choisissez le retour du colis.';

  @override
  String get topUpCancel => 'Choisir le retour à la place';

  @override
  String get termsTitle => 'Conditions d’utilisation';

  @override
  String get termsUpdateTitle => 'Nos conditions ont changé';

  @override
  String get termsSignupIntro =>
      'Avant de créer votre compte, lisez les conditions et la politique de confidentialité jusqu’en bas. Elles expliquent les prix, les frais quand une livraison échoue et ce que nous faisons de vos données.';

  @override
  String get termsUpdateIntro =>
      'Lisez la nouvelle version jusqu’en bas, puis signez-la avec le code reçu par SMS. Sans signature, vous suivez vos livraisons en cours mais ne pouvez plus en commander de nouvelles.';

  @override
  String get termsLater => 'Plus tard';

  @override
  String get termsEnd => 'Vous êtes arrivé au bout des textes.';

  @override
  String get termsScrollFirst => 'Faites défiler les textes jusqu’en bas pour pouvoir les accepter.';

  @override
  String get termsCheckPrefix => 'J’ai lu et j’accepte les ';

  @override
  String termsCheckTerms(String version) {
    return 'conditions d’utilisation (version $version)';
  }

  @override
  String get termsCheckAnd => ' et la ';

  @override
  String get termsCheckPrivacy => 'politique de confidentialité';

  @override
  String get termsCreateAccount => 'Accepter et créer mon compte';

  @override
  String get termsGetCode => 'Recevoir le code pour signer';

  @override
  String termsCodeSent(String phone) {
    return 'Code envoyé au $phone. Il vaut signature de votre acceptation.';
  }

  @override
  String get termsSign => 'Signer';

  @override
  String termsAcceptedOn(String version, String date) {
    return 'Version $version acceptée le $date';
  }

  @override
  String termsVersionLine(String version) {
    return 'Version $version';
  }

  @override
  String get termsSection => 'Conditions et confidentialité';

  @override
  String get termsToSign => 'Nouvelle version à lire et signer';

  @override
  String get termsSigned => 'Conditions signées. Merci !';

  @override
  String get termsPrivacyTitle => 'Politique de confidentialité';

  @override
  String get walletTitle => 'Portefeuille';

  @override
  String get shopToReceive => 'Ventes à recevoir';

  @override
  String shopPayoutDaily(String hour, String phone) {
    return 'Reversées chaque jour à $hour h sur le $phone.';
  }

  @override
  String shopPayoutOnDemand(String phone) {
    return 'Reversées à votre demande sur le $phone.';
  }

  @override
  String shopToday(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livraisons',
      one: '1 livraison',
      zero: 'aucune livraison',
    );
    return 'Aujourd’hui : $amount encaissés · $_temp0';
  }

  @override
  String shopDebt(String amount) {
    return 'Frais d’échec à régler : $amount. Ils seront pris sur vos prochaines ventes ; au-delà de 3 000 F, vos nouvelles commandes attendent le règlement.';
  }

  @override
  String payoutOpen(String amount) {
    return 'Reversement en cours : $amount';
  }

  @override
  String payoutNow(String amount) {
    return 'Recevoir $amount maintenant';
  }

  @override
  String get payoutRequested => 'Reversement demandé : l’argent arrive sur votre Mobile Money.';

  @override
  String get taraBalance => 'Solde Tara';

  @override
  String get taraBalanceBody => 'Sert à payer vos livraisons et, s’il y en a, les frais d’échec.';

  @override
  String get topUpAction => 'Recharger';

  @override
  String get withdrawAction => 'Retirer';

  @override
  String get topUpHowMuch => 'Combien voulez-vous ajouter ?';

  @override
  String topUpDone(String amount) {
    return 'Solde rechargé de $amount.';
  }

  @override
  String withdrawBody(String amount, String phone) {
    return 'Tout votre solde ($amount) part sur votre numéro $phone.';
  }

  @override
  String withdrawConfirm(String amount) {
    return 'Retirer $amount';
  }

  @override
  String get withdrawDone => 'Retrait demandé : l’argent arrive sur votre Mobile Money.';

  @override
  String get movements => 'Mouvements';

  @override
  String get movementsShop => 'Boutique';

  @override
  String get movementsBalance => 'Solde Tara';

  @override
  String get movementsEmpty => 'Aucun mouvement pour l’instant.';

  @override
  String get seeMore => 'Voir plus';

  @override
  String get lineCodCollected => 'Vente encaissée';

  @override
  String get lineOrderCharged => 'Livraison payée';

  @override
  String get lineOrderReleased => 'Frais rendus (annulation)';

  @override
  String get lineFailureFee => 'Frais d’échec';

  @override
  String get lineCredit => 'Avoir de Tara';

  @override
  String get lineTopUp => 'Recharge';

  @override
  String get linePayout => 'Reversement';

  @override
  String get lineWithdrawal => 'Retrait';

  @override
  String get linePayoutFailed => 'Reversement échoué, montant rendu';

  @override
  String get lineRefund => 'Remboursement';

  @override
  String get payoutsTitle => 'Reversements';

  @override
  String get payoutStatusDone => 'Reçu';

  @override
  String get payoutStatusOpen => 'En cours';

  @override
  String get payoutStatusFailed => 'Échoué, montant rendu';

  @override
  String get statementsTitle => 'Relevés mensuels';

  @override
  String get statementsBody => 'Le relevé PDF de chaque mois : encaissements, frais, reversements, soldes.';

  @override
  String statementCurrent(String month) {
    return '$month (en cours)';
  }

  @override
  String statementShare(String month) {
    return 'Relevé Tara de $month';
  }

  @override
  String walletBalanceTile(String amount) {
    return 'Solde Tara : $amount';
  }

  @override
  String get askTitle => 'Demander l’adresse';

  @override
  String get askIntro =>
      'Envoyez un lien à votre client : il place lui-même son point et écrit un repère. Vous êtes prévenu dès que c’est fait, et la livraison se crée avec son adresse.';

  @override
  String get askSendWhatsapp => 'Envoyer par WhatsApp';

  @override
  String get askSendSms => 'Par SMS';

  @override
  String askSent(String name) {
    return 'Lien envoyé à $name. Vous serez prévenu dès qu’il aura placé son point.';
  }

  @override
  String get askRequested => 'Adresses demandées';

  @override
  String get askNone => 'Aucune adresse demandée pour l’instant.';

  @override
  String askPending(String date) {
    return 'En attente · lien valable jusqu’au $date';
  }

  @override
  String askReceived(String landmark) {
    return 'Point reçu · $landmark';
  }

  @override
  String get askExpired => 'Expiré sans réponse';

  @override
  String get askCreateOrder => 'Créer la livraison';

  @override
  String get askResend => 'Renvoyer';

  @override
  String askArrived(String name) {
    return '$name a placé son point : vous pouvez créer la livraison.';
  }

  @override
  String get myAddresses => 'Mes adresses';

  @override
  String get myAddressesEmpty =>
      'Enregistrez votre boutique ou votre maison : elles vous seront proposées pour l’enlèvement.';

  @override
  String get addAddress => 'Ajouter une adresse';

  @override
  String get newAddressTitle => 'Nouvelle adresse';

  @override
  String removeAddress(String label) {
    return 'Retirer $label';
  }

  @override
  String removeAddressConfirm(String label) {
    return 'Retirer « $label » de vos adresses ? Les livraisons passées ne changent pas.';
  }

  @override
  String get removeYes => 'Oui, retirer';

  @override
  String get mediaSection => 'Pour aider le livreur (facultatif)';

  @override
  String get facadePhoto => 'Photo de la façade';

  @override
  String get facadePhotoHint => 'Le livreur reconnaît l’entrée au premier coup d’œil.';

  @override
  String get takePhoto => 'Prendre la photo';

  @override
  String get retake => 'Reprendre';

  @override
  String get removeMedia => 'Retirer';

  @override
  String get voiceNote => 'Note vocale';

  @override
  String get voiceNoteHint => '30 secondes pour expliquer le chemin, dans la langue de votre choix.';

  @override
  String get recordNote => 'Enregistrer';

  @override
  String recordingNote(String elapsed) {
    return 'Enregistrement… $elapsed / 0:30';
  }

  @override
  String get stopRecording => 'Arrêter';

  @override
  String listenNote(String length) {
    return 'Écouter ($length)';
  }

  @override
  String get stopListening => 'Arrêter l’écoute';

  @override
  String get redoNote => 'Refaire';

  @override
  String get micDenied => 'Micro refusé : autorisez-le pour Tara dans les réglages du téléphone.';

  @override
  String get facadePhotoLabel => 'Photo de la façade prise';
}
