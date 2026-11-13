import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/activity/deposit_screen.dart';

import 'helpers/harness.dart';
import 'screens_activity_golden_test.dart' show activity, activityApi;
import 'screens_auth_golden_test.dart' show settle;

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  testWidgets('jour, semaine, mois : gains de la période et barre en cours', (tester) async {
    final api = activityApi();
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(find.text('5 courses'), findsNothing);
    expect(find.text('4 courses'), findsOneWidget);
    // Tranche de 14 h à 16 h en cours : sa valeur s'affiche au-dessus.
    expect(find.text('3 000'), findsOneWidget);

    await tapText(tester, 'Semaine');
    await tapText(tester, 'Mois');
    expect(api.periods, ['day', 'week', 'month']);
    expect(find.text('Gains du mois'), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
  });

  testWidgets('solde prépayé : disponible et argent mis de côté, pas d’espèces à reverser', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi()));
    await settle(tester);
    expect(find.text('Solde disponible'), findsOneWidget);
    expect(find.text('29\u00a0500\u00a0F'), findsOneWidget);
    expect(find.text('12\u00a0500\u00a0F mis de côté pour vos courses en cours'), findsOneWidget);
    expect(find.text('Espèces à reverser à Tara'), findsNothing);

    final idle = activityApi()
      ..wallet0 = const RiderWallet(earnings: 8000, available: 8000, cashHeld: 0, cashLimit: 50000);
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(idle));
    await settle(tester);
    expect(find.text('Couvre l’argent à encaisser sur vos courses'), findsOneWidget);
  });

  testWidgets('recharger : montant au choix, demande Mobile Money, solde mis à jour', (tester) async {
    final api = activityApi()..paymentStatuses = ['PENDING', 'SUCCEEDED'];
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    await tapText(tester, 'Recharger');
    expect(find.text('Recharger mon solde'), findsOneWidget);

    await tapText(tester, '25\u00a0000\u00a0F');
    await tapText(tester, 'Envoyer la demande');
    // Numéro du livreur repris, MTN deviné d'après le 677.
    expect(api.topUps.single.$1, 25000);
    expect(api.topUps.single.$2, '+237677123456');
    expect(api.topUps.single.$3, 'MTN');
    expect(find.text('Validez la demande sur votre téléphone…'), findsOneWidget);

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('25\u00a0000\u00a0F ajoutés à votre solde.'), findsOneWidget);
    // 29 500 disponibles + 25 000 rechargés.
    expect(find.text('54\u00a0500 FCFA', findRichText: true), findsOneWidget);
    await tapText(tester, 'Fermer');
    expect(find.byType(DepositScreen), findsNothing);
  });

  testWidgets('recharger : autre montant, bornes, même demande renvoyée sans doublon', (tester) async {
    const offline = ApiException(code: ApiException.network, message: '');
    final api = activityApi()..topUpErrors.addAll([offline, offline]);
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    await tapText(tester, 'Recharger');

    await tester.enterText(find.byType(EditableText).first, '300');
    await settle(tester);
    await tapText(tester, 'Envoyer la demande');
    expect(find.text('Montant entre 500\u00a0F et 500\u00a0000\u00a0F.'), findsOneWidget);
    expect(api.topUps, isEmpty);

    // Réseau coupé : la même demande renvoyée garde sa clé ; un autre montant en prend une autre.
    await tester.enterText(find.byType(EditableText).first, '15000');
    await settle(tester);
    await tapText(tester, 'Envoyer la demande');
    await tapText(tester, 'Envoyer la demande');
    await tester.enterText(find.byType(EditableText).first, '20000');
    await settle(tester);
    await tapText(tester, 'Envoyer la demande');
    expect([for (final t in api.topUps) t.$1], [15000, 15000, 20000]);
    expect(api.topUps[0].$4, api.topUps[1].$4);
    expect(api.topUps[2].$4, isNot(api.topUps[1].$4));
  });

  testWidgets('anciennes espèces : heure limite de dépôt, puis retard', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi(legacyCash: true)));
    await settle(tester);
    expect(find.text('À déposer avant demain 09:40'), findsOneWidget);

    final late = activityApi()
      ..wallet0 = const RiderWallet(earnings: 0, available: 0, cashHeld: 37500, cashLimit: 25000, cashOverdue: true);
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(late));
    await settle(tester);
    expect(find.text('En retard\u00a0: plus de courses jusqu’au dépôt.'), findsOneWidget);
  });

  testWidgets('solde : retrait gratuit à partir du seuil, frais Mobile Money en dessous', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalFeeBps: 250,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(
      find.text('Retrait gratuit dès 20\u00a0000\u00a0F ; en dessous, 2,5\u00a0% de frais Mobile Money retenus.'),
      findsOneWidget,
    );
  });

  testWidgets('dernières courses : trois, puis toutes ; statut, encaissement et gain', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi()));
    await settle(tester);
    expect(find.text('14:52 · Livrée · 12 500 F encaissés'), findsOneWidget);
    expect(find.text('13:20 · Livrée · Mobile Money'), findsOneWidget);
    expect(find.text('11:05 · Retour au vendeur'), findsOneWidget);
    expect(find.text('Akwa → Bépanda'), findsNothing);

    await tapText(tester, 'Tout voir');
    expect(find.text('03/11 · 18:40 · Annulée'), findsOneWidget);
  });

  testWidgets('reverser les espèces : demande Mobile Money, confirmation, retour à l’activité', (tester) async {
    final api = activityApi(legacyCash: true)..paymentStatuses = ['PENDING', 'SUCCEEDED'];
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    await tapText(tester, 'Reverser');
    expect(find.byType(DepositScreen), findsOneWidget);

    await tapText(tester, 'Envoyer la demande');
    // Numéro du livreur repris, MTN deviné d'après le 677 ; montant : toutes les espèces.
    expect(api.deposits.single.$1, 37500);
    expect(api.deposits.single.$2, '+237677123456');
    expect(api.deposits.single.$3, 'MTN');
    expect(find.text('Validez la demande sur votre téléphone…'), findsOneWidget);

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('37 500 F reversés à Tara.'), findsOneWidget);
    await tapText(tester, 'Fermer');
    expect(find.byType(DepositScreen), findsNothing);
  });
}
