import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/features/profile/profile_screen.dart';
import 'package:tara_ui/components/buttons.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_legal_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show shopOwner;
import 'screens_new_order_golden_test.dart' show orderApi, overrides;

Widget profile(FakeClientApi api) => ProviderScope(
  overrides: [
    ...overrides(api),
    appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    legalApiProvider.overrideWithValue(FakeLegalApi()),
  ],
  child: const ProfileScreen(me: shopOwner),
);

Finder removeButton(String label) =>
    find.byWidgetPredicate((widget) => widget is GlassIconButton && widget.label == 'Retirer $label');

/// Ligne « Mes adresses » du menu du profil : sa page s'ouvre.
Future<void> showAddresses(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Mes adresses'), 100, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Mes adresses'));
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  goldenTest('profil : mes adresses', (tester) async {
    const variant = Variant(Brightness.light, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, profile(orderApi()));
    await settle(tester);
    await showAddresses(tester);
    // Page ouverte depuis le menu du profil : par-dessus l'écran capturé d'habitude.
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/06_profil/adresses_${variant.name}.png'));
  });

  testWidgets('retire une adresse après confirmation', (tester) async {
    final api = orderApi();
    await pumpVariant(tester, Variant.matrix.first, profile(api));
    await settle(tester);
    await showAddresses(tester);
    expect(find.text('Maison'), findsOneWidget);
    await tester.tap(removeButton('Maison'));
    await settle(tester);
    expect(find.textContaining('Retirer « Maison » de vos adresses ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(api.deletedAddresses, isEmpty);

    await tester.tap(removeButton('Maison'));
    await settle(tester);
    await tester.tap(find.text('Oui, retirer'));
    await settle(tester);
    expect(api.deletedAddresses, ['00000000-0000-4000-8000-000000000202']);
    expect(find.text('Maison'), findsNothing);
    expect(find.text('Boutique'), findsOneWidget);
  });

  testWidgets('ajoute une adresse placée sur la carte, avec son libellé', (tester) async {
    final api = orderApi()..saved = [];
    await pumpVariant(tester, Variant.matrix.first, profile(api));
    await settle(tester);
    await showAddresses(tester);
    expect(find.textContaining('Enregistrez votre boutique ou votre maison'), findsOneWidget);
    await tester.tap(find.text('Ajouter une adresse'));
    await settle(tester);
    expect(find.text('Nouvelle adresse'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Portail vert face à l’école publique');
    await tester.tap(find.text('Maison'));
    await settle(tester);
    await tester.tap(find.text('Enregistrer l’adresse'));
    await settle(tester);
    expect(api.createdAddresses.single['label'], 'Maison');
    await showAddresses(tester);
    expect(find.text('Maison'), findsOneWidget);
  });
}
