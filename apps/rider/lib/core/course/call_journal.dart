import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../session/session_store.dart';

/// Appel passé depuis l'app pendant une course.
@immutable
class CallEntry {
  const CallEntry({required this.to, required this.at, this.durationSeconds});

  factory CallEntry.fromJson(Json json) => CallEntry(
    to: json['to']! as String,
    at: DateTime.parse(json['at']! as String).toLocal(),
    durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
  );

  /// RECIPIENT (destinataire) ou SENDER (expéditeur).
  final String to;
  final DateTime at;

  /// Temps passé hors de l'app pendant l'appel (approché : le téléphone ne dit pas si
  /// l'appel a abouti). Null tant que le livreur n'est pas revenu dans l'app.
  final int? durationSeconds;

  CallEntry withDuration(int seconds) => CallEntry(to: to, at: at, durationSeconds: seconds);

  Json toJson() => {'to': to, 'at': at.toUtc().toIso8601String(), 'durationSeconds': durationSeconds};

  /// Entrée du journal d'appels joint à l'échec (POST /rider/orders/{id}/fail).
  Json toApi() => {'to': to, 'at': at.toUtc().toIso8601String(), 'durationSeconds': durationSeconds ?? 0};
}

/// Journal des appels passés depuis l'app pendant la course, gardé sur le téléphone : il
/// sert de preuve d'appel en cas d'échec (E6). La durée est mesurée au retour dans l'app.
class CallJournal extends ChangeNotifier {
  CallJournal({required this.store, required this.dial, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _key = 'tara.call-journal';

  final KeyValueStore store;

  /// Ouvre l'application Téléphone avec le numéro.
  final Future<void> Function(String phone) dial;
  final DateTime Function() _now;

  Map<String, List<CallEntry>> _calls = {};
  ({String orderId, int index})? _ongoing;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final saved = await store.read(_key);
    if (saved == null) return;
    try {
      _calls = {
        for (final MapEntry(:key, :value) in (jsonDecode(saved) as Json).entries)
          key: [for (final item in value! as List<Object?>) CallEntry.fromJson(item! as Json)],
      };
      notifyListeners();
    } catch (_) {
      await store.delete(_key);
    }
  }

  List<CallEntry> forOrder(String orderId) => List.unmodifiable(_calls[orderId] ?? const <CallEntry>[]);

  /// Heures des appels au destinataire (preuve d'appel exigée selon le motif d'échec).
  List<DateTime> recipientCalls(String orderId) => [
    for (final call in forOrder(orderId))
      if (call.to == 'RECIPIENT') call.at,
  ];

  /// Appel depuis l'app : noté, puis le téléphone compose le numéro.
  Future<void> call(String orderId, {required String to, required String phone}) async {
    await load();
    final entries = [...?_calls[orderId], CallEntry(to: to, at: _now())];
    _calls = {..._calls, orderId: entries};
    _ongoing = (orderId: orderId, index: entries.length - 1);
    notifyListeners();
    await _save();
    await dial(phone);
  }

  /// Retour dans l'app après un appel : sa durée approchée est notée.
  Future<void> resumed() async {
    final ongoing = _ongoing;
    if (ongoing == null) return;
    _ongoing = null;
    final entries = [...?_calls[ongoing.orderId]];
    if (ongoing.index >= entries.length) return;
    final entry = entries[ongoing.index];
    final seconds = _now().difference(entry.at).inSeconds.clamp(0, 3600);
    entries[ongoing.index] = entry.withDuration(seconds);
    _calls = {..._calls, ongoing.orderId: entries};
    notifyListeners();
    await _save();
  }

  /// Seule la course en cours garde ses appels (les autres sont terminées).
  Future<void> retainOnly(String? orderId) async {
    await load();
    if (_calls.keys.every((key) => key == orderId)) return;
    _calls = {
      for (final entry in _calls.entries)
        if (entry.key == orderId) entry.key: entry.value,
    };
    notifyListeners();
    await _save();
  }

  Future<void> _save() => store.write(
    _key,
    jsonEncode({
      for (final e in _calls.entries) e.key: [for (final c in e.value) c.toJson()],
    }),
  );
}
