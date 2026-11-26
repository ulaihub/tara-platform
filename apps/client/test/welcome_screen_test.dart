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

  testWidgets('particulier : le nom est obligatoire, puis enregistré', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, welcome(api: api));
    await settle(tester);
    await tapText(tester, 'Continuer');
    expect(find.text('Obligatoire'), findsOneWidget);
    expect(api.names, isEmpty);

    await type(tester, 'Votre nom', 'Awa Ngono');
    await tapText(tester, 'Continuer');
    expect(api.names, ['Awa Ngono']);
    expect(api.merchants, isEmpty);
  });

  testWidgets('boutique : son nom, reversements au numéro du compte (masqué), MTN deviné', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, welcome(api: api));
    await settle(tester);
    await tapText(tester, 'Pour ma boutique');
    expect(find.text('Nom de votre boutique'), findsOneWidget);
    expect(find.text('6 77 •• •• 56'), findsOneWidget);
    await tapText(tester, 'Continuer');
    expect(api.names, isEmpty);

    await type(tester, 'Nom de votre boutique', 'Awa Fashion');
    await tapText(tester, 'Continuer');
    expect(api.names, ['Awa Fashion']);
    expect(api.merchants.single, {
      'shopName': 'Awa Fashion',
      'category': null,
      'payoutPhone': '+237677123456',
      'payoutOperator': 'MTN',
      'rccm': null,
      'niu': null,
    });
  });

  testWidgets('boutique : le numéro des reversements se modifie, Orange deviné', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, welcome(api: api));
    await settle(tester);
    await tapText(tester, 'Pour ma boutique');
    await type(tester, 'Nom de votre boutique', 'Awa Fashion');
    await tapText(tester, '6 77 •• •• 56');
    await type(tester, 'Numéro Mobile Money', '690112233');
    await tapText(tester, 'Continuer');
    expect(api.merchants.single['payoutPhone'], '+237690112233');
    expect(api.merchants.single['payoutOperator'], 'ORANGE');
  });
}
