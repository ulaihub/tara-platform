import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/course/course_actions.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/features/course/collection_screen.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;

final here = GeoPoint(latitude: 4.0283, longitude: 9.6957, recordedAt: DateTime.utc(2026, 11, 4, 9));

void main() {
  late List<String> sent;
  late FakeRiderApi api;
  late ActiveOrderController active;
  ActionOutcome? done;

  Future<void> pumpCollection(WidgetTester tester) async {
    sent = [];
    done = null;
    api = FakeRiderApi();
    final store = MemoryKeyValueStore();
    final queue = ActionQueue(
      store: store,
      send: (path, body) async {
        sent.add(path.split('/').last);
        return null;
      },
      upload: (path) async => 'proofs/$path',
      deletePhoto: (_) async {},
    );
    active = ActiveOrderController(
      store: store,
      fetchActive: () async => [],
      fetchOrder: (_) async => order(status: 'IN_DELIVERY'),
      hasPendingActions: (_) => false,
    );
    await tester.runAsync(() => active.start(order(status: 'IN_DELIVERY')));
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          riderApiProvider.overrideWithValue(api),
          courseActionsProvider.overrideWithValue(
            CourseActions(queue: queue, activeOrder: active, locate: () async => here),
          ),
        ],
        child: CollectionScreen(
          order: order(status: 'IN_DELIVERY'),
          draft: const DeliveryDraft(photoPath: 'remise.jpg', code: '4821'),
          onBack: () {},
          onDone: (outcome) => done = outcome,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  /// Laisse passer le temps simulé : minuteries et réponses de la fausse API.
  Future<void> wait(WidgetTester tester, Duration duration) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(duration ~/ 10);
    }
  }

  testWidgets('espèces : monnaie à rendre, puis encaissement et livraison', (tester) async {
    await pumpCollection(tester);
    expect(find.text('12\u00A0500\u00A0F (exact)'), findsOneWidget);
    // Solde prépayé : l'argent encaissé est pris sur le solde, déjà mis de côté.
    expect(find.text('Pris sur votre solde (déjà mis de côté)'), findsOneWidget);
    expect(find.text('−12\u00A0500\u00A0F'), findsOneWidget);
    await tapText(tester, '15\u00A0000\u00A0F');
    expect(find.text('2\u00A0500\u00A0F'), findsOneWidget);
    await tapText(tester, 'Confirmer l’encaissement');
    await wait(tester, const Duration(seconds: 1));
    expect(sent, ['collect', 'deliver']);
    expect(done, ActionOutcome.sent);
  });

  testWidgets('Mobile Money : demande au numéro du client, confirmation, livraison', (tester) async {
    await pumpCollection(tester);
    await tapText(tester, 'Mobile Money');
    expect(find.text('Pris sur votre solde (déjà mis de côté)'), findsNothing);
    await tapText(tester, 'Envoyer la demande de paiement');
    // Numéro du destinataire repris ; Orange deviné d'après le 69…
    expect(api.requests.single, ('+237690000202', 'ORANGE'));
    expect(find.text('En attente de la validation du client…'), findsOneWidget);
    expect(find.text('Demande envoyée au client'), findsOneWidget);
    expect(done, isNull);

    api.collections = [const Collection(total: 0, complete: true)];
    await wait(tester, const Duration(seconds: 7));
    expect(sent, ['deliver']);
    expect(done, ActionOutcome.sent);
  });

  testWidgets('Mobile Money refusé : message, renvoi possible', (tester) async {
    await pumpCollection(tester);
    await tapText(tester, 'Mobile Money');
    await tapText(tester, 'Envoyer la demande de paiement');
    api.collections = [const Collection(total: 12500, complete: false)];
    await wait(tester, const Duration(seconds: 7));
    expect(find.textContaining('Paiement non abouti'), findsOneWidget);
    expect(find.text('Renvoyer la demande'), findsOneWidget);
    expect(done, isNull);
  });
}
