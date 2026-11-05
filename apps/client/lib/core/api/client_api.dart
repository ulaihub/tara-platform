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

  /// Prix d'une livraison (C2), recalculé ensuite par le serveur à la création.
  Future<Quote> quote({
    required String pickupAddressId,
    required String dropoffAddressId,
    required String packageSize,
    DateTime? scheduledFor,
    String? promoCode,
  }) async => Quote.fromJson(
    await _api.post(
      '/orders/quote',
      body: {
        'pickup': {'addressId': pickupAddressId},
        'dropoff': {'addressId': dropoffAddressId},
        'packageSize': packageSize,
        'scheduledFor': ?scheduledFor?.toUtc().toIso8601String(),
        'promoCode': ?promoCode,
      },
    ) as Json,
  );

  /// Nouvelle commande (C1). La même [idempotencyKey] renvoyée après une coupure rend la
  /// commande déjà créée au lieu d'en créer une seconde.
  Future<Placement> createOrder({
    required String idempotencyKey,
    required Json shared,
    required Json delivery,
    String? promoCode,
  }) async => Placement.single(
    await _api.post(
      '/orders',
      body: {...shared, ...delivery, 'promoCode': ?promoCode},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Json,
  );

  /// Jusqu'à 10 livraisons depuis le même enlèvement (C4), un seul code d'enlèvement.
  Future<Placement> createBatch({
    required String idempotencyKey,
    required Json shared,
    required List<Json> deliveries,
  }) async => Placement.batch(
    await _api.post(
      '/orders/batch',
      body: {...shared, 'items': deliveries},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Json,
  );

  /// Demande de paiement Mobile Money des frais d'une commande (validée sur le téléphone).
  Future<Payment> payOrder(String orderId, {required String phone, required String operator}) async =>
      Payment.fromJson(await _api.post('/orders/$orderId/pay', body: {'phone': phone, 'operator': operator}) as Json);

  /// Un seul paiement Mobile Money pour toutes les livraisons d'un lot (C4).
  Future<Payment> payBatch(String batchId, {required String phone, required String operator}) async => Payment.fromJson(
    await _api.post('/orders/batches/$batchId/pay', body: {'phone': phone, 'operator': operator}) as Json,
  );

  Future<Payment> payment(String id) async => Payment.fromJson(await _api.get('/payments/$id') as Json);

  /// Commande suivie (F1) : trajet, livreur, étapes.
  Future<TrackedOrder> order(String id) async => TrackedOrder.fromJson(await _api.get('/orders/$id') as Json);

  /// Nouveau code d'enlèvement si l'expéditeur a perdu le précédent.
  Future<String> newPickupCode(String orderId) async =>
      (await _api.post('/orders/$orderId/pickup-code') as Json)['pickupCode']! as String;

  Future<void> cancelOrder(String orderId, String reason) =>
      _api.post('/orders/$orderId/cancel', body: {'reason': reason});

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
