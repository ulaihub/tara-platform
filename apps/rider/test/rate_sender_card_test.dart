import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/home/rate_sender_card.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

Widget card({ValueChanged<int>? onRate, VoidCallback? onClose}) => Stack(
  children: [
    const Positioned.fill(
      child: TaraScreen(
        blobs: [BlobSpec(alignment: Alignment(1.2, -1), size: 300, colors: BlobSpec.brand, blur: 70)],
        child: SizedBox.expand(),
      ),
    ),
    Positioned(
      left: 16,
      right: 16,
      top: 120,
      child: RateSenderCard(name: 'Awa Fashion', onRate: onRate ?? (_) {}, onClose: onClose ?? () {}),
    ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    goldenTest('noter l’expéditeur ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), card());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Notez Awa Fashion'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/18_noter_expediteur/${brightness.name}.png'));
    });
  }

  testWidgets('une étoile touchée envoie la note, merci, puis la carte s’efface', (tester) async {
    final rated = <int>[];
    var closed = 0;
    await pumpVariant(tester, Variant.matrix.first, card(onRate: rated.add, onClose: () => closed++));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('4 étoiles'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(rated, [4]);
    expect(find.text('Merci ! Votre note aide Tara à bien choisir ses clients.'), findsOneWidget);
    // Plus de deuxième note.
    await tester.tap(find.bySemanticsLabel('1 étoile'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));
    expect(rated, [4]);
    expect(closed, 1);
  });

  testWidgets('fermer sans noter', (tester) async {
    var closed = 0;
    final rated = <int>[];
    await pumpVariant(tester, Variant.matrix.first, card(onRate: rated.add, onClose: () => closed++));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(closed, 1);
    expect(rated, isEmpty);
  });
}
