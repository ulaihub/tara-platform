import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/core/offline/action_queue.dart';

const offline = ApiException(code: ApiException.network, message: 'hors ligne');
const wrongCode = ApiException(code: 'DELIVERY_CODE_INVALID', message: 'Code incorrect', status: 422);

/// Faux serveur : refuse tout tant que `online` est faux, garde les envois reçus.
class FakeServer {
  bool online = false;
  final sent = <(String, Map<String, Object?>)>[];
  final uploads = <String>[];
  final refused = <String>{};

  Future<Object?> send(String path, Map<String, Object?> body) async {
    if (!online) throw offline;
    if (refused.contains(path)) throw wrongCode;
    sent.add((path, body));
    return null;
  }

  Future<String> upload(String file) async {
    if (!online) throw offline;
    uploads.add(file);
    return 'proof/${uploads.length}';
  }
}

void main() {
  late FakeServer server;
  late MemoryKeyValueStore storage;
  final deleted = <String>[];

  ActionQueue queue() => ActionQueue(
    store: storage,
    send: server.send,
    upload: server.upload,
    deletePhoto: (path) async => deleted.add(path),
  );

  setUp(() {
    server = FakeServer();
    storage = MemoryKeyValueStore();
    deleted.clear();
  });

  test('20 actions sans réseau, toutes envoyées une fois au retour du réseau, dans l’ordre', () async {
    final q = queue();
    final start = DateTime.utc(2026, 11, 3, 9);
    for (var i = 0; i < 20; i++) {
      await q.enqueue(
        orderId: 'order-${i % 4}',
        kind: i.isEven ? 'pickup' : 'deliver',
        body: {'latitude': 4.05, 'longitude': 9.7},
        photoPath: '/photos/$i.jpg',
        now: start.add(Duration(minutes: i)),
      );
    }
    await q.flush();
    expect(q.pendingCount, 20);
    expect(server.sent, isEmpty);

    // Redémarrage de l'app : la file est relue depuis le stockage chiffré.
    final restarted = queue();
    await restarted.load();
    expect(restarted.pendingCount, 20);

    server.online = true;
    await restarted.flush();
    expect(restarted.pendingCount, 0);
    expect(server.sent, hasLength(20));
    expect(server.uploads, hasLength(20));
    expect(deleted, hasLength(20));
    // Ordre respecté, heure réelle de chaque action et identifiants tous différents.
    final times = [for (final (_, body) in server.sent) body['occurredAt']! as String];
    expect(times, [...times]..sort());
    expect(times.first, '2026-11-03T09:00:00.000Z');
    expect({for (final (_, body) in server.sent) body['clientEventId']}, hasLength(20));
    expect(server.sent.first.$2['photoKey'], 'proof/1');
  });

  test('photo envoyée une seule fois même si l’action échoue ensuite', () async {
    final q = queue();
    server.online = true;
    server.refused.add('/rider/orders/A/deliver');
    await q.enqueue(orderId: 'A', kind: 'deliver', body: {'deliveryCode': '1234'}, photoPath: '/p.jpg');
    await q.flush();
    expect(server.uploads, ['/p.jpg']);
    final failure = q.failures.single;
    expect(failure.failureCode, 'DELIVERY_CODE_INVALID');
    expect(failure.body['photoKey'], 'proof/1');

    // Code corrigé par le livreur : même identifiant, pas de nouvel envoi de photo.
    server.refused.clear();
    await q.retry(failure.id, body: {'deliveryCode': '4321'});
    expect(q.items, isEmpty);
    expect(server.uploads, hasLength(1));
    expect(server.sent.single.$2['deliveryCode'], '4321');
    expect(server.sent.single.$2['clientEventId'], failure.id);
  });

  test('une action refusée bloque la suite de sa course, pas les autres courses', () async {
    final q = queue();
    server.refused.add('/rider/orders/A/pickup');
    await q.enqueue(orderId: 'A', kind: 'pickup', body: {});
    await q.enqueue(orderId: 'A', kind: 'depart', body: {});
    await q.enqueue(orderId: 'B', kind: 'pickup', body: {});
    server.online = true;
    await q.flush();
    expect(server.sent.map((s) => s.$1), ['/rider/orders/B/pickup']);
    expect(q.failures.map((f) => f.kind), ['pickup']);
    expect(q.forOrder('A').map((a) => a.kind), ['pickup', 'depart']);

    await q.discard(q.failures.single.id);
    server.refused.clear();
    await q.flush();
    expect(server.sent.map((s) => s.$1).last, '/rider/orders/A/depart');
  });

  test('erreur serveur passagère : l’action reste en attente sans être marquée refusée', () async {
    final q = ActionQueue(
      store: storage,
      send: (_, _) async => throw const ApiException(code: 'INTERNAL_ERROR', message: '', status: 503),
      upload: server.upload,
    );
    await q.enqueue(orderId: 'A', kind: 'depart', body: {});
    await q.flush();
    expect(q.pendingCount, 1);
    expect(q.failures, isEmpty);
  });
  test('encaissement fait hors réseau puis inutile (déjà payé) : retiré, la livraison part', () async {
    final sent = <String>[];
    final q = ActionQueue(
      store: storage,
      send: (path, body) async {
        if (path.endsWith('/collect')) {
          throw const ApiException(code: 'COLLECTION_NOT_EXPECTED', message: 'Rien à encaisser.', status: 409);
        }
        sent.add(path);
        return null;
      },
      upload: (file) async => file,
    );
    await q.enqueue(orderId: 'o1', kind: 'collect', body: {'method': 'CASH'});
    await q.enqueue(orderId: 'o1', kind: 'deliver', body: {'deliveryCode': '4821'});
    await q.flush();
    await q.flush();
    expect(q.items, isEmpty);
    expect(q.failures, isEmpty);
    expect(sent, ['/rider/orders/o1/deliver']);
  });
}
