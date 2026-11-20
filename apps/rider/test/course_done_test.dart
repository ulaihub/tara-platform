import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/home/course_done_screen.dart';
import 'package:tara_rider/features/home/home_summary.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

const _summary = HomeSummary(fullName: 'Awa Ngono', earnings: 7500, delivered: 5, onlineSeconds: 3600, available: 0);

Widget done({required int delivered, List<int>? rated, VoidCallback? onDone}) => ProviderScope(
  overrides: [homeSummaryProvider.overrideWith((ref) async => _summary)],
  child: CourseDoneScreen(
    reference: 'TR-48301',
    deliveredAt: DateTime(2026, 11, 20, 15, 26),
    earning: 1050,
    deliveredToday: delivered,
    senderName: 'Boutique Awa',
    onRate: (stars) => rated?.add(stars),
    onDone: onDone ?? () {},
  ),
);

void main() {
  setUpAll(loadAppFonts);

  test('célébrations : 5, 10, puis chaque dizaine ; la prochaine annoncée', () {
    expect(
      [
        for (var n = 1; n <= 31; n++)
          if (CourseDoneScreen.isMilestone(n)) n,
      ],
      [5, 10, 20, 30],
    );
    expect(
      [
        for (final n in [1, 4, 5, 9, 12]) CourseDoneScreen.nextMilestone(n),
      ],
      [5, 5, 10, 10, 20],
    );
  });

  testWidgets('course livrée : gain, pièce qui tinte, objectif, note puis continuer', (tester) async {
    final rated = <int>[];
    var closed = 0;
    await pumpVariant(tester, Variant.matrix.first, done(delivered: 3, rated: rated, onDone: () => closed++));
    await tester.pump(const Duration(milliseconds: 300));
    expect(sounds.played, [TaraSound.cash]);
    expect(find.text('+1 050 F'), findsOneWidget);
    expect(find.text('3e COURSE DU JOUR · BRAVO AWA'), findsOneWidget);
    expect(find.text('Objectif du jour : 5 courses'), findsOneWidget);
    expect(find.text('Encore 2 courses pour la prochaine célébration.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('4 étoiles'));
    await tester.pump();
    expect(rated, [4]);
    expect(find.text('Merci ! Votre note aide Tara à bien choisir ses clients.'), findsOneWidget);

    await tester.tap(find.text('Continuer · rester en ligne'));
    expect(closed, 1);
  });

  for (final brightness in Brightness.values) {
    goldenTest('17 course livrée ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), done(delivered: 5));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('5 courses aujourd’hui !'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/17_course_livree/${brightness.name}.png'));
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
