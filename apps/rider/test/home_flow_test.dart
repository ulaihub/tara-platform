import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/course/course_actions.dart';
import 'package:tara_rider/core/course/proof_photo.dart';
import 'package:tara_rider/core/location/location_tracker.dart';
import 'package:tara_rider/core/location/online_controller.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/core/session/session_store.dart';
import 'package:tara_rider/features/course/collection_screen.dart';
import 'package:tara_rider/features/course/delivery_screen.dart';
import 'package:tara_rider/features/course/pickup_screen.dart';
import 'package:tara_rider/features/home/home_flow.dart';
import 'package:tara_rider/features/home/home_summary.dart';
import 'package:tara_rider/features/map/tara_map.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_home_golden_test.dart' show summary;

class _Positions implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;
  @override
  Future<GeoPoint?> current() async => GeoPoint(latitude: 4.05, longitude: 9.7, recordedAt: DateTime.utc(2026, 11, 3));
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) => const Stream.empty();
}

/// Accueil avec une course en cours : services sans réseau ni minuterie.
Future<({ActiveOrderController active, ActionQueue queue})> pumpHome(
  WidgetTester tester,
  RiderOrder order, {
  Future<Object?> Function(String path, Json body)? send,
}) async {
  final store = MemoryKeyValueStore();
  final queue = ActionQueue(store: store, send: send ?? (_, _) async => null, upload: (path) async => path);
  final active = ActiveOrderController(
    store: store,
    fetchActive: () async => [],
    fetchOrder: (_) async => throw const ApiException(code: ApiException.network, message: ''),
    hasPendingActions: (id) => queue.forOrder(id).any((a) => !a.failed),
  );
  await active.start(order);
  final online = OnlineController(
    positions: _Positions(),
    setPresence: ({required online, required position}) async => const Presence(online: true, blockers: []),
    sendPosition: (_) async {},
  );
  await online.goOnline();
  await pumpVariant(
    tester,
    Variant.matrix.first,
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        realMapProvider.overrideWithValue(false),
        homeSummaryProvider.overrideWith((ref) async => summary),
        actionQueueProvider.overrideWithValue(queue),
        activeOrderProvider.overrideWithValue(active),
        courseActionsProvider.overrideWithValue(CourseActions(queue: queue, activeOrder: active)),
        onlineControllerProvider.overrideWithValue(online),
        takeProofPhotoProvider.overrideWithValue(() async => 'remise.jpg'),
        riderApiProvider.overrideWithValue(FakeRiderApi()),
      ],
      child: const HomeFlow(),
    ),
  );
  await settle(tester);
  return (active: active, queue: queue);
}

void main() {
  testWidgets('course acceptée : enlèvement, retour à l’accueil puis « Reprendre »', (tester) async {
    await pumpHome(tester, order());
    expect(find.byType(PickupScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Retour'));
    await settle(tester);
    expect(find.byType(PickupScreen), findsNothing);
    expect(find.text('Course TR-48213 en cours'), findsOneWidget);
    expect(find.text('Recherche de courses…'), findsNothing);

    await tester.tap(find.text('Reprendre'));
    await settle(tester);
    expect(find.byType(PickupScreen), findsOneWidget);
  });

  testWidgets('colis à bord : écran de livraison ; livraison déclarée sans code : attente du support', (tester) async {
    final (:active, queue: _) = await pumpHome(tester, order(status: 'IN_DELIVERY'));
    expect(find.byType(DeliveryScreen), findsOneWidget);
    await tester.runAsync(() => active.update(active.order!.withChanges({'awaitingSupportValidation': true})));
    await settle(tester);
    expect(find.text('Livraison déclarée'), findsOneWidget);
  });

  testWidgets('argent à encaisser : « Confirmer la livraison » ouvre d’abord l’encaissement', (tester) async {
    await pumpHome(tester, order(status: 'IN_DELIVERY'));
    await tester.enterText(find.byType(EditableText).first, '4821');
    await tester.ensureVisible(find.text('Photographier la remise'));
    await tester.tap(find.text('Photographier la remise'));
    await settle(tester);
    await tester.tap(find.text('Confirmer la livraison'));
    await settle(tester);
    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.text('À encaisser auprès du client'), findsOneWidget);
    // Retour : la livraison préparée (code, photo) est toujours là.
    await tester.tap(find.bySemanticsLabel('Retour').last);
    await settle(tester);
    expect(find.byType(CollectionScreen), findsNothing);
    expect(find.textContaining('Photo de remise'), findsOneWidget);
  });

  testWidgets('enlèvement refusé plus tard (code faux) : l’écran 08 revient avec le message', (tester) async {
    final (:active, :queue) = await pumpHome(
      tester,
      order(status: 'IN_DELIVERY'),
      send: (path, body) async => throw const ApiException(
        code: 'PICKUP_CODE_INVALID',
        message: 'Code de l’expéditeur incorrect. Essais restants : 4.',
        status: 422,
      ),
    );
    await tester.runAsync(() async {
      await queue.enqueue(
        orderId: active.order!.id,
        kind: 'pickup',
        body: {'pickupCode': '0000', 'latitude': 4.05, 'longitude': 9.7},
        photoPath: 'colis.jpg',
      );
      await queue.flush();
    });
    await settle(tester);
    expect(find.byType(PickupScreen), findsOneWidget);
    expect(find.text('Code de l’expéditeur incorrect. Essais restants : 4.'), findsOneWidget);
  });
}
