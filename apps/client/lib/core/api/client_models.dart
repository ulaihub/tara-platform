import 'package:flutter/foundation.dart';
import 'package:tara_core/api/models.dart';

export 'package:tara_core/api/models.dart';

/// Modèles des réponses de l'API utilisées par l'app expéditeur. Chaque champ lu ici existe
/// dans le contrat `apps/api/openapi.json` (vérifié par test/api_contract_test.dart).

T _field<T>(Json json, String key) => json[key] as T;
DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

@immutable
class MobileMoneyOperator {
  const MobileMoneyOperator(this.code, this.name);
  final String code;
  final String name;
}

/// Réglages publics de l'app (GET /public/config), gardés sur le téléphone.
@immutable
class AppConfig {
  const AppConfig({
    required this.dialCode,
    required this.currency,
    required this.supportPhone,
    required this.operators,
    this.mobileMoneyFeeBps = 0,
    this.waiting = const WaitingRules(),
  });

  factory AppConfig.fromJson(Json json) {
    final country = _field<Json>(json, 'country');
    final waiting = json['waiting'] as Json?;
    return AppConfig(
      dialCode: _field(country, 'dialCode'),
      currency: _field(country, 'currency'),
      supportPhone: _field(json, 'supportPhone'),
      operators: [
        for (final item in _field<List<Object?>>(json, 'mobileMoneyOperators'))
          MobileMoneyOperator(_field(item! as Json, 'code'), _field(item as Json, 'name')),
      ],
      // Réglages gardés d'une version antérieure : sans taux, pas de frais affichés.
      mobileMoneyFeeBps: (json['mobileMoneyFeeBps'] as num?)?.toInt() ?? 0,
      waiting: waiting == null
          ? const WaitingRules()
          : WaitingRules(
              freeMinutes: _field<num>(waiting, 'freeMinutes').toInt(),
              stepMinutes: _field<num>(waiting, 'stepMinutes').toInt(),
              feePerStep: _field<num>(waiting, 'feePerStep').toInt(),
              maxFee: (waiting['maxFee'] as num?)?.toInt() ?? 400,
              maxMinutes: (waiting['maxMinutes'] as num?)?.toInt() ?? 30,
              absentFee: (waiting['absentFee'] as num?)?.toInt() ?? 700,
            ),
    );
  }

  static const fields = ['country', 'supportPhone', 'mobileMoneyOperators', 'mobileMoneyFeeBps', 'waiting'];

  final String dialCode;
  final String currency;
  final String? supportPhone;
  final List<MobileMoneyOperator> operators;

  /// Frais Mobile Money payés par le client, en points de base (600 = 6 %).
  final int mobileMoneyFeeBps;

  /// Attente du livreur au point d'enlèvement : gratuite, puis payante (D).
  final WaitingRules waiting;
}

/// Attente du livreur au point d'enlèvement (D), comptée depuis son arrivée.
@immutable
class WaitingRules {
  const WaitingRules({
    this.freeMinutes = 10,
    this.stepMinutes = 5,
    this.feePerStep = 100,
    this.maxFee = 400,
    this.maxMinutes = 30,
    this.absentFee = 700,
  });

  final int freeMinutes;
  final int stepMinutes;
  final int feePerStep;

  /// Plafond des frais d'attente (30 min d'attente comptées au plus).
  final int maxFee;

  /// Après [maxMinutes] d'attente, le livreur peut partir : [absentFee] facturés à l'expéditeur.
  final int maxMinutes;
  final int absentFee;
}

/// Boutique du marchand (A2) : reversements vers son numéro Mobile Money.
@immutable
class Merchant {
  const Merchant({
    required this.shopName,
    required this.category,
    required this.payoutPhone,
    required this.payoutOperator,
  });

  factory Merchant.fromJson(Json json) => Merchant(
    shopName: _field(json, 'shopName'),
    category: _field(json, 'category'),
    payoutPhone: _field(json, 'payoutPhone'),
    payoutOperator: _field(json, 'payoutOperator'),
  );

  static const fields = ['shopName', 'category', 'payoutPhone', 'payoutOperator'];

  final String shopName;
  final String? category;
  final String payoutPhone;
  final String payoutOperator;
}

/// Compte connecté (GET /me).
@immutable
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.locale,
    required this.referralCode,
    required this.merchant,
  });

  factory Me.fromJson(Json json) {
    final merchant = json['merchant'] as Json?;
    return Me(
      id: _field(json, 'id'),
      phone: _field(json, 'phone'),
      fullName: _field(json, 'fullName'),
      locale: _field(json, 'locale'),
      referralCode: _field(json, 'referralCode'),
      merchant: merchant == null ? null : Merchant.fromJson(merchant),
    );
  }

  static const fields = ['id', 'phone', 'fullName', 'locale', 'referralCode', 'merchant'];

  final String id;
  final String phone;
  final String? fullName;
  final String locale;
  final String? referralCode;
  final Merchant? merchant;

  /// Profil à compléter à la première connexion : le nom figure dans les SMS envoyés aux
  /// destinataires (« Awa vous envoie un colis »).
  bool get needsProfile => (fullName ?? '').trim().length < 2;
}

