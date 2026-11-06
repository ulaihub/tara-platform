import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/catalog/catalog_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

/// Captures de référence du catalogue : tout le catalogue, sur la largeur de chaque
/// format d'écran, dans les deux thèmes, avec le texte à 100 % et à 130 %.
const _catalog = ValueKey('catalog');

void main() {
  setUpAll(loadAppFonts);

  final variants = [
    ...Variant.matrix,
    const Variant(Brightness.dark, ScreenSize.compact, 1, reducedEffects: true),
    const Variant(Brightness.light, ScreenSize.compact, 1, reducedEffects: true),
  ];

  for (final variant in variants) {
    goldenTest('catalogue ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        const Align(
          alignment: Alignment.topCenter,
          child: RepaintBoundary(key: _catalog, child: CatalogScreen(scrollable: false)),
        ),
        surface: Size(variant.screen.size.width, 6400),
      );
      // Instant fixe des animations : compte à rebours à 18 s, gouttes à mi-chemin.
      // Image par image (250 ms) : les transitions de niveau suivent le temps comme à l'écran.
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 248));
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(CatalogScreen), matchesGoldenFile('goldens/catalog/${variant.name}.png'));
    });
  }

  testWidgets('catalogue sans débordement ni erreur au défilement', (tester) async {
    await pumpVariant(tester, const Variant(Brightness.dark, ScreenSize.compact, 1.3), const CatalogScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
