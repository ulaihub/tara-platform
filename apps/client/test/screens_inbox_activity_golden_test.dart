import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/home/activity_screen.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/home/notifications_screen.dart';
import 'package:tara_client/features/tracking/tracking_screen.dart';
import 'package:tara_core/session/session_store.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopApi, shopOwner;
import 'screens_new_order_golden_test.dart' show overrides;

/// Mercredi 4 novembre 2026, 10:20 : cinq notifications, trois non lues.
List<InboxItem> sampleInbox() => [
  InboxItem(
    id: '00000000-0000-4000-8000-000000000901',
    kind: 'LOCATION_LINK_SUBMITTED',
    title: 'Adresse reçue',
    body: 'Paul a placé son point : « Portail bleu ». Vous pouvez valider la livraison.',
    read: false,
    createdAt: homeNow.subtract(const Duration(seconds: 20)),
  ),
  InboxItem(
    id: '00000000-0000-4000-8000-000000000902',
    kind: 'RIDER_ARRIVED_PICKUP',
    title: 'Votre livreur est arrivé',
    body: 'TR-48291 · Il vous attend. Attente gratuite 10 min.',
    orderId: '00000000-0000-4000-8000-000000000501',
    read: false,
    createdAt: homeNow.subtract(const Duration(minutes: 4)),
  ),
  InboxItem(
    id: '00000000-0000-4000-8000-000000000903',
    kind: 'ORDER_DELIVERY_FAILED',
    title: 'Livraison impossible',
    body: 'TR-48288 n’a pas pu être livré. Choisissez vite : nouvelle tentative ou retour.',
    orderId: '00000000-0000-4000-8000-000000000502',
    read: false,
    createdAt: homeNow.subtract(const Duration(minutes: 20)),
  ),
  InboxItem(
    id: '00000000-0000-4000-8000-000000000904',
    kind: 'ORDER_DELIVERED',
    title: 'Colis livré',
    body: 'Votre colis TR-48301 a été livré.',
    orderId: '00000000-0000-4000-8000-000000000503',
    read: true,
    createdAt: DateTime(2026, 11, 4, 8, 24),
  ),
  InboxItem(
    id: '00000000-0000-4000-8000-000000000905',
    kind: 'PAYOUT_SENT',
    title: 'Argent envoyé',
    body: '128 500 FCFA envoyés sur votre Mobile Money.',
    read: true,
    createdAt: DateTime(2026, 11, 3, 18, 2),
  ),
];

/// Semaine du lundi 2 novembre 2026 (minuit au Cameroun = 23 h UTC la veille).
MerchantActivity weekActivity() {
  final monday = DateTime.utc(2026, 11, 1, 23);
  const sales = [41500, 55000, 38500, 72500, 61000, 84000, 34000];
  const counts = [5, 6, 4, 9, 7, 8, 3];
  return MerchantActivity(
    period: 'week',
    from: monday,
    buckets: [
      for (var i = 0; i < 7; i++)
        (
          from: monday.add(Duration(days: i)),
          to: monday.add(Duration(days: i + 1)),
          sales: sales[i],
          deliveries: counts[i],
        ),
    ],
    deliveries: 42,
    collected: 386500,
    successRate: 96,
    deliveriesChange: 12,
    collectedChange: 8,
    successRateChange: 2,
    averageMinutes: 47,
    zones: const [
      (name: 'Bonapriso', share: 28),
      (name: 'Akwa', share: 21),
      (name: 'Deïdo', share: 17),
      (name: 'Bonamoussadi', share: 12),
    ],
  );
}

MerchantActivity dayActivity() {
  final midnight = DateTime.utc(2026, 11, 3, 23);
  const sales = [0, 12250, 9800, 0, 15450, 0, 0];
  return MerchantActivity(
    period: 'day',
    from: midnight,
    buckets: [
      for (var i = 0; i < 7; i++)
        (
          from: midnight.add(Duration(hours: 8 + 2 * i)),
          to: midnight.add(Duration(hours: 10 + 2 * i)),
          sales: sales[i],
          deliveries: sales[i] > 0 ? 1 : 0,
        ),
    ],
    deliveries: 3,
    collected: 37500,
    successRate: 100,
    deliveriesChange: -25,
    collectedChange: null,
    successRateChange: 4,
    averageMinutes: 41,
    zones: const [(name: 'Bonapriso', share: 34), (name: 'Akwa', share: 33), (name: 'Deïdo', share: 33)],
  );
}

