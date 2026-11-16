import 'package:package_info_plus/package_info_plus.dart';

import '../session/session_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Connexion par code reçu par WhatsApp ou SMS (A1).
class AuthApi {
  AuthApi(this._api, this._store, {required this.platform});

  final ApiClient _api;
  final SessionStore _store;

  /// ANDROID ou IOS.
  final String platform;

  /// Code par WhatsApp quand le serveur l'a activé, sinon par SMS ; [channel] SMS le force
  /// (« Recevoir par SMS »). [appHash] : empreinte de l'app Android, ajoutée au SMS par le
  /// serveur s'il la connaît (lecture automatique du code).
  Future<OtpChallenge> requestOtp(String phone, {required String locale, String? appHash, OtpChannel? channel}) async =>
      OtpChallenge.fromJson(
        await _api.post(
          '/auth/otp',
          body: {'phone': phone, 'locale': locale, 'appHash': ?appHash, 'channel': ?channel?.code},
          auth: false,
        ) as Json,
      );

  /// Vérifie le code ; la session est enregistrée dans le stockage chiffré. Nouveau compte :
  /// `TERMS_REQUIRED`, puis le même code avec [terms] (versions lues et acceptées), que le
  /// code signe.
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String locale,
    Map<String, String>? terms,
    String? referralCode,
  }) async {
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    final json = await _api.post(
      '/auth/otp/verify',
      auth: false,
      body: {
        'challengeId': challengeId,
        'code': code,
        'locale': locale,
        'terms': ?terms,
        // Code de parrainage d'un ami (C6) : pris en compte à la création du compte seulement.
        'referralCode': ?referralCode,
        'device': {'installationId': await _store.installationId(), 'platform': platform, 'appVersion': ?appVersion},
      },
    ) as Json;
    await _store.write(StoredSession.fromTokens(json));
    return AuthSession.fromJson(json);
  }

  /// Déconnexion : le jeton de renouvellement est révoqué, même si le réseau manque
  /// la session locale est effacée.
  Future<void> logout() async {
    final session = await _store.read();
    try {
      if (session != null) {
        await _api.post('/auth/logout', body: {'refreshToken': session.refreshToken}, auth: false);
      }
    } finally {
      await _store.clear();
    }
  }
}
