import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/core/api/client_models.dart';

import 'helpers/harness.dart';
import 'wallet_screen_test.dart' show wallet, walletApi;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('boutique : son solde Tara se recharge et paie ses livraisons avant ses ventes', (tester) async {
    // Le cas signalé : boutique dont le solde Tara restait à 0 après une recharge.
    final api = walletApi()
      ..wallet0 = const Wallet(
        customerBalance: 1100,
        merchantBalance: 0,
        payoutSchedule: 'DAILY',
        plan: 'FREE',
        payoutPhone: '+237659038812',
      );
    await pumpVariant(tester, Variant.matrix.first, wallet(api), surface: const Size(390, 1200));
    await settle(tester);
    expect(find.text('Solde Tara'), findsWidgets);
    expect(find.text('Recharger'), findsOneWidget);
    expect(
      find.text(
        'Paie vos livraisons et frais avant vos ventes. Jamais reversé tout seul : retirez-le quand vous voulez.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vos livraisons se paient d’abord avec votre solde Tara, puis avec vos ventes.'), findsOneWidget);
    expect(find.text('Pas de réserve : toutes vos ventes vous sont reversées.'), findsOneWidget);
  });

  testWidgets('boutique : la réserve du soir se règle en un geste', (tester) async {
    final api = walletApi();
    await pumpVariant(tester, Variant.matrix.first, wallet(api), surface: const Size(390, 1200));
    await settle(tester);
    await tester.tap(find.text('Modifier'));
    await settle(tester);
    expect(find.text('Réserve pour vos livraisons'), findsOneWidget);
    await tester.tap(find.text('10\u00a0000'));
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(api.reserves, [10000]);
    expect(find.textContaining('Réserve gardée chaque soir : 10'), findsOneWidget);
  });
}
