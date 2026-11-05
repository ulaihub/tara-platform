import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/core/api/client_models.dart';

/// Chaque champ lu par l'app existe dans le contrat de l'API (apps/api/openapi.json) :
/// un renommage côté serveur casse ce test avant de casser l'app chez les expéditeurs.
void main() {
  final contract = jsonDecode(File('../api/openapi.json').readAsStringSync()) as Map<String, Object?>;
  final schemas = (contract['components']! as Map)['schemas']! as Map;

  Set<String> propertiesOf(String name) {
    final schema = schemas[name] as Map?;
    expect(schema, isNotNull, reason: 'schéma $name absent du contrat');
    return ((schema!['properties'] ?? <String, Object?>{}) as Map).keys.cast<String>().toSet();
  }

  final models = <String, List<String>>{
    'OtpChallenge': OtpChallenge.fields,
    'SessionUser': SessionUser.fields,
    'AuthSession': AuthSession.fields,
    'AppConfig': AppConfig.fields,
    'Me': Me.fields,
    'Merchant': Merchant.fields,
    'OrderSummary': OrderSummary.fields,
    'Wallet': Wallet.fields,
    'Zone': Neighborhood.fields,
    'Address': Address.fields,
    'Recipient': Recipient.fields,
    'LocationLink': LocationLink.fields,
    'Quote': Quote.fields,
    'Order': PlacedOrder.fields,
    'CreatedOrder': Placement.singleFields,
    'CreatedBatch': Placement.batchFields,
    'Payment': Payment.fields,
  };
  test('portefeuille : ventes du jour de la boutique', () {
    final wallet = jsonEncode(schemas['Wallet']);
    expect(wallet, allOf(contains('"todaySales"'), contains('"todayDeliveries"')));
  });

  for (final MapEntry(key: schema, value: fields) in models.entries) {
    test('modèle $schema conforme au contrat', () {
      expect(propertiesOf(schema), containsAll(fields));
    });
  }
}