/// Commande dans une liste (GET /orders) : accueil et historique.
@immutable
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.recipientName,
    required this.dropoffLandmark,
    required this.dropoffNeighborhood,
    required this.totalPrice,
    required this.codAmount,
    required this.scheduledFor,
    required this.createdAt,
    this.failureDecision,
    this.batchNumber,
  });

  factory OrderSummary.fromJson(Json json) => OrderSummary(
    id: _field(json, 'id'),
    reference: _field(json, 'reference'),
    status: _field(json, 'status'),
    batchNumber: (json['batchNumber'] as num?)?.toInt(),
    recipientName: _field(json, 'recipientName'),
    dropoffLandmark: _field(json, 'dropoffLandmark'),
    dropoffNeighborhood: _field(json, 'dropoffNeighborhood'),
    totalPrice: _field<num>(json, 'totalPrice').toInt(),
    codAmount: _field<num>(json, 'codAmount').toInt(),
    scheduledFor: _date(json['scheduledFor']),
    createdAt: DateTime.parse(_field(json, 'createdAt')),
    failureDecision: json['failureDecision'] as String?,
  );

  static const fields = [
    'id',
    'reference',
    'status',
    'recipientName',
    'dropoffLandmark',
    'dropoffNeighborhood',
    'totalPrice',
    'codAmount',
    'scheduledFor',
    'failureDecision',
    'createdAt',
  ];

  final String id;
  final String reference;

  /// Numéro du colis dans son envoi, écrit dessus (null hors envoi de plusieurs colis).
  final int? batchNumber;

  /// CREATED, SEARCHING_RIDER, ASSIGNED, PICKED_UP, IN_DELIVERY, DELIVERY_FAILED,
  /// DELIVERED, RETURNED ou CANCELLED.
  final String status;
  final String recipientName;
  final String dropoffLandmark;
  final String? dropoffNeighborhood;
  final int totalPrice;

  /// Montant à encaisser auprès du destinataire (0 sans encaissement).
  final int codAmount;
  final DateTime? scheduledFor;
  final DateTime createdAt;

  /// Après un échec : RETRY ou RETURN une fois choisi, null tant qu'il faut décider.
  final String? failureDecision;
}

/// Portefeuille (GET /me/wallet) : solde Tara de l'expéditeur, solde de la boutique.
@immutable
class Wallet {
  const Wallet({
    required this.customerBalance,
    required this.merchantBalance,
    required this.payoutSchedule,
    this.todaySales = 0,
    this.todayDeliveries = 0,
    this.plan,
    this.payoutPhone,
    this.payoutHour = 18,
    this.payoutReserve = 0,
    this.withdrawalFreeFrom = 0,
    this.withdrawalFeeBps = 0,
    this.withdrawalFeeSharePercent = 100,
    this.withdrawalMinimum = 0,
    this.customerWithdrawalMinimum = 0,
    this.openPayout,
  });

  factory Wallet.fromJson(Json json) {
    final merchant = json['merchant'] as Json?;
    final open = json['openPayout'] as Json?;
    return Wallet(
      customerBalance: _field<num>(_field<Json>(json, 'customer'), 'balance').toInt(),
      merchantBalance: merchant == null ? null : _field<num>(merchant, 'balance').toInt(),
      payoutSchedule: merchant == null ? null : _field<String>(merchant, 'payoutSchedule'),
      todaySales: merchant == null ? 0 : _field<num>(merchant, 'todaySales').toInt(),
      todayDeliveries: merchant == null ? 0 : _field<num>(merchant, 'todayDeliveries').toInt(),
      plan: merchant == null ? null : _field<String>(merchant, 'plan'),
      payoutPhone: merchant == null ? null : _field<String>(merchant, 'payoutPhone'),
      payoutHour: merchant == null ? 18 : _field<num>(merchant, 'payoutHour').toInt(),
      payoutReserve: merchant == null ? 0 : (merchant['payoutReserve'] as num? ?? 0).toInt(),
      withdrawalFreeFrom: merchant == null ? 0 : _field<num>(_field<Json>(merchant, 'withdrawal'), 'freeFrom').toInt(),
      withdrawalFeeBps: merchant == null ? 0 : _field<num>(_field<Json>(merchant, 'withdrawal'), 'feeBps').toInt(),
      withdrawalFeeSharePercent: merchant == null
          ? 100
          : (_field<Json>(merchant, 'withdrawal')['feeSharePercent'] as num? ?? 100).toInt(),
      // Serveur d'avant : pas de minimum du prestataire.
      withdrawalMinimum: merchant == null ? 0 : (_field<Json>(merchant, 'withdrawal')['minimum'] as num? ?? 0).toInt(),
      customerWithdrawalMinimum: (_field<Json>(json, 'customer')['withdrawalMinimum'] as num? ?? 0).toInt(),
      openPayout: open == null
          ? null
          : (amount: _field<num>(open, 'amount').toInt(), status: _field<String>(open, 'status')),
    );
  }

  static const fields = ['customer', 'merchant', 'openPayout'];

  /// Champs lus dans `merchant` (vérifiés contre le contrat de l'API).
  static const merchantFields = [
    'balance',
    'payoutSchedule',
    'plan',
    'payoutPhone',
    'payoutHour',
    'payoutReserve',
    'todaySales',
    'todayDeliveries',
    'withdrawal',
  ];

  final int customerBalance;

