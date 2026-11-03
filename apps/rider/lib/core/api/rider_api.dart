import 'package:dio/dio.dart';

import 'api_client.dart';
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

  /// Portefeuille : gains disponibles, espèces détenues et plafond.
  Future<Json> wallet() async => await _api.get('/rider/wallet') as Json;

  Future<RiderProfile> profile() async => RiderProfile.fromJson(await _api.get('/riders/me') as Json);

  Future<List<DocumentRequirement>> requirements() async => [
    for (final item in await _api.get('/riders/requirements') as List<Object?>)
      DocumentRequirement.fromJson(item! as Json),
  ];

  Future<RiderProfile> apply({
    required String vehicleType,
    required String guarantorName,
    required String guarantorPhone,
    String? plateNumber,
    ({String name, String phone})? emergencyContact,
  }) async => RiderProfile.fromJson(
    await _api.post(
      '/riders/apply',
      body: {
        'vehicleType': vehicleType,
        'plateNumber': ?plateNumber,
        'guarantorName': guarantorName,
        'guarantorPhone': guarantorPhone,
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

  Future<Earnings> earnings(String period) async =>
      Earnings.fromJson(await _api.get('/rider/earnings', query: {'period': period}) as Json);

  Future<SafetyAlert> raiseAlert(GeoPoint position, {String? orderId, String? note}) async => SafetyAlert.fromJson(
    await _api.post(
      '/rider/alerts',
      body: {'latitude': position.latitude, 'longitude': position.longitude, 'orderId': ?orderId, 'note': ?note},
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

  /// Jeton de notification de cet appareil (null pour ne plus rien recevoir).
  Future<void> registerPushToken(String installationId, String? token) =>
      _api.put('/me/devices/$installationId/push-token', body: {'pushToken': token});
}
