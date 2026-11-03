import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/auth_api.dart';
import '../core/api/models.dart';
import '../core/api/rider_api.dart';
import '../core/env.dart';
import '../core/offline/action_queue.dart';
import '../core/session/session_store.dart';

/// Stockage chiffré du téléphone (remplacé par un stockage en mémoire dans les tests).
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => const SecureKeyValueStore());

/// Adresse de l'API (remplaçable dans les tests).
final apiUrlProvider = Provider<String>((ref) => Env.apiUrl);

/// Langue des messages du serveur : celle choisie dans l'app.
final languageCodeProvider = Provider<String>((ref) => 'fr');

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

final riderApiProvider = Provider<RiderApi>((ref) => RiderApi(ref.watch(apiClientProvider)));

/// File des actions de course faites sans réseau.
final actionQueueProvider = Provider<ActionQueue>((ref) {
  final api = ref.watch(apiClientProvider);
  final rider = ref.watch(riderApiProvider);
  final queue = ActionQueue(
    store: ref.watch(keyValueStoreProvider),
    send: (path, body) => api.post(path, body: body),
    upload: rider.uploadProofPhoto,
  );
  // Nouvel essai régulier : le retour du réseau n'est pas toujours signalé par le téléphone.
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(queue.flush()));
  ref.onDispose(() {
    timer.cancel();
    queue.dispose();
  });
  unawaited(queue.load());
  return queue;
});

enum AuthStatus { signedOut, signedIn }

/// Session du livreur : connexion par code SMS, déconnexion, session refusée par le serveur.
class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async =>
      await ref.read(sessionStoreProvider).read() == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  Future<OtpChallenge> requestCode(String phone) =>
      ref.read(authApiProvider).requestOtp(phone, locale: ref.read(languageCodeProvider));

  Future<AuthSession> verifyCode({required String challengeId, required String code, String? termsVersion}) async {
    final session = await ref
        .read(authApiProvider)
        .verifyOtp(
          challengeId: challengeId,
          code: code,
          locale: ref.read(languageCodeProvider),
          termsVersion: termsVersion,
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

/// Réglages de l'app : gardés sur le téléphone, rafraîchis à chaque ouverture. Sans réseau
/// au tout premier lancement, les valeurs par défaut du serveur s'appliquent.
class RiderConfigController extends AsyncNotifier<RiderConfig> {
  static const _key = 'tara.rider-config';

  static const fallback = {
    'country': {'code': 'CM', 'dialCode': '+237', 'currency': 'XAF'},
    'safetyHotline': '+237640114064',
    'supportPhone': null,
    'mobileMoneyOperators': [
      {'code': 'MTN', 'name': 'MTN Mobile Money'},
      {'code': 'ORANGE', 'name': 'Orange Money'},
    ],
    'offerTimeoutSeconds': 30,
  };

  @override
  Future<RiderConfig> build() async {
    final store = ref.read(keyValueStoreProvider);
    final cached = await store.read(_key);
    unawaited(refresh());
    return RiderConfig.fromJson(cached == null ? fallback : jsonDecode(cached) as Json);
  }

  Future<void> refresh() async {
    if (await ref.read(sessionStoreProvider).read() == null) return;
    try {
      final json = await ref.read(apiClientProvider).get('/rider/config') as Json;
      await ref.read(keyValueStoreProvider).write(_key, jsonEncode(json));
      state = AsyncData(RiderConfig.fromJson(json));
    } catch (_) {
      // Hors connexion : on garde la dernière configuration connue.
    }
  }
}

final riderConfigProvider = AsyncNotifierProvider<RiderConfigController, RiderConfig>(RiderConfigController.new);
