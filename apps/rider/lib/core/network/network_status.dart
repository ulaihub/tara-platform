import 'dart:async';

import 'package:flutter/foundation.dart';

/// Réseau disponible ou non, pour le bandeau « Hors connexion » (15, A13). Hors connexion :
/// le téléphone n'a aucun réseau, ou le temps réel reste coupé alors qu'il en a un (réseau
/// sans internet, serveur injoignable), au-delà d'un court délai pour éviter les clignotements.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus({
    Stream<bool>? hasNetwork,
    ValueListenable<bool>? realtimeConnected,
    this.grace = const Duration(seconds: 15),
  }) : _realtime = realtimeConnected {
    _network = hasNetwork?.listen((value) {
      _hasNetwork = value;
      _update();
    });
    _realtime?.addListener(_update);
    _update();
  }

  /// État fixé (tests, catalogue).
  NetworkStatus.fixed({required bool offline}) : _realtime = null, grace = Duration.zero {
    _offline = offline;
  }

  final ValueListenable<bool>? _realtime;
  final Duration grace;
  StreamSubscription<bool>? _network;
  Timer? _timer;
  bool _hasNetwork = true;
  bool _offline = false;

  bool get offline => _offline;

  void _update() {
    final cut = !_hasNetwork || (_realtime != null && !_realtime.value);
    if (!cut) {
      _timer?.cancel();
      _timer = null;
      _set(false);
    } else if (!_hasNetwork) {
      // Plus aucun réseau : inutile d'attendre.
      _timer?.cancel();
      _timer = null;
      _set(true);
    } else {
      _timer ??= Timer(grace, () {
        _timer = null;
        if (_realtime != null && !_realtime.value) _set(true);
      });
    }
  }

  void _set(bool offline) {
    if (offline == _offline) return;
    _offline = offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_network?.cancel());
    _realtime?.removeListener(_update);
    super.dispose();
  }
}
