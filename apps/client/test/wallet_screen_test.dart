import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/wallet/wallet_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_test/fake_pin.dart';
import 'package:tara_ui/components/pin_flow.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, person, shopOwner;
import 'screens_new_order_golden_test.dart' show storeWithMobileMoneyFee;

WalletLine line(String id, String kind, int amount, {String? reference, int minutes = 0}) => WalletLine(
  id: id,
  at: DateTime(2026, 11, 4, 10, 20).subtract(Duration(minutes: minutes)),
  kind: kind,
  description: 'Libellé serveur $kind',
  amount: amount,
  orderReference: reference,
);

/// Boutique d'Awa : 128 500 F à recevoir, offre Pro (reversement immédiat), solde Tara 3 500 F.
FakeClientApi walletApi({String plan = 'PRO', int shopBalance = 128500}) => FakeClientApi()
  ..wallet0 = Wallet(
    customerBalance: 3500,
    merchantBalance: shopBalance,
    payoutSchedule: 'DAILY',
    todaySales: 37500,
    todayDeliveries: 3,
    plan: plan,
    payoutPhone: '+237677123456',
  )
  ..lines['merchant'] = [
    line('1', 'COD_COLLECTED', 12250, reference: 'TR-48211'),
    line('2', 'COD_COLLECTED', 9800, reference: 'TR-48212', minutes: 35),
    line('3', 'FAILURE_FEE_CHARGED', -750, reference: 'TR-48213', minutes: 70),
    line('4', 'PAYOUT_REQUESTED', -86000, minutes: 960),
  ]
  ..lines['customer'] = [
    line('5', 'PAYMENT_RECEIVED', 5000, minutes: 120),
    line('6', 'ORDER_CHARGED', -1500, reference: 'TR-48214', minutes: 180),
  ]
  ..payoutList = [
    Payout(
      id: 'p1',
      beneficiary: 'MERCHANT',
      amount: 86000,
      status: 'SUCCEEDED',
      requestedAt: DateTime.utc(2026, 11, 3, 17),
      completedAt: DateTime.utc(2026, 11, 3, 17, 2),
    ),
  ];

