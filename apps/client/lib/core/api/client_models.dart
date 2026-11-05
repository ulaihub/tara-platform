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
  });

  factory Wallet.fromJson(Json json) {
    final merchant = json['merchant'] as Json?;
    return Wallet(
      customerBalance: _field<num>(_field<Json>(json, 'customer'), 'balance').toInt(),
      merchantBalance: merchant == null ? null : _field<num>(merchant, 'balance').toInt(),
      payoutSchedule: merchant == null ? null : _field<String>(merchant, 'payoutSchedule'),
      todaySales: merchant == null ? 0 : _field<num>(merchant, 'todaySales').toInt(),
      todayDeliveries: merchant == null ? 0 : _field<num>(merchant, 'todayDeliveries').toInt(),
    );
  }

  static const fields = ['customer', 'merchant'];

  final int customerBalance;

  /// Ventes encaissées pas encore reversées (null sans boutique).
  final int? merchantBalance;

  /// DAILY (chaque jour) ou ON_DEMAND (à la demande).
  final String? payoutSchedule;

  /// Boutique : encaissé à la livraison aujourd'hui, et livraisons du jour.
  final int todaySales;
  final int todayDeliveries;
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
  });
  factory LocationLink.fromJson(Json json) {
    final address = json['address'] as Json?;
    return LocationLink(
      id: _field(json, 'id'),
      url: _field(json, 'url'),
      recipientName: _field(json, 'recipientName'),
      status: _field(json, 'status'),
      expiresAt: DateTime.parse(_field(json, 'expiresAt')),
      address: address == null ? null : Address.fromJson(address),
    );
  }
  static const fields = ['id', 'url', 'recipientName', 'status', 'expiresAt', 'address'];

  final String id;
  final String url;
  final String? recipientName;

  /// PENDING, SUBMITTED ou EXPIRED.
  final String status;
  final DateTime expiresAt;
  final Address? address;
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
  );
  static const fields = [
    'distanceMeters',
    'estimatedMinutes',
    'basePrice',
    'surcharges',
    'discountTotal',
    'totalPrice',
    'promoCode',
  ];

  final int distanceMeters;
  final int? estimatedMinutes;
  final int basePrice;
  final List<({String code, int amount})> surcharges;
  final int discountTotal;
  final int totalPrice;
  final String? promoCode;
}
