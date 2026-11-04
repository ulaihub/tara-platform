import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/auth_api.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/client_api.dart';
import '../core/api/client_models.dart';
import '../core/env.dart';

/// Stockage chiffré du téléphone (remplacé par un stockage en mémoire dans les tests).
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => const SecureKeyValueStore());

/// Adresse de l'API (remplaçable dans les tests).
final apiUrlProvider = Provider<String>((ref) => Env.apiUrl);

/// Réglages d'affichage (thème, langue, effets), chargés au démarrage (main).
final appSettingsProvider = Provider<AppSettings>((ref) => AppSettings());

/// Langue des messages du serveur : celle choisie dans l'app, sinon celle du téléphone
/// (anglais ou, à défaut, français). Recalculée quand l'expéditeur la change.
final languageCodeProvider = Provider<String>((ref) {
  final settings = ref.watch(appSettingsProvider);
  void changed() => ref.invalidateSelf();
  settings.addListener(changed);
  ref.onDispose(() => settings.removeListener(changed));
  return settings.languageCode(PlatformDispatcher.instance.locale);
});

/// Ouverture d'un lien ou d'un appel (remplacée dans les tests).
final launcherProvider = Provider<Future<bool> Function(Uri uri)>((ref) => launchUrl);

/// Version de l'app (remplacée dans les tests).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore(ref.watch(keyValueStoreProvider)));

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ref.watch(apiUrlProvider),
    store: ref.watch(sessionStoreProvider),
    locale: () => ref.read(languageCodeProvider),
    onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
  ),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
  ),
);

final clientApiProvider = Provider<ClientApi>((ref) => ClientApi(ref.watch(apiClientProvider)));

enum AuthStatus { signedOut, signedIn }

/// Session de l'expéditeur : connexion par code SMS, déconnexion, session refusée.
class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async =>
      await ref.read(sessionStoreProvider).read() == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  Future<OtpChallenge> requestCode(String phone) =>
      ref.read(authApiProvider).requestOtp(phone, locale: ref.read(languageCodeProvider));

  Future<AuthSession> verifyCode({
    required String challengeId,
    required String code,
    String? termsVersion,
    String? referralCode,
  }) async {
    final session = await ref
        .read(authApiProvider)
        .verifyOtp(
          challengeId: challengeId,
          code: code,
          locale: ref.read(languageCodeProvider),
          termsVersion: termsVersion,
          referralCode: referralCode,
        );
    state = const AsyncData(AuthStatus.signedIn);
    return session;
  }

  Future<void> logout() async {
    try {
      await ref.read(authApiProvider).logout();
    } finally {
      state = const AsyncData(AuthStatus.signedOut);
    }
  }

  void sessionExpired() => state = const AsyncData(AuthStatus.signedOut);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthStatus>(AuthController.new);

/// Réglages publics de l'app : gardés sur le téléphone, rafraîchis à chaque ouverture.
/// Sans réseau au tout premier lancement, les valeurs par défaut s'appliquent.
class AppConfigController extends AsyncNotifier<AppConfig> {
  static const _key = 'tara.app-config';

  static const fallback = {
    'country': {'code': 'CM', 'dialCode': '+237', 'currency': 'XAF'},
    'supportPhone': null,
    'mobileMoneyOperators': [
      {'code': 'MTN', 'name': 'MTN MoMo'},
      {'code': 'ORANGE', 'name': 'Orange Money'},
    ],
  };

  @override
  Future<AppConfig> build() async {
    final cached = await ref.read(keyValueStoreProvider).read(_key);
    unawaited(refresh());
    return AppConfig.fromJson(cached == null ? fallback : jsonDecode(cached) as Json);
  }

  Future<void> refresh() async {
    try {
      final json = await ref.read(apiClientProvider).get('/public/config', auth: false) as Json;
      final config = AppConfig.fromJson(json);
      await ref.read(keyValueStoreProvider).write(_key, jsonEncode(json));
      state = AsyncData(config);
    } catch (_) {
      // Sans réseau : les réglages gardés restent valables.
    }
  }
}

final appConfigProvider = AsyncNotifierProvider<AppConfigController, AppConfig>(AppConfigController.new);

/// Compte connecté (nom, boutique) ; relu après chaque modification du profil.
final meProvider = FutureProvider<Me>((ref) => ref.read(clientApiProvider).me());
