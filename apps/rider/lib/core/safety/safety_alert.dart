import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/models.dart';
import '../offline/action_queue.dart';
import '../realtime/realtime_client.dart';
import '../session/session_store.dart';

/// Étape de l'alerte SOS sur le téléphone.
enum SafetyStatus {
  /// Aucune alerte en cours.
  idle,

  /// Envoi en cours.
  sending,

  /// Reçue par l'équipe Tara.
  sent,

  /// Sans réseau : gardée sur le téléphone et renvoyée jusqu'à ce que le serveur la reçoive.
  pending,

  /// Pas envoyée : position introuvable ou refus du serveur. Appels et SMS restent possibles.
  failed,
}

/// Alerte gardée sur le téléphone tant que le serveur ne l'a pas reçue.
@immutable
class PendingAlert {
  const PendingAlert({required this.clientEventId, required this.position, this.orderId});

  factory PendingAlert.fromJson(Json json) => PendingAlert(
    clientEventId: json['clientEventId']! as String,
    orderId: json['orderId'] as String?,
    position: GeoPoint(
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recordedAt']! as String),
    ),
  );

  final String clientEventId;
  final GeoPoint position;
  final String? orderId;

  Json toJson() => {
    'clientEventId': clientEventId,
    'orderId': orderId,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracy': position.accuracy,
    'recordedAt': position.recordedAt.toUtc().toIso8601String(),
  };
}

/// Alerte SOS du livreur (14, E8). Volet équipe Tara : l'alerte part au serveur (position,
/// course), qui prévient les agents et le contact d'urgence ; sans réseau elle est gardée et
/// renvoyée sans doublon. Le livreur suit ensuite la prise en charge en direct (agent,
/// police appelée par l'agent, alerte close). Le volet police (appel du 117) est à l'écran.
class SafetyAlertController extends ChangeNotifier {
  SafetyAlertController({
    required this.store,
    required this.send,
    required this.cancel,
    required this.locate,
    Stream<RealtimeEvent>? events,
    this.retryEvery = const Duration(seconds: 15),
    String Function()? newId,
  }) : _newId = newId ?? newEventId {
    _events = events?.listen(_onEvent);
  }

  static const _key = 'tara.safety-alert';

  final KeyValueStore store;
  final Future<SafetyAlert> Function(PendingAlert alert) send;
  final Future<SafetyAlert> Function(String id) cancel;

  /// Position du moment (dernière connue, sinon mesurée).
  final Future<GeoPoint?> Function() locate;
  final Duration retryEvery;
  final String Function() _newId;

  StreamSubscription<RealtimeEvent>? _events;
  Timer? _retry;

  SafetyStatus _status = SafetyStatus.idle;
  SafetyStatus get status => _status;

  /// Alerte telle que le serveur l'a reçue (prise en charge, police appelée, close).
  SafetyAlert? _alert;
  SafetyAlert? get alert => _alert;

  /// Alerte gardée sur le téléphone, pas encore reçue par le serveur.
  PendingAlert? _pending;
  PendingAlert? get pending => _pending;

  /// Position jointe à l'alerte (ou la dernière connue avant l'envoi).
  GeoPoint? _position;
  GeoPoint? get position => _position ?? _pending?.position;

  /// Refus du serveur (message à afficher) ; null pour une position introuvable.
  String? _error;
  String? get error => _error;

  /// Alerte en cours : envoyée et pas encore close, ou en attente du réseau.
  bool get active => _status == SafetyStatus.sending || _status == SafetyStatus.pending || _status == SafetyStatus.sent;

  /// Alerte restée sur le téléphone (app fermée sans réseau) : renvoyée au démarrage.
  Future<void> restore() async {
    final saved = await store.read(_key);
    if (saved == null || _pending != null) return;
    try {
      _pending = PendingAlert.fromJson(jsonDecode(saved) as Json);
    } catch (_) {
      await store.delete(_key);
      return;
    }
    _setStatus(SafetyStatus.pending);
    await retry();
  }

  /// Position affichée avant l'envoi (précision).
  Future<void> refreshPosition() async {
    if (active) return;
    final position = await locate();
    if (position != null) {
      _position = position;
      notifyListeners();
    }
  }

  /// Maintien de 3 s terminé : l'alerte part, ou reste sur le téléphone sans réseau.
  Future<void> raise({String? orderId}) async {
    if (active) return;
    _error = null;
    _alert = null;
    _setStatus(SafetyStatus.sending);
    final position = await locate();
    if (position == null) {
      _setStatus(SafetyStatus.failed);
      return;
    }
    _position = position;
    _pending = PendingAlert(clientEventId: _newId(), position: position, orderId: orderId);
    await store.write(_key, jsonEncode(_pending!.toJson()));
    await _send();
  }

  /// Nouvel essai (minuterie, retour du réseau).
  Future<void> retry() async {
    if (_status == SafetyStatus.pending) await _send();
  }

  Future<void> _send() async {
    final pending = _pending;
    if (pending == null) return;
    try {
      final alert = await send(pending);
      _retry?.cancel();
      _pending = null;
      await store.delete(_key);
      _alert = alert;
      _setStatus(SafetyStatus.sent);
    } on ApiException catch (error) {
      if (error.isNetwork) {
        _setStatus(SafetyStatus.pending);
        _retry ??= Timer.periodic(retryEvery, (_) => unawaited(retry()));
      } else {
        // Refus du serveur (session expirée, compte suspendu) : l'écran propose appels et SMS.
        _retry?.cancel();
        _retry = null;
        _pending = null;
        await store.delete(_key);
        _error = error.message;
        _setStatus(SafetyStatus.failed);
      }
    }
  }

  /// Annulation (fausse manœuvre, danger écarté). Reçue par le serveur, l'alerte reste
  /// ouverte côté équipe, qui rappelle le livreur. Renvoie false sans réseau.
  Future<bool> cancelAlert() async {
    final alert = _alert;
    if (_status == SafetyStatus.sent && alert != null) {
      try {
        await cancel(alert.id);
      } on ApiException catch (error) {
        if (error.isNetwork) return false;
        // Déjà close par l'équipe : rien à annuler.
      }
    }
    _retry?.cancel();
    _retry = null;
    _pending = null;
    await store.delete(_key);
    _alert = null;
    _position = null;
    _setStatus(SafetyStatus.idle);
    return true;
  }

  void _onEvent(RealtimeEvent event) {
    final current = _alert;
    if (event.name != 'safety-alert.status' || current == null || event.payload['id'] != current.id) return;
    final updated = SafetyAlert.fromJson(event.payload);
    _alert = updated;
    // Close par l'équipe : un nouveau maintien relance une alerte.
    _setStatus(updated.resolvedAt != null ? SafetyStatus.idle : SafetyStatus.sent);
  }

  void _setStatus(SafetyStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _retry?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}
