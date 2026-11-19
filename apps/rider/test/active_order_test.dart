import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';

import 'helpers/orders.dart';

const offline = ApiException(code: ApiException.network, message: 'hors ligne');
const _key = 'tara.active-order';

class _Server {
  List<RiderOrder> active = [];
  RiderOrder? byId;
  Object? error;
  int fetches = 0;

  Future<List<RiderOrder>> fetchActive() async {
    if (error != null) throw error!;
    return active;
  }

  Future<RiderOrder> fetchOrder(String id) async {
    fetches++;
    if (error != null) throw error!;
    return byId!;
  }
}

void main() {
  late MemoryKeyValueStore store;
  late _Server server;
  late StreamController<RealtimeEvent> events;
  var pending = false;

  ActiveOrderController controller() => ActiveOrderController(
    store: store,
    fetchActive: server.fetchActive,
    fetchOrder: server.fetchOrder,
    hasPendingActions: (_) => pending,
    events: events.stream,
  );

  setUp(() {
    store = MemoryKeyValueStore();
    server = _Server();
    events = StreamController<RealtimeEvent>.broadcast();
    pending = false;
  });

  tearDown(() => events.close());

  test('garde la course sur le téléphone et la reprend sans réseau', () async {
    final first = controller();
    await first.start(order());
    expect(jsonDecode((await store.read(_key))!), isA<Map<String, Object?>>());

    server.error = offline;
    final restarted = controller();
    await restarted.restore();
    expect(restarted.order?.reference, 'TR-48213');
    expect(restarted.order?.pickup.line, 'Akwa · face à la pharmacie du Centre');
  });

  test('au démarrage, la course du serveur remplace celle du téléphone', () async {
    await controller().start(order());
    server.active = [order(status: 'IN_DELIVERY')];
    final restarted = controller();
    await restarted.restore();
    expect(restarted.order?.status, 'IN_DELIVERY');
  });

  test('actions encore en file : l’état du téléphone, en avance, est gardé', () async {
    await controller().start(order(status: 'PICKED_UP'));
    pending = true;
    server.active = [order()];
    final restarted = controller();
    await restarted.restore();
    expect(restarted.order?.status, 'PICKED_UP');
  });

  test('course annulée par l’expéditeur : retirée et signalée une fois', () async {
    final active = controller();
    await active.start(order());
    await active.update(order(status: 'CANCELLED'));
    expect(active.order, isNull);
    expect(await store.read(_key), isNull);
    expect(active.takeEnded(), OrderEnded.cancelled);
    expect(active.takeEnded(), isNull);
  });

  test('course introuvable (réattribuée) : retirée et signalée', () async {
    final active = controller();
    await active.start(order());
    server.error = const ApiException(code: 'ORDER_NOT_FOUND', message: '', status: 404);
    await active.refresh();
    expect(active.order, isNull);
    expect(active.takeEnded(), OrderEnded.reassigned);
  });

  test('un événement temps réel de la course la relit sur le serveur', () async {
    final active = controller();
    await active.start(order());
    server.byId = order(status: 'PICKED_UP');
    events.add(const RealtimeEvent('order.status', {'orderId': '00000000-0000-4000-8000-000000000099'}));
    await pumpEventQueue();
    expect(server.fetches, 0);
    events.add(const RealtimeEvent('order.status', {'orderId': '00000000-0000-4000-8000-000000000002'}));
    await pumpEventQueue();
    expect(active.order?.status, 'PICKED_UP');
  });

  test('une notification d’annulation de la course la relit aussi', () async {
    final pushes = StreamController<Json>.broadcast();
    final active = ActiveOrderController(
      store: store,
      fetchActive: server.fetchActive,
      fetchOrder: server.fetchOrder,
      hasPendingActions: (_) => pending,
      pushes: pushes.stream,
    );
    await active.start(order());
    server.byId = order(status: 'CANCELLED');
    pushes.add({'type': 'order.cancelled', 'orderId': '00000000-0000-4000-8000-000000000002'});
    await pumpEventQueue();
    expect(active.order, isNull);
    expect(active.takeEnded(), OrderEnded.cancelled);
    await pushes.close();
  });

  test('quand la file de la course se vide, la course est relue', () async {
    final active = controller();
    await active.start(order());
    pending = true;
    active.queueChanged();
    expect(server.fetches, 0);
    pending = false;
    server.byId = order(status: 'IN_DELIVERY');
    active.queueChanged();
    await pumpEventQueue();
    expect(active.order?.status, 'IN_DELIVERY');
  });

  test('livrée : la course quitte le téléphone, le livreur en est informé', () async {
    final active = controller();
    await active.start(order());
    await active.update(order(status: 'DELIVERED'));
    expect(active.order, isNull);
    expect(active.takeEnded(), OrderEnded.delivered);
  });

  group('tournée (2c)', () {
    RiderOrder stop(String id, int seq, String status) => RiderOrder.fromJson({
      ...orderJson(id: id, status: status),
      'tourId': '00000000-0000-4000-8000-0000000000aa',
      'stopSeq': seq,
    });

    test('tous les colis sont gardés ; l’enlèvement d’abord, puis les arrêts dans l’ordre', () async {
      final a = stop('00000000-0000-4000-8000-000000000011', 1, 'ASSIGNED');
      final b = stop('00000000-0000-4000-8000-000000000012', 2, 'ASSIGNED');
      final c = stop('00000000-0000-4000-8000-000000000013', 3, 'ASSIGNED');
      server.active = [c, b, a];
      final active = controller();
      await active.start(b);
      expect(active.tour, hasLength(3));
      expect(active.order?.id, a.id);

      // Colis récupérés : le premier client est l'arrêt en cours.
      for (final picked in [a, b, c]) {
        await active.update(picked.withStatus('PICKED_UP'));
      }
      expect(active.order?.id, a.id);
      await active.update(a.withStatus('IN_DELIVERY'));
      await active.update(a.withStatus('DELIVERED'));
      // Arrêt livré : la tournée continue avec le suivant, sans finir la course.
      expect(active.takeEnded(), OrderEnded.delivered);
      expect(active.order?.id, b.id);
      expect(active.tourLeft.map((o) => o.id), [b.id, c.id]);

      // Livraison impossible chez b : il passe après c.
      await active.update(b.withStatus('DELIVERY_FAILED'));
      expect(active.order?.id, c.id);

      // Reprise sur le téléphone : la tournée revient telle quelle.
      final again = controller();
      server.error = offline;
      await again.restore();
      expect(again.tour, hasLength(3));
      expect(again.order?.id, c.id);
    });

    test('dernier arrêt livré : la course se termine', () async {
      final a = stop('00000000-0000-4000-8000-000000000021', 1, 'IN_DELIVERY');
      final b = stop('00000000-0000-4000-8000-000000000022', 2, 'DELIVERED');
      server.active = [a];
      final active = controller();
      await active.start(a);
      await active.update(a.withStatus('DELIVERED'));
      expect(active.order, isNull);
      expect(active.takeEnded(), OrderEnded.delivered);
      expect(b.inProgress, isFalse);
    });
  });
}
