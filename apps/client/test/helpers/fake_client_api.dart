import 'package:tara_client/core/api/client_api.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';

/// API expéditeur sans réseau : compte, nom et boutique enregistrés.
class FakeClientApi extends ClientApi {
  FakeClientApi() : super(ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())));

  final names = <String>[];

  /// Commandes en cours (accueil) et portefeuille renvoyés.
  List<OrderSummary> active = [];
  List<OrderSummary> history = [];
  Wallet wallet0 = const Wallet(customerBalance: 0, merchantBalance: null, payoutSchedule: null);

  @override
  Future<List<OrderSummary>> orders({required String scope, int limit = 20}) async =>
      scope == 'active' ? active : history;

  @override
  Future<Wallet> wallet() async => wallet0;
  final merchants = <Map<String, String?>>[];

  @override
  Future<Me> me() async => const Me(
    id: '00000000-0000-4000-8000-0000000000aa',
    phone: '+237677123456',
    fullName: null,
    locale: 'FR',
    referralCode: 'TARA-7KQ2PM',
    merchant: null,
  );

  @override
  Future<void> updateName(String fullName) async => names.add(fullName);

  /// Adresses enregistrées, carnet de destinataires et liens de localisation.
  List<Address> saved = [];
  List<Recipient> recents = [];
  final createdAddresses = <Map<String, Object?>>[];
  final createdLinks = <Map<String, String?>>[];

  /// Ce que renvoie la relecture d'un lien (le destinataire a-t-il placé son point ?).
  LocationLink? linkAfter;

  @override
  Future<List<Address>> addresses() async => saved;

  @override
  Future<List<Neighborhood>> neighborhoods() async => [
    for (final (i, name) in ['Akwa', 'Bali', 'Bépanda', 'Bonamoussadi', 'Bonapriso', 'Deïdo', 'Makepe'].indexed)
      Neighborhood(id: '00000000-0000-4000-8000-00000000010$i', name: name),
  ];

  @override
  Future<Address> createAddress({
    required double latitude,
    required double longitude,
    required String landmark,
    String? neighborhoodId,
    String? label,
    String? contactName,
    String? contactPhone,
  }) async {
    createdAddresses.add({
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
      'neighborhoodId': neighborhoodId,
      'label': label,
      'contactName': contactName,
      'contactPhone': contactPhone,
    });
    final created = fakeAddress('9${createdAddresses.length}', landmark, label: label, neighborhood: 'Akwa');
    if (label != null) saved = [created, ...saved];
    return created;
  }

  @override
  Future<List<Recipient>> recipients({String? query}) async => recents;

  @override
  Future<LocationLink> createLocationLink({String? recipientName, String? recipientPhone}) async {
    createdLinks.add({'recipientName': recipientName, 'recipientPhone': recipientPhone});
    return pendingLink(recipientName);
  }

  @override
  Future<LocationLink> locationLink(String id) async => linkAfter ?? pendingLink(null);

  // --- Prix, commande, paiement ------------------------------------------------------

  final quotes = <Map<String, Object?>>[];
  final created = <({String key, Map<String, Object?> body, bool batch})>[];
  final paid = <({String orderId, String phone, String operator})>[];
  final cancelled = <String>[];

  /// Refus renvoyé à la prochaine création de commande.
  ApiException? createError;

  /// États successifs du paiement relu (le dernier est répété).
  List<String> paymentStatuses = ['PENDING'];

  @override
  Future<Quote> quote({
    required String pickupAddressId,
    required String dropoffAddressId,
    required String packageSize,
    DateTime? scheduledFor,
    String? promoCode,
  }) async {
    quotes.add({'dropoff': dropoffAddressId, 'size': packageSize, 'promo': promoCode, 'at': scheduledFor});
    if (promoCode != null && promoCode != 'BIENVENUE') {
      throw const ApiException(code: 'PROMO_INVALID', message: 'Code promo inconnu.', status: 422);
    }
    final surcharges = [
      if (packageSize == 'XL') (code: 'HEAVY_PARCEL', amount: 500),
      if (scheduledFor != null && (scheduledFor.hour >= 20 || scheduledFor.hour < 6)) (code: 'NIGHT', amount: 300),
    ];
    final discount = promoCode == null ? 0 : 500;
    const base = 1200;
    return Quote(
      distanceMeters: 4200,
      estimatedMinutes: 18,
      basePrice: base,
      surcharges: surcharges,
      discountTotal: discount,
      totalPrice: base + surcharges.fold<int>(0, (sum, s) => sum + s.amount) - discount,
      promoCode: promoCode,
    );
  }

  PlacedOrder _placed(int i, Map<String, Object?> item) => PlacedOrder(
    id: '00000000-0000-4000-8000-00000000050$i',
    reference: 'TR-4830$i',
    status: 'SEARCHING_RIDER',
    totalPrice: item['packageSize'] == 'XL' ? 1700 : 1200,
  );

  @override
  Future<Placement> createOrder({
    required String idempotencyKey,
    required Map<String, Object?> shared,
    required Map<String, Object?> delivery,
    String? promoCode,
  }) async {
    created.add((key: idempotencyKey, body: {...shared, ...delivery, 'promoCode': ?promoCode}, batch: false));
    final error = createError;
    if (error != null) {
      createError = null;
      throw error;
    }
    return Placement(orders: [_placed(1, delivery)], pickupCode: '4821');
  }

  @override
  Future<Placement> createBatch({
    required String idempotencyKey,
    required Map<String, Object?> shared,
    required List<Map<String, Object?>> deliveries,
  }) async {
    created.add((key: idempotencyKey, body: {...shared, 'items': deliveries}, batch: true));
    return Placement(
      orders: [for (final (i, d) in deliveries.indexed) _placed(i + 1, d)],
      pickupCode: '7302',
      batchId: '00000000-0000-4000-8000-000000000600',
    );
  }

  @override
  Future<Payment> payOrder(String orderId, {required String phone, required String operator}) async {
    paid.add((orderId: orderId, phone: phone, operator: operator));
    return const Payment(
      id: '00000000-0000-4000-8000-000000000700',
      status: 'PENDING',
      amount: 1200,
      failureReason: null,
    );
  }

  final batchPaid = <({String batchId, String phone, String operator})>[];

  @override
  Future<Payment> payBatch(String batchId, {required String phone, required String operator}) async {
    batchPaid.add((batchId: batchId, phone: phone, operator: operator));
    return const Payment(
      id: '00000000-0000-4000-8000-000000000701',
      status: 'PENDING',
      amount: 2900,
      failureReason: null,
    );
  }

  @override
  Future<Payment> payment(String id) async {
    final status = paymentStatuses.length > 1 ? paymentStatuses.removeAt(0) : paymentStatuses.first;
    return Payment(id: id, status: status, amount: 1200, failureReason: null);
  }

  @override
  Future<void> cancelOrder(String orderId, String reason) async => cancelled.add(orderId);

  /// Commandes suivies, par identifiant (modifiées par les tests au fil des étapes).
  final tracked = <String, TrackedOrder>{};

  @override
  Future<TrackedOrder> order(String id) async => tracked[id]!;

  @override
  Future<String> newPickupCode(String orderId) async => '5190';

  @override
  Future<Merchant> becomeMerchant({
    required String shopName,
    String? category,
    required String payoutPhone,
    required String payoutOperator,
    String? rccm,
    String? niu,
  }) async {
    merchants.add({
      'shopName': shopName,
      'category': category,
      'payoutPhone': payoutPhone,
      'payoutOperator': payoutOperator,
      'rccm': rccm,
      'niu': niu,
    });
    return Merchant(shopName: shopName, category: category, payoutPhone: payoutPhone, payoutOperator: payoutOperator);
  }
}

/// Adresse de test : point dans Douala, quartier et repère.
Address fakeAddress(
  String id,
  String landmark, {
  String? label,
  String? neighborhood,
  bool verified = false,
  double latitude = 4.05,
  double longitude = 9.70,
}) => Address(
  id: '00000000-0000-4000-8000-0000000002${id.padLeft(2, '0')}',
  label: label,
  contactName: null,
  contactPhone: null,
  neighborhood: neighborhood == null
      ? null
      : Neighborhood(id: '00000000-0000-4000-8000-000000000199', name: neighborhood),
  landmark: landmark,
  latitude: latitude,
  longitude: longitude,
  verified: verified,
  motorbikeRestricted: false,
);

/// Lien de localisation envoyé, en attente du destinataire (ou rempli si [address]).
LocationLink pendingLink(String? name, {Address? address}) => LocationLink(
  id: '00000000-0000-4000-8000-000000000301',
  url: 'https://tara.cm/l/Q7mK2pXa9RtL4vNe',
  recipientName: name,
  status: address == null ? 'PENDING' : 'SUBMITTED',
  expiresAt: DateTime.utc(2026, 11, 7, 10),
  address: address,
);
