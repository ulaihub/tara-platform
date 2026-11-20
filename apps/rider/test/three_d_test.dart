import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_ui/components/three_d.dart';

import 'helpers/harness.dart';

void main() {
  final week = [
    for (final (day, rides) in [('Lun', 4), ('Mar', 6), ('Jeu', 7)])
      Column3D(label: day, value: rides.toDouble(), detail: '$rides courses'),
  ];

  testWidgets('colonnes en relief : le jour touché s’allume et donne son détail', (tester) async {
    final chosen = <int>[];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      Scaffold(
        body: Center(
          child: SizedBox(width: 300, child: Column3DChart(columns: week, selected: 2, onSelected: chosen.add)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Détail du jour en cours au-dessus de sa colonne.
    expect(find.text('7 courses'), findsOneWidget);
    expect(find.bySemanticsLabel('Jeu : 7 courses'), findsOneWidget);

    await tester.tap(find.text('Mar'));
    await tester.pump();
    expect(chosen, [1]);
    expect(find.text('6 courses'), findsOneWidget);
    expect(find.text('7 courses'), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel('Mar : 6 courses')), isSemantics(isSelected: true, isButton: true));
  });

  testWidgets('colis 3D : décrit pour le lecteur d’écran, immobile sans animations', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: Parcel3D(label: 'n° 4', semanticLabel: 'Colis Tara')),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel('Colis Tara'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
