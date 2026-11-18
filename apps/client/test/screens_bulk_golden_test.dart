import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/bulk/bulk_screen.dart';
import 'package:tara_client/features/bulk/bulk_send_screen.dart';
import 'package:tara_client/features/bulk/contacts_screen.dart';
import 'package:tara_client/features/bulk/paste_screen.dart';
import 'package:tara_client/features/bulk/phone_contacts.dart';
import 'package:tara_client/features/orders/orders_screen.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/swipe_button.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopOwner;
import 'screens_new_order_golden_test.dart' show orderApi, overrides;

/// La liste des maquettes, telle qu'une boutique la colle depuis WhatsApp.
const pastedList = '''
Marie 690112233 Bonapriso pharmacie 12500
Jean Mbarga 677445566 Deido immeuble bleu
Chantal 6 99 88 77 66 Bepanda
Samuel Etoa 655443322 Akwa boulangerie 8000
Brice 69912 Makepe
Awa 690 55 44 33 Bali carrefour 15000''';

/// Contacts du téléphone, accès accordé ou non.
class FakePhoneContacts implements PhoneContacts {
  FakePhoneContacts({this.granted = true});

  final bool granted;
  var asked = false;

  @override
  Future<bool> request() async {
    asked = true;
    return granted;
  }

  @override
  Future<List<PhoneContact>> mobiles() async => const [
    PhoneContact('Brice Nana', '699123456'),
    PhoneContact('Grace Fouda', '691223344'),
    PhoneContact('Rose Ekambi', '696554433'),
  ];

  @override
  Future<void> openSettings() async {}
}

Widget bulk(FakeClientApi api, {MemoryKeyValueStore? store, PhoneContacts? contacts, VoidCallback? onClose}) =>
    ProviderScope(
      overrides: [
        ...overrides(api, store: store),
        phoneContactsProvider.overrideWithValue(contacts ?? FakePhoneContacts()),
      ],
      child: BulkScreen(me: shopOwner, onClose: onClose ?? () {}, now: () => homeNow),
    );

/// Touche un texte, après l'avoir fait défiler à l'écran.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await settle(tester);
  await tester.tap(finder.first);
  await settle(tester);
}

/// Coller la liste des maquettes et l'ajouter.
Future<void> pasteList(WidgetTester tester, {bool add = true}) async {
  await tester.tap(find.text('Coller'));
  await settle(tester);
  await tester.enterText(find.byType(TextField), pastedList);
  await settle(tester);
  if (!add) return;
  FocusManager.instance.primaryFocus?.unfocus();
  await tapOn(tester, find.text('Ajouter 6 clients'));
}

