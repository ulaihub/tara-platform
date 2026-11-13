import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/core/location.dart';
import 'package:tara_client/core/media/address_media.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/order/address_editor.dart';
import 'package:tara_client/features/order/new_order_flow.dart';
import 'package:tara_client/features/order/when_step.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, person, shopOwner;

/// Marchande avec sa boutique et sa maison enregistrées, et trois destinataires habituels.
FakeClientApi orderApi() => FakeClientApi()
  ..wallet0 = const Wallet(customerBalance: 0, merchantBalance: 128500, payoutSchedule: 'DAILY')
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

/// Photo du colis prise dans les tests (petite image du dossier fixtures).
final parcelPhoto = File('test/fixtures/colis.jpg').absolute.path;

/// Réglages de l'app gardés sur le téléphone, frais Mobile Money à 6 % (compte Sebpay particulier).
MemoryKeyValueStore storeWithMobileMoneyFee() =>
    MemoryKeyValueStore()
      ..values['tara.app-config'] = jsonEncode({...AppConfigController.fallback, 'mobileMoneyFeeBps': 600});

List<Override> overrides(
  FakeClientApi api, {
  Future<bool> Function(Uri uri)? launcher,
  FakeRealtime? realtime,
  MemoryKeyValueStore? store,
}) => [
  keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
  takeParcelPhotoProvider.overrideWithValue(() async => parcelPhoto),
  clientApiProvider.overrideWithValue(api),
  realMapProvider.overrideWithValue(false),
  currentPositionProvider.overrideWithValue(() async => MapPoint.douala),
  launcherProvider.overrideWithValue(launcher ?? (_) async => true),
  realtimeProvider.overrideWithValue(realtime ?? FakeRealtime()),
];

Widget flow(
  FakeClientApi api, {
  Me me = shopOwner,
  VoidCallback? onClose,
  Future<bool> Function(Uri uri)? launcher,
  FakeRealtime? realtime,
  MemoryKeyValueStore? store,
}) => ProviderScope(
  overrides: overrides(api, launcher: launcher, realtime: realtime, store: store),
  child: NewOrderFlow(me: me, onClose: onClose ?? () {}, now: () => homeNow),
);

/// Étape 3 : enlèvement choisi d'office, destinataire pris dans les récents.
Future<void> toPackage(WidgetTester tester) async {
  await toRecipient(tester);
  await tester.tap(find.text('Marie'));
  await settle(tester);
  await tester.tap(find.text('Continuer'));
  await settle(tester);
}

/// Étape 4 : colis « Documents ».
Future<void> toWhen(WidgetTester tester) async {
  await toPackage(tester);
  // Petit écran, grand texte : la carte photo pousse les natures sous le pli.
  await tester.ensureVisible(find.text('Documents'));
  await settle(tester);
  await tester.tap(find.text('Documents'));
  await tester.tap(find.text('Continuer'));
  await settle(tester);
}

/// Étape 5 : livraison « Documents » tout de suite, prix calculé.
Future<void> toSummary(WidgetTester tester) async {
  await toWhen(tester);
  await tester.tap(find.text('Continuer'));
  await settle(tester);
}

