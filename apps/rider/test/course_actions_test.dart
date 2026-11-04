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

  group('encaissement puis livraison', () {
    const draft = DeliveryDraft(photoPath: 'remise.jpg', code: '4821');
    setUp(() async => active.start(order(status: 'IN_DELIVERY')));

    test('espèces : encaissement d’abord, puis la livraison, la course est livrée', () async {
      final result = await actions.collectCashAndDeliver(order(status: 'IN_DELIVERY'), draft, at: here);
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.map((s) => s.$1.split('/').last), ['collect', 'deliver']);
      expect(sent.first.$2, containsPair('method', 'CASH'));
      expect(sent.first.$2['clientEventId'], isA<String>());
      expect(active.order, isNull);
    });

    test('sans réseau : les deux gardés dans l’ordre, livraison en attente d’envoi', () async {
      server = (path, body) async => throw offline;
      final result = await actions.collectCashAndDeliver(order(status: 'IN_DELIVERY'), draft, at: here);
      expect(result.outcome, ActionOutcome.queued);
      expect(queue.items.map((a) => a.kind), ['collect', 'deliver']);
      expect(active.order?.deliveryQueued, isTrue);
      // Réessai : l'encaissement déjà en file n'est pas doublé.
      await actions.collectCashAndDeliver(order(status: 'IN_DELIVERY'), draft, at: here);
      expect(queue.items.where((a) => a.kind == 'collect'), hasLength(1));
    });

    test('déjà payé (Mobile Money confirmé entre-temps) : on livre sans encaisser', () async {
      server = (path, body) async {
        if (path.endsWith('/collect')) {
          throw const ApiException(code: 'COLLECTION_NOT_EXPECTED', message: 'Rien à encaisser.', status: 409);
        }
        return null;
      };
      final result = await actions.collectCashAndDeliver(order(status: 'IN_DELIVERY'), draft, at: here);
      expect(result.outcome, ActionOutcome.sent);
      expect(queue.items, isEmpty);
      expect(active.order, isNull);
    });
  });
  group('échec, nouvelle tentative et retour', () {
    final calls = [
      {'to': 'RECIPIENT', 'at': '2026-11-03T15:00:00.000Z', 'durationSeconds': 30},
      {'to': 'RECIPIENT', 'at': '2026-11-03T15:06:00.000Z', 'durationSeconds': 25},
    ];
    setUp(() async => active.start(order(status: 'IN_DELIVERY')));

    test('échec reçu : motif, appels et photo du lieu ; la course attend l’expéditeur', () async {
      final result = await actions.fail(
        order(status: 'IN_DELIVERY'),
        reason: 'RECIPIENT_ABSENT',
        callLog: calls,
        photoPath: 'lieu.jpg',
        at: here,
      );
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.single.$1, endsWith('/fail'));
      expect(sent.single.$2, containsPair('reason', 'RECIPIENT_ABSENT'));
      expect(sent.single.$2['callLog'], calls);
      expect(sent.single.$2, containsPair('photoKey', 'proofs/lieu.jpg'));
      expect(active.order?.status, 'DELIVERY_FAILED');
      expect(active.order?.failureReason, 'RECIPIENT_ABSENT');
      expect(active.order?.failureDecisionDueAt?.difference(active.order!.failedAt!), const Duration(minutes: 15));
    });

    test('appels insuffisants selon le serveur : message, l’échec reste à corriger', () async {
      server = (path, body) async => throw const ApiException(
        code: 'FAILURE_CALLS_REQUIRED',
        message: 'Appelez le destinataire au moins 2 fois.',
        status: 422,
      );
      final result = await actions.fail(
        order(status: 'IN_DELIVERY'),
        reason: 'RECIPIENT_ABSENT',
        callLog: const [],
        photoPath: 'lieu.jpg',
        at: here,
      );
      expect(result.outcome, ActionOutcome.refused);
      expect(result.message, 'Appelez le destinataire au moins 2 fois.');
      expect(actions.refused(order().id, 'fail')?.id, result.actionId);
      expect(active.order?.status, 'IN_DELIVERY');
    });

    test('nouvelle tentative : la course repart vers le destinataire', () async {
      await active.update(
        order(status: 'DELIVERY_FAILED', failureDecision: 'RETRY', failureReason: 'RECIPIENT_ABSENT'),
      );
      final result = await actions.retryDelivery(active.order!, at: here);
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.single.$1, endsWith('/retry'));
      expect(active.order?.status, 'IN_DELIVERY');
      expect(active.order?.failureDecision, isNull);
    });

    test('retour avec le code du vendeur : la course est terminée', () async {
      await active.update(order(status: 'DELIVERY_FAILED', failureDecision: 'RETURN', failureReason: 'REFUSED'));
      final result = await actions.returnToSender(active.order!, code: '5521', photoPath: 'rendu.jpg', at: here);
      expect(result.outcome, ActionOutcome.sent);
      expect(sent.single.$1, endsWith('/return'));
      expect(sent.single.$2, containsPair('senderCode', '5521'));
      expect(active.order, isNull);
      expect(active.takeEnded(), OrderEnded.returned);
    });

    test('retour sans réseau : gardé sur le téléphone, la course l’indique', () async {
      server = (path, body) async => throw offline;
      await active.update(order(status: 'DELIVERY_FAILED', failureDecision: 'RETURN', failureReason: 'REFUSED'));
      final result = await actions.returnToSender(active.order!, code: '5521', photoPath: 'rendu.jpg', at: here);
      expect(result.outcome, ActionOutcome.queued);
      expect(active.order?.returnQueued, isTrue);
      expect(queue.items.single.kind, 'return');
    });
  });
}