  /// Ventes encaissées pas encore reversées (null sans boutique). Négatif : frais d'échec dus.
  final int? merchantBalance;

  /// DAILY (chaque jour) ou ON_DEMAND (à la demande).
  final String? payoutSchedule;

  /// Boutique : encaissé à la livraison aujourd'hui, et livraisons du jour.
  final int todaySales;
  final int todayDeliveries;

  /// FREE, PRO ou BUSINESS : le reversement à la demande est réservé aux offres payantes.
  final String? plan;

  /// Numéro Mobile Money des reversements de la boutique.
  final String? payoutPhone;

  /// Reversement gratuit à partir de ce montant ; en dessous, ce taux (points de base) est retenu.
  final int withdrawalFreeFrom;
  final int withdrawalFeeBps;

  /// Part des frais payée par la boutique, en % ; Tara paie le reste.
  final int withdrawalFeeSharePercent;

  /// Heure du reversement quotidien (heure du Cameroun).
  final int payoutHour;

  /// Boutique : gardé chaque soir de ses ventes sur son solde Tara, pour ses livraisons.
  final int payoutReserve;

  /// Ce qui peut payer une livraison : le solde Tara, puis les ventes d'une boutique.
  int get spendable => customerBalance + (merchantBalance ?? 0);

  /// Plus petit envoi que le prestataire Mobile Money accepte (0 : aucun), pour les ventes de la
  /// boutique et pour le solde Tara : en dessous, rien ne peut partir.
  final int withdrawalMinimum;
  final int customerWithdrawalMinimum;

  /// Reversement ou retrait en cours.
  final ({int amount, String status})? openPayout;

  bool get canPayoutNow => plan != null && plan != 'FREE';

  /// Reversement possible tout de suite : offre payante, ou petit solde (sous 500 F) que le
  /// reversement de 18 h ne prendrait jamais, versé en entier ; jamais sous le minimum du
  /// prestataire.
  bool get canPayoutBalanceNow {
    final balance = merchantBalance ?? 0;
    return openPayout == null &&
        balance > 0 &&
        balance >= withdrawalMinimum &&
        (canPayoutNow || balance < payoutMinimum);
  }

  /// Ventes qui attendent d'atteindre le minimum du prestataire avant de partir.
  bool get salesBelowMinimum {
    final balance = merchantBalance ?? 0;
    return balance >= 0 && withdrawalMinimum > payoutMinimum && balance < withdrawalMinimum;
  }

  /// Plus petit reversement automatique (comme le serveur).
  static const payoutMinimum = 500;
}

/// Ligne du portefeuille (G2) : recharge, vente encaissée, frais, reversement…
@immutable
class WalletLine {
  const WalletLine({
    required this.id,
    required this.at,
    required this.kind,
    required this.description,
    required this.amount,
    required this.orderReference,
  });
  factory WalletLine.fromJson(Json json) => WalletLine(
    id: _field(json, 'id'),
    at: DateTime.parse(_field(json, 'at')),
    kind: _field(json, 'kind'),
    description: _field(json, 'description'),
    amount: _field<num>(json, 'amount').toInt(),
    orderReference: _field(json, 'orderReference'),
  );
  static const fields = ['id', 'at', 'kind', 'description', 'amount', 'orderReference'];

  final String id;
  final DateTime at;

  /// Nature de l'écriture (COD_COLLECTED, PAYOUT_REQUESTED…).
  final String kind;

  /// Libellé du serveur (en français), repris si la nature n'a pas de libellé dans l'app.
  final String description;

  /// Positif : le solde augmente.
  final int amount;
  final String? orderReference;
}

/// Reversement de la boutique ou retrait du solde vers Mobile Money (G3, G8).
@immutable
class Payout {
  const Payout({
    required this.id,
    required this.beneficiary,
    required this.amount,
    required this.status,
    required this.requestedAt,
    required this.completedAt,
  });
  factory Payout.fromJson(Json json) => Payout(
    id: _field(json, 'id'),
    beneficiary: _field(json, 'beneficiary'),
    amount: _field<num>(json, 'amount').toInt(),
    status: _field(json, 'status'),
    requestedAt: DateTime.parse(_field(json, 'requestedAt')),
    completedAt: json['completedAt'] == null ? null : DateTime.parse(_field(json, 'completedAt')),
  );
  static const fields = ['id', 'beneficiary', 'amount', 'status', 'requestedAt', 'completedAt'];

  final String id;

  /// MERCHANT (reversement de la boutique) ou CUSTOMER (retrait du solde).
  final String beneficiary;
  final int amount;

  /// PENDING, AWAITING_APPROVAL, PROCESSING, SUCCEEDED, FAILED ou CANCELLED.
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;

  bool get open => const {'PENDING', 'AWAITING_APPROVAL', 'PROCESSING'}.contains(status);
}

/// Quartier de Douala (liste des zones, B1).
@immutable
class Neighborhood {
  const Neighborhood({required this.id, required this.name});
  factory Neighborhood.fromJson(Json json) => Neighborhood(id: _field(json, 'id'), name: _field(json, 'name'));
  static const fields = ['id', 'name'];

  final String id;
  final String name;
}

