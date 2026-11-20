import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/features/activity/deposit_screen.dart';
import 'package:tara_rider/features/activity/withdraw_screen.dart';
import 'package:tara_test/fake_pin.dart';
import 'package:tara_ui/components/buttons.dart';

import 'helpers/harness.dart';
import 'screens_activity_golden_test.dart' show activity, activityApi;
import 'screens_auth_golden_test.dart' show settle;

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await Scrollable.ensureVisible(tester.element(find.text(text).last), alignment: .3);
    await tester.pump();
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  testWidgets('semaine en colonnes : aujourd’hui allumé, jour touché détaillé, jours à venir', (tester) async {
    final api = activityApi();
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(api.periods.first, 'week');
    expect(find.text('25\u00a0800\u00a0F'), findsOneWidget);
    expect(find.text('17 courses'), findsWidgets);
    // Mercredi 4 en cours : son détail est affiché sous les colonnes.
    expect(find.text('Mercredi 4 nov. · aujourd’hui'), findsOneWidget);
    expect(find.bySemanticsLabel('Mer : Mercredi 4 nov. · aujourd’hui : 6\u00a0750\u00a0F · 4 courses'), findsOneWidget);

    await tester.tap(find.text('Mar'));
    await settle(tester);
    expect(find.text('Mardi 3 nov.'), findsOneWidget);
    expect(find.text('11\u00a0250\u00a0F · 8 courses', findRichText: true), findsOneWidget);

    // Vendredi n'est pas encore roulé.
    await tester.tap(find.text('Ven'));
    await settle(tester);
    expect(find.text('à venir'), findsOneWidget);
    expect(find.bySemanticsLabel('Ven : Vendredi 6 nov. : pas encore roulé'), findsOneWidget);
  });

  testWidgets('solde prépayé : disponible et argent mis de côté, pas d’espèces à reverser', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi(), shown: true));
    await settle(tester);
    expect(find.text('Solde disponible'), findsOneWidget);
    expect(find.text('29\u00a0500 F', findRichText: true), findsOneWidget);
    expect(find.text('12\u00a0500\u00a0F mis de côté pour vos courses en cours'), findsOneWidget);
    expect(find.text('Espèces à reverser à Tara'), findsNothing);

    final idle = activityApi()
      ..wallet0 = const RiderWallet(earnings: 8000, available: 8000, cashHeld: 0, cashLimit: 50000);
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(idle, shown: true));
    await settle(tester);
    expect(find.text('Couvre l’argent à encaisser sur vos courses'), findsOneWidget);
  });

  testWidgets('recharger : montant au choix, demande Mobile Money, solde mis à jour', (tester) async {
    final api = activityApi()..paymentStatuses = ['PENDING', 'SUCCEEDED'];
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true));
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

  testWidgets('recharger : la règle de retrait est dite avant de payer', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 8000,
        available: 8000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalMinimum: 30000,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true), surface: const Size(390, 1200));
    await settle(tester);
    await tapText(tester, 'Recharger');
    expect(
      find.text(
        'Ce solde couvre l’argent à encaisser de vos courses. Il se retire vers Mobile Money à partir de 30\u00a0000\u00a0F.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
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

  testWidgets('frais de retrait : seule la part du livreur est annoncée', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalFeeBps: 250,
        withdrawalFeeSharePercent: 50,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(
      find.text('Retrait gratuit dès 20\u00a0000\u00a0F ; en dessous, 1,25\u00a0% de frais Mobile Money retenus.'),
      findsOneWidget,
    );
  });

  testWidgets('retirer : tout le disponible, frais partagés et montant reçu avant de confirmer', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalFeeBps: 250,
        withdrawalFeeSharePercent: 50,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    expect(find.text('Retirer vers Mobile Money'), findsOneWidget);
    // 440 F de frais Mobile Money sur 18 000 F : seule la part du livreur (220 F) est annoncée.
    expect(find.text('Frais Mobile Money : 220\u00a0F.'), findsOneWidget);
    expect(find.textContaining('Tara'), findsNothing);
    expect(find.text('Retrait gratuit dès 20\u00a0000\u00a0F.'), findsOneWidget);
    expect(
      find.text('Envoyé sur votre numéro +237\u00a06\u00a077\u00a012\u00a034\u00a056, le seul permis pour un retrait.'),
      findsOneWidget,
    );

    await tapText(tester, 'Recevoir 17\u00a0780\u00a0F');
    // Confirmé par le code secret, comme un retrait MoMo.
    expect(find.text('Pour retirer 18\u00a0000\u00a0F'), findsOneWidget);
    await enterPin(tester, '2580');
    // Tout le disponible : le montant est laissé au serveur ; MTN deviné d'après le 677.
    expect(api.withdrawProofs.single?.pin, '2580');
    expect(api.withdrawals.single.$1, isNull);
    expect(api.withdrawals.single.$2, '+237677123456');
    expect(api.withdrawals.single.$3, 'MTN');
    expect(
      find.text(
        'Retrait demandé : 17\u00a0780\u00a0F arrivent sur votre Mobile Money dans quelques minutes. Une notification vous préviendra.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Fermer');
    expect(find.byType(WithdrawScreen), findsNothing);
  });

  testWidgets('retirer : sous le minimum du prestataire, rien ne part et il manque tant', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 50000,
        withdrawalMinimum: 30000,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    expect(
      find.text(
        'Le retrait vers Mobile Money est possible à partir de 30\u00a0000\u00a0F. Il vous manque encore '
        '12\u00a0000\u00a0F : votre solde reste en sécurité chez Tara en attendant.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    expect(api.withdrawals, isEmpty);

    // Au-dessus du minimum : un montant partiel plus petit est refusé, tout le solde part.
    final enough = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 45000,
        available: 45000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalMinimum: 30000,
      );
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(enough, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    await tester.enterText(find.byType(EditableText).first, '20000');
    await settle(tester);
    await tapText(tester, 'Recevoir 0\u00a0F');
    expect(find.text('Entre 30\u00a0000\u00a0F et 45\u00a0000\u00a0F, ou tout le solde.'), findsOneWidget);
    expect(enough.withdrawals, isEmpty);
    await tester.enterText(find.byType(EditableText).first, '');
    await settle(tester);
    await tapText(tester, 'Recevoir 45\u00a0000\u00a0F');
    await enterPin(tester, '2580');
    expect(enough.withdrawals.single.$1, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('retirer : un montant partiel sous 500 F refusé, un petit solde retiré en entier', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalFeeBps: 250,
        withdrawalFeeSharePercent: 50,
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    await tester.enterText(find.byType(EditableText).first, '200');
    await settle(tester);
    await tapText(tester, 'Recevoir 0\u00a0F');
    expect(find.text('Entre 500\u00a0F et 18\u00a0000\u00a0F, ou tout le solde.'), findsOneWidget);
    expect(api.withdrawals, isEmpty);

    // Un autre montant : envoyé tel quel.
    await tester.enterText(find.byType(EditableText).first, '5000');
    await settle(tester);
    await tapText(tester, 'Recevoir 4\u00a0939\u00a0F');
    await enterPin(tester, '2580');
    expect(api.withdrawals.single.$1, 5000);

    // Petit solde (300 F, sous le minimum) : retiré en entier.
    final small = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 300,
        available: 300,
        cashHeld: 0,
        cashLimit: 25000,
        withdrawalFreeFrom: 20000,
        withdrawalFeeBps: 250,
        withdrawalFeeSharePercent: 50,
      );
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, activity(small, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    await tapText(tester, 'Recevoir 296\u00a0F');
    await enterPin(tester, '2580');
    expect(small.withdrawals.single.$1, isNull);
  });

  testWidgets('retrait en cours : mentionné, pas de second retrait', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(
        earnings: 18000,
        available: 18000,
        cashHeld: 0,
        cashLimit: 25000,
        openPayout: OpenPayout(id: 'pay0', amount: 5000, status: 'PROCESSING'),
      );
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(find.text('Retrait de 5\u00a0000\u00a0F en cours'), findsOneWidget);
    expect(find.text('Retirer'), findsNothing);
  });

  testWidgets('dernières courses : trois, puis toutes ; statut, encaissement et gain', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, activity(activityApi()));
    await settle(tester);
    // Les dernières courses sont sous la semaine et le solde : l'écran défile jusqu'à elles.
    await tester.scrollUntilVisible(find.text('Dernières courses'), 200);
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

  testWidgets('solde masqué : affiché avec le code secret, une erreur compte un essai', (tester) async {
    final api = activityApi();
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    expect(find.text('29\u00a0500 F', findRichText: true), findsNothing);
    expect(find.text('••••• F', findRichText: true), findsOneWidget);

    await Scrollable.ensureVisible(tester.element(find.text('••••• F', findRichText: true)), alignment: .3);
    await tester.pump();
    await tester.tap(find.text('••••• F', findRichText: true));
    await settle(tester);
    expect(find.text('Pour voir votre solde'), findsOneWidget);
    await enterPin(tester, '1111');
    expect(find.text('Code secret incorrect. Encore 4 essai(s) avant blocage.'), findsOneWidget);
    await enterPin(tester, '2580');
    await settle(tester);
    expect(find.text('29\u00a0500 F', findRichText: true), findsOneWidget);
    expect(api.pins!.accepted.single.pin, '2580');
  });

  testWidgets('retirer avec le solde masqué : un seul code secret, qui confirme aussi le retrait', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(earnings: 18000, available: 18000, cashHeld: 0, cashLimit: 25000);
    await pumpVariant(tester, Variant.matrix.first, activity(api));
    await settle(tester);
    await tapText(tester, 'Retirer');
    expect(find.text('Pour voir votre solde'), findsOneWidget);
    await enterPin(tester, '2580');
    await settle(tester);
    expect(find.text('Retirer vers Mobile Money'), findsOneWidget);
    await tapText(tester, 'Recevoir 18\u00a0000\u00a0F');
    // Pas de second code : celui donné pour voir le solde confirme le retrait.
    expect(find.text('Code secret'), findsNothing);
    expect(api.withdrawProofs.single?.pin, '2580');
  });

  testWidgets('premier retrait : le code secret se choisit deux fois, les codes trop simples refusés', (tester) async {
    final api = activityApi()
      ..wallet0 = const RiderWallet(earnings: 18000, available: 18000, cashHeld: 0, cashLimit: 25000)
      ..pins = FakePinApi(isSet: false);
    await pumpVariant(tester, Variant.matrix.first, activity(api, shown: true));
    await settle(tester);
    await tapText(tester, 'Retirer');
    await tapText(tester, 'Recevoir 18\u00a0000\u00a0F');
    expect(find.text('Choisissez votre code secret'), findsOneWidget);
    await enterPin(tester, '4826');
    expect(find.text('Confirmez votre code secret'), findsOneWidget);
    await enterPin(tester, '4820');
    expect(find.text('Les deux codes sont différents. Recommencez.'), findsOneWidget);
    await enterPin(tester, '4826');
    await enterPin(tester, '4826');
    await settle(tester);
    expect(api.pins!.sets.single.$1, '4826');
    expect(api.withdrawals, hasLength(1));
  });
}
