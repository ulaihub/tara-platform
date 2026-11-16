import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/models.dart';
import 'package:tara_core/api/pin_api.dart';
import 'package:tara_core/security/biometrics.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_sms/tara_sms.dart';

/// Code secret sans réseau : mêmes règles que le serveur (5 erreurs, empreinte par téléphone).
class FakePinApi extends PinApi {
  FakePinApi({this.isSet = true, this.pin = '2580', this.key})
    : super(
        ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())),
        SessionStore(MemoryKeyValueStore()),
      );

  bool isSet;
  bool locked = false;
  String pin;
  int remaining = 5;

  /// Clé de l'empreinte gardée sur le téléphone.
  String? key;

  /// Preuves acceptées, codes enregistrés (code, code actuel, code reçu), codes oubliés demandés.
  final accepted = <PinProof>[];
  final sets = <(String pin, String? current, String? code)>[];
  int resetCodes = 0;

  /// Contrôle une preuve comme le serveur ; lève les mêmes erreurs.
  void check(PinProof proof) {
    if (!isSet) {
      throw const ApiException(code: 'PIN_NOT_SET', message: 'Choisissez d’abord votre code secret.', status: 403);
    }
    if (locked) throw const ApiException(code: 'PIN_LOCKED', message: 'Code secret bloqué.', status: 403);
    if (proof.biometricKey case final given?) {
      if (given != key) {
        throw const ApiException(code: 'BIOMETRIC_INVALID', message: 'Empreinte à réactiver.', status: 403);
      }
    } else if (proof.pin != pin) {
      remaining--;
      if (remaining == 0) {
        locked = true;
        throw const ApiException(code: 'PIN_LOCKED', message: 'Code secret bloqué.', status: 403);
      }
      throw ApiException(
        code: 'PIN_INVALID',
        message: 'Code secret incorrect. Encore $remaining essai(s) avant blocage.',
        status: 403,
      );
    }
    remaining = 5;
    accepted.add(proof);
  }

  @override
  Future<PinStatus> status() async => PinStatus(set: isSet, locked: locked, remainingAttempts: locked ? 0 : remaining);

  @override
  Future<void> set(String pin, {String? currentPin, String? challengeId, String? code}) async {
    if (code == null && isSet) check(PinProof.pin(currentPin ?? ''));
    sets.add((pin, currentPin, code));
    isSet = true;
    locked = false;
    remaining = 5;
    this.pin = pin;
    key = null;
  }

  @override
  Future<OtpChallenge> requestResetCode({String? appHash, OtpChannel? channel}) async {
    resetCodes++;
    return OtpChallenge(
      challengeId: '00000000-0000-4000-8000-0000000000aa',
      expiresAt: DateTime.utc(2026, 11, 16, 10),
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<void> verify(PinProof proof) async => check(proof);

  @override
  Future<void> enableBiometric(String pin) async {
    check(PinProof.pin(pin));
    key = 'cle-empreinte-de-test-0123456789abcdef0123456789';
  }

  @override
  Future<void> disableBiometric() async => key = null;

  @override
  Future<String?> biometricKey() async => key;

  @override
  Future<void> forgetBiometric() async => key = null;
}

/// Capteur d'empreinte de test : présent ou non, accepte ou refuse.
class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.present = true, this.accept = true});

  bool present;
  bool accept;
  int prompts = 0;

  @override
  Future<bool> available() async => present;

  @override
  Future<bool> confirm(BiometricPrompt prompt) async {
    prompts++;
    return present && accept;
  }
}

/// Lecture du SMS de test : le test « reçoit » le SMS avec [deliver].
class FakeSmsCodeReader implements SmsCodeReader {
  FakeSmsCodeReader({this.hash = 'FA+9qCX9VSu'});

  final String? hash;
  final waits = <bool>[];
  Completer<String?>? _pending;

  /// Un SMS arrive : son code est remis à l'écran qui l'attend.
  void deliver(String code) {
    final pending = _pending;
    _pending = null;
    pending?.complete(code);
  }

  @override
  Future<String?> appHash() async => hash;

  @override
  Future<String?> waitForCode({required bool autoRead, int length = 6}) {
    waits.add(autoRead);
    _pending?.complete(null);
    final pending = Completer<String?>();
    _pending = pending;
    return pending.future;
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    _pending = null;
    pending?.complete(null);
  }
}

/// Tape [digits] sur le pavé du code secret.
Future<void> enterPin(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(digit).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
