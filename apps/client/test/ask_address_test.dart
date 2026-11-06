import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/features/home/ask_address_screen.dart';
import 'package:tara_client/features/order/new_order_flow.dart';
import 'package:tara_core/session/session_store.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopOwner;
import 'screens_new_order_golden_test.dart' show orderApi, overrides, toRecipient;

final received = pendingLink(
  'Marie Ngo',
  phone: '+237677889900',
  address: fakeAddress('7', 'Portail bleu après la pharmacie du carrefour', neighborhood: 'Bonapriso'),
);

FakeClientApi linksApi() => FakeClientApi()
  ..links = [
    received,
    pendingLink('Jean Mbarga', phone: '+237699112233'),
    pendingLink('Chantal Eyike', phone: '+237655778899', status: 'EXPIRED'),
  ];

Widget ask(FakeClientApi api, {List<Uri>? opened, ValueChanged<LocationLink>? onCreate, FakeRealtime? realtime}) =>
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        clientApiProvider.overrideWithValue(api),
        launcherProvider.overrideWithValue((uri) async {
          opened?.add(uri);
          return true;
        }),
        realtimeProvider.overrideWithValue(realtime ?? FakeRealtime()),
      ],
      child: AskAddressScreen(me: shopOwner, onBack: () {}, onCreateOrder: onCreate ?? (_) {}),
    );

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('demander l’adresse ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, ask(linksApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/10_demander_adresse/${variant.name}.png'));
    });
  }

  testWidgets('envoie le lien par WhatsApp avec le message prêt, puis le liste', (tester) async {
    final api = FakeClientApi();
    final opened = <Uri>[];
    await pumpVariant(tester, Variant.matrix.first, ask(api, opened: opened));
    await settle(tester);
    expect(find.text('Aucune adresse demandée pour l’instant.'), findsOneWidget);

    await tester.tap(find.text('Envoyer par WhatsApp'));
    await settle(tester);
    expect(find.text('Saisissez d’abord le nom et le numéro du destinataire.'), findsOneWidget);
    expect(api.createdLinks, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'Marie Ngo');
    await tester.enterText(find.byType(TextField).at(1), '677889900');
    api.links = [pendingLink('Marie Ngo', phone: '+237677889900')];
    await tester.tap(find.text('Envoyer par WhatsApp'));
    await settle(tester);
    expect(api.createdLinks, [
      {'recipientName': 'Marie Ngo', 'recipientPhone': '+237677889900'},
    ]);
    expect(opened.single.host, 'wa.me');
    expect(opened.single.path, '/237677889900');
    expect(opened.single.queryParameters['text'], contains('https://tara.cm/l/Q7mK2pXa9RtL4vNe'));
    expect(opened.single.queryParameters['text'], startsWith('Bonjour Marie, Awa Fashion vous envoie un colis'));
    expect(find.textContaining('Lien envoyé à Marie.'), findsOneWidget);
    expect(find.textContaining('En attente'), findsOneWidget);
  });

  testWidgets('point reçu : « Créer la livraison » avec ce destinataire ; lien expiré : renvoyé', (tester) async {
    final api = linksApi();
    final opened = <Uri>[];
    final created = <LocationLink>[];
    await pumpVariant(tester, Variant.matrix.first, ask(api, opened: opened, onCreate: created.add));
    await settle(tester);
    expect(find.text('Point reçu · Portail bleu après la pharmacie du carrefour'), findsOneWidget);
    await tester.tap(find.text('Créer la livraison').first);
    await settle(tester);
    expect(created.single.recipientName, 'Marie Ngo');

    await tester.scrollUntilVisible(find.text('Renvoyer'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await settle(tester);
    await tester.tap(find.text('Renvoyer'));
    await settle(tester);
    expect(api.createdLinks.single['recipientPhone'], '+237655778899');
    expect(opened.single.path, '/237655778899');
  });

  testWidgets('le destinataire place son point : la liste est relue, un son l’annonce', (tester) async {
    final api = FakeClientApi()..links = [pendingLink('Marie Ngo', phone: '+237677889900')];
    final realtime = FakeRealtime();
    await pumpVariant(tester, Variant.matrix.first, ask(api, realtime: realtime));
    await settle(tester);
    expect(find.textContaining('En attente'), findsOneWidget);
    api.links = [received];
    realtime.emit('location-link.submitted', {'linkId': 'x'});
    await settle(tester);
    expect(find.textContaining('Point reçu'), findsOneWidget);
    expect(sounds.played, isNotEmpty);
  });

  testWidgets('la livraison créée depuis le lien reprend le destinataire et son adresse', (tester) async {
    final api = orderApi()..recents = [];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: overrides(api),
        child: NewOrderFlow(me: shopOwner, onClose: () {}, now: () => homeNow, fromLink: received),
      ),
    );
    await toRecipient(tester);
    expect(find.widgetWithText(TextField, 'Marie Ngo'), findsOneWidget);
    expect(find.widgetWithText(TextField, '6 77 88 99 00'), findsOneWidget);
    expect(find.textContaining('Portail bleu après la pharmacie du carrefour'), findsWidgets);
  });
}
