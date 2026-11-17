import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/core/api/client_models.dart';

import 'helpers/harness.dart';
import 'wallet_screen_test.dart' show wallet, walletApi;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('boutique : un seul solde, ses ventes, sans recharge qui repartirait le soir', (tester) async {
    // Le cas signalé : boutique sans ancien solde Tara.
    final api = walletApi()
      ..wallet0 = const Wallet(
        customerBalance: 0,
        merchantBalance: 1100,
        payoutSchedule: 'DAILY',
        todaySales: 0,
        todayDeliveries: 0,
        plan: 'FREE',
        payoutPhone: '+237659038812',
      );
    await pumpVariant(tester, Variant.matrix.first, wallet(api));
    await settle(tester);
    expect(find.text('Ventes à recevoir'), findsOneWidget);
    expect(
      find.text('Vos ventes paient aussi vos livraisons : choisissez « Mes ventes » au moment de payer.'),
      findsOneWidget,
    );
    // Ni « Solde Tara » à 0 ni « Recharger » : rien ne prête à confusion.
    expect(find.text('Solde Tara'), findsNothing);
    expect(find.text('Recharger'), findsNothing);
  });

  testWidgets('boutique avec un ancien solde Tara : à retirer, pas à recharger', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, wallet(walletApi()));
    await settle(tester);
    expect(find.text('Solde Tara'), findsWidgets);
    expect(
      find.text('Ancien solde, d’avant votre boutique : vous pouvez le retirer sur votre Mobile Money.'),
      findsOneWidget,
    );
    expect(find.text('Recharger'), findsNothing);
    expect(find.text('Retirer'), findsOneWidget);
  });
}
