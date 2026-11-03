import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/course/course_actions.dart';
import 'package:tara_rider/core/course/proof_photo.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/core/session/session_store.dart';
import 'package:tara_rider/features/course/pickup_screen.dart';
import 'package:tara_rider/features/map/tara_map.dart';

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

Widget scope(Widget child) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    realMapProvider.overrideWithValue(false),
    takeProofPhotoProvider.overrideWithValue(() async => photo),
    courseActionsProvider.overrideWithValue(courseActions()),
  ],
  child: child,
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
