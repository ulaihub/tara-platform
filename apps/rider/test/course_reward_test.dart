import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/home/course_reward.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/motion/liquid_background.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

Widget reward({required int delivered, VoidCallback? onDone}) => Stack(
  children: [
    const Positioned.fill(
      child: TaraScreen(
        blobs: [BlobSpec(alignment: Alignment(1.2, -1), size: 300, colors: BlobSpec.brand, blur: 70)],
        child: SizedBox.expand(),
      ),
    ),
    Positioned.fill(
      child: CourseReward(earning: 1500, deliveredToday: delivered, onDone: onDone ?? () {}),
    ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  test('paliers : 5, 10, puis chaque dizaine', () {
    expect(
      [
        for (var n = 1; n <= 31; n++)
          if (CourseReward.isMilestone(n)) n,
      ],
      [5, 10, 20, 30],
    );
  });

  testWidgets('le gain s’envole, la pièce tinte à l’arrivée, puis tout disparaît', (tester) async {
    var done = 0;
    await pumpVariant(tester, Variant.matrix.first, reward(delivered: 3, onDone: () => done++));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+1 500 F'), findsOneWidget);
    expect(sounds.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(sounds.played, [TaraSound.cash]);
    expect(find.textContaining('courses aujourd’hui'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, 1);
  });

  for (final brightness in Brightness.values) {
    goldenTest('palier de 10 courses ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), reward(delivered: 10));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('10 courses aujourd’hui !'), findsOneWidget);
      expect(find.text('Bravo, continuez comme ça.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/17_palier/${brightness.name}.png'));
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