void main() {
  setUpAll(loadAppFonts);

  const regular = [Variant(Brightness.dark, ScreenSize.regular, 1), Variant(Brightness.light, ScreenSize.regular, 1)];

  for (final variant in regular) {
    final theme = variant.brightness.name;

    goldenTest('07 liste vide $theme', (tester) async {
      await pumpVariant(tester, variant, bulk(orderApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Ajoutez vos clients du jour'), findsOneWidget);
      // Boutique choisie d'office comme départ.
      expect(find.text('Boutique'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_liste_envoi/vide_$theme.png'));
    });

    goldenTest('07 coller une liste $theme', (tester) async {
      await pumpVariant(tester, variant, bulk(orderApi()), surface: const Size(390, 1100));
      await settle(tester);
      await pasteList(tester, add: false);
      expect(tester.takeException(), isNull);
      expect(find.text('5 sur 6'), findsOneWidget);
      expect(find.textContaining('numéro incomplet (69912)'), findsOneWidget);
      // Marie et Jean sont des clients connus : leur adresse est reprise.
      expect(find.textContaining('· adresse connue'), findsNWidgets(2));
      await expectLater(find.byType(PasteScreen), matchesGoldenFile('goldens/07_coller/$theme.png'));
    });

    goldenTest('07 choisir des clients $theme', (tester) async {
      final contacts = FakePhoneContacts();
      await pumpVariant(tester, variant, bulk(orderApi(), contacts: contacts), surface: const Size(390, 1000));
      await settle(tester);
      await tester.tap(find.text('Contacts'));
      await settle(tester);
      // Rien n'est lu avant que l'expéditeur le demande.
      expect(contacts.asked, isFalse);
      await tapOn(tester, find.text('Voir mes contacts'));
      await tapOn(tester, find.textContaining('Marie Ngo'));
      await tapOn(tester, find.textContaining('Grace Fouda'));
      expect(tester.takeException(), isNull);
      expect(find.text('Ajouter 2 clients'), findsOneWidget);
      await expectLater(find.byType(ContactsScreen), matchesGoldenFile('goldens/07_contacts/$theme.png'));
    });

    goldenTest('07 vérifier, envoyer, colis numérotés $theme', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, variant, bulk(api), surface: const Size(390, 1400));
      await settle(tester);
      await pasteList(tester);
      await tapOn(tester, find.text('Vérifier et envoyer · 5 colis'));
      expect(tester.takeException(), isNull);
      expect(find.text('2 colis prêts : ils partent tout de suite.'), findsOneWidget);
      expect(
        find.text('3 clients n’ont pas encore placé leur point : leurs colis partiront dès qu’ils le feront.'),
        findsOneWidget,
      );
      expect(find.text('1 client à compléter : il reste dans la liste et ne part pas.'), findsOneWidget);
      // Ventes de la boutique (128 500 F) : elles paient d'office.
      expect(find.text('Pris sur vos ventes : il vous restera 126\u00a0100\u00a0F à recevoir.'), findsOneWidget);
      await expectLater(find.byType(BulkSendScreen), matchesGoldenFile('goldens/07_envoi/$theme.png'));

      await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Envoi parti !'), findsOneWidget);
      expect(find.text('Attend son point'), findsNWidgets(3));
      await expectLater(find.byType(BulkSendScreen), matchesGoldenFile('goldens/07_envoi_parti/$theme.png'));

      final body = api.created.single.body;
      expect(body['feePaymentMethod'], 'WALLET');
      final items = (body['items']! as List).cast<Map<String, Object?>>();
      expect([for (final i in items) i['recipientName']], ['Marie', 'Jean Mbarga', 'Chantal', 'Samuel Etoa', 'Awa']);
      expect([for (final i in items) i['askAddress'] == true], [false, false, true, true, true]);
      expect([for (final i in items) i['codAmount']], [12500, 0, 0, 8000, 15000]);
    });
  }

  for (final variant in Variant.matrix) {
    goldenTest('07 liste d’envoi ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, bulk(orderApi()));
      await settle(tester);
      await pasteList(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('6 clients'), findsOneWidget);
      expect(find.text('Vérifier et envoyer · 5 colis'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_liste_envoi/${variant.name}.png'));
    });
  }

  testWidgets('un client à compléter se corrige, la liste reste sur le téléphone', (tester) async {
    final store = MemoryKeyValueStore();
    await pumpVariant(tester, Variant.matrix.last, bulk(orderApi(), store: store), surface: const Size(390, 1200));
    await settle(tester);
    await pasteList(tester);
    await tapOn(tester, find.textContaining('numéro incomplet (69912)'));
    expect(find.text('Client n° 5'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '699123456');
    await tapOn(tester, find.text('Enregistrer'));
    expect(find.text('Vérifier et envoyer · 6 colis'), findsOneWidget);
    // La liste est gardée (chiffrée) sur le téléphone : rien ne se perd si l'app se ferme.
    await tester.pump(const Duration(seconds: 1));
    final saved = jsonDecode(store.values['bulk_draft:${shopOwner.id}']!) as Map<String, Object?>;
    expect((saved['lines']! as List).length, 6);

    await tester.pumpWidget(const SizedBox());
    await pumpVariant(tester, Variant.matrix.last, bulk(orderApi(), store: store), surface: const Size(390, 1200));
    await settle(tester);
    expect(find.text('6 clients'), findsOneWidget);
    expect(find.textContaining('Brice'), findsOneWidget);
    expect(find.textContaining('numéro incomplet'), findsNothing);
  });

  testWidgets('un prix impossible bloque l’envoi et dit quel client corriger', (tester) async {
    final api = orderApi()..unpricedAddressId = orderApi().recents.first.lastAddress.id;
    await pumpVariant(tester, Variant.matrix.last, bulk(api), surface: const Size(390, 1400));
    await settle(tester);
    await pasteList(tester);
    await tapOn(tester, find.text('Vérifier et envoyer · 5 colis'));
    expect(find.textContaining('Client n° 1 (Marie) : Cette adresse est hors de la zone desservie.'), findsOneWidget);
    await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
    await settle(tester);
    expect(api.created, isEmpty);
  });

  testWidgets('les contacts refusés : l’app explique comment les autoriser', (tester) async {
    await pumpVariant(tester, Variant.matrix.last, bulk(orderApi(), contacts: FakePhoneContacts(granted: false)));
    await settle(tester);
    await tapOn(tester, find.text('Contacts'));
    await tapOn(tester, find.text('Voir mes contacts'));
    expect(find.text('Ouvrir les réglages'), findsOneWidget);
  });

  testWidgets('les quartiers de Tara rectifient l’écriture de la liste', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.last,
      ProviderScope(
        overrides: overrides(orderApi()),
        child: const PasteScreen(room: 100, known: {}, initialText: 'Paul 690112233 deido immeuble bleu'),
      ),
    );
    await settle(tester);
    expect(find.textContaining('Deïdo'), findsOneWidget);
  });

  for (final variant in regular) {
    goldenTest('07 colis en attente dans Commandes ${variant.brightness.name}', (tester) async {
      final opened = <String>[];
      PendingDelivery pending(String id, int number, String name, String status, {String? reason}) => PendingDelivery(
        id: '00000000-0000-4000-8000-00000000070$id',
        batchId: '00000000-0000-4000-8000-000000000600',
        batchNumber: number,
        recipientName: name,
        recipientPhone: '+237690554433',
        status: status,
        blockedReason: reason,
        linkUrl: 'https://tara.test/l/lien$id',
        linkExpiresAt: DateTime(2026, 11, 7, 10),
        orderId: null,
        codAmount: 0,
      );
      final api = orderApi()
        ..pendingList = [
          pending('1', 3, 'Chantal', 'WAITING'),
          pending('2', 5, 'Awa', 'BLOCKED', reason: 'INSUFFICIENT_BALANCE'),
          pending('3', 4, 'Samuel Etoa', 'EXPIRED'),
        ];
      await pumpVariant(
        tester,
        variant,
        ProviderScope(
          overrides: overrides(api),
          child: OrdersScreen(onOpenOrder: (_) {}, onOpenOrderId: opened.add, now: () => homeNow),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('En attente de l’adresse'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_commandes_en_attente/${variant.brightness.name}.png'));

      // Départ bloqué : payer par Mobile Money crée la commande et l'ouvre sur son paiement.
      await tapOn(tester, find.text('Awa'));
      await tapOn(tester, find.text('Payer par Mobile Money · MTN Mobile Money'));
      expect(api.pendingActions, ['release:00000000-0000-4000-8000-000000000702:MOMO_MTN']);
      expect(opened, ['00000000-0000-4000-8000-000000000777']);

      // Lien expiré : un nouveau lien part.
      await tapOn(tester, find.text('Samuel Etoa'));
      await tapOn(tester, find.text('Renvoyer le lien'));
      expect(api.pendingActions.last, 'resend:00000000-0000-4000-8000-000000000703');
    });
  }
}
