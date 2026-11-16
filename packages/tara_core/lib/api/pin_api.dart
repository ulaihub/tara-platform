import '../session/session_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Code secret du compte (comme Orange Money et MTN MoMo) et empreinte digitale : demandés
/// pour voir le solde, retirer de l'argent et supprimer le compte.
class PinApi {
  PinApi(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  Future<PinStatus> status() async => PinStatus.fromJson(await _api.get('/me/pin') as Json);

  /// Premier code ; changement avec [currentPin] ; code oublié avec le code reçu.
  Future<void> set(String pin, {String? currentPin, String? challengeId, String? code}) async {
    await _api.put(
      '/me/pin',
      body: {'pin': pin, 'currentPin': ?currentPin, 'challengeId': ?challengeId, 'code': ?code},
    );
    // L'empreinte est à réactiver avec le nouveau code.
    await _store.clearBiometricKey();
  }

  /// Code oublié ou bloqué : code par WhatsApp ou SMS pour en choisir un nouveau.
  Future<OtpChallenge> requestResetCode({String? appHash, OtpChannel? channel}) async => OtpChallenge.fromJson(
    await _api.post('/me/pin/code', body: {'appHash': ?appHash, 'channel': ?channel?.code}) as Json,
  );

  /// Vérifie le code ou l'empreinte (avant d'afficher le solde).
  Future<void> verify(PinProof proof) => _api.post('/me/pin/verify', body: proof.toJson());

  /// Empreinte sur ce téléphone : le code est vérifié une fois, la clé reçue le remplace.
  Future<void> enableBiometric(String pin) async {
    final json = await _api.post(
      '/me/pin/biometric',
      body: {'pin': pin, 'installationId': await _store.installationId()},
    ) as Json;
    await _store.writeBiometricKey(json['key']! as String);
  }

  Future<void> disableBiometric() async {
    await _store.clearBiometricKey();
    await _api.send('DELETE', '/me/pin/biometric', query: {'installationId': await _store.installationId()});
  }

  /// Clé de l'empreinte gardée sur ce téléphone, s'il y en a une.
  Future<String?> biometricKey() => _store.biometricKey();

  /// Clé refusée par le serveur (code changé ailleurs) : oubliée ici.
  Future<void> forgetBiometric() => _store.clearBiometricKey();
}
