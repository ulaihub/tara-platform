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
    expect(find.text('Faites défiler jusqu’en bas pour pouvoir accepter.'), findsOneWidget);
    expect(find.text('Lu à 0%'), findsOneWidget);
    // Avant la lecture : la case ne se coche pas, le bouton ne fait rien.
    await tester.tap(find.byType(TaraCheckRow));
    await tester.tap(find.text('Accepter et créer mon compte'));
    await settle(tester);
    expect(accepted, isEmpty, reason: 'textes non lus');

    await readToEnd(tester);
    expect(find.text('Lu à 100%'), findsOneWidget);
    expect(find.text('Faites défiler jusqu’en bas pour pouvoir accepter.'), findsNothing);
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

  testWidgets('une nouvelle version s’accepte d’un geste, sans code SMS', (tester) async {
    final legal = FakeLegalApi(status: newVersion());
    var signed = 0;
    await pumpVariant(
      tester,
      _variant,
      _scoped(
        TermsScreen.update(onLater: () {}, onSigned: () => signed++),
        legal: legal,
      ),
    );
    await settle(tester);
    expect(
      find.text(
        'Lisez la nouvelle version jusqu’en bas, puis acceptez-la. Sans acceptation, vos livraisons '
        'en cours continuent, mais vous ne pourrez pas en commander de nouvelles.',
      ),
      findsOneWidget,
    );
    // Maquette : pas de case pour une nouvelle version ; le bouton s'active après lecture.
    expect(find.byType(TaraCheckRow), findsNothing);
    await tester.tap(find.text('J’accepte la nouvelle version'));
    await settle(tester);
    expect(legal.signed, isEmpty, reason: 'textes non lus');
    await readToEnd(tester);

    // Refus du serveur : message affiché, rien d'accepté, on peut réessayer.
    legal.acceptError = const ApiException(code: 'INTERNAL', message: 'Réessayez dans un instant.', status: 500);
    await tester.tap(find.text('J’accepte la nouvelle version'));
    await settle(tester);
    expect(find.text('Réessayez dans un instant.'), findsOneWidget);
    expect(signed, 0);

    legal.acceptError = null;
    await tester.tap(find.text('J’accepte la nouvelle version'));
    await settle(tester);
    expect(find.byType(EditableText), findsNothing);
    expect(legal.signed.single, {'expediteurs': '2026-11', 'confidentialite': '2026-11'});
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
