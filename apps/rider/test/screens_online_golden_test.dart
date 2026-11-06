import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/home/home_online_screen.dart';
import 'package:tara_rider/features/home/home_summary.dart';
import 'package:tara_rider/features/map/tara_map.dart';
import 'package:tara_rider/features/offer/offer_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_home_golden_test.dart' show summary;

final expiresAt = DateTime.utc(2026, 11, 3, 18, 30);

final offer = Offer(
  id: '00000000-0000-4000-8000-000000000001',
  orderId: '00000000-0000-4000-8000-000000000002',
  expiresAt: expiresAt,
  approachMeters: 1200,
  pickupName: 'Boutique Mama Ngo',
  pickupNeighborhood: 'Akwa',
  dropoffNeighborhood: 'Bonapriso',
  dropoffCity: 'Douala',
  distanceMeters: 6800,
  estimatedMinutes: 22,
  riderEarning: 1500,
  codAmount: 12500,
  cashFee: 0,
  packageSize: 'MEDIUM',
  isFragile: true,
  isExpress: false,
);

Widget scope(Widget child) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    realMapProvider.overrideWithValue(false),
    homeSummaryProvider.overrideWith((ref) async => summary),
  ],
  child: child,
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('06 accueil en ligne ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        scope(tabs(0, HomeOnlineScreen(onWentOffline: () {}, onDetails: () {}, onSos: () {}))),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/06_accueil_en_ligne/${variant.name}.png'));
    });

    goldenTest('07 proposition ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        scope(
          OfferScreen(
            offer: offer,
            onAccepted: (_) {},
            onClosed: (_) {},
            now: () => expiresAt.subtract(const Duration(seconds: 18)),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      // 30 s pour décider : l'argent à encaisser et le colis se lisent sans faire défiler.
      final buttonsTop = tester.getRect(find.text('Accepter')).top - 20;
      for (final detail in ['À encaisser', 'Colis moyen', 'Fragile']) {
        expect(tester.getRect(find.textContaining(detail)).bottom, lessThan(buttonsTop), reason: detail);
      }
      await expectLater(capture, matchesGoldenFile('goldens/07_proposition/${variant.name}.png'));
    });
  }
}
