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
  });

  factory AppConfig.fromJson(Json json) {
    final country = _field<Json>(json, 'country');
    return AppConfig(
      dialCode: _field(country, 'dialCode'),
      currency: _field(country, 'currency'),
      supportPhone: _field(json, 'supportPhone'),
      operators: [
        for (final item in _field<List<Object?>>(json, 'mobileMoneyOperators'))
          MobileMoneyOperator(_field(item! as Json, 'code'), _field(item as Json, 'name')),
      ],
    );
  }

  static const fields = ['country', 'supportPhone', 'mobileMoneyOperators'];

  final String dialCode;
  final String currency;
  final String? supportPhone;
  final List<MobileMoneyOperator> operators;
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
  });

  factory OrderSummary.fromJson(Json json) => OrderSummary(
    id: _field(json, 'id'),
    reference: _field(json, 'reference'),
    status: _field(json, 'status'),
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
    'todaySales',
    'todayDeliveries',
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

  /// Heure du reversement quotidien (heure du Cameroun).
  final int payoutHour;

  /// Reversement ou retrait en cours.
  final ({int amount, String status})? openPayout;

  bool get canPayoutNow => plan != null && plan != 'FREE';
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
    this.vehicleType = 'MOTORBIKE',
    this.retryFee = 0,
    this.returnFee = 0,
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
    vehicleType: json['vehicleType'] as String? ?? 'MOTORBIKE',
    retryFee: _field<num>(json, 'retryFee').toInt(),
    returnFee: _field<num>(json, 'returnFee').toInt(),
  );
  static const fields = [
    'distanceMeters',
    'estimatedMinutes',
    'basePrice',
    'surcharges',
    'discountTotal',
    'totalPrice',
    'promoCode',
    'vehicleType',
    'retryFee',
    'returnFee',
  ];

  final int distanceMeters;
  final int? estimatedMinutes;
  final int basePrice;
  final List<({String code, int amount})> surcharges;
  final int discountTotal;
  final int totalPrice;
  final String? promoCode;

  /// MOTORBIKE, ou TRICYCLE pour un gros objet.
  final String vehicleType;

  /// Seulement si la livraison échoue (E6) : nouvelle tentative, retour à l'expéditeur.
  final int retryFee;
  final int returnFee;
}

/// Commande créée (C1) : de quoi la suivre et afficher son prix.
@immutable
class PlacedOrder {
  const PlacedOrder({required this.id, required this.reference, required this.status, required this.totalPrice});
  factory PlacedOrder.fromJson(Json json) => PlacedOrder(
    id: _field(json, 'id'),
    reference: _field(json, 'reference'),
    status: _field(json, 'status'),
    totalPrice: _field<num>(_field<Json>(json, 'pricing'), 'totalPrice').toInt(),
  );
  static const fields = ['id', 'reference', 'status', 'pricing'];

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
  const Placement({required this.orders, required this.pickupCode, this.batchId});

  factory Placement.single(Json json) =>
      Placement(orders: [PlacedOrder.fromJson(_field<Json>(json, 'order'))], pickupCode: _field(json, 'pickupCode'));

  factory Placement.batch(Json json) => Placement(
    orders: [for (final item in _field<List<Object?>>(json, 'orders')) PlacedOrder.fromJson(item! as Json)],
    pickupCode: _field(json, 'pickupCode'),
    batchId: _field(json, 'batchId'),
  );

  static const singleFields = ['order', 'pickupCode', 'replayed'];
  static const batchFields = ['batchId', 'pickupCode', 'replayed', 'orders'];

  final List<PlacedOrder> orders;
  final String? pickupCode;
  final String? batchId;

  int get total => orders.fold(0, (sum, order) => sum + order.totalPrice);
}

/// Paiement Mobile Money (G1) : en attente de validation sur le téléphone, réussi ou refusé.
@immutable
class Payment {
  const Payment({required this.id, required this.status, required this.amount, required this.failureReason});
  factory Payment.fromJson(Json json) => Payment(
    id: _field(json, 'id'),
    status: _field(json, 'status'),
    amount: _field<num>(json, 'amount').toInt(),
    failureReason: _field(json, 'failureReason'),
  );
  static const fields = ['id', 'status', 'amount', 'failureReason'];

  final String id;

  /// PENDING, SUCCEEDED, FAILED ou CANCELLED.
  final String status;
  final int amount;
  final String? failureReason;
}

/// Livreur d'une course, vu par l'expéditeur (F1) : numéro seulement pendant la course.
@immutable
class OrderRider {
  const OrderRider({required this.name, required this.phone, required this.vehicleType, required this.plateNumber});
  factory OrderRider.fromJson(Json json) => OrderRider(
    name: _field(json, 'name'),
    phone: _field(json, 'phone'),
    vehicleType: _field(json, 'vehicleType'),
    plateNumber: _field(json, 'plateNumber'),
  );
  static const fields = ['name', 'phone', 'vehicleType', 'plateNumber'];

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
    this.refusalReason,
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
      rider: rider == null ? null : OrderRider.fromJson(rider),
      timeline: [
        for (final item in _field<List<Object?>>(json, 'timeline'))
          (status: _field<String>(item! as Json, 'status'), at: DateTime.parse(_field(item as Json, 'at'))),
      ],
      createdAt: DateTime.parse(_field(json, 'createdAt')),
      failure: failure == null ? null : OrderFailure.fromJson(failure),
      rating: rating == null ? null : OrderRating.fromJson(rating),
      refusalReason: refused ? (json['cancelReason'] as String? ?? '') : null,
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

  /// Colis refusé par le livreur à l'enlèvement (non conforme) : le motif, sinon null. Le
  /// déplacement ([retryFee]) est alors à la charge de l'expéditeur.
  final String? refusalReason;

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
    refusalReason: refusalReason,
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

  /// RECIPIENT_ABSENT, RECIPIENT_UNREACHABLE, REFUSED, ADDRESS_NOT_FOUND, PAYMENT_REFUSED, OTHER.
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