/// Glisser pour commander.
Future<void> slideToOrder(WidgetTester tester) async {
  await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
  await settle(tester);
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
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

    goldenTest('05 quand ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await toWhen(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Étape 4 sur 5 · Quand'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_quand/${variant.name}.png'));
    });

    goldenTest('05 récapitulatif ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()));
      await toSummary(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Étape 5 sur 5 · Récapitulatif'), findsOneWidget);
      expect(find.text('Commander · 1\u00a0200\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_recapitulatif/${variant.name}.png'));
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

    goldenTest('05 colis gros objet puis récapitulatif ${brightness.name}', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, variant, flow(api), surface: const Size(390, 1760));
      await toPackage(tester);
      await tester.tap(find.text('Cuisine, maison'));
      await tester.enterText(find.byType(TextField).at(0), 'Réfrigérateur 2 portes');
      await tester.tap(find.text('Gros objet'));
      await settle(tester);
      expect(
        find.text('Trop grand ou trop lourd pour une moto. Tarif tricycle, affiché avant de commander.'),
        findsOne,
      );
      await tester.tap(find.text('Aide pour charger'));
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/05_colis/gros_objet_${brightness.name}.png'));

      await tester.tap(find.text('Continuer'));
      await settle(tester);
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      // Prix tricycle et manutention annoncés avant de commander, comme le déplacement
      // facturé si le colis est refusé.
      expect(api.quotes.last, containsPair('size', 'BULKY'));
      expect(api.quotes.last, containsPair('loadingHelp', true));
      expect(find.text('Manutention (chargement à deux)'), findsOneWidget);
      expect(find.text('Commander · 4\u00a0500\u00a0F'), findsOneWidget);
      expect(find.textContaining('son déplacement (1\u00a0500 F) reste à votre charge'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_recapitulatif/gros_objet_${brightness.name}.png'));
    });

    goldenTest('05 colis photo analysée ${brightness.name}', (tester) async {
      final api = orderApi()
        ..parcelAnalysis = const ParcelAnalysis(
          photoKey: 'parcel_photo-1',
          isParcel: true,
          size: 'BULKY',
          contents: 'HOUSEHOLD',
          description: 'Réfrigérateur 2 portes',
          fragile: true,
          prohibited: ['matière dangereuse (gaz, carburant…)'],
          confidence: 'high',
        );
      await pumpVariant(tester, variant, flow(api), surface: const Size(390, 1900));
      await toPackage(tester);
      final context = tester.element(find.text('Photographier le colis'));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(parcelPhoto)), width: 168), context));
      await tester.tap(find.text('Prendre la photo'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(api.uploads.last, (parcelPhoto, 'PARCEL_PHOTO'));
      expect(api.analyzed, ['address/parcel_photo-1']);
      expect(find.text('Proposition appliquée'), findsOneWidget);
      expect(find.text('Réfrigérateur 2 portes'), findsOneWidget);
      expect(find.textContaining('La photo semble montrer : matière dangereuse'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_colis/photo_${brightness.name}.png'));
    });

    goldenTest('05 récapitulatif Mobile Money ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        flow(orderApi(), store: storeWithMobileMoneyFee()),
        surface: const Size(390, 1500),
      );
      await toSummary(tester);
      await tapVisible(tester, 'MTN Mobile Money');
      await settle(tester);
      // 1 200 F de course, 77 F de frais Mobile Money (6 %), payés en plus.
      expect(find.text('Frais Mobile Money'), findsOneWidget);
      expect(find.text('+77\u00a0F'), findsOneWidget);
      expect(find.text('Commander · 1\u00a0277\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_recapitulatif/mobile_money_${brightness.name}.png'));

      // En espèces : rien de plus.
      await tapVisible(tester, 'Espèces à l’enlèvement');
      await settle(tester);
      expect(find.text('Frais Mobile Money'), findsNothing);
      expect(find.text('Commander · 1\u00a0200\u00a0F'), findsOneWidget);
    });

    goldenTest('05 quand programmé ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()), surface: const Size(390, 1340));
      await toWhen(tester);
      await tester.tap(find.text('Programmer'));
      await settle(tester);
      await tester.tap(find.text('Demain'));
      await settle(tester);
      await tester.tap(find.text('20:00'));
      await settle(tester);
      expect(
        find.text('Enlèvement prévu demain à 20:00.\nEntre 20 h et 6 h, un supplément de nuit s’applique.'),
        findsOneWidget,
      );
      await expectLater(capture, matchesGoldenFile('goldens/05_quand/programme_${brightness.name}.png'));
    });

    goldenTest('05 récapitulatif complet ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, flow(orderApi()), surface: const Size(390, 1500));
      await toSummary(tester);
      await expectLater(capture, matchesGoldenFile('goldens/05_recapitulatif/complet_${brightness.name}.png'));
    });

    goldenTest('05 paiement puis commande envoyée ${brightness.name}', (tester) async {
      final api = orderApi();
      final realtime = FakeRealtime();
      await pumpVariant(tester, variant, flow(api, realtime: realtime));
      await toSummary(tester);
      await tapVisible(tester, 'MTN Mobile Money');
      await slideToOrder(tester);
      expect(find.text('Validez le paiement sur votre téléphone'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_paiement/${brightness.name}.png'));

      api.paymentStatuses = ['SUCCEEDED'];
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      realtime.emit('order.status', {'orderId': '00000000-0000-4000-8000-000000000501', 'status': 'ASSIGNED'});
      await settle(tester);
      expect(find.text('Livreur trouvé ! Il vient chercher le colis.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_commande_envoyee/${brightness.name}.png'));
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

  testWidgets('l’aide pour charger ne se propose que pour un gros objet et part avec la commande', (tester) async {
    final api = orderApi();
    await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1760));
    await toPackage(tester);
    await tester.tap(find.text('Cuisine, maison'));
    await settle(tester);
    expect(find.text('Aide pour charger'), findsNothing);
    await tester.tap(find.text('Gros objet'));
    await settle(tester);
    await tester.tap(find.text('Aide pour charger'));
    await settle(tester);
    // Retour à une taille ordinaire : l'option disparaît et ne part pas.
    await tester.tap(find.text('L'));
    await settle(tester);
    expect(find.text('Aide pour charger'), findsNothing);
    await tester.tap(find.text('Gros objet'));
    await settle(tester);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    await tapVisible(tester, 'Espèces à l’enlèvement');
    await slideToOrder(tester);
    await settle(tester);
    expect(api.created.single.body, containsPair('packageSize', 'BULKY'));
    expect(api.created.single.body, containsPair('loadingHelp', true));
  });

  testWidgets('photo du colis : jointe à la commande ; analyse indisponible, on choisit soi-même', (tester) async {
    final api = orderApi()
      ..parcelAnalysisError = const ApiException(
        code: 'PARCEL_ANALYSIS_UNAVAILABLE',
        message: 'L’analyse de la photo est momentanément indisponible. Choisissez la taille et la nature vous-même.',
        status: 503,
      );
    await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1800));
    await toPackage(tester);
    await tester.tap(find.text('Prendre la photo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(find.text('Photo jointe'), findsOneWidget);
    expect(find.textContaining('momentanément indisponible'), findsOneWidget);
    await tester.tap(find.text('Documents'));
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    await tapVisible(tester, 'Espèces à l’enlèvement');
    await slideToOrder(tester);
    await settle(tester);
    expect(api.created.single.body, containsPair('parcelPhotoKey', 'address/parcel_photo-1'));
  });

  testWidgets('un particulier n’a pas de montant à encaisser', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi(), me: person), surface: const Size(390, 1400));
    await toPackage(tester);
    expect(find.text('Étape 3 sur 5 · Colis'), findsOneWidget);
    expect(find.text('À encaisser auprès du destinataire'), findsNothing);
    expect(find.text('Valeur du contenu (facultatif)'), findsOneWidget);
  });

  group('créneaux (C3)', () {
    test('30 min d’avance au moins, 7 jours au plus, de 6 h à 21 h 30', () {
      final now = DateTime(2026, 11, 4, 10, 20);
      final days = scheduleDays(now);
      expect(days, hasLength(8));
      expect(scheduleSlots(days.first, now).first, DateTime(2026, 11, 4, 11));
      expect(scheduleSlots(days[1], now), hasLength(32));
      expect(scheduleSlots(days.last, now).last, DateTime(2026, 11, 11, 10));
      expect(isNightSlot(DateTime(2026, 11, 5, 20)), isTrue);
      expect(isNightSlot(DateTime(2026, 11, 5, 19, 30)), isFalse);
    });

    test('le soir, plus de créneau aujourd’hui : on commence demain', () {
      final now = DateTime(2026, 11, 4, 21, 10);
      expect(scheduleDays(now).first, DateTime(2026, 11, 5));
    });
  });

  testWidgets('programmer demande une heure ; changer de jour la retire', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, flow(orderApi()), surface: const Size(390, 1200));
    await toWhen(tester);
    expect(find.text('Jour'), findsNothing);
    await tester.tap(find.text('Programmer'));
    await settle(tester);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    await tester.ensureVisible(find.text('Choisissez une heure de passage.'));
    expect(find.text('Choisissez une heure de passage.'), findsOneWidget);

    await tester.tap(find.text('11:00'));
    await settle(tester);
    expect(find.text('Choisissez une heure de passage.'), findsNothing);
    expect(find.text('Enlèvement prévu aujourd’hui à 11:00.'), findsOneWidget);

    await tester.tap(find.text('Demain'));
    await settle(tester);
    expect(find.textContaining('Enlèvement prévu'), findsNothing);
    expect(find.text('06:00'), findsOneWidget);

    // Revenir à « Maintenant » : plus rien à choisir.
    await tester.tap(find.text('Maintenant'));
    await settle(tester);
    expect(find.text('Jour'), findsNothing);
  });

  group('récapitulatif et commande (étape 5)', () {
    testWidgets('Mobile Money : commande, demande de paiement, confirmation, livreur trouvé', (tester) async {
      final api = orderApi();
      final realtime = FakeRealtime();
      var closed = 0;
      await pumpVariant(
        tester,
        Variant.matrix.first,
        flow(api, realtime: realtime, onClose: () => closed++),
        surface: const Size(390, 1500),
      );
      await toSummary(tester);
      await tapVisible(tester, 'MTN Mobile Money');
      expect(api.quotes.single, {
        'dropoff': '00000000-0000-4000-8000-000000000204',
        'size': 'S',
        'promo': null,
        'at': null,
        'loadingHelp': false,
      });
      await slideToOrder(tester);

      final order = api.created.single;
      expect(order.batch, isFalse);
      expect(order.key, hasLength(32));
      expect(order.body, {
        'pickupAddressId': '00000000-0000-4000-8000-000000000201',
        'isExpress': false,
        'feePayer': 'SENDER',
        'feePaymentMethod': 'MOMO_MTN',
        'dropoffAddressId': '00000000-0000-4000-8000-000000000204',
        'recipientName': 'Marie Ngo',
        'recipientPhone': '+237690112233',
        'packageSize': 'S',
        'packageContents': 'DOCUMENTS',
        'isFragile': false,
        'codAmount': 0,
      });
      expect(api.paid.single, (
        orderId: '00000000-0000-4000-8000-000000000501',
        phone: '+237677123456',
        operator: 'MTN',
      ));
      expect(find.text('Validez le paiement sur votre téléphone'), findsOneWidget);
      expect(find.textContaining('6\u00a077\u00a012\u00a034\u00a056'), findsOneWidget);

      // Validé sur le téléphone : la relecture suivante le voit.
      api.paymentStatuses = ['SUCCEEDED'];
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('Commande envoyée !'), findsOneWidget);
      expect(find.text('4 8 2 1'), findsOneWidget);
      expect(find.text('TR-48301 · Marie Ngo'), findsOneWidget);
      expect(find.text('Recherche d’un livreur…'), findsOneWidget);
      expect(sounds.played, [TaraSound.sent]);

      realtime.emit('order.status', {'orderId': '00000000-0000-4000-8000-000000000501', 'status': 'ASSIGNED'});
      await settle(tester);
      expect(find.text('Livreur trouvé ! Il vient chercher le colis.'), findsOneWidget);
      expect(sounds.played, [TaraSound.sent, TaraSound.received]);

      await tester.tap(find.text('Retour à l’accueil'));
      await settle(tester);
      expect(closed, 1);
    });

    testWidgets('paiement refusé : nouvelle demande, ou annulation de la commande', (tester) async {
      final api = orderApi()..paymentStatuses = ['FAILED'];
      var closed = 0;
      await pumpVariant(
        tester,
        Variant.matrix.first,
        flow(api, onClose: () => closed++),
        surface: const Size(390, 1500),
      );
      await toSummary(tester);
      await tapVisible(tester, 'MTN Mobile Money');
      await slideToOrder(tester);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('Le paiement n’a pas abouti.'), findsOneWidget);
      expect(sounds.played, [TaraSound.error]);

      api.paymentStatuses = ['PENDING'];
      await tester.tap(find.text('Renvoyer la demande'));
      await settle(tester);
      expect(api.paid, hasLength(2));
      expect(find.text('Validez le paiement sur votre téléphone'), findsOneWidget);

      api.paymentStatuses = ['FAILED'];
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      await tester.tap(find.text('Annuler la commande'));
      await settle(tester);
      expect(api.cancelled, ['00000000-0000-4000-8000-000000000501']);
      expect(closed, 1);
    });

    testWidgets('espèces à l’enlèvement : commande envoyée sans paiement en ligne', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      await tapVisible(tester, 'Espèces à l’enlèvement');
      await slideToOrder(tester);
      expect(api.created.single.body['feePaymentMethod'], 'CASH');
      expect(api.paid, isEmpty);
      expect(find.text('Commande envoyée !'), findsOneWidget);
    });

    testWidgets('le destinataire paie : à la livraison, jamais par le solde', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      await tapVisible(tester, 'Mes ventes');
      await tapVisible(tester, 'Le destinataire');
      expect(find.text('Moyen de paiement'), findsNothing);
      await slideToOrder(tester);
      expect(api.created.single.body, containsPair('feePayer', 'RECIPIENT'));
      expect(api.created.single.body, containsPair('feePaymentMethod', 'CASH'));
    });

    testWidgets('code promo : refusé avec le message du serveur, puis appliqué', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ex. BIENVENUE'), 'faux');
      await tapVisible(tester, 'Appliquer');
      expect(find.text('Code promo inconnu.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'bienvenue');
      await tapVisible(tester, 'Appliquer');
      expect(find.text('Code BIENVENUE appliqué'), findsOneWidget);
      expect(find.text('−500\u00a0F'), findsOneWidget);
      expect(find.text('Commander · 700\u00a0F'), findsOneWidget);
      await slideToOrder(tester);
      expect(api.created.single.body['promoCode'], 'BIENVENUE');
    });

    testWidgets('tarif pro : remise affichée avant de commander ; un code moins avantageux n’est pas utilisé', (
      tester,
    ) async {
      final api = orderApi()..proDiscountBps = 1000;
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      // 10 % de 1 200 F = 120 F, arrondis à 100 F pour la monnaie.
      expect(find.text('Tarif pro (10\u00a0%)'), findsOneWidget);
      expect(find.text('−100\u00a0F'), findsOneWidget);
      expect(find.text('Commander · 1\u00a0100\u00a0F'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/05_recapitulatif/tarif_pro.png'));

      // Tarif pro de 50 % : plus avantageux que le code de 500 F, qui n'est pas consommé.
      api.proDiscountBps = 5000;
      await tester.enterText(find.widgetWithText(TextField, 'Ex. BIENVENUE'), 'bienvenue');
      await tapVisible(tester, 'Appliquer');
      expect(
        find.text('Votre tarif pro (−50\u00a0%) est plus avantageux : ce code n’est pas utilisé.'),
        findsOneWidget,
      );
      expect(find.text('Code BIENVENUE appliqué'), findsNothing);
      await slideToOrder(tester);
      expect(api.created.single.body['promoCode'], isNull);
    });

    testWidgets('plusieurs livraisons : un lot, un seul code, un seul paiement Mobile Money', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1700));
      await toSummary(tester);
      await tapVisible(tester, 'Ajouter une livraison');
      expect(find.text('Étape 2 sur 5 · Destinataire'), findsOneWidget);
      await tester.tap(find.text('Jean'));
      await settle(tester);
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      await tester.tap(find.text('Linge'));
      await tester.tap(find.text('XL'));
      await tester.tap(find.text('Continuer'));
      await settle(tester);

      expect(find.text('Étape 5 sur 5 · Récapitulatif'), findsOneWidget);
      expect(find.text('LIVRAISON 2'), findsOneWidget);
      expect(find.text('Total · 2 livraisons'), findsOneWidget);
      expect(find.text('Commander · 2 900 F'), findsOneWidget);
      expect(find.text('Code promo'), findsNothing);

      await tapVisible(tester, 'MTN Mobile Money');
      await slideToOrder(tester);
      final batch = api.created.single;
      expect(batch.batch, isTrue);
      expect(batch.body['feePaymentMethod'], 'MOMO_MTN');
      expect(
        [for (final item in batch.body['items']! as List) (item as Map)['recipientName']],
        ['Marie Ngo', 'Jean Mbarga'],
      );
      // Une seule demande de paiement pour tout le lot.
      expect(api.paid, isEmpty);
      expect(api.batchPaid.single, (
        batchId: '00000000-0000-4000-8000-000000000600',
        phone: '+237677123456',
        operator: 'MTN',
      ));
      expect(find.textContaining('2 900 F'), findsOneWidget);

      api.paymentStatuses = ['SUCCEEDED'];
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('2 livraisons · TR-48301 → TR-48302'), findsOneWidget);
      expect(find.text('7 3 0 2'), findsOneWidget);
    });

    testWidgets('boutique : ses ventes couvrent la course, elles sont proposées d’office', (tester) async {
      final api = orderApi();
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      expect(find.text('Pris sur vos ventes : il vous restera 127 300 F à recevoir.'), findsOneWidget);
      await slideToOrder(tester);
      expect(api.created.single.body['feePaymentMethod'], 'WALLET');
      expect(api.paid, isEmpty);
      expect(find.text('Commande envoyée !'), findsOneWidget);
    });

    testWidgets('boutique : ventes insuffisantes, Mobile Money de son opérateur proposé', (tester) async {
      final api = orderApi()..wallet0 = const Wallet(customerBalance: 0, merchantBalance: 500, payoutSchedule: 'DAILY');
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      expect(find.text('Disponible : 500 F, pas assez pour cette commande.'), findsOneWidget);
      await slideToOrder(tester);
      expect(api.created.single.body['feePaymentMethod'], 'MOMO_MTN');
    });

    testWidgets('ajout abandonné : retour au récapitulatif, sans livraison vide', (tester) async {
      await pumpVariant(tester, Variant.matrix.first, flow(orderApi()), surface: const Size(390, 1500));
      await toSummary(tester);
      await tapVisible(tester, 'Ajouter une livraison');
      await tester.tap(find.bySemanticsLabel('Retour'));
      await settle(tester);
      expect(find.text('Étape 5 sur 5 · Récapitulatif'), findsOneWidget);
      expect(find.text('LIVRAISON 2'), findsNothing);
    });

    testWidgets('coupure pendant la commande : nouvel essai avec la même clé, sans doublon', (tester) async {
      final api = orderApi()..createError = const ApiException(code: 'NETWORK', message: '');
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toSummary(tester);
      await tapVisible(tester, 'Espèces à l’enlèvement');
      await slideToOrder(tester);
      expect(find.text('Commande envoyée !'), findsNothing);
      await slideToOrder(tester);
      expect(api.created, hasLength(2));
      expect(api.created.first.key, api.created.last.key);
      expect(find.text('Commande envoyée !'), findsOneWidget);
    });

    testWidgets('créneau dépassé au moment de commander : retour à l’heure de passage', (tester) async {
      final api = orderApi()
        ..createError = const ApiException(code: 'SCHEDULE_INVALID', message: 'Créneau invalide.', status: 422);
      await pumpVariant(tester, Variant.matrix.first, flow(api), surface: const Size(390, 1500));
      await toWhen(tester);
      await tester.tap(find.text('Programmer'));
      await settle(tester);
      await tapVisible(tester, '11:00');
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      await tapVisible(tester, 'Espèces à l’enlèvement');
      await slideToOrder(tester);
      expect(find.text('Étape 4 sur 5 · Quand'), findsOneWidget);
      await tester.ensureVisible(find.text('Choisissez une heure de passage.'));
      expect(find.text('Choisissez une heure de passage.'), findsOneWidget);
    });
  });
}
