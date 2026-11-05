import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/core/location.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/order/address_editor.dart';
import 'package:tara_client/features/order/new_order_flow.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show person, shopOwner;

/// Marchande avec sa boutique et sa maison enregistrées, et trois destinataires habituels.
FakeClientApi orderApi() => FakeClientApi()
  ..saved = [
    fakeAddress('1', 'Rue Joss, immeuble Socar, 2e étage', label: 'Boutique', neighborhood: 'Akwa', verified: true),
    fakeAddress('2', 'Portail vert face à l’école publique', label: 'Maison', neighborhood: 'Bonapriso'),
    // Adresse de livraison sans libellé : pas proposée à l'enlèvement.
    fakeAddress('3', 'Carrefour Ndokoti', neighborhood: 'Ndokoti'),
  ]
  ..recents = [
    Recipient(
      name: 'Marie Ngo',
      phone: '+237690112233',
      ordersCount: 12,
      lastAddress: fakeAddress('4', 'Face pharmacie du Rond-point', neighborhood: 'Bonapriso', verified: true),
    ),
    Recipient(
      name: 'Jean Mbarga',
      phone: '+237677445566',
      ordersCount: 4,
      lastAddress: fakeAddress('5', 'Immeuble bleu derrière la boulangerie', neighborhood: 'Deïdo'),
    ),
    Recipient(
      name: 'Chantal Eyike',
      phone: '+237655778899',
      ordersCount: 2,
      lastAddress: fakeAddress('6', 'Ruelle après le marché', neighborhood: 'Bépanda', verified: true),
    ),
  ];

List<Override> overrides(FakeClientApi api, {Future<bool> Function(Uri uri)? launcher}) => [
  keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
  clientApiProvider.overrideWithValue(api),
  realMapProvider.overrideWithValue(false),
  currentPositionProvider.overrideWithValue(() async => MapPoint.douala),
  launcherProvider.overrideWithValue(launcher ?? (_) async => true),
];

Widget flow(FakeClientApi api, {Me me = shopOwner, VoidCallback? onClose, Future<bool> Function(Uri uri)? launcher}) =>
    ProviderScope(
      overrides: overrides(api, launcher: launcher),
      child: NewOrderFlow(me: me, onClose: onClose ?? () {}),
    );

/// Étape 3 : enlèvement choisi d'office, destinataire pris dans les récents.
Future<void> toPackage(WidgetTester tester) async {
  await toRecipient(tester);
  await tester.tap(find.text('Marie'));
  await settle(tester);
  await tester.tap(find.text('Continuer'));
  await settle(tester);
}

/// Interrupteur « Fragile » de l'étape 3.
bool fragileOn(WidgetTester tester) => tester.widget<GlassSwitch>(find.byType(GlassSwitch)).value;

Future<void> toRecipient(WidgetTester tester) async {
  await settle(tester);
  await tester.tap(find.text('Continuer'));
  await settle(tester);
}

