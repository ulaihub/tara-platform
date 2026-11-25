import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/onboarding/intro_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;

/// Courte présentation du livreur : courses, gains, sécurité.
void main() {
  setUpAll(loadAppFonts);

  const names = ['1_courses', '2_gains', '3_securite'];
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final (page, name) in names.indexed) {
      goldenTest('présentation livreur $name ${brightness.name}', (tester) async {
        await pumpVariant(
          tester,
          Variant(brightness, ScreenSize.regular, 1),
          RiderIntroScreen(initialPage: page, onDone: () {}),
        );
        await settle(tester);
        await expectLater(capture, matchesGoldenFile('goldens/00_presentation/${name}_${brightness.name}.png'));
      });
    }
  }
}
