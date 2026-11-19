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
  packageSize: 'M',
  isFragile: true,
  isExpress: false,
);

/// Tournée (2c) : 3 colis d'une boutique, dans l'ordre des arrêts.
final tourOffer = Offer(
  id: '00000000-0000-4000-8000-000000000003',
  orderId: '00000000-0000-4000-8000-000000000004',
  expiresAt: expiresAt,
  approachMeters: 900,
  pickupName: 'Boutique Mama Ngo',
  pickupNeighborhood: 'Akwa',
  dropoffNeighborhood: 'Bonapriso',
  dropoffCity: 'Douala',
  distanceMeters: 9800,
  estimatedMinutes: 29,
  riderEarning: 3220,
  codAmount: 27500,
  cashFee: 0,
  packageSize: 'M',
  isFragile: false,
  isExpress: false,
  approachBonus: 200,
  tourParcels: const [
    TourParcel(
      orderId: 'a',
      batchNumber: 4,
      packageSize: 'S',
      neighborhood: 'Bonapriso',
      riderEarning: 840,
      codAmount: 12500,
    ),
    TourParcel(orderId: 'b', batchNumber: 9, packageSize: 'M', neighborhood: 'Deïdo', riderEarning: 1050, codAmount: 0),
    TourParcel(
      orderId: 'c',
      batchNumber: 12,
      packageSize: 'S',
      neighborhood: 'Bonamoussadi',
      riderEarning: 1130,
      codAmount: 15000,
    ),
  ],
);

/// Gros objet avec aide au chargement payée par l'expéditeur.
final bulkyOffer = Offer(
  id: '00000000-0000-4000-8000-000000000003',
  orderId: '00000000-0000-4000-8000-000000000004',
  expiresAt: expiresAt,
  approachMeters: 2100,
  pickupName: 'Électro Kotto',
  pickupNeighborhood: 'Kotto',
  dropoffNeighborhood: 'Bonamoussadi',
  dropoffCity: 'Douala',
  distanceMeters: 5400,
  estimatedMinutes: 19,
  riderEarning: 4800,
  codAmount: 0,
  cashFee: 0,
  packageSize: 'BULKY',
  isFragile: false,
  isExpress: false,
  loadingHelp: true,
);

/// Vendeur à 3,6 km sous la pluie : prime d'approche et prime de renfort payées par Tara.
final bonusOffer = Offer(
  id: '00000000-0000-4000-8000-000000000005',
  orderId: '00000000-0000-4000-8000-000000000006',
  expiresAt: expiresAt,
  approachMeters: 3600,
  pickupName: 'Saveurs de Deïdo',
  pickupNeighborhood: 'Deïdo',
  dropoffNeighborhood: 'Logbessou',
  dropoffCity: 'Douala',
  distanceMeters: 16800,
  estimatedMinutes: 34,
  riderEarning: 1295 + 200 + 300,
  approachBonus: 200,
  boostBonus: 300,
  codAmount: 0,
  cashFee: 0,
  packageSize: 'S',
  isFragile: false,
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

  for (final brightness in Brightness.values) {
    goldenTest('07 proposition gros objet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scope(
          OfferScreen(
            offer: bulkyOffer,
            onAccepted: (_) {},
            onClosed: (_) {},
            now: () => expiresAt.subtract(const Duration(seconds: 18)),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Avant d'accepter : c'est un gros objet, et il faut venir à deux.
      expect(find.text('Nouvelle course · Gros objet'), findsOneWidget);
      expect(find.text('Venir à deux'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_proposition_gros_objet/${brightness.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('07 proposition avec primes ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scope(
          OfferScreen(
            offer: bonusOffer,
            onAccepted: (_) {},
            onClosed: (_) {},
            now: () => expiresAt.subtract(const Duration(seconds: 18)),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Le gain annoncé comprend les primes, détaillées juste dessous.
      expect(find.text('dont prime d’approche 200\u00a0F · prime de renfort 300\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_proposition_primes/${brightness.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('07 proposition de tournée ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scope(
          OfferScreen(
            offer: tourOffer,
            onAccepted: (_) {},
            onClosed: (_) {},
            now: () => expiresAt.subtract(const Duration(seconds: 18)),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tournée · 3 colis'), findsOneWidget);
      expect(find.text('3 arrêts, dans l’ordre'), findsOneWidget);
      expect(find.text('N° 9 · Deïdo'), findsOneWidget);
      expect(find.text('1\u00a0050\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_proposition_tournee/${brightness.name}.png'));
    });
  }
}
