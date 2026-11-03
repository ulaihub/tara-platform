import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/onboarding/profile_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show scoped, settle;

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('03 profil ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(ProfileScreen(onDone: () {}, onBack: () {})));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_profil/${variant.name}.png'));
    });
  }

  // Écran entier (défilement déplié) avec les erreurs de saisie, pour la revue.
  for (final brightness in Brightness.values) {
    goldenTest('03 profil complet ${brightness.name}', (tester) async {
      final variant = Variant(brightness, ScreenSize.regular, 1);
      await pumpVariant(
        tester,
        variant,
        scoped(ProfileScreen(onDone: () {}, onBack: () {})),
        surface: const Size(390, 1560),
      );
      await tester.enterText(find.byType(EditableText).at(0), 'Awa');
      await tester.enterText(find.byType(EditableText).at(5), 'Mama');
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      expect(find.text('Obligatoire'), findsWidgets);
      await expectLater(capture, matchesGoldenFile('goldens/03_profil/complet_erreurs_${brightness.name}.png'));
    });
  }
}
