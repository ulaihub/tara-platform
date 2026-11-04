import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/providers.dart';
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
import 'package:tara_rider/features/map/tara_map.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;

final photo = File('test/fixtures/colis.jpg').absolute.path;

/// Services de course sans minuterie ni réseau : rien ne part pendant une capture.
CourseActions courseActions() {
  final store = MemoryKeyValueStore();
  final queue = ActionQueue(store: store, send: (_, _) async => null, upload: (path) async => path);
  return CourseActions(
    queue: queue,
    activeOrder: ActiveOrderController(
      store: store,
      fetchActive: () async => [],
      fetchOrder: (_) async => order(),
      hasPendingActions: (_) => false,
    ),
  );
}

/// Position du livreur pour les captures (Akwa : à 2,5 km du client de Bonapriso).
class _Positions implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;
  @override
  Future<GeoPoint?> current() async =>
      GeoPoint(latitude: 4.0511, longitude: 9.6942, recordedAt: DateTime.utc(2026, 11, 3));
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) => const Stream.empty();
}

Widget scope(Widget child, {OnlineController? online}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    realMapProvider.overrideWithValue(false),
    takeProofPhotoProvider.overrideWithValue(() async => photo),
    courseActionsProvider.overrideWithValue(courseActions()),
    if (online != null) onlineControllerProvider.overrideWithValue(online),
  ],
  child: child,
);

Widget collection() => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    riderApiProvider.overrideWithValue(FakeRiderApi()),
    courseActionsProvider.overrideWithValue(courseActions()),
  ],
  child: CollectionScreen(
    order: order(status: 'IN_DELIVERY'),
    draft: DeliveryDraft(photoPath: photo, code: '4821'),
    onBack: () {},
    onDone: (_) {},
  ),
);

DeliveryScreen delivery(RiderOrder order) => DeliveryScreen(
  order: order,
  onBack: () {},
  onSos: () {},
  onDelivered: (_) {},
  onCollect: (_) {},
  now: () => DateTime(2026, 11, 3, 15, 4),
);

PickupScreen pickup(RiderOrder order) => PickupScreen(
  order: order,
  onBack: () {},
  onSos: () {},
  onPickedUp: (_) {},
  now: () => DateTime(2026, 11, 3, 14, 32),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('12 encaissement espèces ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, collection());
      await settle(tester);
      await tester.ensureVisible(find.text('15\u00A0000\u00A0F'));
      await tester.tap(find.text('15\u00A0000\u00A0F'));
      await settle(tester);
      // Bas du contenu : sur petit écran, la monnaie à rendre reste visible au-dessus du bouton.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('2\u00A0500\u00A0F').hitTestable(), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/12_encaissement_especes/${variant.name}.png'));
    });

    goldenTest('12 encaissement mobile money ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, collection());
      await settle(tester);
      await tester.tap(find.text('Mobile Money'));
      await settle(tester);
      await tester.ensureVisible(find.text('Envoyer la demande de paiement'));
      await tester.tap(find.text('Envoyer la demande de paiement'));
      await settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('En attente de la validation du client…').hitTestable(), findsOneWidget);
      expect(find.text('Demande envoyée au client'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/12_encaissement_mobile_money/${variant.name}.png'));
    });

    goldenTest('09 livraison ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(delivery(order(status: 'IN_DELIVERY'))));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Code du destinataire'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/09_livraison/${variant.name}.png'));
    });

    goldenTest('09 livraison sans code ${variant.name}', (tester) async {
      final online = OnlineController(
        positions: _Positions(),
        setPresence: ({required online, required position}) async => Presence(online: online, blockers: const []),
        sendPosition: (_) async {},
      );
      await tester.runAsync(online.goOnline);
      await pumpVariant(
        tester,
        variant,
        scope(delivery(order(status: 'IN_DELIVERY', collectAtDelivery: 0)), online: online),
      );
      await settle(tester);
      final context = tester.element(find.byType(DeliveryScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.ensureVisible(find.text('Le client n’a pas de code'));
      await tester.tap(find.text('Le client n’a pas de code'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sa sœur, Brigitte');
      await tester.ensureVisible(find.text('Photographier la remise'));
      await tester.tap(find.text('Photographier la remise'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Vous êtes à 2,5'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/09_livraison_sans_code/${variant.name}.png'));
    });

    goldenTest('08 enlèvement ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(pickup(order())));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Le bouton reste inactif tant que code et photo manquent.
      expect(find.text('Colis récupéré'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement/${variant.name}.png'));
    });

    goldenTest('08 enlèvement prêt ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(pickup(order(collectAtPickup: 0, pickupRestricted: true))));
      await settle(tester);
      // Vignette décodée avant d'apparaître (le décodage ne progresse pas en temps simulé).
      final context = tester.element(find.byType(PickupScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.enterText(find.byType(EditableText).first, '7302');
      await tester.ensureVisible(find.text('Photographier le colis'));
      await tester.tap(find.text('Photographier le colis'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Photo du colis · prise à 14:32'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement_pret/${variant.name}.png'));
    });
  }
}