Widget scoped(FakeClientApi api, Widget child) => ProviderScope(
  overrides: [keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()), clientApiProvider.overrideWithValue(api)],
  child: child,
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('notifications ${variant.name}', (tester) async {
      final api = FakeClientApi()..inboxItems = sampleInbox();
      await pumpVariant(
        tester,
        variant,
        scoped(
          api,
          NotificationsScreen(
            onBack: () {},
            onOpenOrder: (_) {},
            onWallet: () {},
            onAskAddress: () {},
            now: () => homeNow,
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('3 non lues'), findsOneWidget);
      expect(find.text('à l’instant'), findsOneWidget);
      expect(find.text('il y a 4 min'), findsOneWidget);
      expect(find.text('08:24'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/11_notifications/${variant.name}.png'));
    });

    goldenTest('mon activité ${variant.name}', (tester) async {
      final api = FakeClientApi()..activity = {'week': weekActivity(), 'day': dayActivity()};
      await pumpVariant(tester, variant, scoped(api, ActivityScreen(shopName: 'Awa Fashion', onBack: () {})));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Awa Fashion · cette semaine'), findsOneWidget);
      expect(find.text('386 500 F'), findsOneWidget);
      expect(find.text('+12 %'), findsOneWidget);
      expect(find.text('+2 pts'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/12_activite/${variant.name}.png'));
    });
  }

  testWidgets('la cloche : pastille, ouverture d’une commande, « Tout lire »', (tester) async {
    final api = shopApi()..inboxItems = sampleInbox();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: overrides(api),
        child: const HomeFlow(me: shopOwner),
      ),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('Notifications, 3 nouvelles'), findsOneWidget);
    await tester.tap(find.byKey(notificationBellKey));
    await settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);

    // Ouvrir une notification la marque lue.
    await tester.tap(find.text('Livraison impossible'));
    await settle(tester);
    expect(api.inboxItems.where((n) => !n.read).length, 2);
    // La commande s'ouvre par-dessus les notifications.
    expect(find.byType(TrackingScreen), findsOneWidget);
    expect(find.byType(NotificationsScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('« Tout lire » efface la pastille', (tester) async {
    final api = FakeClientApi()..inboxItems = sampleInbox();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      scoped(
        api,
        NotificationsScreen(
          onBack: () {},
          onOpenOrder: (_) {},
          onWallet: () {},
          onAskAddress: () {},
          now: () => homeNow,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Tout lire'));
    await settle(tester);
    expect(api.inboxReads, 1);
    expect(find.text('Tout est lu'), findsOneWidget);
    expect(find.text('hier 18:02'), findsOneWidget);
    expect(find.text('Tout lire'), findsNothing);
  });

  testWidgets('mon activité : changer de période et de moment', (tester) async {
    final api = FakeClientApi()..activity = {'week': weekActivity(), 'day': dayActivity()};
    await pumpVariant(
      tester,
      Variant.matrix.first,
      scoped(api, ActivityScreen(shopName: 'Awa Fashion', onBack: () {})),
    );
    await settle(tester);
    // Dimanche (dernier jour avec des ventes) choisi d'abord, puis jeudi.
    expect(find.text('34 000 F'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-bucket-3')));
    await settle(tester);
    expect(find.text('72 500 F'), findsOneWidget);
    expect(find.text('9 livraisons'), findsOneWidget);

    await tester.tap(find.text('Jour'));
    await settle(tester);
    expect(api.activityAsked, ['week', 'day']);
    expect(find.text('Awa Fashion · aujourd’hui'), findsOneWidget);
    expect(find.text('−25 %'), findsOneWidget);
    expect(find.text('15 450 F'), findsOneWidget);
  });
}
