import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/auth/code_screen.dart';
import 'package:tara_rider/features/auth/sign_in_screen.dart';
import 'package:tara_rider/features/common/splash_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

/// Écrans sans réseau : stockage en mémoire, réglages par défaut.
Widget scoped(Widget child) =>
    ProviderScope(overrides: [keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore())], child: child);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

final challenge = OtpChallenge(
  challengeId: '00000000-0000-4000-8000-000000000000',
  expiresAt: DateTime.utc(2026, 11, 3, 10),
  resendAfterSeconds: 42,
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('01 connexion ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(SignInScreen(onCodeSent: (_, _) {}, initialPhone: '690123456')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/01_connexion/${variant.name}.png'));
    });

    goldenTest('02 code ${variant.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        scoped(CodeScreen(phone: '+237690123456', challenge: challenge, onBack: () {}, onSignedIn: (_) {})),
      );
      await tester.enterText(find.byType(EditableText).first, '4821');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_code/${variant.name}.png'));
    });
  }

  for (final variant in Variant.matrix.where((v) => v.textScale == 1 && v.screen == ScreenSize.regular)) {
    goldenTest('démarrage ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, const SplashScreen());
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/00_demarrage/${variant.name}.png'));
    });
  }

  goldenTest('01 connexion numéro invalide', (tester) async {
    const variant = Variant(Brightness.dark, ScreenSize.compact, 1);
    await pumpVariant(tester, variant, scoped(SignInScreen(onCodeSent: (_, _) {}, initialPhone: '590123456')));
    await tester.tap(find.text('Recevoir le code'));
    await settle(tester);
    expect(find.textContaining('commençant par 6'), findsOneWidget);
    await expectLater(capture, matchesGoldenFile('goldens/01_connexion/erreur_dark_360x640.png'));
  });
}
