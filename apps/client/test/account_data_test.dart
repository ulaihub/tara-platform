import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/profile/delete_account_screen.dart';
import 'package:tara_client/features/profile/profile_screen.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_test/fake_pin.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show person;
import 'screens_new_order_golden_test.dart' show overrides;

class _Auth extends AuthController {
  int logouts = 0;

  @override
  Future<AuthStatus> build() async => AuthStatus.signedIn;

  @override
  Future<void> logout() async {
    logouts++;
    state = const AsyncData(AuthStatus.signedOut);
  }
}

const _empty = Wallet(customerBalance: 0, merchantBalance: null, payoutSchedule: null);

/// Profil de Paul (sans boutique) : copie des données partagée dans [shared].
Widget _account(FakeClientApi api, {_Auth? auth, List<(String, String, Object?)>? shared}) => ProviderScope(
  overrides: [
    ...overrides(api),
    appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    legalApiProvider.overrideWithValue(FakeLegalApi()),
    shareFileProvider.overrideWithValue(
      (bytes, name, mime, text) async => shared?.add((name, mime, jsonDecode(utf8.decode(bytes)))),
    ),
    authControllerProvider.overrideWith(() => auth ?? _Auth()),
  ],
  child: const ProfileScreen(me: person),
);

void main() {
  setUpAll(loadAppFonts);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 120, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  for (final brightness in Brightness.values) {
    goldenTest('supprimer mon compte ${brightness.name}', (tester) async {
      final api = FakeClientApi()..wallet0 = _empty;
      // Écran rendu seul : la capture ne voit pas les pages ouvertes par-dessus le profil.
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        ProviderScope(
          overrides: overrides(api),
          child: DeleteAccountScreen(me: person, onBack: () {}),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/06_supprimer_compte/${brightness.name}.png'));
    });
  }

  testWidgets('télécharger mes données : copie en fichier JSON, par la feuille de partage', (tester) async {
    final api = FakeClientApi()..wallet0 = _empty;
    final shared = <(String, String, Object?)>[];
    await pumpVariant(tester, Variant.matrix.first, _account(api, shared: shared));
    await settle(tester);
    await tapText(tester, 'Télécharger mes données');
    expect(api.exports, 1);
    expect(shared.single.$1, matches(RegExp(r'^tara-donnees-\d{4}-\d{2}-\d{2}\.json$')));
    expect(shared.single.$2, 'application/json');
    expect((shared.single.$3! as Map)['user'], {'phone': '+237677123456', 'fullName': 'Awa Ngono'});
  });

  testWidgets('supprimer mon compte : bloqué tant qu’il reste de l’argent chez Tara', (tester) async {
    final api = FakeClientApi()
      ..wallet0 = const Wallet(customerBalance: 3500, merchantBalance: null, payoutSchedule: null);
    await pumpVariant(tester, Variant.matrix.first, _account(api));
    await settle(tester);
    await tapText(tester, 'Supprimer mon compte');
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(
      find.text('Il vous reste 3\u00a0500\u00a0F chez Tara : retirez-les d’abord vers votre Mobile Money.'),
      findsOneWidget,
    );
    expect(find.text('Ouvrir mon portefeuille'), findsOneWidget);
    await tester.tap(find.text('Supprimer avec mon code secret'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Code secret'), findsNothing);
    expect(api.deletions, isEmpty);
  });

  testWidgets('supprimer mon compte : refus du serveur affiché après le code secret', (tester) async {
    final api = FakeClientApi()
      ..wallet0 = _empty
      ..deletionErrors.add(
        const ApiException(
          code: 'ACCOUNT_HAS_ACTIVE_ORDERS',
          message: 'Des commandes sont en cours : attendez leur fin pour supprimer le compte.',
          status: 422,
        ),
      );
    await pumpVariant(tester, Variant.matrix.first, _account(api));
    await settle(tester);
    await tapText(tester, 'Supprimer mon compte');
    await tester.tap(find.text('Supprimer avec mon code secret'));
    await settle(tester);
    expect(find.text('Pour supprimer votre compte'), findsOneWidget);
    await enterPin(tester, '2580');
    await settle(tester);
    // Le refus revient sur l'écran de suppression.
    expect(find.text('Des commandes sont en cours : attendez leur fin pour supprimer le compte.'), findsOneWidget);
    expect(api.deletions, isEmpty);
  });

  testWidgets('supprimer mon compte : code secret, suppression définitive, déconnexion, sans SMS', (tester) async {
    final api = FakeClientApi()..wallet0 = _empty;
    final auth = _Auth();
    await pumpVariant(tester, Variant.matrix.first, _account(api, auth: auth));
    await settle(tester);
    await tapText(tester, 'Supprimer mon compte');
    await tester.tap(find.text('Supprimer avec mon code secret'));
    await settle(tester);
    await enterPin(tester, '0000');
    expect(find.text('Code secret incorrect. Encore 4 essai(s) avant blocage.'), findsOneWidget);
    expect(api.deletions, isEmpty);
    await enterPin(tester, '2580');
    await settle(tester);
    expect(api.deletions.single.pin, '2580');
    expect(auth.logouts, 1);
  });
}
