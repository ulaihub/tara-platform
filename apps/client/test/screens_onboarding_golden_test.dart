import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/auth/code_screen.dart';
import 'package:tara_client/features/auth/sign_in_screen.dart';
import 'package:tara_client/features/legal/terms_screen.dart';
import 'package:tara_client/features/onboarding/welcome_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/check_row.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';

/// Écrans sans réseau : stockage en mémoire, API factice.
Widget scoped(Widget child, {FakeClientApi? api, FakeLegalApi? legal}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api ?? FakeClientApi()),
    legalApiProvider.overrideWithValue(legal ?? FakeLegalApi()),
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
  WelcomeScreen(me: newAccount, onDone: () {}),
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
        scoped(
          CodeScreen(
            phone: '+237677123456',
            // Maquette : code envoyé sur WhatsApp, lecture automatique en cours.
            challenge: OtpChallenge(
              challengeId: challenge.challengeId,
              expiresAt: challenge.expiresAt,
              resendAfterSeconds: 42,
              channel: OtpChannel.whatsapp,
              autoRead: true,
            ),
            onBack: () {},
            onSignedIn: (_) {},
            onTermsRequired: (_, _) {},
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText).first, '3710');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_code/${variant.name}.png'));
    });

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

    goldenTest('02 nouvelle version à accepter ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(TermsScreen.update(onLater: () {}, onSigned: () {})));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/02_conditions_nouvelle_version/${variant.name}.png'));
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
    goldenTest('03 bienvenue boutique remplie ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), welcome());
      await settle(tester);
      await tester.tap(find.text('Pour ma boutique'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Awa Fashion');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_bienvenue_boutique/complet_${brightness.name}.png'));
    });
  }
}

/// Fait défiler les textes des conditions jusqu'en bas.
Future<void> readToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
  await settle(tester);
}
