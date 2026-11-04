import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/auth/code_screen.dart';
import 'package:tara_client/features/auth/sign_in_screen.dart';
import 'package:tara_client/features/onboarding/welcome_screen.dart';
import 'package:tara_core/session/session_store.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';

/// Écrans sans réseau : stockage en mémoire, API factice.
Widget scoped(Widget child, {FakeClientApi? api}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api ?? FakeClientApi()),
  ],
  child: child,
);

final challenge = OtpChallenge(
  challengeId: '00000000-0000-4000-8000-000000000000',
  expiresAt: DateTime.utc(2026, 11, 3, 10),
  resendAfterSeconds: 42,
);

const newAccount = Me(
  id: '00000000-0000-4000-8000-0000000000aa',
  phone: '+237677123456',
  fullName: null,
  locale: 'FR',
  referralCode: 'TARA-7KQ2PM',
  merchant: null,
);

Widget welcome({FakeClientApi? api}) => scoped(
  WelcomeScreen(me: newAccount, onDone: () {}, onLogout: () {}),
  api: api,
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('01 connexion ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(SignInScreen(onCodeSent: (_, _, _) {}, initialPhone: '690123456')));
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

    goldenTest('03 bienvenue ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, welcome());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_bienvenue/${variant.name}.png'));
    });

    goldenTest('03 bienvenue boutique ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, welcome());
      await settle(tester);
      await tester.tap(find.text('Pour ma boutique'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_bienvenue_boutique/${variant.name}.png'));
    });
  }

  goldenTest('01 connexion avec parrainage', (tester) async {
    const variant = Variant(Brightness.light, ScreenSize.regular, 1);
    await pumpVariant(
      tester,
      variant,
      scoped(SignInScreen(onCodeSent: (_, _, _) {}, initialPhone: '690123456', initialReferral: 'TARA-7KQ2PM')),
    );
    await settle(tester);
    expect(find.text('Code de parrainage'), findsOneWidget);
    await expectLater(capture, matchesGoldenFile('goldens/01_connexion/parrainage_light.png'));
  });

  for (final brightness in Brightness.values) {
    goldenTest('03 bienvenue boutique complet ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), welcome(), surface: const Size(390, 1500));
      await settle(tester);
      await tester.tap(find.text('Pour ma boutique'));
      await settle(tester);
      await tester.tap(find.text('Ajouter RCCM et NIU (facultatif)'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_bienvenue_boutique/complet_${brightness.name}.png'));
    });
  }
}
