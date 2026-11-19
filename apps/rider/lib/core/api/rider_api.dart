import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:tara_core/api/api_client.dart';

import 'models.dart';

/// Routes de l'app livreur. Les actions d'une course (enlèvement, encaissement espèces,
/// livraison, échec, retour) passent par la file hors connexion, pas directement ici.
class RiderApi {
  RiderApi(this._api);

  final ApiClient _api;

  Future<RiderConfig> config() async => RiderConfig.fromJson(await _api.get('/rider/config') as Json);

  /// Compte : nom, téléphone, langue.
  Future<Json> me() async => await _api.get('/me') as Json;

  /// Nom affiché du livreur (PATCH /me).
  Future<void> updateName(String fullName) => _api.send('PATCH', '/me', body: {'fullName': fullName});

  /// Langue des SMS et notifications envoyés au livreur (choisie dans le profil).
  Future<void> updateLocale(String languageCode) =>
      _api.send('PATCH', '/me', body: {'locale': languageCode == 'en' ? 'EN' : 'FR'});

  /// Portefeuille : gains disponibles, espèces détenues et plafond.
  Future<Json> wallet() async => await _api.get('/rider/wallet') as Json;

  Future<RiderProfile> profile() async => RiderProfile.fromJson(await _api.get('/riders/me') as Json);

  Future<List<DocumentRequirement>> requirements() async => [
    for (final item in await _api.get('/riders/requirements') as List<Object?>)
      DocumentRequirement.fromJson(item! as Json),
  ];

  Future<RiderProfile> apply({
    required String vehicleType,
    String? plateNumber,
    ({String name, String phone})? guarantor,
    ({String name, String phone})? emergencyContact,
  }) async => RiderProfile.fromJson(
    await _api.post(
      '/riders/apply',
      body: {
        'vehicleType': vehicleType,
        'plateNumber': ?plateNumber,
        if (guarantor != null) ...{'guarantorName': guarantor.name, 'guarantorPhone': guarantor.phone},
        if (emergencyContact != null)
          'emergencyContact': {'name': emergencyContact.name, 'phone': emergencyContact.phone},
      },
    ) as Json,
  );

  /// Pièce justificative (photo compressée ou PDF, 5 Mo au plus côté serveur).
  Future<void> uploadDocument({
    required String type,
    required String filePath,
    DateTime? expiresOn,
    void Function(double progress)? onProgress,
  }) async {
    await _api.post(
      '/riders/me/documents',
      onSendProgress: onProgress == null ? null : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
      body: FormData.fromMap({
        'type': type,
        if (expiresOn != null) 'expiresOn': expiresOn.toIso8601String().substring(0, 10),
        'file': await MultipartFile.fromFile(filePath),
      }),
    );
  }

  Future<RiderProfile> setEmergencyContact(String name, String phone) async => RiderProfile.fromJson(
    await _api.put('/riders/me/emergency-contact', body: {'name': name, 'phone': phone}) as Json,
  );

  Future<RiderProfile> removeEmergencyContact() async =>
      RiderProfile.fromJson(await _api.delete('/riders/me/emergency-contact') as Json);

  Future<Presence> setPresence({required bool online, required GeoPoint position}) async =>
      Presence.fromJson(await _api.put('/rider/presence', body: {'online': online, ...position.toJson()}) as Json);

  Future<Presence> presence() async => Presence.fromJson(await _api.get('/rider/presence') as Json);

  Future<void> sendLocation(GeoPoint position) => _api.post('/rider/location', body: position.toJson());

  Future<List<Json>> offers() async => [
    for (final item in await _api.get('/rider/offers') as List<Object?>) item! as Json,
  ];

  Future<Json> acceptOffer(String offerId) async => await _api.post('/rider/offers/$offerId/accept') as Json;

  Future<void> declineOffer(String offerId) => _api.post('/rider/offers/$offerId/decline');

  Future<List<Json>> orders({required String scope}) async {
    final page = await _api.get('/rider/orders', query: {'scope': scope}) as Json;
    return [for (final item in page['items']! as List<Object?>) item! as Json];
  }

  Future<Json> order(String id) async => await _api.get('/rider/orders/$id') as Json;

  /// Courses en cours, la plus récente d'abord.
  Future<List<RiderOrder>> activeOrders() async => [
    for (final json in await orders(scope: 'active')) RiderOrder.fromJson(json),
  ];

  Future<RiderOrder> riderOrder(String id) async => RiderOrder.fromJson(await order(id));

  /// Expéditeur absent après l'attente maximale (D) : la course est annulée, l'attente payée.
  Future<RiderOrder> senderAbsent(
    String orderId, {
    required double latitude,
    required double longitude,
    required List<Json> callLog,
  }) async => RiderOrder.fromJson(
    await _api.post(
      '/rider/orders/$orderId/sender-absent',
      body: {'latitude': latitude, 'longitude': longitude, 'callLog': callLog},
    ) as Json,
  );

  /// Arrivé au point d'enlèvement (D) : l'expéditeur est prévenu, l'attente compte.
  Future<RiderOrder> arrived(String orderId, {required double latitude, required double longitude}) async =>
      RiderOrder.fromJson(
        await _api.post('/rider/orders/$orderId/arrived', body: {'latitude': latitude, 'longitude': longitude}) as Json,
      );

  /// Courses terminées (livrées, rendues, annulées), la plus récente d'abord (E9).
  Future<List<RiderOrder>> history() async => [
    for (final json in await orders(scope: 'history')) RiderOrder.fromJson(json),
  ];

