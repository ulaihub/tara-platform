import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/home/home_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/tara_icons.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';

/// Mercredi 4 novembre 2026, 10:20 (heure du téléphone).
final homeNow = DateTime(2026, 11, 4, 10, 20);

const shopOwner = Me(
  id: '00000000-0000-4000-8000-0000000000aa',
  phone: '+237677123456',
  fullName: 'Awa Ngono',
  locale: 'FR',
  referralCode: 'TARA-7KQ2PM',
  merchant: Merchant(shopName: 'Awa Fashion', category: 'FASHION', payoutPhone: '+237677123456', payoutOperator: 'MTN'),
);

const person = Me(
  id: '00000000-0000-4000-8000-0000000000ab',
  phone: '+237699112233',
  fullName: 'Paul Ekwalla',
  locale: 'FR',
  referralCode: 'TARA-Q4M7XZ',
  merchant: null,
);

OrderSummary summary(
  String id,
  String status,
  String name,
  String? neighborhood, {
  DateTime? scheduledFor,
  String? failureDecision,
  int? batchNumber,
}) => OrderSummary(
  id: '00000000-0000-4000-8000-00000000000$id',
  reference: 'TR-4821$id',
  status: status,
  recipientName: name,
  dropoffLandmark: 'Face pharmacie du Rond-point',
  dropoffNeighborhood: neighborhood,
  totalPrice: 1500,
  codAmount: 12500,
  scheduledFor: scheduledFor?.toUtc(),
  createdAt: DateTime.utc(2026, 11, 4, 8),
  failureDecision: failureDecision,
  batchNumber: batchNumber,
);

FakeClientApi shopApi() => FakeClientApi()
  ..wallet0 = const Wallet(
    customerBalance: 0,
    merchantBalance: 128500,
    payoutSchedule: 'DAILY',
    todaySales: 37500,
    todayDeliveries: 3,
  )
  ..active = [
    summary('1', 'IN_DELIVERY', 'Marie Ngo', 'Bonapriso'),
    // Colis n° 2 d'un envoi de plusieurs colis : le numéro est rappelé.
    summary('2', 'ASSIGNED', 'Jean Mbarga', 'Akwa', batchNumber: 2),
    summary('3', 'DELIVERY_FAILED', 'Chantal Eyike', 'Bépanda'),
    summary('4', 'CREATED', 'Samuel Etoa', 'Deïdo', scheduledFor: DateTime(2026, 11, 5, 9, 30)),
  ];

Widget home(Me me, FakeClientApi api) => ProviderScope(
  overrides: [keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()), clientApiProvider.overrideWithValue(api)],
  child: tabs(
    0,
    HomeScreen(
      me: me,
      onNewOrder: () {},
      onLocationLink: () {},
      onBulk: () {},
      onOpenOrder: (_) {},
      onWallet: () {},
      onReceipts: () {},
      onSeeAll: () {},
      now: () => homeNow,
    ),
  ),
);

/// Écran d'onglet dans son cadre : barre en verre au-dessus du contenu.
Widget tabs(int current, Widget child) => Builder(
  builder: (context) => TaraTabShell(
    items: const [
      TabItem(TaraIcons.home, 'Accueil'),
      TabItem(TaraIcons.package, 'Commandes'),
      TabItem(TaraIcons.wallet, 'Portefeuille'),
      TabItem(TaraIcons.user, 'Profil'),
    ],
    action: TabAction(icon: TaraIcons.plus, label: 'Nouvelle livraison', onPressed: () {}),
    current: current,
    onSelected: (_) {},
    child: child,
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('04 accueil boutique ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, home(shopOwner, shopApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Awa Fashion'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/04_accueil_boutique/${variant.name}.png'));
    });

    goldenTest('04 accueil particulier ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, home(person, FakeClientApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/04_accueil_particulier/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('04 accueil boutique complet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        home(shopOwner, shopApi()),
        surface: const Size(390, 1180),
      );
      await settle(tester);
      expect(find.text('Prévue demain à 09:30 · TR-48214'), findsOneWidget);
      expect(find.text('37 500 F'), findsOneWidget);
      expect(find.text('Encaissé aujourd’hui · 3 livraisons'), findsOneWidget);
      expect(find.text('128 500 F reversés'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/04_accueil_boutique/complet_${brightness.name}.png'));
    });
  }

  testWidgets('échec : « à décider », puis la décision prise', (tester) async {
    final api = shopApi();
    await pumpVariant(tester, Variant.matrix.first, home(shopOwner, api), surface: const Size(390, 1180));
    await settle(tester);
    expect(find.text('Livraison impossible · à décider · TR-48213'), findsOneWidget);

    api.active = [summary('3', 'DELIVERY_FAILED', 'Chantal Eyike', 'Bépanda', failureDecision: 'RETURN')];
    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.first, home(shopOwner, api), surface: const Size(390, 1180));
    await settle(tester);
    expect(find.text('Retour en cours · TR-48213'), findsOneWidget);
  });
}
