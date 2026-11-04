import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/models.dart';
import '../realtime/realtime_client.dart';
import '../session/session_store.dart';

/// Pourquoi la course a quitté l'écran : livrée, ou retirée au livreur.
enum OrderEnded { delivered, cancelled, reassigned }

/// Course en cours du livreur. Gardée sur le téléphone (stockage chiffré) pour que la
/// course, ses adresses et ses codes restent disponibles sans réseau ; tenue à jour par
/// l'API, le temps réel et les actions faites hors ligne.
class ActiveOrderController extends ChangeNotifier {
  ActiveOrderController({
    required this.store,
    required this.fetchActive,
    required this.fetchOrder,
    required this.hasPendingActions,
    Stream<RealtimeEvent>? events,
    Stream<Json>? pushes,
  }) {
    _events = events?.listen((event) => _onEvent(event.name, event.payload));
    // Annulation et réattribution arrivent par notification (`type`, `orderId`).
    _pushes = pushes?.listen((data) => _onEvent('${data['type']}', data));
  }

  static const _key = 'tara.active-order';

  /// Stockage chiffré du téléphone.
  final KeyValueStore store;

  /// Courses en cours selon le serveur (la plus récente d'abord).
  final Future<List<RiderOrder>> Function() fetchActive;
  final Future<RiderOrder> Function(String id) fetchOrder;

  /// Actions de cette course encore dans la file : l'état du téléphone est en avance.
  final bool Function(String orderId) hasPendingActions;

  StreamSubscription<RealtimeEvent>? _events;
  StreamSubscription<Json>? _pushes;
  RiderOrder? _order;
  OrderEnded? _ended;
  bool _loaded = false;
  bool _hadPending = false;

  RiderOrder? get order => _order;

  /// Course livrée, annulée ou réattribuée : à signaler une fois au livreur.
  OrderEnded? takeEnded() {
    final ended = _ended;
    _ended = null;
    return ended;
  }

  /// Au démarrage : la course gardée sur le téléphone, puis celle du serveur.
  Future<void> restore() async {
    if (!_loaded) {
      _loaded = true;
      final raw = await store.read(_key);
      if (raw != null) {
        try {
          _order = RiderOrder.fromJson(jsonDecode(raw) as Json);
        } catch (_) {
          await store.delete(_key);
        }
        notifyListeners();
      }
    }
    try {
      final active = await fetchActive();
      final current = _order;
      if (current != null && hasPendingActions(current.id)) return;
      final latest = active.firstOrNull;
      if (latest != null) {
        await _set(latest);
      } else if (current != null) {
        await refresh();
      }
    } on ApiException {
      // Sans réseau : la course du téléphone fait foi jusqu'au retour du réseau.
    }
  }

  /// Course acceptée (réponse de l'API).
  Future<void> start(RiderOrder order) => _set(order);

  /// Nouvel état de la course (réponse d'une action, ou état changé sur le téléphone).
  Future<void> update(RiderOrder order) async {
    if (order.inProgress) return _set(order);
    if (order.status == 'CANCELLED') _ended = OrderEnded.cancelled;
    if (order.status == 'DELIVERED') _ended = OrderEnded.delivered;
    await clear();
  }

  /// Relit la course sur le serveur (événement temps réel, retour dans l'app).
  Future<void> refresh() async {
    final current = _order;
    if (current == null || hasPendingActions(current.id)) return;
    try {
      await update(await fetchOrder(current.id));
    } on ApiException catch (error) {
      // Introuvable : la course a été donnée à un autre livreur.
      if (error.status == 404) {
        _ended = OrderEnded.reassigned;
        await clear();
      }
    }
  }

  /// Plus de course en cours (terminée, ou déconnexion : rien ne reste sur le téléphone).
  Future<void> clear() async {
    _order = null;
    await store.delete(_key);
    notifyListeners();
  }

  Future<void> _set(RiderOrder order) async {
    _order = order;
    await store.write(_key, jsonEncode(order.raw));
    notifyListeners();
  }

  /// La file d'actions a changé : quand toutes les actions de la course sont parties, la
  /// course est relue sur le serveur (il fait foi à nouveau).
  void queueChanged() {
    final current = _order;
    if (current == null) return;
    final pending = hasPendingActions(current.id);
    if (_hadPending && !pending) unawaited(refresh());
    _hadPending = pending;
  }

  void _onEvent(String name, Json payload) {
    const watched = {'order.status', 'order.cancelled', 'order.reassigned'};
    if (watched.contains(name) && payload['orderId'] == _order?.id) unawaited(refresh());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_pushes?.cancel());
    super.dispose();
  }
}
