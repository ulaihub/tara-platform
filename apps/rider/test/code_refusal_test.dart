import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/auth_api.dart';
import 'package:tara_core/api/models.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/features/auth/code_screen.dart';
import 'package:tara_test/fake_legal_api.dart';
import 'package:tara_test/fake_pin.dart';

import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;

/// Vérification refusée par le serveur (code faux, expiré, numéro bloqué pour la journée).
class _RefusingAuthApi extends AuthApi {
  _RefusingAuthApi()
    : super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
        platform: 'ANDROID',
      );

  final verified = <String>[];

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String locale,
    Map<String, String>? terms,
    String? referralCode,
  }) async {
    verified.add(code);
    throw const ApiException(
      code: 'OTP_LOCKED',
      message: 'Trop de codes incorrects pour ce numéro. Réessayez demain ou contactez le support.',
      status: 429,
    );
  }
}

void main() {
  testWidgets('code refusé : les cases se vident mais le message reste, sans nouvel essai automatique', (tester) async {
    final auth = _RefusingAuthApi();
    final sms = FakeSmsCodeReader();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          legalApiProvider.overrideWithValue(FakeLegalApi(app: 'rider')),
          authApiProvider.overrideWithValue(auth),
          smsCodeReaderProvider.overrideWithValue(sms),
        ],
        child: CodeScreen(
          phone: '+237690123456',
          challenge: OtpChallenge(
            challengeId: '00000000-0000-4000-8000-0000000000aa',
            expiresAt: DateTime.utc(2026, 11, 16, 10),
            resendAfterSeconds: 60,
            autoRead: true,
          ),
          onBack: () {},
          onSignedIn: (_) {},
          onTermsRequired: (_, _) {},
        ),
      ),
    );
    await settle(tester);
    sms.deliver('482193');
    await settle(tester);
    expect(auth.verified, ['482193']);
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
