import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/course/course_actions.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/core/session/session_store.dart';

import 'helpers/orders.dart';

const offline = ApiException(code: ApiException.network, message: 'hors ligne');
ApiException wrongCode(int remaining) => ApiException(
  code: 'PICKUP_CODE_INVALID',
  message: 'Code de l’expéditeur incorrect. Essais restants : $remaining.',
  status: 422,
);

final here = GeoPoint(latitude: 4.05, longitude: 9.7, recordedAt: DateTime.utc(2026, 11, 3, 9));

void main() {
  late List<(String, Json)> sent;
  late List<String> uploads;
  late List<String> deleted;
  late Future<Object?> Function(String path, Json body) server;
  late ActionQueue queue;
  late ActiveOrderController active;
  late CourseActions actions;

  setUp(() async {
    sent = [];
    uploads = [];
    deleted = [];
    server = (path, body) async => null;
    final store = MemoryKeyValueStore();
    queue = ActionQueue(
      store: store,
      send: (path, body) async {
        final result = await server(path, body);
        sent.add((path, body));
        return result;
      },
      upload: (path) async {
        uploads.add(path);
        return 'proofs/$path';
      },
      deletePhoto: (path) async => deleted.add(path),
    );
    active = ActiveOrderController(
      store: store,
      fetchActive: () async => [],
      fetchOrder: (_) async => throw offline,
      hasPendingActions: (id) => queue.forOrder(id).any((a) => !a.failed),
    );
    await active.start(order());
    actions = CourseActions(queue: queue, activeOrder: active, settleTimeout: const Duration(seconds: 2));
  });

  test('avec réseau : photo, enlèvement puis départ envoyés ; la course passe en livraison', () async {
    final result = await actions.pickUp(order(), code: '7302', photoPath: 'colis.jpg', at: here);
    await queue.flush();

    expect(result.outcome, ActionOutcome.sent);
    expect(uploads, ['colis.jpg']);
    expect(sent.map((s) => s.$1), [
      '/rider/orders/00000000-0000-4000-8000-000000000002/pickup',
      '/rider/orders/00000000-0000-4000-8000-000000000002/depart',
    ]);
    expect(sent.first.$2, containsPair('pickupCode', '7302'));
    expect(sent.first.$2, containsPair('photoKey', 'proofs/colis.jpg'));
    expect(sent.first.$2['clientEventId'], isA<String>());
    expect(active.order?.status, 'IN_DELIVERY');
    expect(deleted, ['colis.jpg']);
  });

  test('sans réseau : tout reste sur le téléphone et la course avance quand même', () async {
    server = (path, body) async => throw offline;
    final result = await actions.pickUp(order(), code: '7302', photoPath: 'colis.jpg', at: here);

    expect(result.outcome, ActionOutcome.queued);
    expect(queue.items.map((a) => a.kind), ['pickup', 'depart']);
    expect(active.order?.status, 'IN_DELIVERY');
    expect(deleted, isEmpty);
  });

  test('code incorrect : message du serveur, puis code corrigé sans renvoyer la photo', () async {
    var attempts = 0;
    server = (path, body) async {
      if (path.endsWith('/pickup') && attempts++ == 0) throw wrongCode(4);
      return null;
    };
    final refused = await actions.pickUp(order(), code: '0000', photoPath: 'colis.jpg', at: here);
    expect(refused.outcome, ActionOutcome.refused);
    expect(refused.message, 'Code de l’expéditeur incorrect. Essais restants : 4.');
    expect(actions.refused(order().id, 'pickup')?.id, refused.actionId);
    expect(active.order?.status, 'ASSIGNED');

    final fixed = await actions.pickUp(
      order(),
      code: '7302',
      photoPath: 'colis.jpg',
      at: here,
      retryActionId: refused.actionId,
    );
    await queue.flush();
    expect(fixed.outcome, ActionOutcome.sent);
    expect(uploads, ['colis.jpg']);
    expect(sent.where((s) => s.$1.endsWith('/depart')), hasLength(1));
    expect(actions.refused(order().id, 'pickup'), isNull);
  });

  test('photo reprise après un refus : l’ancienne action et sa photo sont abandonnées', () async {
    var attempts = 0;
    server = (path, body) async {
      if (path.endsWith('/pickup') && attempts++ == 0) throw wrongCode(4);
      return null;
    };
    final refused = await actions.pickUp(order(), code: '0000', photoPath: 'flou.jpg', at: here);
    await actions.pickUp(order(), code: '7302', photoPath: 'net.jpg', at: here, retryActionId: refused.actionId);
    await queue.flush();

    expect(uploads, ['flou.jpg', 'net.jpg']);
    expect(deleted, containsAll(['flou.jpg', 'net.jpg']));
    expect(queue.items, isEmpty);
  });

  test('réseau très lent : on continue sans attendre, l’envoi se poursuit', () async {
    final slow = Completer<void>();
    server = (path, body) async {
      await slow.future;
      return null;
    };
    final result = await actions.pickUp(order(), code: '7302', photoPath: 'colis.jpg', at: here);
    expect(result.outcome, ActionOutcome.queued);
    expect(active.order?.status, 'IN_DELIVERY');
    slow.complete();
    await queue.flush();
    await queue.flush();
    expect(queue.items, isEmpty);
  });

  group('livraison', () {
    setUp(() async => active.start(order(status: 'IN_DELIVERY')));

    test('avec le code : reçue, la course est livrée et quitte le téléphone', () async {
      final result = await actions.deliver(
        order(status: 'IN_DELIVERY'),
        code: '4821',
        photoPath: 'remise.jpg',
        at: here,
      );
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.single.$1, endsWith('/deliver'));
      expect(sent.single.$2, containsPair('deliveryCode', '4821'));
      expect(sent.single.$2.containsKey('receivedBy'), isFalse);
      expect(active.order, isNull);
    });

    test('sans code : nom de la personne qui reçoit, attente de la validation du support', () async {
      final result = await actions.deliver(
        order(status: 'IN_DELIVERY'),
        receivedBy: 'Sa sœur, Brigitte',
        photoPath: 'remise.jpg',
        at: here,
      );
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.single.$2, containsPair('receivedBy', 'Sa sœur, Brigitte'));
      expect(sent.single.$2.containsKey('deliveryCode'), isFalse);
      expect(active.order?.awaitingSupportValidation, isTrue);
      expect(active.order?.status, 'IN_DELIVERY');
    });

    test('sans réseau : livraison gardée, la course l’indique en attendant l’envoi', () async {
      server = (path, body) async => throw offline;
      final result = await actions.deliver(
        order(status: 'IN_DELIVERY'),
        code: '4821',
        photoPath: 'remise.jpg',
        at: here,
      );
      expect(result.outcome, ActionOutcome.queued);
      expect(active.order?.deliveryQueued, isTrue);
      expect(queue.items.single.kind, 'deliver');
    });

    test('code faux puis passage sans code : l’action refusée est remplacée', () async {
      var attempts = 0;
      server = (path, body) async {
        if (attempts++ == 0) {
          throw const ApiException(
            code: 'DELIVERY_CODE_INVALID',
            message: 'Code du destinataire incorrect.',
            status: 422,
          );
        }
        return null;
      };
      final refused = await actions.deliver(
        order(status: 'IN_DELIVERY'),
        code: '0000',
        photoPath: 'remise.jpg',
        at: here,
      );
      expect(refused.outcome, ActionOutcome.refused);
      expect(actions.refused(order().id, 'deliver')?.id, refused.actionId);

      final fixed = await actions.deliver(
        order(status: 'IN_DELIVERY'),
        receivedBy: 'Le gardien',
        photoPath: 'remise.jpg',
        at: here,
        retryActionId: refused.actionId,
      );
      expect(fixed.outcome, ActionOutcome.sent);
      expect(sent.single.$2.containsKey('deliveryCode'), isFalse);
      // La photo de remise, gardée, n'est pas renvoyée : elle était déjà sur le serveur.
      expect(uploads, ['remise.jpg']);
      expect(sent.single.$2, containsPair('photoKey', 'proofs/remise.jpg'));
      expect(actions.refused(order().id, 'deliver'), isNull);
      expect(queue.items, isEmpty);
    });
  });
}