/// Point placé sur la carte (B1) : desservi ou non, et quartier déduit, affichés sous
/// l'épingle dès que la carte s'arrête.
@immutable
class PointLocation {
  const PointLocation({required this.inServiceArea, this.neighborhood});
  factory PointLocation.fromJson(Json json) {
    final neighborhood = json['neighborhood'];
    return PointLocation(
      inServiceArea: json['inServiceArea'] == true,
      neighborhood: neighborhood is Json ? Neighborhood.fromJson(neighborhood) : null,
    );
  }
  static const fields = ['inServiceArea', 'neighborhood'];

  final bool inServiceArea;
  final Neighborhood? neighborhood;
}

/// Adresse (B1) : point, quartier, repère écrit ; confirmée par une livraison (B4).
@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.contactName,
    required this.contactPhone,
    required this.neighborhood,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    required this.verified,
    required this.motorbikeRestricted,
  });

  factory Address.fromJson(Json json) {
    final neighborhood = json['neighborhood'] as Json?;
    return Address(
      id: _field(json, 'id'),
      label: _field(json, 'label'),
      contactName: _field(json, 'contactName'),
      contactPhone: _field(json, 'contactPhone'),
      neighborhood: neighborhood == null ? null : Neighborhood.fromJson(neighborhood),
      landmark: _field(json, 'landmark'),
      latitude: _field<num>(json, 'latitude').toDouble(),
      longitude: _field<num>(json, 'longitude').toDouble(),
      verified: json['verifiedAt'] != null,
      motorbikeRestricted: json['motorbikeRestricted'] == true,
    );
  }

  static const fields = [
    'id',
    'label',
    'contactName',
    'contactPhone',
    'neighborhood',
    'landmark',
    'latitude',
    'longitude',
    'verifiedAt',
    'motorbikeRestricted',
  ];

  final String id;
  final String? label;
  final String? contactName;
  final String? contactPhone;
  final Neighborhood? neighborhood;
  final String landmark;
  final double latitude;
  final double longitude;

  /// Point confirmé par une livraison réussie.
  final bool verified;

  /// Dans une zone interdite aux motos (B6).
  final bool motorbikeRestricted;

  /// « Bonapriso · Portail bleu après la pharmacie ».
  String get summary => [?neighborhood?.name, landmark].join(' · ');

  /// Même forme que la réponse de l'API, pour garder l'adresse sur le téléphone (liste
  /// d'envoi en cours).
  Json toJson() => {
    'id': id,
    'label': label,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'neighborhood': neighborhood == null ? null : {'id': neighborhood!.id, 'name': neighborhood!.name},
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'verifiedAt': verified ? 'verified' : null,
    'motorbikeRestricted': motorbikeRestricted,
  };
}

/// Destinataire fréquent du carnet (B5), avec sa dernière adresse.
@immutable
class Recipient {
  const Recipient({required this.name, required this.phone, required this.ordersCount, required this.lastAddress});
  factory Recipient.fromJson(Json json) => Recipient(
    name: _field(json, 'name'),
    phone: _field(json, 'phone'),
    ordersCount: _field<num>(json, 'ordersCount').toInt(),
    lastAddress: Address.fromJson(_field<Json>(json, 'lastAddress')),
  );
  static const fields = ['name', 'phone', 'ordersCount', 'lastAddress'];

  final String name;
  final String phone;
  final int ordersCount;
  final Address lastAddress;
}

/// Lien de localisation (B3) envoyé au destinataire pour qu'il place son point.
@immutable
class LocationLink {
  const LocationLink({
    required this.id,
    required this.url,
    required this.recipientName,
    required this.status,
    required this.expiresAt,
    required this.address,
    this.recipientPhone,
  });
  factory LocationLink.fromJson(Json json) {
    final address = json['address'] as Json?;
    return LocationLink(
      id: _field(json, 'id'),
      url: _field(json, 'url'),
      recipientName: _field(json, 'recipientName'),
      recipientPhone: json['recipientPhone'] as String?,
      status: _field(json, 'status'),
      expiresAt: DateTime.parse(_field(json, 'expiresAt')),
      address: address == null ? null : Address.fromJson(address),
    );
  }
  static const fields = ['id', 'url', 'recipientName', 'recipientPhone', 'status', 'expiresAt', 'address'];

  final String id;
  final String url;
  final String? recipientName;

  /// Numéro du destinataire au format +237…
  final String? recipientPhone;

  /// PENDING, SUBMITTED ou EXPIRED.
  final String status;
  final DateTime expiresAt;
  final Address? address;
}

/// Proposition tirée de la photo du colis : à confirmer ou corriger par l'expéditeur.
@immutable
class ParcelAnalysis {
  const ParcelAnalysis({
    required this.photoKey,
    required this.isParcel,
    required this.size,
    required this.contents,
    required this.description,
    required this.fragile,
    required this.prohibited,
    required this.confidence,
  });

  factory ParcelAnalysis.fromJson(Json json) {
    final suggestion = _field<Json>(json, 'suggestion');
    return ParcelAnalysis(
      photoKey: _field(json, 'photoKey'),
      isParcel: _field(json, 'isParcel'),
      size: _field(suggestion, 'size'),
      contents: _field(suggestion, 'contents'),
      description: suggestion['description'] as String?,
      fragile: _field(suggestion, 'fragile'),
      prohibited: [
        for (final item in _field<List<Object?>>(json, 'prohibited')) _field<String>(item! as Json, 'label'),
      ],
      confidence: _field(json, 'confidence'),
    );
  }
  static const fields = ['photoKey', 'isParcel', 'suggestion', 'prohibited', 'confidence'];

