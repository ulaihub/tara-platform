import 'package:package_info_plus/package_info_plus.dart';

import '../session/session_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Connexion par code SMS (A1).
class AuthApi {
  AuthApi(this._api, this._store, {required this.platform});

  final ApiClient _api;
  final SessionStore _store;

  /// ANDROID ou IOS.
  final String platform;

  Future<OtpChallenge> requestOtp(String phone, {required String locale}) async => OtpChallenge.fromJson(
    await _api.post('/auth/otp', body: {'phone': phone, 'locale': locale}, auth: false) as Json,
  );

  /// Vérifie le code ; la session est enregistrée dans le stockage chiffré.
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String locale,
    String? termsVersion,
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
        'termsVersion': ?termsVersion,
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
