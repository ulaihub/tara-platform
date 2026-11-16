import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/auth/code_screen.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/auth_api.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_test/fake_pin.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';

/// Connexion sans réseau : codes demandés (canal, empreinte de l'app) et codes vérifiés.
class _AuthApi extends AuthApi {
  _AuthApi()
    : super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
        platform: 'ANDROID',
      );

  final requests = <(String phone, String? appHash, OtpChannel? channel)>[];
  final verified = <String>[];

  /// Refus renvoyé par le serveur à la vérification (sinon : conditions à accepter).
  ApiException? refusal;

  @override
  Future<OtpChallenge> requestOtp(String phone, {required String locale, String? appHash, OtpChannel? channel}) async {
    requests.add((phone, appHash, channel));
    return OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000bb',
      expiresAt: DateTime.utc(2026, 11, 16, 10),
      resendAfterSeconds: 0,
      autoRead: true,
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String locale,
    Map<String, String>? terms,
    String? referralCode,
  }) async {
    verified.add(code);
    throw refusal ?? const ApiException(code: 'TERMS_REQUIRED', message: 'Acceptez les conditions.', status: 422);
  }
}

void main() {
  Future<(_AuthApi, FakeSmsCodeReader, List<String>)> pump(WidgetTester tester, OtpChallenge challenge) async {
    final auth = _AuthApi();
    final sms = FakeSmsCodeReader();
    final codes = <String>[];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientApiProvider.overrideWithValue(FakeClientApi()),
          legalApiProvider.overrideWithValue(FakeLegalApi()),
          authApiProvider.overrideWithValue(auth),
          smsCodeReaderProvider.overrideWithValue(sms),
        ],
        child: CodeScreen(
          phone: '+237690123456',
          challenge: challenge,
          onBack: () {},
          onSignedIn: (_) {},
          onTermsRequired: (_, code) => codes.add(code),
        ),
      ),
    );
    await settle(tester);
    return (auth, sms, codes);
  }

  testWidgets('Android lit le SMS : le code se remplit et se vérifie sans rien taper', (tester) async {
    final challenge = OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000aa',
      expiresAt: DateTime.utc(2026, 11, 16, 10),
      resendAfterSeconds: 60,
      autoRead: true,
    );
    final (auth, sms, codes) = await pump(tester, challenge);
    // SMS portant l'empreinte de l'app : lecture sans demande d'accord.
    expect(sms.waits, [true]);
    sms.deliver('482193');
    await settle(tester);
    expect(auth.verified, ['482193']);
    expect(codes, ['482193']);
  });

  testWidgets('code envoyé sur WhatsApp : « Recevoir par SMS » redemande le code par SMS', (tester) async {
    final challenge = OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000aa',
      expiresAt: DateTime.utc(2026, 11, 16, 10),
      resendAfterSeconds: 0,
      channel: OtpChannel.whatsapp,
    );
    final (auth, sms, _) = await pump(tester, challenge);
    expect(find.textContaining('Code envoyé sur WhatsApp au +237'), findsOneWidget);
    // Sans empreinte dans le message : Android demandera l'accord si un SMS arrive.
    expect(sms.waits, [false]);
    await tester.ensureVisible(find.text('Recevoir par SMS'));
    await tester.tap(find.text('Recevoir par SMS'));
    await settle(tester);
    expect(auth.requests.single.$2, 'FA+9qCX9VSu');
    expect(auth.requests.single.$3, OtpChannel.sms);
    expect(find.text('Recevoir par SMS'), findsNothing);
    // Nouveau code : nouvelle attente du SMS, cette fois avec l'empreinte.
    expect(sms.waits, [false, true]);
  });

  testWidgets('code refusé : les cases se vident mais le message reste, sans nouvel essai automatique', (tester) async {
    final challenge = OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000aa',
      expiresAt: DateTime.utc(2026, 11, 16, 10),
      resendAfterSeconds: 60,
      autoRead: true,
    );
    final (auth, sms, codes) = await pump(tester, challenge);
    auth.refusal = const ApiException(
      code: 'OTP_LOCKED',
      message: 'Trop de codes incorrects pour ce numéro. Réessayez demain ou contactez le support.',
      status: 429,
    );
    sms.deliver('482193');
    await settle(tester);
    expect(auth.verified, ['482193']);
    expect(codes, isEmpty);
    // Avant : le message s'effaçait avec les cases, l'écran semblait repartir de zéro.
    expect(
      find.text('Trop de codes incorrects pour ce numéro. Réessayez demain ou contactez le support.'),
      findsOneWidget,
    );
    expect(sms.waits, [true]);

    // Retaper un chiffre efface le message.
    await tester.enterText(find.byType(EditableText).first, '4');
    await settle(tester);
    expect(find.textContaining('Trop de codes incorrects'), findsNothing);
  });
}
