import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/support_api.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_test/fake_support.dart';
import 'package:tara_ui/components/support_flow.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_account_golden_test.dart' show AccountHarness;
import 'screens_auth_golden_test.dart' show settle;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('compte : écrire au service client, motifs du livreur, numéro à appeler', (tester) async {
    final support = FakeSupportBackend();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      AccountHarness().screen(extra: [supportBackendProvider.overrideWithValue(support)]),
    );
    await settle(tester);
    final row = find.text('Écrire au service client');
    await tester.scrollUntilVisible(row, 120, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
    expect(find.byType(SupportHomeScreen), findsOneWidget);
    expect(find.textContaining('Urgent ? Appelez le +237'), findsOneWidget);

    await tester.tap(find.text('Nouvelle demande'));
    await settle(tester);
    // Les motifs d'un livreur : pas de « comportement du livreur » ni de « retard ».
    expect(find.text('Gains, solde ou retrait'), findsOneWidget);
    expect(find.text('Comportement du livreur'), findsNothing);
    await tester.tap(find.text('Gains, solde ou retrait'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Retrait non reçu');
    await tester.enterText(find.byType(TextField).at(1), 'J’ai demandé un retrait hier, rien reçu.');
    await settle(tester);
    await tester.tap(find.text('Envoyer la demande'));
    await settle(tester);
    expect(support.opened.single.category, SupportCategory.payment);
    expect(find.byType(SupportThreadScreen), findsOneWidget);
    expect(find.text('SUP-1001 · Envoyée'), findsOneWidget);
  });
}
