import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/activity/activity_screen.dart';
import 'package:tara_rider/features/activity/deposit_screen.dart';
import 'package:tara_rider/features/activity/withdraw_screen.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;

/// Mercredi 4 novembre 2026, 15:10 (heure du téléphone).
final activityNow = DateTime(2026, 11, 4, 15, 10);

Earnings earningsOf(String period, String bucket, List<(DateTime, int, int)> series) => Earnings(
  period: period,
  delivered: series.fold(0, (sum, item) => sum + item.$3),
  failed: 0,
  earnings: series.fold(0, (sum, item) => sum + item.$2),
  cashCollected: 0,
  onlineSeconds: 0,
  bucket: bucket,
  series: [for (final (start, earnings, delivered) in series) EarningsBucket(start, earnings, delivered)],
);

RiderOrder finished({
  required String id,
  required String status,
  required DateTime at,
  required String from,
  required String to,
  int earning = 1500,
  Json? collected,
}) {
  final json = orderJson(id: id, status: status);
  return RiderOrder.fromJson({
    ...json,
    'riderEarning': earning,
    'completedAt': at.toUtc().toIso8601String(),
    'collected': collected,
    'pickup': {
      ...json['pickup']! as Json,
      'neighborhood': {'id': 'n1', 'name': from},
    },
    'dropoff': {
      ...json['dropoff']! as Json,
      'neighborhood': {'id': 'n2', 'name': to},
    },
  });
}

/// [legacyCash] : espèces encaissées avant le solde prépayé, encore à reverser.
FakeRiderApi activityApi({bool legacyCash = false}) {
  final api = FakeRiderApi()
    ..wallet0 = legacyCash
        ? RiderWallet(
            earnings: 9000,
            available: 0,
            cashHeld: 37500,
            cashLimit: 50000,
            cashDueBy: DateTime(2026, 11, 5, 9, 40),
          )
        : const RiderWallet(
            earnings: 42000,
            reserved: 12500,
            available: 29500,
            cashHeld: 0,
            cashLimit: 50000,
            withdrawalFreeFrom: 50000,
            withdrawalFeeBps: 250,
            withdrawalFeeSharePercent: 50,
          )
    ..earningsByPeriod['day'] = earningsOf('day', 'two_hours', [
      for (final (hour, value, count) in [
        (6, 0, 0),
        (8, 1500, 1),
        (10, 0, 0),
        (12, 2250, 1),
        (14, 3000, 2),
        (16, 0, 0),
        (18, 0, 0),
        (20, 0, 0),
      ])
        (DateTime(2026, 11, 4, hour), value, count),
    ])
    ..earningsByPeriod['week'] = earningsOf('week', 'day', [
      for (final (day, value, count) in [
        (2, 7800, 5),
        (3, 11250, 8),
        (4, 6750, 4),
        (5, 0, 0),
        (6, 0, 0),
        (7, 0, 0),
        (8, 0, 0),
      ])
        (DateTime(2026, 11, day), value, count),
    ])
    ..earningsByPeriod['month'] = earningsOf('month', 'week', [
      for (final (day, value, count) in [(1, 9300, 6), (8, 0, 0), (15, 0, 0), (22, 0, 0), (29, 0, 0)])
        (DateTime(2026, 11, day), value, count),
    ])
    ..finished = [
      finished(
        id: '00000000-0000-4000-8000-0000000000c1',
        status: 'DELIVERED',
        at: DateTime(2026, 11, 4, 14, 52),
        from: 'Akwa',
        to: 'Bonapriso',
        collected: {'amount': 12500, 'method': 'CASH'},
      ),
      finished(
        id: '00000000-0000-4000-8000-0000000000c2',
        status: 'DELIVERED',
        at: DateTime(2026, 11, 4, 13, 20),
        from: 'Bali',
        to: 'Deïdo',
        earning: 1250,
        collected: {'amount': 8000, 'method': 'MOBILE_MONEY'},
      ),
      finished(
        id: '00000000-0000-4000-8000-0000000000c3',
        status: 'RETURNED',
        at: DateTime(2026, 11, 4, 11, 5),
        from: 'Bonamoussadi',
        to: 'Makepe',
        earning: 750,
      ),
      finished(
        id: '00000000-0000-4000-8000-0000000000c4',
        status: 'CANCELLED',
        at: DateTime(2026, 11, 3, 18, 40),
        from: 'Akwa',
        to: 'Bépanda',
      ),
    ];
  return api;
}

Widget activity(FakeRiderApi api) => ProviderScope(
  overrides: [keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()), riderApiProvider.overrideWithValue(api)],
  child: tabs(1, ActivityScreen(now: () => activityNow)),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('13 activité ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, activity(activityApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Gains d’aujourd’hui'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/13_activite/${variant.name}.png'));
    });

    goldenTest('13 activité semaine ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, activity(activityApi()));
      await settle(tester);
      await tester.tap(find.text('Semaine'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Auj.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/13_activite_semaine/${variant.name}.png'));
    });

    goldenTest('13 recharger ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, activity(activityApi()));
      await settle(tester);
      await tester.ensureVisible(find.text('Recharger'));
      await settle(tester);
      await tester.tap(find.text('Recharger'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DepositScreen), findsOneWidget);
      expect(find.text('Recharger mon solde'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/13_recharger/${variant.name}.png'));
    });

    goldenTest('13 retirer ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, activity(activityApi()));
      await settle(tester);
      await tester.ensureVisible(find.text('Retirer'));
      await settle(tester);
      await tester.tap(find.text('Retirer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(WithdrawScreen), findsOneWidget);
      // 29 500 F sous le seuil gratuit : 720 F de frais, 360 F pour le livreur, 360 F pour Tara.
      expect(find.text('Recevoir 29\u00a0140\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/13_retirer/${variant.name}.png'));
    });

    goldenTest('13 reverser ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, activity(activityApi(legacyCash: true)));
      await settle(tester);
      await tester.ensureVisible(find.text('Reverser'));
      await settle(tester);
      await tester.tap(find.text('Reverser'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DepositScreen), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/13_reverser/${variant.name}.png'));
    });
  }
}
