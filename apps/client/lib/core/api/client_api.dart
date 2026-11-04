import 'package:tara_core/api/api_client.dart';

import 'client_models.dart';

/// Services de l'API pour l'expéditeur : compte, mode marchand, réglages.
class ClientApi {
  ClientApi(this._api);

  final ApiClient _api;

  Future<Me> me() async => Me.fromJson(await _api.get('/me') as Json);

  /// Commandes de l'expéditeur, la plus récente d'abord : en cours (active) ou terminées
  /// (history).
  Future<List<OrderSummary>> orders({required String scope, int limit = 20}) async {
    final page = await _api.get('/orders', query: {'scope': scope, 'limit': limit}) as Json;
    return [for (final item in page['items']! as List<Object?>) OrderSummary.fromJson(item! as Json)];
  }

  /// Solde Tara de l'expéditeur et, pour un marchand, ventes encaissées à reverser.
  Future<Wallet> wallet() async => Wallet.fromJson(await _api.get('/me/wallet') as Json);

  /// Adresses enregistrées de l'expéditeur (enlèvement), la plus récente d'abord.
  Future<List<Address>> addresses() async => [
    for (final item in await _api.get('/addresses') as List<Object?>) Address.fromJson(item! as Json),
  ];

  /// Nouvelle adresse (B1) : point, repère obligatoire, quartier (déduit du point sinon).
  Future<Address> createAddress({
    required double latitude,
    required double longitude,
    required String landmark,
    String? neighborhoodId,
    String? label,
    String? contactName,
    String? contactPhone,
  }) async => Address.fromJson(
    await _api.post(
      '/addresses',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'landmark': landmark,
        'neighborhoodId': ?neighborhoodId,
        'label': ?label,
        'contactName': ?contactName,
        'contactPhone': ?contactPhone,
      },
    ) as Json,
  );

  /// Quartiers de Douala, pour le choix du quartier d'une adresse.
  Future<List<Neighborhood>> neighborhoods() async => [
    for (final item in await _api.get('/zones', query: {'kind': 'NEIGHBORHOOD', 'city': 'Douala'}) as List<Object?>)
      Neighborhood.fromJson(item! as Json),
  ];

  /// Destinataires fréquents (B5), filtrés par nom ou numéro.
  Future<List<Recipient>> recipients({String? query}) async => [
    for (final item in await _api.get('/recipients', query: {'q': ?query}) as List<Object?>)
      Recipient.fromJson(item! as Json),
  ];

  /// Lien de localisation (B3) : le destinataire place lui-même son point.
  Future<LocationLink> createLocationLink({String? recipientName, String? recipientPhone}) async =>
      LocationLink.fromJson(
        await _api.post('/location-links', body: {'recipientName': ?recipientName, 'recipientPhone': ?recipientPhone})
            as Json,
      );

  Future<LocationLink> locationLink(String id) async =>
      LocationLink.fromJson(await _api.get('/location-links/$id') as Json);

  /// Nom affiché aux livreurs et dans les SMS des destinataires.
  Future<void> updateName(String fullName) => _api.send('PATCH', '/me', body: {'fullName': fullName});

  /// Langue des SMS et notifications (choisie dans l'app).
  Future<void> updateLocale(String languageCode) =>
      _api.send('PATCH', '/me', body: {'locale': languageCode == 'en' ? 'EN' : 'FR'});

  /// Passage en mode marchand (A2) : boutique et numéro Mobile Money des reversements.
  Future<Merchant> becomeMerchant({
    required String shopName,
    String? category,
    required String payoutPhone,
    required String payoutOperator,
    String? rccm,
    String? niu,
  }) async => Merchant.fromJson(
    await _api.put(
      '/me/merchant',
      body: {
        'shopName': shopName,
        'category': ?category,
        'payoutPhone': payoutPhone,
        'payoutOperator': payoutOperator,
        'rccm': ?rccm,
        'niu': ?niu,
      },
    ) as Json,
  );
}
