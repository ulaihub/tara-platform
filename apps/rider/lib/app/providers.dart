import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/auth_api.dart';
import '../core/api/models.dart';
import '../core/api/rider_api.dart';
import '../core/course/active_order.dart';
import '../core/course/course_actions.dart';
import '../core/course/track_buffer.dart';
import '../core/env.dart';
import '../core/location/location_tracker.dart';
import '../core/location/online_controller.dart';
import '../core/offline/action_queue.dart';
import '../core/push/push_service.dart';
import '../core/realtime/realtime_client.dart';
import '../core/session/session_store.dart';

/// Stockage chiffré du téléphone (remplacé par un stockage en mémoire dans les tests).
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => const SecureKeyValueStore());

/// Adresse de l'API (remplaçable dans les tests).
final apiUrlProvider = Provider<String>((ref) => Env.apiUrl);

/// Langue des messages du serveur : anglais si le téléphone est en anglais, sinon français.
final languageCodeProvider = Provider<String>(
  (ref) => PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'fr',
);

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

/// Course en cours : gardée sur le téléphone, mise à jour par l'API et le temps réel.
final activeOrderProvider = Provider<ActiveOrderController>((ref) {
  final rider = ref.watch(riderApiProvider);
  final queue = ref.watch(actionQueueProvider);
  final controller = ActiveOrderController(
    store: ref.watch(keyValueStoreProvider),
    fetchActive: rider.activeOrders,
    fetchOrder: rider.riderOrder,
    hasPendingActions: (orderId) => queue.forOrder(orderId).any((action) => !action.failed),
    events: ref.watch(realtimeProvider).stream,
    pushes: ref.watch(pushServiceProvider).messages,
  );
  queue.addListener(controller.queueChanged);
  ref.onDispose(() {
    queue.removeListener(controller.queueChanged);
    controller.dispose();
  });
  return controller;
});

/// Positions de la course prises sans réseau (trajet enregistré).
final trackBufferProvider = Provider<TrackBuffer>(
  (ref) => TrackBuffer(
    store: ref.watch(keyValueStoreProvider),
    upload: ref.watch(riderApiProvider).uploadTrack,
    activeOrderId: () => ref.read(activeOrderProvider).order?.id,
  ),
);

/// Actions de course (enlèvement, livraison…) passées par la file hors connexion.
final courseActionsProvider = Provider<CourseActions>(
  (ref) => CourseActions(queue: ref.watch(actionQueueProvider), activeOrder: ref.watch(activeOrderProvider)),
);

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
      // Adresses, contacts et trajet de la course : rien ne reste sur le téléphone.
      await ref.read(activeOrderProvider).clear();
      await ref.read(trackBufferProvider).clear();
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

/// Connexion temps réel du livreur connecté. Jeton refusé : une requête REST le renouvelle.
final realtimeProvider = Provider<RealtimeClient>((ref) {
  final api = ref.watch(apiClientProvider);
  final client = RealtimeClient(
    baseUrl: ref.watch(apiUrlProvider),
    store: ref.watch(sessionStoreProvider),
    onTokenRejected: () async {
      try {
        await api.get('/rider/presence');
      } catch (_) {
        // Session refusée : AuthController repasse à la connexion.
      }
    },
  );
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

/// Passage en ligne et envoi des positions (temps réel, sinon requête HTTP).
final onlineControllerProvider = Provider<OnlineController>((ref) {
  final rider = ref.watch(riderApiProvider);
  final realtime = ref.watch(realtimeProvider);
  final track = ref.watch(trackBufferProvider);
  final controller = OnlineController(
    positions: ref.watch(positionSourceProvider),
    setPresence: rider.setPresence,
    sendPosition: (position) async {
      if (!realtime.sendLocation(position)) await rider.sendLocation(position);
    },
    // Trajet de la course : positions sans réseau gardées, envoyées au retour du réseau.
    onUnsent: (position) => unawaited(track.add(position)),
    onSent: () => unawaited(track.flush()),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final positionSourceProvider = Provider<PositionSource>((ref) => DevicePositionSource());

final pushServiceProvider = Provider<PushService>((ref) {
  final rider = ref.watch(riderApiProvider);
  final store = ref.watch(sessionStoreProvider);
  final push = PushService(register: (token) async => rider.registerPushToken(await store.installationId(), token));
  ref.onDispose(() => unawaited(push.dispose()));
  return push;
});

/// Services actifs tant que le livreur est connecté : temps réel, notifications, file des
/// actions relancée au retour du réseau. Arrêtés à la déconnexion.
final riderRuntimeProvider = Provider<void>((ref) {
  final signedIn = ref.watch(authControllerProvider).value == AuthStatus.signedIn;
  if (!signedIn) return;
  final realtime = ref.watch(realtimeProvider)..connect();
  final queue = ref.watch(actionQueueProvider);
  final push = ref.watch(pushServiceProvider);
  final activeOrder = ref.watch(activeOrderProvider);
  unawaited(push.start().catchError((Object _) {}));
  unawaited(activeOrder.restore());
  final track = ref.watch(trackBufferProvider);
  unawaited(track.flush());
  final connectivity = Connectivity().onConnectivityChanged.listen((results) {
    if (results.contains(ConnectivityResult.none)) return;
    unawaited(queue.flush());
    unawaited(track.flush());
  });
  // Reconnexion du temps réel : souvent le signe que le réseau est revenu.
  void onRealtime() {
    if (realtime.connected.value) unawaited(queue.flush());
  }

  realtime.connected.addListener(onRealtime);
  // Retour dans l'app : file relancée, réglages rafraîchis.
  final lifecycle = AppLifecycleListener(
    onResume: () {
      unawaited(queue.flush());
      unawaited(track.flush());
      unawaited(activeOrder.refresh());
      unawaited(ref.read(riderConfigProvider.notifier).refresh());
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(connectivity.cancel());
    realtime.connected.removeListener(onRealtime);
    realtime.disconnect();
  });
});