  /// Recharge du solde prépayé par Mobile Money (G5) : demande au téléphone du livreur ;
  /// les frais de l'opérateur sont pour Tara, le solde reçoit le montant entier.
  /// [idempotencyKey] : la même demande renvoyée n'en crée pas une seconde.
  Future<PaymentRequest> topUp({
    required int amount,
    required String phone,
    required String operator,
    required String idempotencyKey,
  }) async => PaymentRequest.fromJson(
    await _api.post(
      '/rider/topups',
      body: {'amount': amount, 'phone': phone, 'operator': operator},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Json,
  );

  /// Retrait des gains vers le Mobile Money du livreur (son propre numéro) : [amount] pris
  /// sur le disponible (tout le disponible si absent). Sous le seuil gratuit, une part des
  /// frais Mobile Money est retenue. [idempotencyKey] : la même demande renvoyée n'en crée pas
  /// une seconde.
  /// Retrait des gains ; [proof] : code secret ou empreinte, exigé une fois le code choisi.
  Future<Payout> withdraw({
    int? amount,
    required String phone,
    required String operator,
    required String idempotencyKey,
    PinProof? proof,
  }) async => Payout.fromJson(
    await _api.post(
      '/rider/withdrawals',
      body: {'amount': ?amount, 'phone': phone, 'operator': operator, ...?proof?.toJson()},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Json,
  );

  /// Toutes les données personnelles du compte (droit d'accès), en JSON.
  Future<Json> exportData() async => await _api.get('/me/export') as Json;

  /// Dépôt des espèces détenues par Mobile Money (G5) : demande au téléphone du livreur.
  /// [idempotencyKey] : la même demande renvoyée n'en crée pas une seconde.
  Future<PaymentRequest> depositCash({
    required int amount,
    required String phone,
    required String operator,
    required String idempotencyKey,
  }) async => PaymentRequest.fromJson(
    await _api.post(
      '/rider/cash-deposits',
      body: {'amount': amount, 'phone': phone, 'operator': operator},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Json,
  );

  /// État d'un paiement (repli quand le temps réel est coupé).
  Future<PaymentRequest> payment(String id) async => PaymentRequest.fromJson(await _api.get('/payments/$id') as Json);

  Future<RiderWallet> riderWallet() async => RiderWallet.fromJson(await wallet());

  /// Ce qui reste à encaisser auprès du destinataire.
  Future<Collection> collection(String orderId) async =>
      Collection.fromJson(await _api.get('/rider/orders/$orderId/collection') as Json);

  /// Espèces reçues (frais de retour) : enregistrées tout de suite, prises sur le solde.
  Future<Collection> collectCash(String orderId) async =>
      Collection.fromJson(await _api.post('/rider/orders/$orderId/collect', body: {'method': 'CASH'}) as Json);

  /// Demande de paiement Mobile Money envoyée au téléphone du destinataire.
  Future<Collection> collectMobileMoney(String orderId, {required String phone, required String operator}) async =>
      Collection.fromJson(
        await _api.post(
          '/rider/orders/$orderId/collect',
          body: {'method': 'MOBILE_MONEY', 'phone': phone, 'operator': operator},
        ) as Json,
      );

  /// Note de l'expéditeur après la course (F4), une fois, dans les 7 jours.
  Future<void> rateSender(String orderId, int score) =>
      _api.post('/rider/orders/$orderId/rating', body: {'score': score});

  /// Positions de la course prises sans réseau, envoyées en lot.
  Future<void> uploadTrack(String orderId, List<Json> points) =>
      _api.post('/rider/orders/$orderId/track', body: {'points': points});

  /// Itinéraire de la position du livreur à la prochaine étape de la course.
  Future<RiderRoute> route(String orderId, GeoPoint from) async => RiderRoute.fromJson(
    await _api.get(
      '/rider/orders/$orderId/route',
      query: {'latitude': '${from.latitude}', 'longitude': '${from.longitude}'},
    ) as Json,
  );

  Future<Earnings> earnings(String period) async =>
      Earnings.fromJson(await _api.get('/rider/earnings', query: {'period': period}) as Json);

  /// Alerte SOS (E8). [clientEventId] : renvoyée au retour du réseau, elle n'est pas doublée.
  Future<SafetyAlert> raiseAlert(
    GeoPoint position, {
    required String clientEventId,
    String? orderId,
    String? note,
  }) async => SafetyAlert.fromJson(
    await _api.post(
      '/rider/alerts',
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': ?position.accuracy,
        'orderId': ?orderId,
        'note': ?note,
        'clientEventId': clientEventId,
      },
    ) as Json,
  );

  Future<SafetyAlert> cancelAlert(String id) async =>
      SafetyAlert.fromJson(await _api.post('/rider/alerts/$id/cancel') as Json);

  /// Photo de preuve : renvoie la clé à joindre à l'action (enlèvement, livraison, échec).
  Future<String> uploadProofPhoto(String filePath) async {
    final media = await _api.post(
      '/media',
      body: FormData.fromMap({'kind': 'PROOF_PHOTO', 'file': await MultipartFile.fromFile(filePath)}),
    ) as Json;
    return media['key']! as String;
  }

  /// Photo de façade (`photo`) ou note vocale (`voice`) de l'adresse d'enlèvement
  /// (`pickup`) ou de livraison (`dropoff`), pendant la course (B2).
  Future<Uint8List> addressMedia(String orderId, String stop, String kind) =>
      _api.getBytes('/rider/orders/$orderId/address-media/$stop/$kind');

  /// Jeton de notification de cet appareil (null pour ne plus rien recevoir).
  Future<void> registerPushToken(String installationId, String? token) =>
      _api.put('/me/devices/$installationId/push-token', body: {'pushToken': token});
}
