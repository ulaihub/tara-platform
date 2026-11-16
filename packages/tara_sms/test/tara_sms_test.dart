import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_sms/tara_sms.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trouve le code avant l’empreinte de l’app', () {
    const sms =
        'Tara : votre code de connexion est 482913. Il expire dans 5 min. Ne le partagez avec personne.'
        '\n\nFA+9qCX9VS123456';
    expect(codeInSms(sms), '482913');
    expect(codeInSms('Code 12345 trop court'), isNull);
    expect(codeInSms('Tara : 1234567'), isNull);
    expect(codeInSms('Tara : 4821', length: 4), '4821');
    // SMS d'un autre expéditeur (Mobile Money, opérateur) : jamais pris pour le code.
    expect(codeInSms('Transfert de 482913 FCFA reçu. Solde : 12 500 FCFA.'), isNull);
  });

  test('lit le SMS par le canal Android, avec ou sans accord', () async {
    const channel = MethodChannel('tara_sms');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'appHash' => 'FA+9qCX9VSu',
        'listen' => 'Tara : votre code de connexion est 482913.\n\nFA+9qCX9VSu',
        _ => null,
      };
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const reader = SmsCodeReader();
    expect(await reader.appHash(), 'FA+9qCX9VSu');
    expect(await reader.waitForCode(autoRead: true), '482913');
    expect(await reader.waitForCode(autoRead: false), '482913');
    await reader.cancel();
    expect(calls.map((call) => call.arguments).toList(), [
      null,
      {'consent': false},
      {'consent': true},
      null,
    ]);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await reader.appHash(), isNull);
    expect(await reader.waitForCode(autoRead: true), isNull);
  });
}
