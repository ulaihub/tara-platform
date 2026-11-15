import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/models.dart';
import '../session/session_store.dart';

/// Événement reçu du serveur : `offer.new`, `offer.closed`, `order.status`,
/// `payment.status`, `payout.status`, `location-link.submitted`, `session.expired`.
@immutable
class RealtimeEvent {
  const RealtimeEvent(this.name, this.payload);
  final String name;
  final Json payload;
}

/// Connexion temps réel (Socket.IO, espace `/realtime`). Le jeton d'accès est relu à chaque
/// (re)connexion : après un renouvellement, la reconnexion suivante utilise le nouveau.
/// Le temps réel accélère l'app ; l'API REST reste la référence (rien n'est perdu sans lui).
///
/// Coupure réseau : Socket.IO se reconnecte seul. Refus du serveur à la reconnexion (jeton
/// expiré pendant la coupure, par exemple) : Socket.IO abandonne ; le jeton est alors
/// renouvelé et la connexion relancée, avec un délai qui s'allonge si le refus se répète.
class RealtimeClient {
  RealtimeClient({
    required this.baseUrl,
    required this.store,
    this.onTokenRejected,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 60)],
  });

  static const events = [
    'offer.new',
    'offer.closed',
    'order.status',
    'payment.status',
    'payout.status',
    'location-link.submitted',
    'rider.position',
  ];

  final String baseUrl;
  final SessionStore store;

  /// Jeton refusé ou expiré : l'app le renouvelle (requête REST) puis se reconnecte.
  final Future<void> Function()? onTokenRejected;

  /// Attente avant chaque nouvel essai après un refus du serveur (la dernière se répète).
  final List<Duration> retryDelays;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final connected = ValueNotifier<bool>(false);
  io.Socket? _socket;
  Timer? _retry;
  int _refusals = 0;
  bool _renewing = false;

  Stream<RealtimeEvent> get stream => _events.stream;

  void connect() {
    if (_socket != null) return;
    final socket = io.io(
      '$baseUrl/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setAuthFn((callback) {
            unawaited(store.read().then((session) => callback({'token': session?.accessToken ?? ''})));
          })
          .build(),
    );
    socket
      ..onConnect((_) {
        _refusals = 0;
        connected.value = true;
      })
      ..onDisconnect((_) => connected.value = false)
      ..on('session.expired', (_) => unawaited(_renewAndReconnect()))
      ..onConnectError((_) {
        connected.value = false;
        // Socket.IO ne réessaie plus de lui-même après un refus du serveur (socket inactif).
        if (!socket.active) _scheduleRenewal();
      });
    for (final name in events) {
      socket.on(name, (data) {
        if (data is Map) _events.add(RealtimeEvent(name, Map<String, Object?>.from(data)));
      });
    }
    _socket = socket..connect();
  }

  void _scheduleRenewal() {
    if (_retry != null || _renewing || _socket == null) return;
    final delay = retryDelays[_refusals < retryDelays.length ? _refusals : retryDelays.length - 1];
    _refusals += 1;
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(_renewAndReconnect());
    });
  }

  Future<void> _renewAndReconnect() async {
    if (_renewing || _socket == null) return;
    _renewing = true;
    _socket?.disconnect();
    try {
      await onTokenRejected?.call();
    } catch (_) {
      // Sans réseau : la reconnexion échouera et sera retentée plus tard.
    } finally {
      _renewing = false;
    }
    // Déconnecté entre-temps (session terminée) : on ne rouvre rien.
    _socket?.connect();
  }

  /// Position envoyée par le temps réel (moins coûteux qu'une requête HTTP).
  bool sendLocation(GeoPoint position) {
    final socket = _socket;
    if (socket == null || !connected.value) return false;
    socket.emit('rider.location', position.toJson());
    return true;
  }

  /// Suit une commande (statut, position du livreur). [onAck] reçoit la réponse du
  /// serveur : statut et dernière position connue, pour ne pas attendre le prochain envoi.
  void subscribeOrder(String orderId, {void Function(Json ack)? onAck}) {
    final socket = _socket;
    if (socket == null) return;
    if (onAck == null) {
      socket.emit('order.subscribe', {'orderId': orderId});
      return;
    }
    socket.emitWithAck(
      'order.subscribe',
      {'orderId': orderId},
      ack: (Object? data) {
        if (data is Map) onAck(Map<String, Object?>.from(data));
      },
    );
  }

  void unsubscribeOrder(String orderId) => _socket?.emit('order.unsubscribe', {'orderId': orderId});

  void disconnect() {
    _retry?.cancel();
    _retry = null;
    _refusals = 0;
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  Future<void> dispose() async {
    disconnect();
    connected.dispose();
    await _events.close();
  }
}
