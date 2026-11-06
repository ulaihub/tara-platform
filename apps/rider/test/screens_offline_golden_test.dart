import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/network/network_status.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/features/map/tara_map.dart';
import 'package:tara_rider/features/offline/pending_actions_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;

const offlineError = ApiException(code: ApiException.network, message: '');

/// File de la course en cours : trois actions faites sans réseau, ou une refusée.
Future<({ActionQueue queue, ActiveOrderController active})> offlineCourse({bool refused = false}) async {
  final store = MemoryKeyValueStore();
  final queue = ActionQueue(
    store: store,
    send: (path, body) async {
      if (refused && path.endsWith('/deliver')) {
        throw const ApiException(
          code: 'DELIVERY_CODE_INVALID',
          message: 'Code du destinataire incorrect.',
          status: 422,
        );
      }
      throw offlineError;
    },
    upload: (path) async => throw offlineError,
  );
  final active = ActiveOrderController(
    store: store,
    fetchActive: () async => [],
    fetchOrder: (_) async => throw offlineError,
    hasPendingActions: (id) => queue.forOrder(id).any((a) => !a.failed),
  );
  await active.start(order(status: 'IN_DELIVERY'));
  final id = order().id;
  if (refused) {
    await queue.enqueue(
      orderId: id,
      kind: 'deliver',
      body: {'deliveryCode': '0000'},
      now: DateTime(2026, 11, 4, 18, 31),
    );
  } else {
    await queue.enqueue(orderId: id, kind: 'collect', body: {'method': 'CASH'}, now: DateTime(2026, 11, 4, 18, 31));
    await queue.enqueue(
      orderId: id,
      kind: 'deliver',
      body: {'deliveryCode': '4821'},
      photoPath: 'remise.jpg',
      now: DateTime(2026, 11, 4, 18, 32),
    );
  }
  await queue.flush();
  return (queue: queue, active: active);
}

Widget offlineScreen(ActionQueue queue, ActiveOrderController active, {required bool offline}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    realMapProvider.overrideWithValue(false),
    actionQueueProvider.overrideWithValue(queue),
    activeOrderProvider.overrideWithValue(active),
    networkStatusProvider.overrideWithValue(NetworkStatus.fixed(offline: offline)),
  ],
  child: PendingActionsScreen(onContinue: () {}),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('15 hors connexion ${variant.name}', (tester) async {
      final course = (await tester.runAsync(offlineCourse))!;
      await pumpVariant(tester, variant, offlineScreen(course.queue, course.active, offline: true));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('2 actions en attente · enregistrées sur le téléphone'), findsOneWidget);
      expect(find.text('Livraison confirmée'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/15_hors_connexion/${variant.name}.png'));
    });

    goldenTest('15 action refusée ${variant.name}', (tester) async {
      final course = (await tester.runAsync(() => offlineCourse(refused: true)))!;
      await pumpVariant(tester, variant, offlineScreen(course.queue, course.active, offline: false));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Refusée'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/15_action_refusee/${variant.name}.png'));
    });
  }
}
