import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_onboarding_golden_test.dart' show welcome;

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    final field = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
    await tester.enterText(find.descendant(of: field, matching: find.byType(EditableText)).first, text);
    await settle(tester);
  }

  testWidgets('particulier : prénom et nom obligatoires, puis enregistrés', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, welcome(api: api));
    await settle(tester);
    await tapText(tester, 'Continuer');
    expect(find.text('Obligatoire'), findsNWidgets(2));
    expect(api.names, isEmpty);

    await type(tester, 'Prénom', 'Awa');
    await type(tester, 'Nom', 'Ngono');
    await tapText(tester, 'Continuer');
    expect(api.names, ['Awa Ngono']);
    expect(api.merchants, isEmpty);
  });

  testWidgets('boutique : nom de la boutique, reversements au numéro du compte, MTN deviné', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, welcome(api: api));
    await settle(tester);
    await type(tester, 'Prénom', 'Awa');
    await type(tester, 'Nom', 'Ngono');
    await tapText(tester, 'Pour ma boutique');
    await tapText(tester, 'Continuer');
    expect(api.names, isEmpty);

    await type(tester, 'Nom de la boutique', 'Awa Fashion');
    await tapText(tester, 'Mode');
    await tapText(tester, 'Continuer');
    expect(api.names, ['Awa Ngono']);
    expect(api.merchants.single, {
      'shopName': 'Awa Fashion',
      'category': 'FASHION',
      'payoutPhone': '+237677123456',
      'payoutOperator': 'MTN',
      'rccm': null,
      'niu': null,
    });
  });
}