Future<void> typeRecipient(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Paul Ekwalla');
  await tester.enterText(find.byType(TextField).at(1), '699112233');
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('05 enlèvement ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Étape 1 sur 5 · Enlèvement'), findsOneWidget);
      expect(find.text('Carrefour Ndokoti'), findsNothing);
      await expectLater(capture, matchesGoldenFile('goldens/05_enlevement/${variant.name}.png'));
    });

    goldenTest('05 destinataire ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await toRecipient(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Étape 2 sur 5 · Destinataire'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_destinataire/${variant.name}.png'));
    });

    goldenTest('05 adresse sur la carte ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await settle(tester);
      await tester.tap(find.text('Nouvelle adresse'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(AddressEditor), matchesGoldenFile('goldens/05_adresse_carte/${variant.name}.png'));
    });

    goldenTest('05 colis ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await toPackage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Étape 3 sur 5 · Colis'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_colis/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    final variant = Variant(brightness, ScreenSize.regular, 1);

    goldenTest('05 enlèvement sans adresse ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(FakeClientApi()));
      await settle(tester);
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      expect(find.text('Choisissez ou ajoutez l’adresse d’enlèvement.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_enlevement/vide_${brightness.name}.png'));
    });

    goldenTest('05 destinataire choisi ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()), surface: const Size(390, 900));
      await toRecipient(tester);
      await tester.tap(find.text('Marie'));
      await settle(tester);
      expect(find.text('Adresse confirmée par une livraison'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_destinataire/choisi_${brightness.name}.png'));
    });

    goldenTest('05 lien envoyé ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()), surface: const Size(390, 900));
      await toRecipient(tester);
      await typeRecipient(tester);
      await tester.tap(find.text('WhatsApp'));
      await settle(tester);
      expect(find.text('Lien envoyé à Paul'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_destinataire/lien_${brightness.name}.png'));
    });

    goldenTest('05 colis rempli ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()), surface: const Size(390, 1640));
      await toPackage(tester);
      await tester.tap(find.text('Électronique'));
      await tester.enterText(find.byType(TextField).at(0), 'Téléphone et chargeur');
      await tester.tap(find.text('M'));
      await tester.enterText(find.byType(TextField).at(1), '125000');
      await tester.enterText(find.byType(TextField).at(2), '125000');
      await tester.enterText(find.byType(TextField).at(3), 'Appeler en arrivant');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(find.text('125\u00a0000'), findsNWidgets(2));
      expect(fragileOn(tester), isTrue);
      await expectLater(capture, matchesGoldenFile('goldens/05_colis/rempli_${brightness.name}.png'));
    });

    goldenTest('05 destinataire incomplet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        flow(FakeClientApi()..saved = orderApi().saved),
        surface: const Size(390, 900),
      );
      await toRecipient(tester);
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      expect(find.text('Saisissez le nom du destinataire.'), findsOneWidget);
      expect(find.text('Indiquez où livrer le colis.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_destinataire/incomplet_${brightness.name}.png'));
    });
  }

  testWidgets('la nouvelle adresse d’enlèvement est enregistrée puis choisie', (tester) async {
    final api = FakeClientApi();
    await pumpVariant(tester, Variant.matrix.first, flow(api));
    await settle(tester);
    await tester.tap(find.text('Nouvelle adresse'));
    await settle(tester);

    // Repère trop court : rien n'est envoyé.
    await tester.enterText(find.byType(TextField), 'Rü');
    await tester.tap(find.text('Enregistrer l’adresse'));
    await settle(tester);
    expect(find.text('Décrivez un repère visible (3 caractères au moins).'), findsOneWidget);
    expect(api.createdAddresses, isEmpty);

    await tester.enterText(find.byType(TextField), '  Rue Joss, immeuble Socar ');
    await tester.tap(find.text('Enregistrer l’adresse'));
    await settle(tester);
    expect(api.createdAddresses.single, {
      'latitude': MapPoint.douala.latitude,
      'longitude': MapPoint.douala.longitude,
      'landmark': 'Rue Joss, immeuble Socar',
      'neighborhoodId': null,
      'label': 'Boutique',
      'contactName': null,
      'contactPhone': null,
    });
    expect(find.text('Étape 1 sur 5 · Enlèvement'), findsOneWidget);
    expect(find.text('Akwa · Rue Joss, immeuble Socar'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.text('Étape 2 sur 5 · Destinataire'), findsOneWidget);
  });

  testWidgets('un récent du carnet remplit nom, numéro et adresse', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi()), surface: const Size(390, 900));
    await toRecipient(tester);
    await tester.tap(find.text('Jean'));
    await settle(tester);
    expect(find.widgetWithText(TextField, 'Jean Mbarga'), findsOneWidget);
    expect(find.widgetWithText(TextField, '6 77 44 55 66'), findsOneWidget);
    expect(find.text('Immeuble bleu derrière la boulangerie'), findsOneWidget);

    // Changer d'adresse rend les deux façons de la donner.
    await tester.tap(find.text('Changer d’adresse'));
    await settle(tester);
    expect(find.text('Placer sur la carte'), findsOneWidget);
    expect(find.text('Demander au destinataire'), findsOneWidget);
  });

  testWidgets('le lien de localisation part par WhatsApp et l’adresse arrive', (tester) async {
    final api = orderApi();
    final opened = <Uri>[];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      flow(
        api,
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
      surface: const Size(390, 900),
    );
    await toRecipient(tester);
    await typeRecipient(tester);
    await tester.tap(find.text('WhatsApp'));
    await settle(tester);

    expect(api.createdLinks.single, {'recipientName': 'Paul Ekwalla', 'recipientPhone': '+237699112233'});
    final uri = opened.single;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/237699112233');
    expect(
      uri.queryParameters['text'],
      'Bonjour Paul, Awa Fashion vous envoie un colis avec Tara. Indiquez où vous le livrer : '
      'https://tara.cm/l/Q7mK2pXa9RtL4vNe',
    );

    // Renvoyer par SMS réutilise le même lien.
    await tester.tap(find.text('SMS'));
    await settle(tester);
    expect(api.createdLinks, hasLength(1));
    expect(opened.last.scheme, 'sms');
    expect(opened.last.path, '+237699112233');

    // Le destinataire place son point : l'adresse s'affiche au tour suivant.
    api.linkAfter = pendingLink(
      'Paul Ekwalla',
      address: fakeAddress('7', 'Maison jaune après le pont', neighborhood: 'Makepe'),
    );
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('Maison jaune après le pont'), findsOneWidget);
    expect(find.text('Placée par le destinataire'), findsOneWidget);
    expect(sounds.played, [TaraSound.received]);
  });

  testWidgets('le lien demande d’abord le nom et le numéro', (tester) async {
    final api = orderApi();
    await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 900));
    await toRecipient(tester);
    await tester.ensureVisible(find.text('WhatsApp'));
    await tester.tap(find.text('WhatsApp'));
    await settle(tester);
    expect(find.text('Saisissez d’abord le nom et le numéro du destinataire.'), findsOneWidget);
    expect(api.createdLinks, isEmpty);
  });

  testWidgets('WhatsApp absent : proposer les SMS', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      flow(orderApi(), launcher: (_) async => false),
      surface: const Size(390, 900),
    );
    await toRecipient(tester);
    await typeRecipient(tester);
    await tester.tap(find.text('WhatsApp'));
    await settle(tester);
    expect(find.text('WhatsApp ne s’est pas ouvert. Essayez par SMS.'), findsOneWidget);
  });

  testWidgets('Retour revient à l’étape précédente, puis ferme', (tester) async {
    var closed = 0;
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi(), onClose: () => closed++));
    await toRecipient(tester);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await settle(tester);
    expect(find.text('Étape 1 sur 5 · Enlèvement'), findsOneWidget);
    expect(closed, 0);
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await settle(tester);
    expect(closed, 1);
  });

  testWidgets('« Nouvelle livraison » ouvre le parcours au-dessus des onglets', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: overrides(orderApi()),
        child: const HomeFlow(me: shopOwner),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Nouvelle livraison'));
    await settle(tester);
    expect(find.byType(NewOrderFlow), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await settle(tester);
    expect(find.byType(NewOrderFlow), findsNothing);
    expect(find.text('Nouvelle livraison'), findsOneWidget);
  });

  testWidgets('la nature du contenu suggère taille et fragilité, sans écraser un choix', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi()), surface: const Size(390, 1400));
    await toPackage(tester);
    await tester.tap(find.text('L'));
    await tester.tap(find.text('Cuisine, maison'));
    await settle(tester);
    expect(fragileOn(tester), isTrue);
    expect(find.text('Jusqu’à 10 kg · carton moyen, sac de linge.'), findsOneWidget);

    // Taille choisie : les documents ne la ramènent pas à S.
    await tester.tap(find.text('Documents'));
    await settle(tester);
    expect(fragileOn(tester), isFalse);
    expect(find.text('Jusqu’à 10 kg · carton moyen, sac de linge.'), findsOneWidget);

    // Fragilité choisie : l'électronique ne la change plus.
    await tester.tap(find.text('Fragile'));
    await settle(tester);
    expect(fragileOn(tester), isTrue);
    await tester.tap(find.text('Médicaments'));
    await settle(tester);
    expect(fragileOn(tester), isTrue);
  });

  testWidgets('un colis « Autre » demande une précision ; les montants ont un plafond', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi()), surface: const Size(390, 1400));
    await toPackage(tester);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.text('Choisissez la nature du contenu.'), findsOneWidget);

    await tester.tap(find.text('Autre'));
    await settle(tester);
    expect(find.text('Précisez le contenu'), findsOneWidget);
    expect(find.text('Décrivez ce que contient le colis.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Pièce de moto');
    await settle(tester);
    expect(find.text('Décrivez ce que contient le colis.'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), '600000');
    await settle(tester);
    expect(find.text('600\u00a0000'), findsOneWidget);
    expect(find.text('500 000 F au plus par livraison.'), findsOneWidget);
  });

  testWidgets('un particulier n’a pas de montant à encaisser', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi(), me: person), surface: const Size(390, 1400));
    await toPackage(tester);
    expect(find.text('Étape 3 sur 5 · Colis'), findsOneWidget);
    expect(find.text('À encaisser auprès du destinataire'), findsNothing);
    expect(find.text('Valeur du contenu (facultatif)'), findsOneWidget);
  });
}
