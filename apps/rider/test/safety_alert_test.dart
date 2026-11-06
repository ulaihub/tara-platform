import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/realtime/realtime_client.dart';
import 'package:tara_rider/core/safety/safety_alert.dart';
import 'package:tara_rider/core/session/session_store.dart';

const offline = ApiException(code: ApiException.network, message: 'hors ligne');
final here = GeoPoint(latitude: 4.0511, longitude: 9.6942, accuracy: 8, recordedAt: DateTime.utc(2026, 11, 4, 9));

Json alertJson({String id = 'a1', String? acknowledgedAt, String? policeCalledAt, String? resolvedAt}) => {
  'id': id,
  'createdAt': '2026-11-04T09:00:00.000Z',
  'cancelledAt': null,
  'resolvedAt': resolvedAt,
  'acknowledgedAt': acknowledgedAt,
  'policeCalledAt': policeCalledAt,
  'neighborhood': 'Akwa',
  'riderPlate': 'LT 482 AB',
};

void main() {
  late MemoryKeyValueStore store;
  late List<PendingAlert> sent;
  late List<String> cancelled;
  late Future<SafetyAlert> Function(PendingAlert alert) server;
  late StreamController<RealtimeEvent> events;
  late GeoPoint? position;
  var ids = 0;

  SafetyAlertController controller() => SafetyAlertController(
    store: store,
    send: (alert) async {
      sent.add(alert);
      return server(alert);
    },
    cancel: (id) async {
      cancelled.add(id);
      return SafetyAlert.fromJson({...alertJson(id: id), 'cancelledAt': '2026-11-04T09:05:00.000Z'});
    },
    locate: () async => position,
    events: events.stream,
    newId: () => 'sos-${++ids}',
  );

  setUp(() {
    ids = 0;
    store = MemoryKeyValueStore();
    sent = [];
    cancelled = [];
    server = (_) async => SafetyAlert.fromJson(alertJson());
    events = StreamController<RealtimeEvent>.broadcast();
    addTearDown(events.close);
    position = here;
  });

  test('avec réseau : alerte reçue avec la position, la course et un identifiant', () async {
    final safety = controller();
    await safety.raise(orderId: 'order-1');

    expect(safety.status, SafetyStatus.sent);
    expect(sent.single.clientEventId, 'sos-1');
    expect(sent.single.orderId, 'order-1');
    expect(sent.single.position.accuracy, 8);
    expect(safety.alert?.plate, 'LT 482 AB');
    expect(await store.read('tara.safety-alert'), isNull);
    // Un second maintien ne relance pas d'alerte tant que la première est en cours.
    await safety.raise();
    expect(sent, hasLength(1));
  });

  test('sans réseau : gardée sur le téléphone, renvoyée avec le même identifiant', () async {
    server = (_) async => throw offline;
    final safety = SafetyAlertController(
      store: store,
      send: (alert) async {
        sent.add(alert);
        return server(alert);
      },
      cancel: (_) async => throw offline,
      locate: () async => here,
      retryEvery: const Duration(milliseconds: 20),
      newId: () => 'sos-${++ids}',
    );
    await safety.raise();
    expect(safety.status, SafetyStatus.pending);
    expect(safety.position, here);
    expect(await store.read('tara.safety-alert'), contains('sos-'));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sent.length, greaterThan(1));
    server = (_) async => SafetyAlert.fromJson(alertJson());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(safety.status, SafetyStatus.sent);
    expect(sent.map((a) => a.clientEventId).toSet(), hasLength(1));
    // Envoyée : plus de nouvel essai.
    final count = sent.length;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sent, hasLength(count));
    safety.dispose();
  });

  test('app relancée sans réseau : l’alerte gardée repart au démarrage', () async {
    server = (_) async => throw offline;
    final first = controller();
    await first.raise(orderId: 'order-1');
    first.dispose();

    server = (_) async => SafetyAlert.fromJson(alertJson());
    final second = controller();
    await second.restore();
    expect(second.status, SafetyStatus.sent);
    expect(sent.last.clientEventId, 'sos-1');
    expect(sent.last.orderId, 'order-1');
    second.dispose();
  });

  test('position introuvable ou refus du serveur : pas envoyée, appels et SMS restent', () async {
    position = null;
    final safety = controller();
    await safety.raise();
    expect(safety.status, SafetyStatus.failed);
    expect(sent, isEmpty);

    position = here;
    server = (_) async => throw const ApiException(code: 'FORBIDDEN', message: 'Accès refusé.', status: 403);
    await safety.raise();
    expect(safety.status, SafetyStatus.failed);
    expect(safety.error, 'Accès refusé.');
    expect(await store.read('tara.safety-alert'), isNull);
  });

  test('suivi en direct : agent, police appelée, puis alerte close', () async {
    final safety = controller();
    await safety.raise();

    events.add(RealtimeEvent('safety-alert.status', alertJson(id: 'autre', acknowledgedAt: '2026-11-04T09:01:00Z')));
    await pumpEventQueue();
    expect(safety.alert?.acknowledgedAt, isNull);

    events.add(RealtimeEvent('safety-alert.status', alertJson(acknowledgedAt: '2026-11-04T09:01:00Z')));
    await pumpEventQueue();
    expect(safety.alert?.acknowledgedAt, isNotNull);

    events.add(
      RealtimeEvent(
        'safety-alert.status',
        alertJson(acknowledgedAt: '2026-11-04T09:01:00Z', policeCalledAt: '2026-11-04T09:03:00Z'),
      ),
    );
    await pumpEventQueue();
    expect(safety.alert?.policeCalledAt, isNotNull);
    expect(safety.status, SafetyStatus.sent);

    events.add(RealtimeEvent('safety-alert.status', alertJson(resolvedAt: '2026-11-04T09:20:00Z')));
    await pumpEventQueue();
    expect(safety.status, SafetyStatus.idle);
    expect(safety.active, isFalse);
  });

  test('annulation : envoyée au serveur ; sans réseau, l’alerte reste en cours', () async {
    final safety = controller();
    await safety.raise();
    expect(await safety.cancelAlert(), isTrue);
    expect(cancelled, ['a1']);
    expect(safety.status, SafetyStatus.idle);

    await safety.raise();
    final unreachable = SafetyAlertController(
      store: store,
      send: (_) async => SafetyAlert.fromJson(alertJson(id: 'a2')),
      cancel: (_) async => throw offline,
      locate: () async => here,
    );
    await unreachable.raise();
    expect(await unreachable.cancelAlert(), isFalse);
    expect(unreachable.status, SafetyStatus.sent);
    unreachable.dispose();
  });
}
