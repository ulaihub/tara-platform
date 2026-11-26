import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/features/onboarding/intro_screen.dart';
import 'package:tara_ui/components/intro.dart';

import 'helpers/harness.dart';

/// Présentation au premier lancement : les 4 écrans des maquettes, « Passer », « Suivant ».
void main() {
  setUpAll(loadAppFonts);

  const names = ['1_envoyer', '2_suivre', '3_encaisser', '4_deux_comptes'];
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final (page, name) in names.indexed) {
      goldenTest('présentation $name ${brightness.name}', (tester) async {
        await pumpVariant(
          tester,
          Variant(brightness, ScreenSize.regular, 1),
          ClientIntroScreen(initialPage: page, onDone: () {}),
        );
        await settle(tester);
        // Chiffres de « Ventes à recevoir » arrivés au bout de leur défilement.
        await tester.pump(const Duration(milliseconds: 1400));
        await expectLater(capture, matchesGoldenFile('goldens/00_presentation/${name}_${brightness.name}.png'));
      });
    }
  }

  goldenTest('« Suivant » avance, « Commencer » termine, « Passer » termine', (tester) async {
    var done = 0;
    await pumpVariant(
      tester,
      const Variant(Brightness.light, ScreenSize.regular, 1),
      ClientIntroScreen(onDone: () => done++),
    );
    await settle(tester);
    expect(find.text('Envoyez un colis en une minute'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(introNextKey));
      await settle(tester);
    }
    expect(find.text('Deux comptes, d’un coup d’œil'.replaceAll('’', "'")), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.byKey(introSkipKey), findsNothing);
    await tester.tap(find.byKey(introNextKey));
    expect(done, 1);
  });
}