/// Portefeuille ; [shown] : solde déjà affiché (code secret donné plus tôt), sinon masqué.
Widget wallet(
  FakeClientApi api, {
  Me me = shopOwner,
  List<(Uint8List, String)>? shared,
  MemoryKeyValueStore? store,
  bool shown = false,
}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
    clientApiProvider.overrideWithValue(api),
    shareFileProvider.overrideWithValue((bytes, name, mime, text) async => shared?.add((bytes, name))),
    pinApiProvider.overrideWithValue(api.pins ??= FakePinApi()),
    biometricsProvider.overrideWithValue(api.biometrics),
    smsCodeReaderProvider.overrideWithValue(api.sms),
    balanceVisibilityProvider.overrideWith((ref) {
      final visibility = BalanceVisibility();
      if (shown) visibility.show();
      ref.onDispose(visibility.dispose);
      return visibility;
    }),
  ],
  child: WalletScreen(me: me, onBack: () {}, now: () => homeNow),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('portefeuille boutique ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, wallet(walletApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/09_portefeuille/${variant.name}.png'));
    });
  }

  goldenTest('portefeuille : mouvements, reversements et relevés', (tester) async {
    const variant = Variant(Brightness.light, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, wallet(walletApi()));
    await settle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await settle(tester);
    await expectLater(capture, matchesGoldenFile('goldens/09_portefeuille/bas_${variant.name}.png'));
  });

  goldenTest('portefeuille d’un particulier : recharge en attente', (tester) async {
    const variant = Variant(Brightness.dark, ScreenSize.regular, 1);
    final api = walletApi()..paymentStatuses = ['PENDING'];
    await pumpVariant(tester, variant, wallet(api, me: person));
    await settle(tester);
    expect(find.text('Ventes à recevoir'), findsNothing);
    expect(find.text('Relevés mensuels'), findsNothing);
    await tester.tap(find.text('Recharger'));
    await settle(tester);
    await tester.tap(find.text('10\u00a0000'));
    await settle(tester);
    await tester.tap(find.text('Payer 10\u00a0000 F'));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(api.topUps, [(10000, '699112233', 'MTN')]);
    expect(find.textContaining('10\u00a0000 F'), findsWidgets);
    await expectLater(capture, matchesGoldenFile('goldens/09_portefeuille/recharge_${variant.name}.png'));
  });

  testWidgets('recharge validée : solde relu, son de pièce, message', (tester) async {
    final api = walletApi()..paymentStatuses = ['SUCCEEDED'];
    await pumpVariant(tester, Variant.matrix.first, wallet(api, me: person));
    await settle(tester);
    await tester.tap(find.text('Recharger'));
    await settle(tester);
    await tester.tap(find.text('Payer 5\u00a0000 F'));
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.text('Solde rechargé de 1\u00a0200 F.'), findsOneWidget);
    expect(sounds.played, isNotEmpty);
  });

  testWidgets('recharge par Mobile Money : frais annoncés et ajoutés au montant', (tester) async {
    final api = walletApi()..paymentStatuses = ['PENDING'];
    await pumpVariant(tester, Variant.matrix.first, wallet(api, me: person, store: storeWithMobileMoneyFee()));
    await settle(tester);
    await tester.tap(find.text('Recharger'));
    await settle(tester);
    // 5 000 F crédités, 320 F de frais Mobile Money (6 %) en plus.
    expect(find.text('+ 320\u00a0F de frais Mobile Money (frais de l’opérateur).'), findsOneWidget);
    await tester.tap(find.text('Payer 5\u00a0320\u00a0F'));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(api.topUps, [(5000, '699112233', 'MTN')]);
  });

  testWidgets('recharge : autre montant tapé, bornes vérifiées', (tester) async {
    final api = walletApi()..paymentStatuses = ['PENDING'];
    await pumpVariant(tester, Variant.matrix.first, wallet(api, me: person));
    await settle(tester);
    await tester.tap(find.text('Recharger'));
    await settle(tester);
    expect(find.text('Autre montant (F)'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '300');
    await settle(tester);
    await tester.tap(find.text('Payer 300\u00a0F'));
    await settle(tester);
    expect(find.text('Montant entre 500\u00a0F et 500\u00a0000\u00a0F.'), findsOneWidget);
    expect(api.topUps, isEmpty);

    await tester.enterText(find.byType(EditableText).first, '7500');
    await settle(tester);
    await tester.tap(find.text('Payer 7\u00a0500\u00a0F'));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(api.topUps, [(7500, '699112233', 'MTN')]);
  });

  testWidgets('boutique : retrait gratuit à partir du seuil, frais en dessous', (tester) async {
    final api = walletApi();
    api.wallet0 = const Wallet(
      customerBalance: 3500,
      merchantBalance: 128500,
      payoutSchedule: 'DAILY',
      todaySales: 37500,
      todayDeliveries: 3,
      plan: 'PRO',
      payoutPhone: '+237677123456',
      withdrawalFreeFrom: 50000,
      withdrawalFeeBps: 250,
    );
    await pumpVariant(tester, Variant.matrix.first, wallet(api));
    await settle(tester);
    expect(
      find.text(
        'Reversement et retrait gratuits dès 50\u00a0000\u00a0F ; en dessous, 2,5\u00a0% de frais Mobile Money retenus.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('boutique : seule sa part des frais est annoncée', (tester) async {
    final api = walletApi();
    api.wallet0 = const Wallet(
      customerBalance: 3500,
      merchantBalance: 128500,
      payoutSchedule: 'DAILY',
      plan: 'PRO',
      payoutPhone: '+237677123456',
      withdrawalFreeFrom: 50000,
      withdrawalFeeBps: 250,
      withdrawalFeeSharePercent: 50,
    );
    await pumpVariant(tester, Variant.matrix.first, wallet(api));
    await settle(tester);
    expect(
      find.text(
        'Reversement et retrait gratuits dès 50\u00a0000\u00a0F ; en dessous, 1,25\u00a0% de frais Mobile Money retenus.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offre gratuite : un petit solde de boutique se reverse en entier', (tester) async {
    final api = walletApi(plan: 'FREE', shopBalance: 300);
    await pumpVariant(tester, Variant.matrix.first, wallet(api, shown: true));
    await settle(tester);
    await tester.tap(find.text('Recevoir 300\u00a0F maintenant'));
    await settle(tester);
    // Confirmé par le code secret.
    await enterPin(tester, '2580');
    await settle(tester);
    expect(api.payoutsNow, 1);
    expect(api.proofs.single?.pin, '2580');
  });

  testWidgets('petit solde Tara : retiré en entier, même sous 500 F', (tester) async {
    final api = walletApi();
    api.wallet0 = const Wallet(customerBalance: 300, merchantBalance: null, payoutSchedule: null);
    await pumpVariant(tester, Variant.matrix.first, wallet(api, me: person));
    await settle(tester);
    await tester.tap(find.text('Retirer'));
    await settle(tester);
    // Solde masqué : le code secret l'affiche, puis confirme le retrait sans être redemandé.
    expect(find.text('Pour voir votre solde'), findsOneWidget);
    await enterPin(tester, '2580');
    await settle(tester);
    await tester.tap(find.text('Retirer 300\u00a0F'));
    await settle(tester);
    expect(find.text('Code secret'), findsNothing);
    expect(api.withdrawals, [('+237699112233', 'MTN')]);
    expect(api.proofs.single?.pin, '2580');
  });

  testWidgets('minimum de Mobile Money : les ventes attendent, le solde Tara ne se retire pas encore', (tester) async {
    final api = walletApi(plan: 'FREE', shopBalance: 1100);
    api.wallet0 = const Wallet(
      customerBalance: 3500,
      merchantBalance: 1100,
      payoutSchedule: 'DAILY',
      plan: 'FREE',
      payoutPhone: '+237677123456',
      withdrawalMinimum: 30000,
      customerWithdrawalMinimum: 30000,
    );
    await pumpVariant(tester, Variant.matrix.first, wallet(api, shown: true), surface: const Size(390, 1400));
    await settle(tester);
    // 1 100 F : rien n'échoue le soir, les ventes attendent d'atteindre 30 000 F.
    expect(find.textContaining('Mobile Money n’envoie pas moins de 30\u00a0000'), findsOneWidget);
    expect(find.textContaining('maintenant'), findsNothing);
    // Solde Tara de 3 500 F : pas de bouton Retirer, il sert aux livraisons.
    expect(find.text('Retirer'), findsNothing);
    expect(find.textContaining('Retrait vers Mobile Money possible à partir de 30\u00a0000'), findsOneWidget);
  });

  testWidgets('reversement immédiat avec l’offre Pro', (tester) async {
    final api = walletApi();
    await pumpVariant(tester, Variant.matrix.first, wallet(api, shown: true));
    await settle(tester);
    await tester.tap(find.text('Recevoir 128\u00a0500 F maintenant'));
    await settle(tester);
    await enterPin(tester, '2580');
    await settle(tester);
    expect(api.payoutsNow, 1);
    expect(find.text('Reversement demandé : l’argent arrive sur votre Mobile Money.'), findsOneWidget);
  });

  testWidgets('offre gratuite : reversement chaque jour, pas à la demande', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, wallet(walletApi(plan: 'FREE')));
    await settle(tester);
    expect(find.textContaining('maintenant'), findsNothing);
    expect(find.textContaining('Reversées chaque jour à 18 h sur le +237'), findsOneWidget);
  });

  testWidgets('frais d’échec dus : montant en rouge, règle expliquée', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, wallet(walletApi(shopBalance: -750)));
    await settle(tester);
    expect(find.textContaining('Frais d’échec à régler : 750 F.'), findsOneWidget);
    expect(find.textContaining('maintenant'), findsNothing);
  });

  testWidgets('retrait de tout le solde vers son propre numéro', (tester) async {
    final api = walletApi();
    await pumpVariant(tester, Variant.matrix.first, wallet(api, me: person));
    await settle(tester);
    expect(find.text('••••• F', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Retirer'));
    await settle(tester);
    await enterPin(tester, '2580');
    await settle(tester);
    expect(find.textContaining('Tout votre solde (3\u00a0500 F)'), findsOneWidget);
    await tester.tap(find.text('Orange Money'));
    await settle(tester);
    await tester.tap(find.text('Retirer 3\u00a0500 F'));
    await settle(tester);
    expect(api.withdrawals, [('+237699112233', 'ORANGE')]);
  });

  testWidgets('mouvements : boutique puis solde Tara, page suivante', (tester) async {
    final api = walletApi()..linesPage = 2;
    await pumpVariant(tester, Variant.matrix.first, wallet(api));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Voir plus'), 200, scrollable: find.byType(Scrollable).first);
    // Un cran de plus : le bouton ne reste pas collé au bas de l'écran.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await settle(tester);
    expect(find.text('TR-48212 · 4 nov., 09h45'), findsOneWidget);
    expect(find.text('Frais d’échec'), findsNothing);
    await tester.tap(find.text('Voir plus'));
    await settle(tester);
    expect(find.text('Frais d’échec'), findsOneWidget);
    expect(find.text('−750 F'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mouvements · Boutique'), -200, scrollable: find.byType(Scrollable).first);
    // La carte « Solde Tara », derrière, passe devant : ses mouvements remplacent ceux
    // de la boutique.
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Afficher la carte Solde Tara'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    // Seule la bande du haut de la carte de derrière dépasse : c'est elle qu'on touche.
    await tester.tapAt(tester.getTopLeft(find.bySemanticsLabel('Afficher la carte Solde Tara')) + const Offset(60, 14));
    await settle(tester);
    expect(find.bySemanticsLabel('Afficher la carte Ventes à recevoir'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mouvements · Solde Tara'), 200, scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('Livraison payée'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Livraison payée'), findsOneWidget);
    expect(find.text('Vente encaissée'), findsNothing);
  });

  testWidgets('relevé du mois : téléchargé puis partagé en PDF', (tester) async {
    final api = walletApi();
    final shared = <(Uint8List, String)>[];
    await pumpVariant(tester, Variant.matrix.first, wallet(api, shared: shared));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Octobre 2026'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settle(tester);
    expect(find.text('Novembre 2026 (en cours)'), findsOneWidget);
    await tester.tap(find.text('Octobre 2026'));
    await settle(tester);
    expect(api.statements, ['2026-10']);
    expect(shared.single.$2, 'releve-tara-2026-10.pdf');
  });
}
