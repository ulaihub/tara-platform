import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/orders/orders_screen.dart';
import 'package:tara_client/features/profile/profile_screen.dart';
import 'package:tara_core/session/session_store.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopApi, shopOwner, summary, tabs;

Widget scoped(Widget child, FakeClientApi api) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api),
    appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
  ],
  child: child,
);

FakeClientApi historyApi() => shopApi()
  ..history = [
    summary('5', 'DELIVERED', 'Marie Ngo', 'Bonapriso'),
    summary('6', 'DELIVERED', 'Jean Mbarga', 'Akwa'),
    summary('7', 'RETURNED', 'Chantal Eyike', 'Bépanda'),
    summary('8', 'CANCELLED', 'Samuel Etoa', 'Deïdo'),
  ];

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('05 commandes ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        scoped(tabs(1, OrdersScreen(onOpenOrder: (_) {}, now: () => homeNow)), shopApi()),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/05_commandes/${variant.name}.png'));
    });

    goldenTest('06 profil ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(tabs(2, const ProfileScreen(me: shopOwner)), shopApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/06_profil/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('05 commandes terminées ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scoped(tabs(1, OrdersScreen(onOpenOrder: (_) {}, now: () => homeNow)), historyApi()),
      );
      await settle(tester);
      await tester.tap(find.text('Terminées'));
      await settle(tester);
      expect(find.text('Livrée · aujourd’hui · TR-48215'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_commandes/terminees_${brightness.name}.png'));
    });

    // Changement d'onglet saisi en pleine transition : l'accueil se floute, les commandes
    // sortent du flou, un reflet de verre traverse l'écran.
    goldenTest('transition vitrée ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scoped(const HomeFlow(me: shopOwner), shopApi()),
      );
      await settle(tester);
      await tester.tap(find.text('Commandes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 170));
      await expectLater(capture, matchesGoldenFile('goldens/transition_onglets/${brightness.name}.png'));
      await settle(tester);
      expect(find.text('Terminées'), findsOneWidget);
    });
  }
}