  final String photoKey;

  /// Faux : la photo ne montre pas de colis, elle est à reprendre.
  final bool isParcel;
  final String size;
  final String contents;
  final String? description;
  final bool fragile;

  /// Objets interdits que la photo semble montrer (libellés).
  final List<String> prohibited;

  /// low, medium ou high.
  final String confidence;
}

/// Prix d'une livraison avant validation (C2).
@immutable
class Quote {
  const Quote({
    required this.distanceMeters,
    required this.estimatedMinutes,
    required this.basePrice,
    required this.surcharges,
    required this.discountTotal,
    required this.totalPrice,
    required this.promoCode,
    this.discountSource,
    this.proDiscountBps = 0,
    this.vehicleType = 'MOTORBIKE',
    this.retryFee = 0,
    this.returnFee = 0,
    this.valueFee = 0,
  });
  factory Quote.fromJson(Json json) => Quote(
    distanceMeters: _field<num>(json, 'distanceMeters').toInt(),
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
    basePrice: _field<num>(json, 'basePrice').toInt(),
    surcharges: [
      for (final item in _field<List<Object?>>(json, 'surcharges'))
        (code: _field<String>(item! as Json, 'code'), amount: _field<num>(item as Json, 'amount').toInt()),
    ],
    discountTotal: _field<num>(json, 'discountTotal').toInt(),
    totalPrice: _field<num>(json, 'totalPrice').toInt(),
    promoCode: _field(json, 'promoCode'),
    discountSource: json['discountSource'] as String?,
    proDiscountBps: (json['proDiscountBps'] as num?)?.toInt() ?? 0,
    vehicleType: json['vehicleType'] as String? ?? 'MOTORBIKE',
    retryFee: _field<num>(json, 'retryFee').toInt(),
    returnFee: _field<num>(json, 'returnFee').toInt(),
    valueFee: (json['valueFee'] as num?)?.toInt() ?? 0,
  );
  static const fields = [
    'distanceMeters',
    'estimatedMinutes',
    'basePrice',
    'surcharges',
    'discountTotal',
    'totalPrice',
    'promoCode',
    'discountSource',
    'proDiscountBps',
    'vehicleType',
    'retryFee',
    'returnFee',
    'valueFee',
  ];

  final int distanceMeters;
  final int? estimatedMinutes;
  final int basePrice;
  final List<({String code, int amount})> surcharges;
  final int discountTotal;
  final int totalPrice;
  final String? promoCode;

  /// D'où vient la remise : PROMO (code promo), VOLUME (tarif pro de la boutique) ou rien.
  final String? discountSource;

  /// Tarif pro appliqué, en points de base (1000 = 10 %).
  final int proDiscountBps;

  /// MOTORBIKE, ou TRICYCLE pour un gros objet.
  final String vehicleType;

  /// Seulement si la livraison échoue (E6) : nouvelle tentative, retour à l'expéditeur.
  final int retryFee;
  final int returnFee;

  /// Garantie de la valeur déclarée au-delà de 25 000 F, comprise dans [totalPrice].
  final int valueFee;
}

/// Commande créée (C1) : de quoi la suivre et afficher son prix.
@immutable
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.totalPrice,
    this.batchNumber,
  });
  factory PlacedOrder.fromJson(Json json) => PlacedOrder(
    id: _field(json, 'id'),
    reference: _field(json, 'reference'),
    status: _field(json, 'status'),
    totalPrice: _field<num>(_field<Json>(json, 'pricing'), 'totalPrice').toInt(),
    batchNumber: (json['batchNumber'] as num?)?.toInt(),
  );
  static const fields = ['id', 'reference', 'status', 'pricing', 'batchNumber'];

  /// Numéro du colis dans son envoi (null pour une commande seule).
  final int? batchNumber;

  final String id;
  final String reference;

  /// CREATED tant que le paiement Mobile Money est attendu, puis SEARCHING_RIDER.
  final String status;
  final int totalPrice;
}

/// Résultat d'une création (une commande ou un lot) : commandes et code d'enlèvement,
/// affiché une seule fois.
@immutable
class Placement {
  const Placement({required this.orders, required this.pickupCode, this.batchId, this.pending = const []});

  factory Placement.single(Json json) =>
      Placement(orders: [PlacedOrder.fromJson(_field<Json>(json, 'order'))], pickupCode: _field(json, 'pickupCode'));

  factory Placement.batch(Json json) => Placement(
    orders: [for (final item in _field<List<Object?>>(json, 'orders')) PlacedOrder.fromJson(item! as Json)],
    pickupCode: _field(json, 'pickupCode'),
    batchId: _field(json, 'batchId'),
    pending: [
      for (final item in (json['pending'] as List<Object?>?) ?? const <Object?>[])
        PendingDelivery.fromJson(item! as Json),
    ],
  );

  static const singleFields = ['order', 'pickupCode', 'replayed'];
  static const batchFields = ['batchId', 'pickupCode', 'replayed', 'orders', 'pending'];

