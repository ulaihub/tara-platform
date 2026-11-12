import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/features/profile/profile_screen.dart';
import 'package:tara_core/api/support_api.dart';
import 'package:tara_test/fake_support.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/support_flow.dart';

import 'helpers/fake_legal_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show shopOwner;
import 'screens_new_order_golden_test.dart' show orderApi, overrides;
import 'screens_tracking_golden_test.dart' as tracking;

Widget profile(FakeSupportBackend support) => ProviderScope(
  overrides: [
    ...overrides(orderApi()),
    appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    legalApiProvider.overrideWithValue(FakeLegalApi()),
    supportBackendProvider.overrideWithValue(support),
  ],
  child: const ProfileScreen(me: shopOwner),
);

Finder iconButton(String label) =>
    find.byWidgetPredicate((widget) => widget is GlassIconButton && widget.label == label);

Future<void> openFromProfile(WidgetTester tester) async {
  final row = find.text('Écrire au service client');
  await tester.scrollUntilVisible(row, 120, scrollable: find.byType(Scrollable).first);
  await tester.tap(row);
  await settle(tester);
}

Future<void> fillRequest(WidgetTester tester, {required String reason}) async {
  await tester.tap(find.text(reason));
  await settle(tester);
  await tester.enterText(find.byType(TextField).at(0), 'Colis non reçu');
  await tester.enterText(find.byType(TextField).at(1), 'Ma cliente dit ne rien avoir reçu.');
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  for (final variant in [Variant.matrix.first, Variant.matrix.last]) {
    goldenTest('service client : nouvelle demande puis réponse de Tara ${variant.name}', (tester) async {
      final support = FakeSupportBackend();
      await pumpVariant(tester, variant, profile(support));
      await settle(tester);
      await openFromProfile(tester);
      expect(find.text('Aide et service client'), findsOneWidget);
      expect(find.textContaining('Aucune demande pour l’instant'), findsOneWidget);

      await tester.tap(find.text('Nouvelle demande'));
      await settle(tester);
      await fillRequest(tester, reason: 'Colis perdu ou non reçu');
      await tester.tap(find.text('Envoyer la demande'));
      await settle(tester);
      expect(support.opened.single.category, SupportCategory.lostParcel);
      expect(support.opened.single.orderId, isNull);
      // La demande s'ouvre : on attend l'équipe.
      expect(find.text('SUP-1001 · Envoyée'), findsOneWidget);
      expect(find.text('L’équipe Tara vous répond ici ; vous serez prévenu.'), findsOneWidget);

      // L'équipe répond ; la liste le signale, les échanges la montrent.
      support.answer('ticket-1001', 'Bonjour, nous rappelons votre cliente et revenons vers vous.');
      await tester.tap(iconButton('Retour').first);
      await settle(tester);
      expect(find.text('Réponse'), findsOneWidget);
      // Page ouverte au-dessus du profil : capturée elle-même.
      await expectLater(
        find.byType(SupportHomeScreen),
        matchesGoldenFile('goldens/17_service_client/liste_${variant.name}.png'),
      );

      await tester.tap(find.text('Colis non reçu'));
      await settle(tester);
      expect(find.text('Service client Tara'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Merci, j’attends.');
      await settle(tester);
      await tester.tap(iconButton('Envoyer'));
      await settle(tester);
      expect(support.replies.single, ('ticket-1001', 'Merci, j’attends.'));
      await expectLater(
        find.byType(SupportThreadScreen),
        matchesGoldenFile('goldens/17_service_client/echanges_${variant.name}.png'),
      );
    });
  }

  testWidgets('« Signaler un problème » depuis le suivi : la demande porte sur la commande', (tester) async {
    final support = FakeSupportBackend();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [supportBackendProvider.overrideWithValue(support)],
        child: tracking.screen(tracking.apiAt('IN_DELIVERY'), FakeRealtime()),
      ),
    );
    await settle(tester);
    final link = find.text('Signaler un problème');
    await tester.ensureVisible(link);
    await settle(tester);
    await tester.tap(link);
    await settle(tester);
    expect(find.text('Commande TR-48301'), findsOneWidget);
    await fillRequest(tester, reason: 'Colis abîmé');
    await tester.tap(find.text('Envoyer la demande'));
    await settle(tester);
    expect(support.opened.single.orderId, tracking.orderId);
    expect(support.opened.single.category, SupportCategory.damagedParcel);
    expect(find.text('Service client Tara'), findsNothing);
    expect(find.textContaining('SUP-1001'), findsOneWidget);
  });
}
