import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/auth/code_screen.dart';
import 'package:tara_client/features/legal/terms_screen.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/auth_api.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/check_row.dart';
import 'package:tara_ui/components/legal_markdown.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';
import 'screens_onboarding_golden_test.dart' show challenge, readToEnd;

/// Connexion sans réseau : un nouveau compte doit d'abord accepter les conditions.
class _NewAccountAuthApi extends AuthApi {
  _NewAccountAuthApi()
    : super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
        platform: 'ANDROID',
      );

  final calls = <Map<String, String>?>[];

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String locale,
    Map<String, String>? terms,
    String? referralCode,
  }) async {
    calls.add(terms);
    throw const ApiException(code: 'TERMS_REQUIRED', message: 'Acceptez les conditions.', status: 422);
  }
}

Widget _scoped(Widget child, {FakeLegalApi? legal, AuthApi? auth}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(FakeClientApi()),
    legalApiProvider.overrideWithValue(legal ?? FakeLegalApi()),
    if (auth != null) authApiProvider.overrideWithValue(auth),
  ],
  child: child,
);

final _variant = Variant.matrix.first;

void main() {
  testWidgets('un nouveau compte passe du code aux conditions, avec le code saisi', (tester) async {
    final auth = _NewAccountAuthApi();
    (OtpChallenge, String)? required;
    await pumpVariant(
      tester,
      _variant,
      _scoped(
        CodeScreen(
          phone: '+237690123456',
          challenge: challenge,
          onBack: () {},
          onSignedIn: (_) {},
          onTermsRequired: (challenge, code) => required = (challenge, code),
        ),
        auth: auth,
      ),
    );
    await tester.enterText(find.byType(EditableText).first, '482193');
    await settle(tester);
    expect(auth.calls, [null]);
    expect(required?.$2, '482193');
    expect(find.text('Acceptez les conditions.'), findsNothing);
  });

  testWidgets('l’inscription n’est possible qu’après lecture jusqu’en bas et case cochée', (tester) async {
    final accepted = <Map<String, String>>[];
    await pumpVariant(
      tester,
      _variant,
      _scoped(TermsScreen.signup(onAccept: (versions) async => accepted.add(versions), onBack: () {})),
    );
    await settle(tester);
    expect(find.byType(TaraCheckRow), findsNothing);
    expect(find.text('Faites défiler les textes jusqu’en bas pour pouvoir les accepter.'), findsOneWidget);

    await readToEnd(tester);
    await tester.tap(find.text('Accepter et créer mon compte'));
    await settle(tester);
    expect(accepted, isEmpty, reason: 'case non cochée');

    await tester.tap(find.byType(TaraCheckRow));
    await settle(tester);
    await tester.tap(find.text('Accepter et créer mon compte'));
    await settle(tester);
    expect(accepted, [
      {'expediteurs': '2026-11', 'confidentialite': '2026-11'},
    ]);
  });

  testWidgets('une nouvelle version se signe avec un code SMS dédié', (tester) async {
    final legal = FakeLegalApi(status: newVersion());
    var signed = 0;
    await pumpVariant(
      tester,
      _variant,
      _scoped(
        TermsScreen.update(phone: '+237677123456', onLater: () {}, onSigned: () => signed++),
        legal: legal,
      ),
    );
    await settle(tester);
    await readToEnd(tester);
    await tester.tap(find.byType(TaraCheckRow));
    await settle(tester);
    await tester.tap(find.text('Recevoir le code pour signer'));
    await settle(tester);
    expect(legal.codes, 1);
    expect(find.textContaining('Il vaut signature de votre acceptation.'), findsOneWidget);

    legal.acceptError = const ApiException(code: 'OTP_INVALID', message: 'Code incorrect.', status: 400);
    await tester.enterText(find.byType(EditableText).first, '111111');
    await settle(tester);
    expect(find.text('Code incorrect.'), findsOneWidget);
    expect(signed, 0);

    legal.acceptError = null;
    await tester.enterText(find.byType(EditableText).first, '654321');
    await settle(tester);
    expect(legal.signed.single.code, '654321');
    expect(legal.signed.single.versions, {'expediteurs': '2026-11', 'confidentialite': '2026-11'});
    expect(signed, 1);
  });

  test('les textes de docs/juridique se découpent sans marque Markdown oubliée', () {
    final folder = Directory('../../docs/juridique');
    for (final name in [
      'conditions-expediteurs.md',
      'conditions-livreurs.md',
      'conditions-destinataires.md',
      'politique-confidentialite.md',
    ]) {
      final blocks = parseLegalMarkdown(File('${folder.path}/$name').readAsStringSync());
      expect(blocks.first, isA<LegalHeading>().having((block) => block.level, 'niveau', 1), reason: name);
      final texts = [
        for (final block in blocks)
          ...switch (block) {
            LegalHeading(:final text) || LegalParagraph(:final text) => [text],
            LegalList(:final items) => items,
            LegalTable(:final header, :final rows) => [...header, for (final row in rows) ...row],
          },
      ];
      for (final text in texts) {
        expect('**'.allMatches(text).length.isEven, isTrue, reason: '$name : « $text »');
        expect(text.startsWith('|') || text.startsWith('- '), isFalse, reason: '$name : « $text »');
      }
    }
    final expediteurs = parseLegalMarkdown(File('${folder.path}/conditions-expediteurs.md').readAsStringSync());
    final fees = expediteurs.whereType<LegalTable>().single;
    expect(fees.header, ['Situation', 'Frais']);
    expect(fees.rows.first, ['Nouvelle tentative', '500 FCFA']);
  });
}
