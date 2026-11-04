import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/session/session_store.dart';
import 'package:tara_rider/features/common/status_screen.dart';
import 'package:tara_rider/features/home/home_offline_screen.dart';
import 'package:tara_rider/features/home/home_summary.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show scoped, settle;

const summary = HomeSummary(
  fullName: 'Awa Ngono',
  earnings: 8750,
  delivered: 6,
  onlineSeconds: 4 * 3600 + 35 * 60,
  available: 23500,
);

Widget home() => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    homeSummaryProvider.overrideWith((ref) async => summary),
    documentLabelsProvider.overrideWith((ref) async => {}),
  ],
  child: HomeOfflineScreen(onWentOnline: () {}, onDetails: () {}, onTab: (_) {}, now: DateTime(2026, 11, 3, 19)),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('05 accueil hors ligne ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, home());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/05_accueil_hors_ligne/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('dossier en vérification ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scoped(
          StatusScreen(
            title: 'Dossier en cours de vérification',
            body: 'Nous vérifions vos pièces, en général sous 48 h. Vous recevrez un SMS dès que vous pourrez prendre des courses.',
            actionLabel: 'Réessayer',
            onAction: () {},
            linkLabel: 'Se déconnecter',
            onLink: () {},
          ),
        ),
      );
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/00_verification/${brightness.name}.png'));
    });
  }
}
