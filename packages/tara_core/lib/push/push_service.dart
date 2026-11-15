import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/models.dart';

/// Notifications (FCM) : autorisation (Android 13 et plus), jeton enregistré auprès de
/// l'API et renouvelé, messages reçus pendant que l'app est ouverte. Les propositions
/// arrivent aussi par le temps réel ; la notification sert quand l'app est fermée.
class PushService {
  PushService({required this.register});

  /// Enregistre le jeton de cet appareil auprès de l'API (null : plus de notifications).
  final Future<void> Function(String? token) register;

  final _messages = StreamController<Json>.broadcast();
  final _opened = StreamController<Json>.broadcast();
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _openedSub;
  Json? _initialOpened;

  /// Messages reçus app ouverte (données : type, orderId, offerId…).
  Stream<Json> get messages => _messages.stream;

  /// Notification touchée alors que l'app était en arrière-plan (données : orderId…).
  Stream<Json> get opened => _opened.stream;

  /// Notification touchée qui a lancé l'app, rendue une seule fois après [start].
  Json? takeInitialOpened() {
    final initial = _initialOpened;
    _initialOpened = null;
    return initial;
  }

  bool get available => Firebase.apps.isNotEmpty;

  Future<void> start() async {
    if (!available) return;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // Jeton d'enregistrement classique : c'est la cible attendue par l'API (champ `token`
    // de FCM HTTP v1). Le nouvel identifiant d'installation (register/onRegistered) ne
    // sera adopté qu'une fois l'envoi côté serveur adapté et vérifié.
    String? token;
    try {
      // ignore: deprecated_member_use
      token = await messaging.getToken();
    } catch (_) {
      // iPhone : le jeton Apple (APNs) peut arriver un peu après le lancement ; le jeton
      // est alors donné par onTokenRefresh ci-dessous.
    }
    if (token != null) await register(token);
    await _refresh?.cancel();
    // ignore: deprecated_member_use
    _refresh = messaging.onTokenRefresh.listen((token) => unawaited(register(token)));
    await _foreground?.cancel();
    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => _messages.add(Map<String, Object?>.from(message.data)),
    );
    await _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _opened.add(Map<String, Object?>.from(message.data)),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) _initialOpened = Map<String, Object?>.from(initial.data);
  }

  /// Déconnexion : l'appareil ne reçoit plus les notifications de ce compte.
  Future<void> stop() async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    await _openedSub?.cancel();
    _refresh = null;
    _foreground = _openedSub = null;
    if (available) {
      try {
        await register(null);
      } catch (_) {
        // Sans réseau : la déconnexion côté serveur révoque déjà la session.
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _messages.close();
    await _opened.close();
  }
}
