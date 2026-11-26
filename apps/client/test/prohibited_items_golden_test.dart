import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/features/order/prohibited_items.dart';
import 'package:tara_ui/components/layout.dart';

import 'helpers/harness.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix.where((v) => v.screen == ScreenSize.compact)) {
    goldenTest('objets interdits ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        const TaraScreen(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(children: [ProhibitedItemsNote()]),
          ),
        ),
      );
      await settle(tester);
      // Replié d'abord ; un toucher déplie la liste.
      expect(find.textContaining('Armes'), findsNothing);
      await tester.tap(find.byKey(prohibitedItemsKey));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Armes'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/objets_interdits/${variant.name}.png'));
    });
  }
}
