import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/auth/code_screen.dart';
import 'package:tara_rider/features/auth/sign_in_screen.dart';
import 'package:tara_rider/features/common/splash_screen.dart';
import 'package:tara_rider/features/legal/terms_screen.dart';
import 'package:tara_test/fake_legal_api.dart';
import 'package:tara_ui/components/check_row.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';

/// Écrans sans réseau : stockage en mémoire, réglages par défaut, conditions d'exemple.
Widget scoped(Widget child, {FakeLegalApi? legal}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    legalApiProvider.overrideWithValue(legal ?? FakeLegalApi(app: 'rider')),
  ],
  child: child,
);

/// Fait défiler les textes jusqu'en bas : la case à cocher devient active.
Future<void> readToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await loadBrandImages(tester);
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
        scoped(
          CodeScreen(
            phone: '+237690123456',
            challenge: challenge,
            onBack: () {},
            onSignedIn: (_) {},
            onTermsRequired: (_, _) {},
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText).first, '4821');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_code/${variant.name}.png'));
    });
  }

  for (final variant in Variant.matrix) {
    goldenTest('02 conditions inscription ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(TermsScreen.signup(onAccept: (_) async {}, onBack: () {})));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_conditions/${variant.name}.png'));
    });

    goldenTest('02 conditions lues et cochées ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(TermsScreen.signup(onAccept: (_) async {}, onBack: () {})));
      await settle(tester);
      await readToEnd(tester);
      await tester.tap(find.byType(TaraCheckRow));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_conditions_cochees/${variant.name}.png'));
    });
  }

  goldenTest('02 nouvelle version à accepter', (tester) async {
    const variant = Variant(Brightness.dark, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, scoped(TermsScreen.update(onLater: () {}, onSigned: () {})));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(capture, matchesGoldenFile('goldens/02_conditions_nouvelle_version/${variant.name}.png'));
  });

  testWidgets('une nouvelle version s’accepte sans code, aux versions affichées', (tester) async {
    final legal = FakeLegalApi(app: 'rider', status: newVersion('rider'));
    var signed = 0;
    await pumpVariant(
      tester,
      const Variant(Brightness.dark, ScreenSize.regular, 1),
      scoped(
        TermsScreen.update(onLater: () {}, onSigned: () => signed++),
        legal: legal,
      ),
    );
    await settle(tester);
    // Maquette : pas de case pour une nouvelle version ; bouton inactif avant la lecture.
    expect(find.byType(TaraCheckRow), findsNothing);
    await tester.tap(find.text('J’accepte la nouvelle version'));
    await settle(tester);
    expect(legal.signed, isEmpty);
    await readToEnd(tester);
    await tester.tap(find.text('J’accepte la nouvelle version'));
    await settle(tester);
    expect(find.byType(EditableText), findsNothing);
    expect(legal.signed.single, {'livreurs': '2026-11', 'confidentialite': '2026-11'});
    expect(signed, 1);
  });

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
