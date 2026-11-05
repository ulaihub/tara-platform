import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/orders/orders_screen.dart';
import 'package:tara_client/features/profile/profile_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopApi, shopOwner, summary, tabs;

Widget scoped(Widget child, FakeClientApi api, {FakeRealtime? realtime}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api),
    appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    realtimeProvider.overrideWithValue(realtime ?? FakeRealtime()),
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
        scoped(HomeFlow(me: shopOwner, now: () => homeNow), shopApi()),
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

  testWidgets('boutique : une livraison s’ajoute aux ventes du jour, en direct', (tester) async {
    final api = shopApi();
    final realtime = FakeRealtime();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      scoped(
        HomeFlow(me: shopOwner, now: () => homeNow),
        api,
        realtime: realtime,
      ),
    );
    await settle(tester);
    expect(find.text('37\u00a0500\u00a0F'), findsOneWidget);
    expect(sounds.played, isEmpty);

    api.wallet0 = const Wallet(
      customerBalance: 0,
      merchantBalance: 141000,
      payoutSchedule: 'DAILY',
      todaySales: 50000,
      todayDeliveries: 4,
    );
    realtime.emit('order.status', {'orderId': 'o1', 'status': 'DELIVERED'});
    await settle(tester);
    expect(find.text('50\u00a0000\u00a0F'), findsOneWidget);
    expect(find.text('4 livraisons · 141\u00a0000\u00a0F à recevoir cette nuit'), findsOneWidget);
    expect(sounds.played, [TaraSound.cash]);
  });

  testWidgets('reversement reçu : bandeau et son de pièce, puis le bandeau s’efface', (tester) async {
    final realtime = FakeRealtime();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      scoped(
        HomeFlow(me: shopOwner, now: () => homeNow),
        shopApi(),
        realtime: realtime,
      ),
    );
    await settle(tester);
    realtime.emit('payout.status', {'payoutId': 'p1', 'status': 'PROCESSING', 'amount': 128500});
    await settle(tester);
    expect(find.textContaining('envoyés sur votre Mobile Money'), findsNothing);

    realtime.emit('payout.status', {'payoutId': 'p1', 'status': 'SUCCEEDED', 'amount': 128500});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('128\u00a0500\u00a0F envoyés sur votre Mobile Money'), findsOneWidget);
    expect(sounds.played, [TaraSound.cash]);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(find.textContaining('envoyés sur votre Mobile Money'), findsNothing);
  });
}