  final List<PlacedOrder> orders;
  final String? pickupCode;
  final String? batchId;

  /// Colis de l'envoi qui attendent l'adresse de leur client.
  final List<PendingDelivery> pending;

  int get total => orders.fold(0, (sum, order) => sum + order.totalPrice);
}

/// Colis d'un envoi qui attend l'adresse de son client (lien envoyé par SMS) : il part seul
/// quand le point arrive.
@immutable
class PendingDelivery {
  const PendingDelivery({
    required this.id,
    required this.batchId,
    required this.batchNumber,
    required this.recipientName,
    required this.recipientPhone,
    required this.status,
    required this.blockedReason,
    required this.linkUrl,
    required this.linkExpiresAt,
    required this.orderId,
    required this.codAmount,
  });
  factory PendingDelivery.fromJson(Json json) => PendingDelivery(
    id: _field(json, 'id'),
    batchId: _field(json, 'batchId'),
    batchNumber: _field<num>(json, 'batchNumber').toInt(),
    recipientName: _field(json, 'recipientName'),
    recipientPhone: _field(json, 'recipientPhone'),
    status: _field(json, 'status'),
    blockedReason: json['blockedReason'] as String?,
    linkUrl: _field(json, 'linkUrl'),
    linkExpiresAt: DateTime.parse(_field(json, 'linkExpiresAt')),
    orderId: json['orderId'] as String?,
    codAmount: _field<num>(json, 'codAmount').toInt(),
  );
  static const fields = [
    'id',
    'batchId',
    'batchNumber',
    'recipientName',
    'recipientPhone',
    'status',
    'blockedReason',
    'linkUrl',
    'linkExpiresAt',
    'orderId',
    'codAmount',
  ];

  final String id;
  final String batchId;
  final int batchNumber;
  final String recipientName;

  /// Au format +237…
  final String recipientPhone;

  /// WAITING, EXPIRED, BLOCKED, RELEASED ou CANCELLED.
  final String status;

  /// Code d'erreur quand le départ automatique a échoué (INSUFFICIENT_BALANCE…).
  final String? blockedReason;
  final String linkUrl;
  final DateTime linkExpiresAt;
  final String? orderId;
  final int codAmount;

  String get firstName => recipientName.trim().split(RegExp(r'\s+')).first;
}

/// Prix de chaque colis d'une liste d'envoi : le prix, ou pourquoi il n'y en a pas.
@immutable
class BatchQuote {
  const BatchQuote({required this.items, required this.totalPrice});
  factory BatchQuote.fromJson(Json json) => BatchQuote(
    items: [
      for (final item in _field<List<Object?>>(json, 'items').cast<Json>())
        (
          quote: item['quote'] == null ? null : Quote.fromJson(item['quote']! as Json),
          error: (item['error'] as Json?)?['message'] as String?,
        ),
    ],
    totalPrice: _field<num>(json, 'totalPrice').toInt(),
  );
  static const fields = ['items', 'totalPrice'];

  final List<({Quote? quote, String? error})> items;
  final int totalPrice;
}

/// Paiement Mobile Money (G1) : en attente de validation sur le téléphone, réussi ou refusé.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.status,
    required this.amount,
    required this.failureReason,
    this.mobileMoneyFee = 0,
  });
  factory Payment.fromJson(Json json) => Payment(
    id: _field(json, 'id'),
    status: _field(json, 'status'),
    amount: _field<num>(json, 'amount').toInt(),
    failureReason: _field(json, 'failureReason'),
    mobileMoneyFee: _field<num>(json, 'mobileMoneyFee').toInt(),
  );
  static const fields = ['id', 'status', 'amount', 'failureReason', 'mobileMoneyFee', 'total'];

  final String id;

  /// PENDING, SUCCEEDED, FAILED ou CANCELLED.
  final String status;

  /// Montant dû à Tara ; le téléphone reçoit une demande de amount + mobileMoneyFee.
  final int amount;
  final String? failureReason;
  final int mobileMoneyFee;
  int get total => amount + mobileMoneyFee;
}

/// Livreur d'une course, vu par l'expéditeur (F1) : numéro seulement pendant la course.
@immutable
class OrderRider {
  const OrderRider({
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.plateNumber,
    this.vehicleBrand,
    this.vehicleColor,
    this.hasPhoto = false,
  });
  factory OrderRider.fromJson(Json json) => OrderRider(
    name: _field(json, 'name'),
    phone: _field(json, 'phone'),
    vehicleType: _field(json, 'vehicleType'),
    plateNumber: _field(json, 'plateNumber'),
    // Serveur d'avant : ni marque, ni couleur, ni photo.
    vehicleBrand: json['vehicleBrand'] as String?,
    vehicleColor: json['vehicleColor'] as String?,
    hasPhoto: json['hasPhoto'] as bool? ?? false,
  );
  static const fields = ['name', 'phone', 'vehicleType', 'plateNumber', 'vehicleBrand', 'vehicleColor', 'hasPhoto'];

  /// Marque et couleur (codes du serveur : NANFANG, RED…), pour reconnaître le livreur.
  final String? vehicleBrand;
  final String? vehicleColor;

  /// Photo de visage validée par Tara : `ClientApi.riderPhoto`.
  final bool hasPhoto;

  final String name;
  final String? phone;

