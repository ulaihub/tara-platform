import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_core/session/session_store.dart';

import '../api/models.dart';

/// Pourquoi la course a quitté l'écran : livrée, ou retirée au livreur.
enum OrderEnded { delivered, returned, cancelled, reassigned }

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
  static const _tourKey = 'tara.active-tour';

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

  /// Tournée (2c) : tous les colis confiés ensemble, dans l'ordre des arrêts ; vide pour une
  /// course seule. [order] est alors l'arrêt en cours.
  List<RiderOrder> _tour = const [];

  RiderOrder? get order => _order;
  List<RiderOrder> get tour => _tour;

  /// Colis de la tournée encore en cours (à récupérer, à bord, à livrer ou à rendre).
  List<RiderOrder> get tourLeft => [
    for (final stop in _tour)
      if (stop.inProgress) stop,
  ];

  /// Arrêt en cours d'une tournée : l'enlèvement d'abord, puis le client vers qui il roule,
  /// puis le prochain colis à bord ; une livraison impossible passe après les autres clients.
  static RiderOrder? currentStop(List<RiderOrder> tour) {
    final left = [
      for (final stop in tour)
        if (stop.inProgress) stop,
    ]..sort((a, b) => (a.stopSeq ?? 0).compareTo(b.stopSeq ?? 0));
    for (final status in const ['ASSIGNED', 'IN_DELIVERY', 'PICKED_UP', 'DELIVERY_FAILED']) {
      final stop = left.where((order) => order.status == status).firstOrNull;
      if (stop != null) return stop;
    }
    return null;
  }

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
          final tour = await store.read(_tourKey);
          if (tour != null) {
            _tour = [for (final item in jsonDecode(tour) as List<Object?>) RiderOrder.fromJson(item! as Json)];
          }
        } catch (_) {
          await store.delete(_key);
          await store.delete(_tourKey);
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
        await _adopt(latest, active);
      } else if (current != null) {
        await refresh();
      }
    } on ApiException {
      // Sans réseau : la course du téléphone fait foi jusqu'au retour du réseau.
    }
  }

  /// Course acceptée (réponse de l'API). Une tournée : ses autres colis sont relus aussitôt.
  Future<void> start(RiderOrder order) async {
    if (order.tourId == null) return _set(order);
    try {
      await _adopt(order, await fetchActive());
    } on ApiException {
      await _set(order);
    }
  }

  /// La course du serveur, et toute sa tournée s'il y en a une.
  Future<void> _adopt(RiderOrder order, List<RiderOrder> active) async {
    final tourId = order.tourId;
    _tour = tourId == null
        ? const []
        : ([
            for (final stop in active)
              if (stop.tourId == tourId) stop,
          ]..sort((a, b) => (a.stopSeq ?? 0).compareTo(b.stopSeq ?? 0)));
    await _set(currentStop(_tour) ?? order);
  }

  /// Nouvel état de la course (réponse d'une action, ou état changé sur le téléphone). Dans
  /// une tournée, un arrêt terminé laisse place au suivant.
  Future<void> update(RiderOrder order) async {
    if (_tour.any((stop) => stop.id == order.id)) {
      _tour = [for (final stop in _tour) stop.id == order.id ? order : stop];
    }
    if (!order.inProgress) {
      if (order.status == 'CANCELLED') _ended = OrderEnded.cancelled;
      if (order.status == 'DELIVERED') _ended = OrderEnded.delivered;
      if (order.status == 'RETURNED') _ended = OrderEnded.returned;
    }
    final next = currentStop(_tour);
    if (next != null) return _set(next);
    if (order.inProgress) return _set(order);
    await clear();
  }

  /// Relit la course sur le serveur (événement temps réel, retour dans l'app).
  Future<void> refresh() async {
    final current = _order;
    if (current == null || hasPendingActions(current.id)) return;
    try {
      if (_tour.isNotEmpty) {
        // Tournée : tous ses colis sont relus (un autre arrêt a pu être annulé entre-temps).
        final active = {for (final stop in await fetchActive()) stop.id: stop};
        _tour = [
          for (final stop in _tour)
            active[stop.id] ?? (stop.inProgress && stop.id != current.id ? await fetchOrder(stop.id) : stop),
        ];
      }
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
    _tour = const [];
    await store.delete(_key);
    await store.delete(_tourKey);
    notifyListeners();
  }

  Future<void> _set(RiderOrder order) async {
    _order = order;
    await store.write(_key, jsonEncode(order.raw));
    if (_tour.isEmpty) {
      await store.delete(_tourKey);
    } else {
      await store.write(_tourKey, jsonEncode([for (final stop in _tour) stop.raw]));
    }
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
    // Décision de l'expéditeur après un échec : `order.status` en direct, sinon notification.
    const watched = {'order.status', 'order.cancelled', 'order.reassigned', 'order.failure-decision'};
    if (watched.contains(name) && payload['orderId'] == _order?.id) unawaited(refresh());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_pushes?.cancel());
    super.dispose();
  }
}
