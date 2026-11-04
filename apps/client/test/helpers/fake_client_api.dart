import 'package:tara_client/core/api/client_api.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_core/api/api_client.dart';
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
Address fakeAddress(String id, String landmark, {String? label, String? neighborhood, bool verified = false}) =>
    Address(
      id: '00000000-0000-4000-8000-0000000002${id.padLeft(2, '0')}',
      label: label,
      contactName: null,
      contactPhone: null,
      neighborhood: neighborhood == null
          ? null
          : Neighborhood(id: '00000000-0000-4000-8000-000000000199', name: neighborhood),
      landmark: landmark,
      latitude: 4.05,
      longitude: 9.70,
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
