import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/core/location.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/tracking/tracking_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopApi, shopOwner;

const orderId = '00000000-0000-4000-8000-000000000501';

/// Commande d'Akwa à Bonapriso, à l'étape [status].
TrackedOrder tracked(String status, {bool withRider = true, int cod = 12500}) {
  DateTime at(int h, int m) => DateTime(2026, 11, 4, h, m);
  final reached = <String, DateTime>{
    'CREATED': at(10, 2),
    'SEARCHING_RIDER': at(10, 2),
    if (const ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERED'].contains(status)) 'ASSIGNED': at(10, 4),
    if (const ['PICKED_UP', 'IN_DELIVERY', 'DELIVERED'].contains(status)) 'PICKED_UP': at(10, 12),
    if (const ['IN_DELIVERY', 'DELIVERED'].contains(status)) 'IN_DELIVERY': at(10, 12),
    if (status == 'DELIVERED') 'DELIVERED': at(10, 35),
  };
  final riderOn = withRider && reached.containsKey('ASSIGNED');
  return TrackedOrder(
    id: orderId,
    reference: 'TR-48301',
    status: status,
    trackingUrl: 'https://tara.cm/t/abc',
    scheduledFor: null,
    pickup: fakeAddress(
      '1',
      'Rue Joss, immeuble Socar',
      label: 'Boutique',
      neighborhood: 'Akwa',
      latitude: 4.0496,
      longitude: 9.6996,
    ),
    dropoff: fakeAddress(
      '4',
      'Face pharmacie du Rond-point',
      neighborhood: 'Bonapriso',
      latitude: 4.0318,
      longitude: 9.6905,
    ),
    recipientName: 'Marie Ngo',
    recipientPhone: '+237690112233',
    contents: 'CLOTHING',
    size: 'M',
    totalPrice: 1500,
    codAmount: cod,
    rider: riderOn
        ? OrderRider(
            name: 'Jean M.',
            phone: status == 'DELIVERED' ? null : '+237677445566',
            vehicleType: 'MOTORBIKE',
            plateNumber: 'LT 482 KQ',
          )
        : null,
    timeline: [for (final MapEntry(:key, :value) in reached.entries) (status: key, at: value)],
    createdAt: at(10, 2),
  );
}

List<Object> launched = [];
List<(String, bool)> shared = [];

Widget screen(FakeClientApi api, FakeRealtime realtime, {VoidCallback? onBack}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api),
    realtimeProvider.overrideWithValue(realtime),
    realMapProvider.overrideWithValue(false),
    launcherProvider.overrideWithValue((uri) async {
      launched.add(uri);
      return true;
    }),
    shareProvider.overrideWithValue((text, png) async => shared.add((text, png != null))),
  ],
  child: TrackingScreen(orderId: orderId, onBack: onBack ?? () {}, now: () => DateTime(2026, 11, 4, 10, 20)),
);

FakeClientApi apiAt(String status) => FakeClientApi()..tracked[orderId] = tracked(status);

