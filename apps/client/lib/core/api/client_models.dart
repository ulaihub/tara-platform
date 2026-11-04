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
  const Wallet({required this.customerBalance, required this.merchantBalance, required this.payoutSchedule});

  factory Wallet.fromJson(Json json) {
    final merchant = json['merchant'] as Json?;
    return Wallet(
      customerBalance: _field<num>(_field<Json>(json, 'customer'), 'balance').toInt(),
      merchantBalance: merchant == null ? null : _field<num>(merchant, 'balance').toInt(),
      payoutSchedule: merchant == null ? null : _field<String>(merchant, 'payoutSchedule'),
    );
  }

  static const fields = ['customer', 'merchant'];

  final int customerBalance;

  /// Ventes encaissées pas encore reversées (null sans boutique).
  final int? merchantBalance;

  /// DAILY (chaque jour) ou ON_DEMAND (à la demande).
  final String? payoutSchedule;
}
