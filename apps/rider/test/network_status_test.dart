import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/network/network_status.dart';

void main() {
  test('plus aucun réseau : hors connexion tout de suite ; retour du réseau : en ligne', () async {
    final network = StreamController<bool>();
    final realtime = ValueNotifier(true);
    final status = NetworkStatus(hasNetwork: network.stream, realtimeConnected: realtime);
    expect(status.offline, isFalse);
    network.add(false);
    await pumpEventQueue();
    expect(status.offline, isTrue);
    network.add(true);
    await pumpEventQueue();
    expect(status.offline, isFalse);
    status.dispose();
    await network.close();
  });

  test('temps réel coupé avec du réseau : hors connexion après un court délai seulement', () async {
    final realtime = ValueNotifier(true);
    final status = NetworkStatus(realtimeConnected: realtime, grace: const Duration(milliseconds: 30));
    realtime.value = false;
    expect(status.offline, isFalse);
    // Reconnexion rapide : pas de bandeau.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    realtime.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(status.offline, isFalse);

    realtime.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(status.offline, isTrue);
    realtime.value = true;
    expect(status.offline, isFalse);
    status.dispose();
  });
}