  /// MOTORBIKE, TRICYCLE ou CAR.
  final String vehicleType;
  final String? plateNumber;
}

/// Commande suivie par l'expéditeur (F1) : trajet, destinataire, livreur, étapes.
@immutable
class TrackedOrder {
  const TrackedOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.trackingUrl,
    required this.scheduledFor,
    required this.pickup,
    required this.dropoff,
    required this.recipientName,
    required this.recipientPhone,
    required this.contents,
    required this.size,
    required this.totalPrice,
    required this.codAmount,
    required this.rider,
    required this.timeline,
    required this.createdAt,
    this.failure,
    this.rating,
    this.retryFee = 0,
    this.returnFee = 0,
    this.cancellationFee = 0,
    this.riderArrivedAt,
    this.waitingFee = 0,
    this.senderAbsent = false,
    this.refusalReason,
    this.feePaymentMethod = 'CASH',
    this.feePaid = true,
    this.batchNumber,
    this.batchSize,
    this.tourNumbers = const [],
  });

  factory TrackedOrder.fromJson(Json json) {
    final recipient = _field<Json>(json, 'recipient');
    final pricing = _field<Json>(json, 'pricing');
    final rider = json['rider'] as Json?;
    final failure = json['failure'] as Json?;
    final rating = json['rating'] as Json?;
    final scheduled = json['scheduledFor'] as String?;
    // Annulée par le livreur : colis non conforme refusé à l'enlèvement, motif à l'appui.
    final refused = _field<List<Object?>>(
      json,
      'timeline',
    ).cast<Json>().any((step) => step['status'] == 'CANCELLED' && step['actorRole'] == 'RIDER');
    final absent = refused && TrackedOrder.isSenderAbsentReason(json['cancelReason'] as String?);
    return TrackedOrder(
      id: _field(json, 'id'),
      reference: _field(json, 'reference'),
      status: _field(json, 'status'),
      trackingUrl: _field(json, 'trackingUrl'),
      scheduledFor: scheduled == null ? null : DateTime.parse(scheduled),
      pickup: Address.fromJson(_field<Json>(json, 'pickup')),
      dropoff: Address.fromJson(_field<Json>(json, 'dropoff')),
      recipientName: _field(recipient, 'name'),
      recipientPhone: _field(recipient, 'phone'),
      contents: json['packageContents'] as String?,
      size: _field(json, 'packageSize'),
      totalPrice: _field<num>(pricing, 'totalPrice').toInt(),
      codAmount: _field<num>(pricing, 'codAmount').toInt(),
      retryFee: _field<num>(pricing, 'retryFee').toInt(),
      returnFee: _field<num>(pricing, 'returnFee').toInt(),
      cancellationFee: (pricing['cancellationFee'] as num?)?.toInt() ?? 0,
      riderArrivedAt: switch (pricing['riderArrivedAt']) {
        final String at => DateTime.parse(at).toLocal(),
        _ => null,
      },
      waitingFee: (pricing['waitingFee'] as num?)?.toInt() ?? 0,
      rider: rider == null ? null : OrderRider.fromJson(rider),
      timeline: [
        for (final item in _field<List<Object?>>(json, 'timeline'))
          (status: _field<String>(item! as Json, 'status'), at: DateTime.parse(_field(item as Json, 'at'))),
      ],
      createdAt: DateTime.parse(_field(json, 'createdAt')),
      failure: failure == null ? null : OrderFailure.fromJson(failure),
      rating: rating == null ? null : OrderRating.fromJson(rating),
      refusalReason: refused && !absent ? (json['cancelReason'] as String? ?? '') : null,
      senderAbsent: absent,
      feePaymentMethod: pricing['feePaymentMethod'] as String? ?? 'CASH',
      // Frais payés par le destinataire : rien à payer d'avance. Serveur d'avant : pas de
      // champ, on suppose les frais réglés.
      feePaid: pricing['feePayer'] == 'RECIPIENT' || (pricing['feePaid'] as bool? ?? true),
      batchNumber: (json['batchNumber'] as num?)?.toInt(),
      batchSize: (json['batchSize'] as num?)?.toInt(),
      // Serveur d'avant la tournée (2c) : pas de champ, colis seul.
      tourNumbers: [for (final n in json['tourNumbers'] as List? ?? const []) (n as num).toInt()],
    );
  }

  static const fields = [
    'id',
    'reference',
    'status',
    'trackingUrl',
    'scheduledFor',
    'pickup',
    'dropoff',
    'recipient',
    'packageContents',
    'packageSize',
    'pricing',
    'rider',
    'failure',
    'cancelReason',
    'rating',
    'timeline',
    'createdAt',
  ];

  final String id;
  final String reference;
  final String status;

  /// Page de suivi publique (partagée au destinataire).
  final String trackingUrl;
  final DateTime? scheduledFor;
  final Address pickup;
  final Address dropoff;
  final String recipientName;
  final String recipientPhone;
  final String? contents;
  final String size;
  final int totalPrice;
  final int codAmount;
  final OrderRider? rider;
  final List<({String status, DateTime at})> timeline;
  final DateTime createdAt;

  /// Livraison impossible (E6) : motif, choix et heure limite ; null hors de cet état.
  final OrderFailure? failure;

  /// Note donnée au livreur (F4), null tant que l'expéditeur n'a pas noté.
  final OrderRating? rating;

  /// Frais d'échec figés à la commande (E6) : nouvelle tentative, retour.
  final int retryFee;
  final int returnFee;

  /// Frais si l'expéditeur annule maintenant (livreur déjà en route), 0 sinon.
  final int cancellationFee;

  /// Arrivée du livreur au point d'enlèvement (D) ; frais d'attente pris à l'enlèvement.
  final DateTime? riderArrivedAt;
  final int waitingFee;

  /// Annulée par le livreur parti après l'attente maximale : l'expéditeur n'est pas venu.
  final bool senderAbsent;

  /// Motif d'annulation donné par le serveur quand le livreur part après l'attente maximale.
  static bool isSenderAbsentReason(String? reason) => (reason ?? '').startsWith('Expéditeur absent');

  /// Colis refusé par le livreur à l'enlèvement (non conforme) : le motif, sinon null. Le
  /// déplacement ([retryFee]) est alors à la charge de l'expéditeur.
  final String? refusalReason;

  /// Moyen de paiement des frais (MOMO_MTN, MOMO_ORANGE, CASH, WALLET) et frais réglés.
  final String feePaymentMethod;
  final bool feePaid;

  /// Envoi de plusieurs colis : numéro écrit sur ce colis, et nombre de colis de l'envoi.
  final int? batchNumber;
  final int? batchSize;

  /// Tournée (2c) : numéros des colis de l'envoi que le même livreur emporte, celui-ci compris ;
  /// vide hors tournée.
  final List<int> tourNumbers;

  /// Commande en attente du paiement Mobile Money de ses frais (aucun livreur cherché avant).
  bool get awaitingPayment => status == 'CREATED' && feePaymentMethod.startsWith('MOMO_') && !feePaid;

  /// Heure du premier passage à [status] (null s'il n'a pas eu lieu).
  DateTime? reachedAt(String status) => timeline.where((step) => step.status == status).firstOrNull?.at;

  TrackedOrder withStatus(String next) => _copy(status: next, failure: next == 'DELIVERY_FAILED' ? failure : null);

  TrackedOrder withRating(OrderRating given) => _copy(rating: given);

  TrackedOrder _copy({String? status, OrderFailure? failure, OrderRating? rating}) => TrackedOrder(
    id: id,
    reference: reference,
    status: status ?? this.status,
    trackingUrl: trackingUrl,
    scheduledFor: scheduledFor,
    pickup: pickup,
    dropoff: dropoff,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    contents: contents,
    size: size,
    totalPrice: totalPrice,
    codAmount: codAmount,
    rider: rider,
    timeline: timeline,
    createdAt: createdAt,
    failure: status == null ? this.failure : failure,
    rating: rating ?? this.rating,
    retryFee: retryFee,
    returnFee: returnFee,
    cancellationFee: cancellationFee,
    riderArrivedAt: riderArrivedAt,
    waitingFee: waitingFee,
    senderAbsent: senderAbsent,
    refusalReason: refusalReason,
    feePaymentMethod: feePaymentMethod,
    feePaid: feePaid,
    batchNumber: batchNumber,
    batchSize: batchSize,
    tourNumbers: tourNumbers,
  );
}

