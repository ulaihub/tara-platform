import 'dart:typed_data';

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
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
    String? photoKey,
    String? voiceNoteKey,
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
        'photoKey': ?photoKey,
        'voiceNoteKey': ?voiceNoteKey,
      },
    ) as Json,
  );

  /// Retire une adresse du carnet ; elle reste attachée aux livraisons passées.
  Future<void> deleteAddress(String id) => _api.delete('/addresses/$id');

  /// Photo de façade (`ADDRESS_PHOTO`) ou note vocale (`VOICE_NOTE`) d'une adresse (B2) :
  /// renvoie la clé à joindre à l'adresse.
  Future<String> uploadMedia(String filePath, String kind, {String? mimeType}) async {
    final file = await MultipartFile.fromFile(
      filePath,
      contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
    );
    final media = await _api.post('/media', body: FormData.fromMap({'kind': kind, 'file': file})) as Json;
    return media['key']! as String;
  }

  /// Quartiers de Douala, pour le choix du quartier d'une adresse.
  Future<List<Neighborhood>> neighborhoods() async => [
    for (final item in await _api.get('/zones', query: {'kind': 'NEIGHBORHOOD', 'city': 'Douala'}) as List<Object?>)
      Neighborhood.fromJson(item! as Json),
  ];

  /// Jeton de notifications de ce téléphone (null : plus de notifications).
  Future<void> registerPushToken(String installationId, String? token) =>
      _api.put('/me/devices/$installationId/push-token', body: {'pushToken': token});

  /// Point placé sur la carte (B1) : desservi ou non, et quartier déduit.
  Future<PointLocation> locate(double latitude, double longitude) async => PointLocation.fromJson(
    await _api.get('/zones/locate', query: {'latitude': latitude, 'longitude': longitude}) as Json,
  );

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

  /// Adresses demandées par lien (B3), les plus récentes d'abord.
  Future<List<LocationLink>> locationLinks() async => [
    for (final item in (await _api.get('/location-links') as List).cast<Json>()) LocationLink.fromJson(item),
  ];

  Future<LocationLink> locationLink(String id) async =>
      LocationLink.fromJson(await _api.get('/location-links/$id') as Json);

  /// Analyse de la photo du colis (envoyée avant avec le type `PARCEL_PHOTO`) : taille, nature,
  /// fragilité proposées, objets interdits signalés.
  Future<ParcelAnalysis> analyzeParcel(String photoKey) async =>
      ParcelAnalysis.fromJson(await _api.post('/orders/parcel-analysis', body: {'photoKey': photoKey}) as Json);

  /// Prix d'une livraison (C2), recalculé ensuite par le serveur à la création.
  Future<Quote> quote({
    required String pickupAddressId,
    required String dropoffAddressId,
    required String packageSize,
    bool loadingHelp = false,
    DateTime? scheduledFor,
    String? promoCode,
  }) async => Quote.fromJson(
    await _api.post(
      '/orders/quote',
      body: {
        'pickup': {'addressId': pickupAddressId},
        'dropoff': {'addressId': dropoffAddressId},
        'packageSize': packageSize,
        if (loadingHelp) 'loadingHelp': true,
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

  /// Recharge du solde Tara par Mobile Money (G1) ; [key] : la même demande renvoyée n'en
  /// crée pas une seconde.
  Future<Payment> topUp({
    required int amount,
    required String phone,
    required String operator,
    required String key,
  }) async => Payment.fromJson(
    await _api.post(
      '/me/wallet/topup',
      body: {'amount': amount, 'phone': phone, 'operator': operator},
      headers: {'Idempotency-Key': key},
    ) as Json,
  );

  /// Historique ligne par ligne (G2) : [account] `customer` (solde Tara) ou `merchant`.
  Future<({List<WalletLine> items, String? nextCursor})> walletLines({
    required String account,
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _api.get(
      '/me/wallet/transactions',
      query: {'account': account, 'limit': limit, 'cursor': ?cursor},
    ) as Json;
    return (
      items: [for (final item in (json['items']! as List).cast<Json>()) WalletLine.fromJson(item)],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  /// Reversements de la boutique et retraits du solde, les plus récents d'abord.
  Future<List<Payout>> payouts({int limit = 10}) async {
    final json = await _api.get('/me/payouts', query: {'limit': limit}) as Json;
    return [for (final item in (json['items']! as List).cast<Json>()) Payout.fromJson(item)];
  }

  /// Reversement immédiat de la boutique (offres Pro et Business, G3).
  /// [proof] : code secret ou empreinte, exigé une fois le code choisi.
  Future<Payout> payoutNow({required String key, PinProof? proof}) async => Payout.fromJson(
    await _api.post('/me/merchant/payouts', body: {...?proof?.toJson()}, headers: {'Idempotency-Key': key}) as Json,
  );

  /// Retrait du solde Tara vers le Mobile Money de l'expéditeur (G8) : tout le disponible.
  Future<Payout> withdraw({
    required String phone,
    required String operator,
    required String key,
    PinProof? proof,
  }) async => Payout.fromJson(
    await _api.post(
      '/me/wallet/refund',
      body: {'phone': phone, 'operator': operator, ...?proof?.toJson()},
      headers: {'Idempotency-Key': key},
    ) as Json,
  );

  /// Toutes les données personnelles du compte (droit d'accès), en JSON.
  Future<Json> exportData() async => await _api.get('/me/export') as Json;

  /// Suppression définitive du compte (droit à l'effacement), confirmée par le code secret
  /// (ou l'empreinte) ; refusée s'il reste une commande en cours, de l'argent dû, un solde ou
  /// un retrait en cours.
  Future<void> deleteAccount({required PinProof proof}) async {
    await _api.post('/me/deletion', body: proof.toJson());
  }

  /// Relevé mensuel PDF de la boutique (G7), [month] au format AAAA-MM.
  Future<Uint8List> statement(String month) => _api.getBytes('/me/merchant/statements/$month');

  /// Après un échec de livraison (E6) : `RETRY` (nouvelle tentative) ou `RETURN` (retour).
  Future<void> failureDecision(String orderId, String decision) =>
      _api.post('/orders/$orderId/failure-decision', body: {'decision': decision});

  /// Note du livreur après la course (F4), une fois, dans les 7 jours.
  Future<OrderRating> rateRider(String orderId, {required int score, String? comment}) async => OrderRating.fromJson(
    await _api.post(
      '/orders/$orderId/rating',
      body: {'score': score, if (comment != null && comment.isNotEmpty) 'comment': comment},
    ) as Json,
  );

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
