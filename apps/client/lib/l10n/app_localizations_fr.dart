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
  String get whereToDeliver => 'Où livrer ?';

  @override
  String get whereToDeliverHint => 'Nom, numéro ou quartier du client';

  @override
  String get quickBulk => 'Plusieurs colis';

  @override
  String get quickAskAddress => 'Demander l’adresse';

  @override
  String get quickReceipts => 'Mes reçus';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get chipDecide => 'Décider';

  @override
  String get chipPay => 'Payer';

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
  String get glassLabel => 'Transparence des barres';

  @override
  String get glassClear => 'Verre';

  @override
  String get glassBalanced => 'Équilibré';

  @override
  String get glassOpaque => 'Opaque';

  @override
  String get glassHint => 'Change la transparence de la barre du bas et des boutons posés en bas de l’écran.';

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
  String get pinHint =>
      'Faites glisser la carte : l’épingle au centre marque l’entrée exacte. Le quartier s’affiche dès qu’elle est posée.';

  @override
  String get pinPlaced => 'Point placé';

  @override
  String get pinOutOfArea => 'Hors de la zone desservie';

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
  String get parcelPhotoTitle => 'Photographier le colis';

  @override
  String get parcelPhotoBody => 'Facultatif · nous proposons la taille et la nature, vous vérifiez.';

  @override
  String get parcelPhotoAnalyzing => 'Analyse de la photo…';

  @override
  String get parcelPhotoAnalyzingBody => 'Quelques secondes.';

  @override
  String get parcelPhotoApplied => 'Proposition appliquée';

  @override
  String parcelPhotoAppliedBody(String summary) {
    return '$summary. Vérifiez ci-dessous.';
  }

  @override
  String get parcelPhotoNotParcel => 'Pas de colis reconnu';

  @override
  String get parcelPhotoNotParcelBody => 'Reprenez la photo en cadrant le colis seul.';

  @override
  String get parcelPhotoAttached => 'Photo jointe';

  @override
  String get parcelPhotoAttachedBody => 'Le livreur la verra. Choisissez la taille et la nature ci-dessous.';

  @override
  String parcelPhotoProhibited(String items) {
    return 'La photo semble montrer : $items. Ces objets sont interdits. Si c’est une erreur, vous pouvez continuer : l’équipe Tara et le livreur en seront informés.';
  }

  @override
  String sizeShort(String size) {
    return 'Taille $size';
  }

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
      'Le livreur encaisse ce montant à la livraison ; il rejoint vos ventes, moins 2 % de frais d’encaissement (250 F au moins), et vous est reversé sur votre Mobile Money.';

  @override
  String get codTooHigh => '500 000 F au plus par livraison.';

  @override
  String get valueLabel => 'Valeur du contenu (facultatif)';

  @override
  String get valueHint => 'Ex. 25 000';

  @override
  String get valueHelp =>
      'En FCFA. Jamais montrée au livreur. Fixe ce que Tara vous rembourse en cas de perte ou de dommage : gratuit jusqu’à 25 000 F, puis 1 % de la valeur au-delà.';

  @override
  String valueFeeHint(String amount) {
    return 'Garantie : +$amount sur le prix de la livraison.';
  }

  @override
  String get valueFeeLine => 'Garantie de la valeur';

  @override
  String get valueTooHigh =>
      '500 000 F au plus. Pour un colis de plus grande valeur, appelez le service client avant d\'envoyer.';

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
    return 'Colis n° $n';
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
  String get addDeliveryHint =>
      'Jusqu’à 10 colis depuis le même enlèvement : un seul code, un seul paiement. Chaque colis part avec un livreur adapté à sa taille.';

  @override
  String get priceBase => 'Course';

  @override
  String get mobileMoneyFeeLine => 'Frais Mobile Money';

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
  String proDiscountLine(String percent) {
    return 'Tarif pro ($percent)';
  }

  @override
  String promoBeatenByPro(String percent) {
    return 'Votre tarif pro (−$percent) est plus avantageux : ce code n’est pas utilisé.';
  }

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
  String get trackSenderAbsent => 'Le livreur est reparti';

  @override
  String trackSenderAbsentBody(int minutes, String fee) {
    return 'Il vous a attendu $minutes min et vous a appelé. La course est annulée ; annulation et attente vous sont facturées : $fee.';
  }

  @override
  String trackRiderWaiting(String rider) {
    return '$rider vous attend';
  }

  @override
  String trackRiderWaitingBody(String until, String fee, int step, String max) {
    return 'Donnez-lui le colis et le code d’enlèvement. Attente gratuite jusqu’à $until, puis $fee par $step min commencées, $max au plus.';
  }

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
  String cancelConfirmFee(String amount) {
    return 'Le livreur est déjà en route : annuler coûte $amount, pour son déplacement. Touchez encore pour confirmer.';
  }

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
      'Lisez la nouvelle version jusqu’en bas, puis acceptez-la. Sans acceptation, vous suivez vos livraisons en cours mais ne pouvez plus en commander de nouvelles.';

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
  String get termsAcceptUpdate => 'J’accepte la nouvelle version';

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
  String get termsToSign => 'Nouvelle version à lire et accepter';

  @override
  String get termsSigned => 'Conditions acceptées. Merci !';

  @override
  String get termsPrivacyTitle => 'Politique de confidentialité';

  @override
  String get walletTitle => 'Portefeuille';

  @override
  String get shopToReceive => 'Ventes à recevoir';

  @override
  String shopPayoutWaitsMinimum(String min) {
    return 'Mobile Money n’envoie pas moins de $min : vos ventes restent sur votre solde et partent le soir où elles atteignent ce montant.';
  }

  @override
  String shopPayoutFromMinimum(String min) {
    return 'Reversement possible à partir de $min (minimum de Mobile Money).';
  }

  @override
  String taraWithdrawFromMinimum(String min) {
    return 'Retrait vers Mobile Money possible à partir de $min. En attendant, ce solde paie vos livraisons.';
  }

  @override
  String deleteAccountSmallBalance(String amount, String min) {
    return 'Il vous reste $amount chez Tara, moins que le plus petit envoi Mobile Money ($min). Utilisez-les pour vos livraisons, ou appelez le service client de Tara.';
  }

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
  String shopWithdrawalRule(String amount, String rate) {
    return 'Reversement et retrait gratuits dès $amount ; en dessous, $rate de frais Mobile Money retenus.';
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
  String topUpFeeNote(String fee) {
    return '+ $fee de frais Mobile Money (frais de l’opérateur).';
  }

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
  String get lineReserve => 'Réserve pour vos livraisons';

  @override
  String get lineCancellationFee => 'Annulation, livreur en route';

  @override
  String get lineWaitingFee => 'Attente du livreur';

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

  @override
  String get supportTitle => 'Aide et service client';

  @override
  String get supportIntro =>
      'Une question, un souci avec une livraison ? Écrivez-nous : l’équipe Tara vous répond ici et vous êtes prévenu de sa réponse.';

  @override
  String get supportNewRequest => 'Nouvelle demande';

  @override
  String get supportEmpty =>
      'Aucune demande pour l’instant. Pour un souci avec une livraison, vous pouvez aussi la signaler depuis son suivi.';

  @override
  String supportCallUs(String phone) {
    return 'Urgent ? Appelez le $phone';
  }

  @override
  String get supportCategoryLostParcel => 'Colis perdu ou non reçu';

  @override
  String get supportCategoryDamagedParcel => 'Colis abîmé';

  @override
  String get supportCategoryLateDelivery => 'Retard';

  @override
  String get supportCategoryPayment => 'Paiement';

  @override
  String get supportCategoryRiderBehavior => 'Comportement du livreur';

  @override
  String get supportCategoryAppBug => 'Problème dans l’app';

  @override
  String get supportCategoryOther => 'Autre';

  @override
  String get supportStatusOpen => 'Envoyée';

  @override
  String get supportStatusInProgress => 'En cours';

  @override
  String get supportStatusResolved => 'Résolue';

  @override
  String get supportStatusClosed => 'Close';

  @override
  String get supportNewTitle => 'Nouvelle demande';

  @override
  String get supportReasonLabel => 'Motif';

  @override
  String get supportSubjectLabel => 'En quelques mots';

  @override
  String get supportSubjectHint => 'Ex. : colis non reçu par ma cliente';

  @override
  String get supportMessageLabel => 'Expliquez-nous';

  @override
  String get supportMessageHint => 'Ce qui s’est passé et ce que vous attendez de Tara.';

  @override
  String supportOrderLine(String reference) {
    return 'Commande $reference';
  }

  @override
  String get supportSend => 'Envoyer la demande';

  @override
  String get supportReplyHint => 'Votre réponse…';

  @override
  String get supportReplySend => 'Envoyer';

  @override
  String get supportClosedNote => 'Cette demande est close. Ouvrez une nouvelle demande si besoin.';

  @override
  String get supportFromTara => 'Service client Tara';

  @override
  String get supportNewAnswer => 'Réponse';

  @override
  String get supportWaitingNote => 'L’équipe Tara vous répond ici ; vous serez prévenu.';

  @override
  String get supportMenuRow => 'Écrire au service client';

  @override
  String get supportMenuRowSubtitle => 'Vos demandes et les réponses de Tara';

  @override
  String get reportProblem => 'Signaler un problème';

  @override
  String get accountDataSection => 'Mon compte et mes données';

  @override
  String get exportDataRow => 'Télécharger mes données';

  @override
  String get exportDataRowSubtitle => 'Une copie de tout ce que Tara garde sur vous';

  @override
  String get exportDataShare => 'Mes données Tara';

  @override
  String get deleteAccountRow => 'Supprimer mon compte';

  @override
  String get deleteAccountRowSubtitle => 'Définitif, confirmé par votre code secret';

  @override
  String get deleteAccountTitle => 'Supprimer mon compte';

  @override
  String get deleteAccountBody =>
      'Votre nom, votre numéro, vos adresses, photos et notes vocales sont effacés, et l’app se déconnecte. Vos livraisons passées restent, sans votre nom, pour la comptabilité.';

  @override
  String get deleteAccountFinal => 'C’est définitif : avec le même numéro, vous repartirez d’un compte vide.';

  @override
  String deleteAccountBalance(String amount) {
    return 'Il vous reste $amount chez Tara : retirez-les d’abord vers votre Mobile Money.';
  }

  @override
  String deleteAccountDebt(String amount) {
    return 'Votre boutique doit $amount à Tara : ils doivent être réglés avant la suppression.';
  }

  @override
  String get deleteAccountPayout => 'Un retrait vers votre Mobile Money est en cours : attendez qu’il arrive.';

  @override
  String get openWallet => 'Ouvrir mon portefeuille';

  @override
  String get deleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get topUpOther => 'Autre montant (F)';

  @override
  String get topUpOtherHint => 'Ex. 15000';

  @override
  String topUpRange(String min, String max) {
    return 'Montant entre $min et $max.';
  }

  @override
  String get failureReasonDamaged =>
      'Le destinataire a refusé le colis : il était abîmé. Une réclamation est ouverte, l’équipe Tara vous contacte.';

  @override
  String get pinCreateTitle => 'Choisissez votre code secret';

  @override
  String get pinCreateBody =>
      '4 chiffres, comme pour Orange Money ou MoMo. Il protège votre solde et vos retraits. Ne le donnez à personne, même à Tara.';

  @override
  String get pinConfirmTitle => 'Confirmez votre code secret';

  @override
  String get pinMismatch => 'Les deux codes sont différents. Recommencez.';

  @override
  String get pinEnterTitle => 'Code secret';

  @override
  String get pinCurrentTitle => 'Votre code secret actuel';

  @override
  String get pinNewTitle => 'Nouveau code secret';

  @override
  String get pinForgot => 'Code oublié ?';

  @override
  String get pinUseBiometrics => 'Utiliser aussi mon empreinte';

  @override
  String get pinBiometricButton => 'Utiliser mon empreinte';

  @override
  String get pinBiometricTitle => 'Confirmez avec votre empreinte';

  @override
  String get pinDelete => 'Effacer';

  @override
  String pinDigitsEntered(int count) {
    return '$count chiffre(s) sur 4';
  }

  @override
  String get pinLockedTitle => 'Code secret bloqué';

  @override
  String get pinLockedBody =>
      'Après 5 erreurs, votre code secret est bloqué. Recevez un code sur votre numéro pour en choisir un nouveau.';

  @override
  String get pinResetBody => 'Recevez un code sur votre numéro pour choisir un nouveau code secret.';

  @override
  String get pinSendCode => 'Recevoir un code';

  @override
  String get pinCodeSentSms => 'Entrez le code reçu par SMS.';

  @override
  String get pinCodeSentWhatsApp => 'Entrez le code reçu sur WhatsApp.';

  @override
  String get codeBySms => 'Recevoir par SMS';

  @override
  String codeSentWhatsAppTo(String phone) {
    return 'Code envoyé sur WhatsApp au $phone';
  }

  @override
  String get pinSaved => 'Code secret enregistré.';

  @override
  String get balanceShow => 'Afficher le solde';

  @override
  String get balanceHide => 'Masquer le solde';

  @override
  String get pinReasonBalance => 'Pour voir votre solde';

  @override
  String pinReasonWithdraw(String amount) {
    return 'Pour retirer $amount';
  }

  @override
  String get pinRowTitle => 'Code secret';

  @override
  String get pinRowSet => 'Changer mon code secret';

  @override
  String get pinRowNotSet => 'Choisir mon code secret';

  @override
  String get biometricRowTitle => 'Empreinte digitale';

  @override
  String get biometricRowBody => 'Confirmer avec l\'empreinte au lieu du code';

  @override
  String get pinReasonDelete => 'Pour supprimer votre compte';

  @override
  String get deleteAccountConfirmPin => 'Supprimer avec mon code secret';

  @override
  String get securitySection => 'Sécurité';

  @override
  String trackPayNow(String amount) {
    return 'Payer $amount par Mobile Money';
  }

  @override
  String get trackPayPending => 'Validez la demande de paiement sur votre téléphone…';

  @override
  String get trackPayFailed => 'Paiement non abouti. Réessayez, ou annulez la livraison.';

  @override
  String trackPayVia(String operator) {
    return 'La demande de paiement part vers ce numéro $operator.';
  }

  @override
  String cardFailureFees(String retry, String ret) {
    return 'Si la livraison échoue : nouvelle tentative $retry, retour $ret';
  }

  @override
  String get batchFailureFeesNote =>
      'En cas d’échec de livraison, les frais indiqués sur chaque colis sont à votre charge. Le colis retourné vous est rendu contre paiement de ce que votre solde Tara ne couvre pas.';

  @override
  String get batchRefusalFeeNote =>
      'Colis différent de ce que vous déclarez (trop grand, trop lourd, interdit) : le livreur peut le refuser, et son déplacement (le prix d’une nouvelle tentative) reste à votre charge.';

  @override
  String get pickupCodeHelpBatch =>
      'Le même code pour chaque livreur qui vient chercher un colis. Notez-le : il ne sera plus affiché.';

  @override
  String get writeNumbersTitle => 'Écrivez son numéro sur chaque colis';

  @override
  String get writeNumbersBody =>
      'Au marqueur, bien visible. Chaque livreur vient chercher un numéro précis : vous saurez lequel lui donner.';

  @override
  String parcelNumberSemantics(int n) {
    return 'Colis numéro $n';
  }

  @override
  String get riderFoundShort => 'Livreur trouvé';

  @override
  String get riderSearchingShort => 'Recherche';

  @override
  String ridersFound(int found, int total) {
    return 'Livreurs trouvés : $found sur $total';
  }

  @override
  String get allRidersFound => 'Tous les livreurs sont trouvés : ils viennent chercher les colis.';

  @override
  String parcelNumberShort(int n) {
    return 'n° $n';
  }

  @override
  String trackAssignedParcel(String rider, int n) {
    return '$rider vient chercher le colis n° $n';
  }

  @override
  String trackAssignedParcelBody(int n) {
    return 'Donnez-lui le colis n° $n et le code d’enlèvement à son arrivée.';
  }

  @override
  String trackAssignedTour(String rider, String numbers) {
    return '$rider vient chercher les colis n° $numbers';
  }

  @override
  String trackAssignedTourBody(int count) {
    return 'Tous partent en une seule tournée. Donnez-lui ces $count colis et le code d’enlèvement à son arrivée.';
  }

  @override
  String listAnd(String head, String last) {
    return '$head et $last';
  }

  @override
  String get bulkEntry => 'Envoyer plusieurs colis';

  @override
  String get bulkEntryBody => 'Jusqu’à 100 clients d’un coup : collez votre liste ou cochez vos contacts.';

  @override
  String bulkResume(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count clients', one: '1 client');
    return 'Reprendre ma liste · $_temp0';
  }

  @override
  String get bulkTitle => 'Liste d’envoi';

  @override
  String bulkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients',
      one: '1 client',
      zero: 'Aucun client',
    );
    return '$_temp0';
  }

  @override
  String get bulkSettings => 'Pour tous les colis';

  @override
  String get bulkPickupMissing => 'Choisissez d’où partent les colis';

  @override
  String get bulkWhenNow => 'Dès que possible';

  @override
  String get bulkDefaultSize => 'Taille des colis';

  @override
  String get bulkAddPaste => 'Coller';

  @override
  String get bulkAddContacts => 'Contacts';

  @override
  String get bulkAddManual => 'Saisir';

  @override
  String get bulkEmptyTitle => 'Ajoutez vos clients du jour';

  @override
  String get bulkEmptyBody =>
      'Collez votre liste WhatsApp, cochez vos clients ou vos contacts, ou saisissez-les un par un. La liste reste sur votre téléphone jusqu’à l’envoi.';

  @override
  String get bulkLineWaiting => 'Tara lui enverra un lien pour placer son point';

  @override
  String get bulkLineIncomplete => 'À compléter';

  @override
  String bulkPhoneIncomplete(Object digits) {
    return 'numéro incomplet ($digits)';
  }

  @override
  String get bulkPhoneMissing => 'numéro manquant';

  @override
  String get bulkNameMissing => 'nom manquant';

  @override
  String get bulkFull => '100 clients au plus par envoi : envoyez cette liste, puis commencez-en une autre.';

  @override
  String bulkReview(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count colis', one: '1 colis');
    return 'Vérifier et envoyer · $_temp0';
  }

  @override
  String bulkAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients ajoutés',
      one: '1 client ajouté',
      zero: 'Aucun client ajouté',
    );
    return '$_temp0';
  }

  @override
  String get bulkClear => 'Vider la liste';

  @override
  String bulkClearConfirm(int count) {
    return 'Retirer les $count clients de la liste ?';
  }

  @override
  String get bulkClearAction => 'Vider';

  @override
  String bulkAddCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients',
      one: '1 client',
      zero: '',
    );
    return 'Ajouter $_temp0';
  }

  @override
  String get pasteTitle => 'Coller une liste';

  @override
  String get pasteBody =>
      'Copiez vos commandes du jour depuis WhatsApp ou vos notes : une ligne par client, avec son numéro.';

  @override
  String get pasteLabel => 'Votre liste';

  @override
  String get pasteHint => 'Marie 690 11 22 33 Bonapriso 12500';

  @override
  String get pasteFromClipboard => 'Coller ce que j’ai copié';

  @override
  String get pasteUnderstood => 'Ce que Tara a compris';

  @override
  String pasteScore(int ok, int total) {
    return '$ok sur $total';
  }

  @override
  String get pasteNote =>
      'Les montants sont ceux à encaisser auprès du client. Sans adresse connue, Tara envoie au client le lien pour placer son point.';

  @override
  String get pastePrivacy => 'Lu sur votre téléphone : rien ne part avant « Ajouter ».';

  @override
  String get pasteKnownAddress => 'adresse connue';

  @override
  String get contactsTitle => 'Choisir des clients';

  @override
  String get contactsSearch => 'Nom ou numéro';

  @override
  String get contactsKnown => 'Vos clients · adresse déjà connue';

  @override
  String contactsOrders(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count commandes', one: '1 commande');
    return '$_temp0';
  }

  @override
  String get contactsPhone => 'Contacts du téléphone';

  @override
  String get contactsAllow => 'Voir mes contacts';

  @override
  String get contactsAllowBody =>
      'Tara lit vos contacts sur ce téléphone pour vous laisser cocher vos clients. Rien n’est envoyé tant que vous ne les ajoutez pas.';

  @override
  String get contactsDenied => 'Accès aux contacts refusé. Vous pouvez l’autoriser dans les réglages du téléphone.';

  @override
  String get contactsOpenSettings => 'Ouvrir les réglages';

  @override
  String get contactsEmpty => 'Aucun contact avec un numéro de mobile camerounais.';

  @override
  String get contactsNote =>
      'Seuls les clients cochés quittent votre téléphone. Pour ceux sans adresse, Tara leur envoie le lien pour placer leur point.';

  @override
  String get lineNew => 'Nouveau client';

  @override
  String lineTitle(int number) {
    return 'Client n° $number';
  }

  @override
  String lineHintNoted(Object hint) {
    return 'Noté dans votre liste : $hint';
  }

  @override
  String get lineAskLink => 'Le client place son point';

  @override
  String get lineAskLinkBody =>
      'Tara lui envoie un lien par SMS à l’envoi ; son colis part dès qu’il a placé son point.';

  @override
  String get lineLastAddress => 'Sa dernière adresse';

  @override
  String get linePlaceOnMap => 'Placer sur la carte';

  @override
  String get lineSize => 'Taille du colis';

  @override
  String lineSizeDefault(Object size) {
    return 'Comme la liste ($size)';
  }

  @override
  String get lineDescription => 'Contenu du colis (facultatif)';

  @override
  String get lineDescriptionHint => '2 paires de chaussures';

  @override
  String get lineSave => 'Enregistrer';

  @override
  String get lineRemove => 'Retirer de la liste';

  @override
  String get bulkSendTitle => 'Vérifier et envoyer';

  @override
  String bulkReadyLine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis prêts : ils partent tout de suite.',
      one: '1 colis prêt : il part tout de suite.',
    );
    return '$_temp0';
  }

  @override
  String bulkWaitingLine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients n’ont pas encore placé leur point : leurs colis partiront dès qu’ils le feront.',
      one: '1 client n’a pas encore placé son point : son colis partira dès qu’il le fera.',
    );
    return '$_temp0';
  }

  @override
  String bulkIncompleteLine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients à compléter : ils restent dans la liste et ne partent pas.',
      one: '1 client à compléter : il reste dans la liste et ne part pas.',
    );
    return '$_temp0';
  }

  @override
  String get bulkFix => 'Corriger';

  @override
  String bulkCourses(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count colis', one: '1 colis');
    return 'Courses · $_temp0';
  }

  @override
  String get bulkCollect => 'À encaisser pour vous';

  @override
  String get bulkPayNow => 'À payer maintenant';

  @override
  String get bulkWaitingPaidLater =>
      'Un colis qui attend son point est payé quand il part : par vos ventes s’il y en a assez, sinon on vous demande de payer.';

  @override
  String bulkQuoteError(int number, String name, String error) {
    return 'Client n° $number ($name) : $error';
  }

  @override
  String bulkSend(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count colis', one: '1 colis');
    return 'Glisser pour envoyer $_temp0';
  }

  @override
  String get bulkSendSemantics => 'Glisser pour envoyer la liste';

  @override
  String get bulkNothingToSend => 'Ajoutez au moins un client complet.';

  @override
  String get bulkSentTitle => 'Envoi parti !';

  @override
  String bulkSentSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count colis', one: '1 colis');
    return '$_temp0';
  }

  @override
  String get bulkSentWaiting => 'Attend son point';

  @override
  String bulkSentWaitingNote(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count clients sans adresse ont reçu un SMS. Chaque colis partira dès que son client aura placé son point : on vous préviendra.',
      one: 'Le client sans adresse a reçu un SMS. Son colis partira dès qu’il aura placé son point : on vous préviendra.',
    );
    return '$_temp0';
  }

  @override
  String bulkSentIncomplete(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients à compléter restent dans votre liste.',
      one: '1 client à compléter reste dans votre liste.',
    );
    return '$_temp0';
  }

  @override
  String get pendingTitle => 'En attente de l’adresse';

  @override
  String get pendingWaiting => 'Lien envoyé · son colis part dès qu’il a placé son point';

  @override
  String get pendingExpired => 'Lien expiré sans réponse';

  @override
  String get pendingBlocked => 'Point reçu, colis pas encore parti';

  @override
  String get pendingBlockedBalance => 'Point reçu, mais vos ventes ne suffisent pas pour payer la course.';

  @override
  String get pendingResend => 'Renvoyer le lien';

  @override
  String get pendingShare => 'Envoyer le lien par WhatsApp';

  @override
  String pendingShareText(String name, String url) {
    return 'Bonjour $name, pour recevoir votre colis, indiquez où vous livrer : $url';
  }

  @override
  String get pendingRemove => 'Retirer de l’envoi';

  @override
  String pendingRemoveConfirm(int number, String name) {
    return 'Retirer le colis n° $number ($name) ? Rien ne vous sera facturé.';
  }

  @override
  String get pendingPayMomo => 'Payer par Mobile Money';

  @override
  String get pendingRetry => 'Réessayer avec mes ventes';

  @override
  String pendingResent(Object name) {
    return 'Nouveau lien envoyé à $name.';
  }

  @override
  String pendingParcel(int number, String name) {
    return 'Colis n° $number · $name';
  }

  @override
  String get taraBalanceShopBody =>
      'Paie vos livraisons et frais avant vos ventes. Jamais reversé tout seul : retirez-le quand vous voulez.';

  @override
  String get shopPaysDeliveries => 'Vos livraisons se paient d’abord avec votre solde Tara, puis avec vos ventes.';

  @override
  String get payWalletTaraAndSales => 'Solde Tara et ventes';

  @override
  String payWalletTaraBody(Object amount) {
    return 'Pris sur votre solde Tara : il vous restera $amount.';
  }

  @override
  String payWalletBothBody(Object amount) {
    return 'Pris sur votre solde Tara, puis vos ventes : il vous restera $amount à recevoir.';
  }

  @override
  String reserveLine(Object amount) {
    return 'Réserve gardée chaque soir : $amount';
  }

  @override
  String get reserveNone => 'Pas de réserve : toutes vos ventes vous sont reversées.';

  @override
  String get reserveChange => 'Modifier';

  @override
  String get reserveTitle => 'Réserve pour vos livraisons';

  @override
  String reserveBody(Object hour) {
    return 'Au reversement de $hour h, Tara garde ce montant de vos ventes sur votre solde Tara : vos livraisons du lendemain sont déjà payées. Le reste vous est reversé, comme d’habitude.';
  }

  @override
  String get reserveZero => 'Aucune';

  @override
  String get reserveSave => 'Enregistrer';

  @override
  String get reserveSaved => 'Réserve enregistrée.';
}
