import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/location/location_tracker.dart';
import 'package:tara_rider/core/location/online_controller.dart';

class FakePositions implements PositionSource {
  LocationAccess access = LocationAccess.granted;
  // ignore: close_sinks, fermé à la fin de chaque test (addTearDown).
  final stream = StreamController<GeoPoint>.broadcast();
  Duration? watchedInterval;

  @override
  Future<LocationAccess> ensureAccess() async => access;
  @override
  Future<GeoPoint?> current() async => point(0);
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) {
    watchedInterval = interval;
    return stream.stream;
  }
}

GeoPoint point(int seconds) =>
    GeoPoint(latitude: 4.05, longitude: 9.7, recordedAt: DateTime.utc(2026, 11, 3, 9).add(Duration(seconds: seconds)));

void main() {
  test('en ligne : présence envoyée, positions régulières, hors ligne : arrêt', () async {
    final positions = FakePositions();
    addTearDown(positions.stream.close);
    final presence = <bool>[];
    final sent = <GeoPoint>[];
    final controller = OnlineController(
      positions: positions,
      interval: Duration.zero,
      setPresence: ({required online, required position}) async {
        presence.add(online);
        return Presence(online: online, blockers: const []);
      },
      sendPosition: (p) async => sent.add(p),
    );
    expect(await controller.goOnline(), isEmpty);
    expect(controller.online, isTrue);
    positions.stream
      ..add(point(10))
      ..add(point(20));
    await Future<void>.delayed(Duration.zero);
    expect(sent.map((p) => p.recordedAt.second), [10, 20]);
    expect(controller.lastPosition?.recordedAt.second, 20);

    await controller.goOffline();
    positions.stream.add(point(30));
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(2));
    expect(presence, [true, false]);
  });

  test('position non envoyée (sans réseau) : remise au trajet ; envoyée : signal du réseau', () async {
    final positions = FakePositions();
    addTearDown(positions.stream.close);
    final unsent = <GeoPoint>[];
    var sentSignals = 0;
    var networkUp = false;
    final controller = OnlineController(
      positions: positions,
      interval: Duration.zero,
      setPresence: ({required online, required position}) async => Presence(online: online, blockers: const []),
      sendPosition: (p) async {
        if (!networkUp) throw const ApiException(code: ApiException.network, message: 'hors ligne');
      },
      onUnsent: unsent.add,
      onSent: () => sentSignals++,
    );
    await controller.goOnline();
    positions.stream.add(point(10));
    await Future<void>.delayed(Duration.zero);
    expect(unsent.map((p) => p.recordedAt.second), [10]);
    networkUp = true;
    positions.stream.add(point(20));
    await Future<void>.delayed(Duration.zero);
    expect(sentSignals, 1);
    expect(unsent, hasLength(1));
  });

  test('pièces expirées : le serveur refuse, la liste est rendue à l’écran', () async {
    final controller = OnlineController(
      positions: FakePositions(),
      setPresence: ({required online, required position}) async => throw const ApiException(
        code: 'RIDER_NOT_ELIGIBLE',
        message: 'Pièces à renouveler',
        status: 422,
        details: {'reasons': 'DRIVING_LICENSE, INSURANCE'},
      ),
      sendPosition: (_) async {},
    );
    expect(await controller.goOnline(), ['DRIVING_LICENSE', 'INSURANCE']);
    expect(controller.online, isFalse);
  });

  test('position refusée : pas de passage en ligne', () async {
    final positions = FakePositions()..access = LocationAccess.deniedForever;
    final controller = OnlineController(
      positions: positions,
      setPresence: ({required online, required position}) async => fail('pas de présence sans position'),
      sendPosition: (_) async {},
    );
    await expectLater(controller.goOnline(), throwsA(isA<LocationAccessException>()));
  });
}
