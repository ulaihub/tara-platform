import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('espèces : heure limite de dépôt, puis retard', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi()));
    await settle(tester);
    expect(find.text('À déposer avant demain 09:40'), findsOneWidget);

    final late = activityApi()
      ..wallet0 = const RiderWallet(earnings: 0, cashHeld: 37500, cashLimit: 25000, cashOverdue: true);
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(late));
    await settle(tester);
    expect(find.text('En retard\u00a0: plus de courses jusqu’au dépôt.'), findsOneWidget);
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
    final api = activityApi()..paymentStatuses = ['PENDING', 'SUCCEEDED'];
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
