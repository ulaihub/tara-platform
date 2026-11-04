import 'dart:async';
import 'dart:convert';

import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';

import '../api/models.dart';

/// Envoi d'un lot de points de trajet (POST /rider/orders/{id}/track).
typedef UploadTrack = Future<void> Function(String orderId, List<Json> points);

/// Positions de la course prises sans réseau, gardées sur le téléphone (stockage chiffré)
/// et envoyées en lot au retour du réseau : le trajet enregistré reste complet même dans
/// les zones mal couvertes. Rien n'est gardé en dehors d'une course.
class TrackBuffer {
  TrackBuffer({required this.store, required this.upload, required this.activeOrderId});

  static const _key = 'tara.track-buffer';

  /// Deux heures de positions (une toutes les 10 s) par course au plus : les plus anciennes
  /// cèdent la place.
  static const maxPoints = 720;

  final KeyValueStore store;
  final UploadTrack upload;

  /// Course en cours (null : aucune, rien n'est gardé).
  final String? Function() activeOrderId;

  Map<String, List<Json>> _points = {};
  bool _loaded = false;
  Future<void>? _flushing;

  int get pendingCount => _points.values.fold(0, (sum, list) => sum + list.length);

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await store.read(_key);
    if (raw == null) return;
    try {
      _points = {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map<String, Object?>).entries)
          key: [for (final point in value! as List<Object?>) point! as Json],
      };
    } catch (_) {
      await store.delete(_key);
    }
  }

  Future<void> _save() async {
    _points.removeWhere((_, points) => points.isEmpty);
    if (_points.isEmpty) {
      await store.delete(_key);
    } else {
      await store.write(_key, jsonEncode(_points));
    }
  }

  /// Position non envoyée : gardée si une course est en cours.
  Future<void> add(GeoPoint position) async {
    final orderId = activeOrderId();
    if (orderId == null) return;
    await _load();
    final points = _points.putIfAbsent(orderId, () => []);
    points.add(position.toTrackJson());
    if (points.length > maxPoints) points.removeRange(0, points.length - maxPoints);
    await _save();
  }

  /// Envoie ce qui est gardé. Sans réseau, on garde et on réessaiera ; un refus du serveur
  /// (course introuvable) écarte les points de cette course.
  Future<void> flush() => _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    await _load();
    for (final orderId in List.of(_points.keys)) {
      final points = List.of(_points[orderId] ?? const <Json>[]);
      if (points.isEmpty) continue;
      try {
        await upload(orderId, points);
        _points[orderId]?.removeRange(0, points.length);
      } on ApiException catch (error) {
        if (_transient(error)) return;
        _points.remove(orderId);
      }
      await _save();
    }
  }

  /// Plus rien à garder (déconnexion).
  Future<void> clear() async {
    _points = {};
    _loaded = true;
    await store.delete(_key);
  }

  static bool _transient(ApiException error) =>
      error.isNetwork ||
      error.status == null ||
      error.status! >= 500 ||
      error.status == 408 ||
      error.status == 429 ||
      error.code == 'SESSION_EXPIRED';
}