/// Note donnée après une course (F4) : 1 à 5 étoiles, mot facultatif pour l'équipe.
@immutable
class OrderRating {
  const OrderRating({required this.score, required this.comment, required this.at});
  factory OrderRating.fromJson(Json json) => OrderRating(
    score: _field<num>(json, 'score').toInt(),
    comment: json['comment'] as String?,
    at: DateTime.parse(_field(json, 'at')),
  );

  static const fields = ['score', 'comment', 'at'];

  final int score;
  final String? comment;
  final DateTime at;
}

/// Échec de livraison vu par l'expéditeur (E6) : il choisit une nouvelle tentative ou le
/// retour du colis avant [decisionDueAt] ; sans réponse, le colis lui revient.
@immutable
class OrderFailure {
  const OrderFailure({
    required this.reason,
    required this.note,
    required this.at,
    this.decision,
    this.decisionDueAt,
    this.retryAllowed = true,
  });

  factory OrderFailure.fromJson(Json json) {
    final due = json['decisionDueAt'] as String?;
    return OrderFailure(
      reason: json['reason'] as String?,
      note: json['note'] as String?,
      at: DateTime.parse(_field(json, 'at')),
      decision: json['decision'] as String?,
      decisionDueAt: due == null ? null : DateTime.parse(due),
      retryAllowed: _field<bool>(json, 'retryAllowed'),
    );
  }

  static const fields = ['reason', 'note', 'at', 'decision', 'decisionDueAt', 'retryAllowed'];

  /// RECIPIENT_ABSENT, RECIPIENT_UNREACHABLE, REFUSED, ADDRESS_NOT_FOUND, PAYMENT_REFUSED, DAMAGED,
  /// OTHER.
  final String? reason;

  /// Explication du livreur (motif « autre »).
  final String? note;
  final DateTime at;

  /// RETRY ou RETURN ; null tant que l'expéditeur doit choisir.
  final String? decision;
  final DateTime? decisionDueAt;

  /// Une seule nouvelle tentative : false après un deuxième échec.
  final bool retryAllowed;
}
