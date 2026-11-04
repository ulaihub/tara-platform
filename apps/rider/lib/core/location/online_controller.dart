import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tara_core/api/api_exception.dart';

import '../api/models.dart';
import 'location_tracker.dart';

/// Envoi d'une position (temps réel si connecté, sinon requête HTTP).
typedef SendPosition = Future<void> Function(GeoPoint position);

/// Passage en ligne : position obligatoire, puis envoi régulier tant que le livreur est en
/// ligne (toutes les 10 s : le serveur le considère hors ligne après 90 s sans nouvelles).
class OnlineController extends ChangeNotifier {
  OnlineController({
    required this.positions,
    required this.setPresence,
    required this.sendPosition,
    this.onUnsent,
    this.onSent,
    this.interval = const Duration(seconds: 10),
    this.notificationTitle = 'Tara Livreur',
    this.notificationText = 'En ligne : votre position est partagée',
  });

  final PositionSource positions;
  final Future<Presence> Function({required bool online, required GeoPoint position}) setPresence;
  final SendPosition sendPosition;

  /// Position non envoyée (sans réseau) : gardée pour le trajet de la course en cours.
  final void Function(GeoPoint position)? onUnsent;

  /// Position envoyée : le réseau est là, les positions gardées peuvent partir.
  final VoidCallback? onSent;
  final Duration interval;
  final String notificationTitle;
  final String notificationText;

  bool _online = false;
  GeoPoint? _last;
  DateTime? _lastSent;
  StreamSubscription<GeoPoint>? _subscription;

  bool get online => _online;

  /// Dernière position connue (jointe aux actions et à l'alerte).
  GeoPoint? get lastPosition => _last;

  /// Passe en ligne. Renvoie les pièces qui bloquent (expirées, manquantes) ou lève une
  /// [LocationAccessException] si la position n'est pas disponible.
  Future<List<String>> goOnline() async {
    final access = await positions.ensureAccess();
    if (access != LocationAccess.granted) throw LocationAccessException(access);
    final position = await positions.current() ?? _last;
    if (position == null) throw const LocationAccessException(LocationAccess.serviceDisabled);
    _last = position;
    try {
      await setPresence(online: true, position: position);
    } on ApiException catch (error) {
      if (error.code == 'RIDER_NOT_ELIGIBLE') {
        final reasons = error.details['reasons'];
        return reasons is String ? reasons.split(', ') : const ['RIDER_NOT_ELIGIBLE'];
      }
      rethrow;
    }
    _online = true;
    _startWatching();
    notifyListeners();
    return const [];
  }

  Future<void> goOffline() async {
    _online = false;
    await _subscription?.cancel();
    _subscription = null;
    notifyListeners();
    final position = _last ?? await positions.current();
    if (position != null) await setPresence(online: false, position: position);
  }

  void _startWatching() {
    unawaited(_subscription?.cancel());
    _subscription = positions
        .watch(interval: interval, notificationTitle: notificationTitle, notificationText: notificationText)
        .listen(_onPosition);
  }

  Future<void> _onPosition(GeoPoint position) async {
    _last = position;
    // La carte suit la position (écran en ligne).
    notifyListeners();
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < interval * 0.8) return;
    _lastSent = now;
    try {
      await sendPosition(position);
      onSent?.call();
    } on ApiException {
      // Sans réseau : la position suivante partira ; pendant une course, celle-ci est
      // gardée pour le trajet et envoyée au retour du réseau.
      onUnsent?.call(position);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class LocationAccessException implements Exception {
  const LocationAccessException(this.access);
  final LocationAccess access;
}