/// Livreur à mi-chemin entre l'enlèvement et la livraison.
const halfway = {'latitude': 4.0405, 'longitude': 9.6950, 'heading': 200};

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    launched = [];
    shared = [];
  });

  for (final variant in Variant.matrix) {
    goldenTest('06 suivi en route ${variant.name}', (tester) async {
      final realtime = FakeRealtime()..ack = const {'ok': true, 'position': halfway};
      await pumpVariant(tester, variant, screen(apiAt('IN_DELIVERY'), realtime));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('En route vers Marie'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_en_route/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    final variant = Variant(brightness, ScreenSize.regular, 1);

    goldenTest('06 suivi recherche ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, screen(apiAt('SEARCHING_RIDER'), FakeRealtime()));
      await settle(tester);
      expect(find.text('Recherche d’un livreur…'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_recherche/${brightness.name}.png'));
    });

    goldenTest('06 suivi livreur trouvé ${brightness.name}', (tester) async {
      final realtime = FakeRealtime()
        ..ack = const {
          'ok': true,
          'position': {'latitude': 4.0560, 'longitude': 9.7040},
        };
      await pumpVariant(tester, variant, screen(apiAt('ASSIGNED'), realtime));
      await settle(tester);
      expect(find.text('Jean M. vient chercher le colis'), findsOneWidget);
      expect(find.text('Moto · LT 482 KQ'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_livreur/${brightness.name}.png'));
    });

    goldenTest('06 suivi livré ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, screen(apiAt('DELIVERED'), FakeRealtime()));
      await settle(tester);
      expect(find.text('Colis livré !'), findsNWidgets(2));
      expect(find.text('12 500 F encaissés'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_livre/${brightness.name}.png'));
    });
  }

  testWidgets('en direct : livreur trouvé, colis récupéré, livré — chaque étape s’annonce', (tester) async {
    final api = apiAt('SEARCHING_RIDER');
    final realtime = FakeRealtime();
    await pumpVariant(tester, Variant.matrix.first, screen(api, realtime));
    await settle(tester);
    expect(realtime.subscribed, [orderId]);
    expect(sounds.played, isEmpty);

    api.tracked[orderId] = tracked('ASSIGNED');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'ASSIGNED'});
    await settle(tester);
    expect(find.text('Jean M. vient chercher le colis'), findsOneWidget);
    expect(sounds.played, [TaraSound.received]);

    // Position du livreur : arrivée estimée à l'enlèvement (≈ 1,2 km).
    realtime.emit('rider.position', {'orderId': orderId, 'latitude': 4.0560, 'longitude': 9.7040});
    await settle(tester);
    expect(find.text('Environ 3 min'), findsOneWidget);
    // Une autre commande ne change rien.
    realtime.emit('order.status', {'orderId': 'autre', 'status': 'DELIVERED'});
    await settle(tester);

    api.tracked[orderId] = tracked('PICKED_UP');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'PICKED_UP'});
    await settle(tester);
    expect(find.text('En route vers Marie'), findsOneWidget);
    expect(sounds.played, [TaraSound.received, TaraSound.pickedUp]);

    api.tracked[orderId] = tracked('DELIVERED');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'DELIVERED'});
    await settle(tester);
    expect(sounds.played, [TaraSound.received, TaraSound.pickedUp, TaraSound.delivered]);
    expect(find.text('10:35 · en 23 min · Livré par Jean M.'), findsOneWidget);

    await tester.tap(find.text('Partager'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(shared.single.$1, 'Colis livré par Tara · TR-48301 · Marie Ngo · 10:35');

    await tester.pumpWidget(const SizedBox());
    expect(realtime.subscribed, isEmpty);
  });

  testWidgets('appeler le livreur, demander un nouveau code d’enlèvement', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      screen(apiAt('ASSIGNED'), FakeRealtime()),
      surface: const Size(390, 1000),
    );
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Appeler Jean M.'));
    await settle(tester);
    expect(launched.single, Uri(scheme: 'tel', path: '+237677445566'));

    await tester.ensureVisible(find.text('Nouveau code d’enlèvement'));
    await tester.tap(find.text('Nouveau code d’enlèvement'));
    await settle(tester);
    expect(find.text('Code d’enlèvement : 5 1 9 0'), findsOneWidget);
  });

  testWidgets('annuler pendant la recherche : confirmation, puis annulée', (tester) async {
    final api = apiAt('SEARCHING_RIDER');
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1000));
    await settle(tester);
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, isEmpty);
    expect(find.text('Touchez encore pour confirmer l’annulation.'), findsOneWidget);
    api.tracked[orderId] = tracked('CANCELLED');
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, [orderId]);
    expect(find.text('Livraison annulée'), findsOneWidget);
  });

  testWidgets('une livraison de l’accueil ouvre son suivi', (tester) async {
    final api = shopApi()..tracked['00000000-0000-4000-8000-000000000001'] = tracked('IN_DELIVERY');
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientApiProvider.overrideWithValue(api),
          realtimeProvider.overrideWithValue(FakeRealtime()),
          realMapProvider.overrideWithValue(false),
        ],
        child: HomeFlow(me: shopOwner, now: () => homeNow),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Marie Ngo · Bonapriso'));
    await settle(tester);
    expect(find.byType(TrackingScreen), findsOneWidget);
    expect(find.text('TR-48301'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await settle(tester);
    expect(find.byType(TrackingScreen), findsNothing);
  });
}
