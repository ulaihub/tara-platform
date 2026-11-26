import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/app/root.dart';
import 'package:tara_client/features/auth/sign_in_screen.dart';
import 'package:tara_client/features/onboarding/intro_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/intro.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';

/// Premier lancement : la présentation passe avant la connexion, puis ne revient plus.
void main() {
  setUpAll(loadAppFonts);

  Widget app(MemoryKeyValueStore store) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      clientApiProvider.overrideWithValue(FakeClientApi()),
      legalApiProvider.overrideWithValue(FakeLegalApi()),
    ],
    child: const RootGate(),
  );

  goldenTest('présentation au premier lancement, puis plus jamais', (tester) async {
    final store = MemoryKeyValueStore();
    const variant = Variant(Brightness.light, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, app(store));
    await settle(tester);
    expect(find.byType(ClientIntroScreen), findsOneWidget);

    await tester.tap(find.byKey(introSkipKey));
    await settle(tester);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(await store.read(introSeenKey), isNotNull);

    // Relance de l'app : directement la connexion.
    await pumpVariant(tester, variant, const SizedBox());
    await pumpVariant(tester, variant, app(store));
    await settle(tester);
    expect(find.byType(ClientIntroScreen), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
