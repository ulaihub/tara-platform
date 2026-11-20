import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/course/call_journal.dart';
import 'package:tara_rider/core/course/course_actions.dart';
import 'package:tara_rider/core/course/proof_photo.dart';
import 'package:tara_rider/core/location/location_tracker.dart';
import 'package:tara_rider/core/location/online_controller.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/features/course/collection_screen.dart';
import 'package:tara_rider/features/course/delivery_screen.dart';
import 'package:tara_rider/features/course/failure_screen.dart';
import 'package:tara_rider/features/course/pickup_screen.dart';
import 'package:tara_rider/features/course/refuse_parcel_screen.dart';
import 'package:tara_rider/features/course/return_screen.dart';
import 'package:tara_rider/features/map/tara_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;

final photo = File('test/fixtures/colis.jpg').absolute.path;

/// Services de course sans minuterie ni réseau : rien ne part pendant une capture.
CourseActions courseActions() {
  final store = MemoryKeyValueStore();
  final queue = ActionQueue(store: store, send: (_, _) async => null, upload: (path) async => path);
  return CourseActions(
    queue: queue,
    activeOrder: ActiveOrderController(
      store: store,
      fetchActive: () async => [],
      fetchOrder: (_) async => order(),
      hasPendingActions: (_) => false,
    ),
    // Devant le vendeur d'Akwa : l'arrivée est signalée sur place.
    locate: () async => GeoPoint(latitude: 4.0511, longitude: 9.6942, recordedAt: DateTime.utc(2026, 11, 3)),
  );
}

/// Position du livreur pour les captures (Akwa : à 2,5 km du client de Bonapriso).
class _Positions implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;
  @override
  Future<GeoPoint?> current() async =>
      GeoPoint(latitude: 4.0511, longitude: 9.6942, recordedAt: DateTime.utc(2026, 11, 3));
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) => const Stream.empty();
}

/// Retour sans frais à encaisser : le solde de l'expéditeur les couvre.
FakeRiderApi noReturnFees() => FakeRiderApi()..collections = [const Collection(total: 0, complete: true)];

Widget scope(Widget child, {OnlineController? online, CallJournal? calls, FakeRiderApi? api}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    riderApiProvider.overrideWithValue(api ?? noReturnFees()),
    realMapProvider.overrideWithValue(false),
    takeProofPhotoProvider.overrideWithValue(() async => photo),
    courseActionsProvider.overrideWithValue(courseActions()),
    callJournalProvider.overrideWithValue(calls ?? CallJournal(store: MemoryKeyValueStore(), dial: (_) async {})),
    if (online != null) onlineControllerProvider.overrideWithValue(online),
  ],
  child: child,
);

/// Appels passés au destinataire, aux heures données (journal sans téléphone).
Future<CallJournal> callsAt(List<DateTime> times) async {
  var clock = times.first;
  final journal = CallJournal(store: MemoryKeyValueStore(), dial: (_) async {}, now: () => clock);
  for (final time in times) {
    clock = time;
    await journal.call(order().id, to: 'RECIPIENT', phone: '+237690000202');
    clock = time.add(const Duration(seconds: 31));
    await journal.resumed();
  }
  return journal;
}

FailureScreen failure() => FailureScreen(
  order: order(status: 'IN_DELIVERY'),
  onBack: () {},
  onDone: (_) {},
  now: () => DateTime(2026, 11, 3, 15, 4),
);

ReturnScreen returning() => ReturnScreen(
  order: order(status: 'DELIVERY_FAILED', failureDecision: 'RETURN', failureReason: 'RECIPIENT_ABSENT'),
  onBack: () {},
  onSos: () {},
  onReturned: (_) {},
  now: () => DateTime(2026, 11, 3, 15, 41),
);

Widget collection() => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    riderApiProvider.overrideWithValue(FakeRiderApi()),
    courseActionsProvider.overrideWithValue(courseActions()),
  ],
  child: CollectionScreen(
    order: order(status: 'IN_DELIVERY'),
    draft: DeliveryDraft(photoPath: photo, code: '4821'),
    onBack: () {},
    onDone: (_) {},
  ),
);

DeliveryScreen delivery(RiderOrder order) => DeliveryScreen(
  order: order,
  onBack: () {},
  onSos: () {},
  onDelivered: (_) {},
  onCollect: (_) {},
  onFailure: () {},
  now: () => DateTime(2026, 11, 3, 15, 4),
);

PickupScreen pickup(RiderOrder order) => PickupScreen(
  order: order,
  onBack: () {},
  onSos: () {},
  onPickedUp: (_) {},
  onRefuse: () {},
  now: () => DateTime(2026, 11, 3, 14, 32),
);

/// Tournée de 3 colis d'une même boutique (numéros 4, 9 et 12).
List<RiderOrder> tourStops() => [
  for (final (seq, number, size, who) in [(1, 4, 'S', 'Paul'), (2, 9, 'M', 'Brice'), (3, 12, 'S', 'Carine')])
    RiderOrder.fromJson({
      ...orderJson(
        id: '00000000-0000-4000-8000-00000000003$seq',
        collectAtPickup: 0,
        packageSize: size,
        batchNumber: number,
      ),
      'recipient': {'name': '$who Ekwalla', 'phone': '+237690000202'},
      'tourId': '00000000-0000-4000-8000-0000000000aa',
      'stopSeq': seq,
    }),
];

PickupScreen tourPickup() => PickupScreen(
  order: tourStops().first,
  tour: tourStops(),
  onBack: () {},
  onSos: () {},
  onPickedUp: (_) {},
  onRefuse: () {},
  now: () => DateTime(2026, 11, 3, 14, 32),
);

RefuseParcelScreen refusal() => RefuseParcelScreen(
  order: order(packageSize: 'BULKY'),
  onBack: () {},
  onDone: (_) {},
  now: () => DateTime(2026, 11, 3, 14, 34),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('12 encaissement espèces ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, collection());
      await settle(tester);
      await tester.ensureVisible(find.text('15\u00A0000'));
      await tester.tap(find.text('15\u00A0000'));
      await settle(tester);
      // Bas du contenu : sur petit écran, la monnaie à rendre reste visible au-dessus du bouton.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('2\u00A0500\u00A0F').hitTestable(), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/12_encaissement_especes/${variant.name}.png'));
    });

    goldenTest('12 encaissement mobile money ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, collection());
      await settle(tester);
      await tester.tap(find.text('Mobile Money'));
      await settle(tester);
      await tester.ensureVisible(find.text('Envoyer la demande de paiement'));
      await tester.tap(find.text('Envoyer la demande de paiement'));
      await settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('En attente de la validation du client…').hitTestable(), findsOneWidget);
      expect(find.text('Demande envoyée au client'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/12_encaissement_mobile_money/${variant.name}.png'));
    });

    goldenTest('09 livraison ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(delivery(order(status: 'IN_DELIVERY'))));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Code du destinataire'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/09_livraison/${variant.name}.png'));
    });

    goldenTest('09 livraison sans code ${variant.name}', (tester) async {
      final online = OnlineController(
        positions: _Positions(),
        setPresence: ({required online, required position}) async => Presence(online: online, blockers: const []),
        sendPosition: (_) async {},
      );
      await tester.runAsync(online.goOnline);
      await pumpVariant(
        tester,
        variant,
        scope(delivery(order(status: 'IN_DELIVERY', collectAtDelivery: 0)), online: online),
      );
      await settle(tester);
      // À 2,5 km : d'abord « en route », avec la distance ; « Je suis arrivé » ouvre la remise.
      expect(find.text('À 2,5\u00a0km'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/09_en_route/${variant.name}.png'));
      await tester.ensureVisible(find.text('Je suis arrivé'));
      await tester.tap(find.text('Je suis arrivé'));
      await settle(tester);
      final context = tester.element(find.byType(DeliveryScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.ensureVisible(find.text('Le client n’a pas de code'));
      await tester.tap(find.text('Le client n’a pas de code'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sa sœur, Brigitte');
      await tester.ensureVisible(find.text('Photographier la remise'));
      await tester.tap(find.text('Photographier la remise'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Vous êtes à 2,5'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/09_livraison_sans_code/${variant.name}.png'));
    });

    goldenTest('08 enlèvement ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(pickup(order())));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Le bouton reste inactif tant que code et photo manquent ; ce qui manque est dit.
      expect(find.text('Glisser · Colis récupéré'), findsOneWidget);
      expect(find.text('Il manque la photo, le code.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement/${variant.name}.png'));
    });

    goldenTest('08 enlèvement prêt ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(pickup(order(collectAtPickup: 0, pickupRestricted: true))));
      await settle(tester);
      // Vignette décodée avant d'apparaître (le décodage ne progresse pas en temps simulé).
      final context = tester.element(find.byType(PickupScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.enterText(find.byType(EditableText).first, '7302');
      await tester.ensureVisible(find.text('Photographier le colis'));
      await tester.tap(find.text('Photographier le colis'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Photo du colis · prise à 14:32'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement_pret/${variant.name}.png'));
    });
    goldenTest('08 colis non conforme ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(refusal()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Rien ne part sans motif ni photo.
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
      await expectLater(capture, matchesGoldenFile('goldens/08_colis_non_conforme/${variant.name}.png'));
    });

    goldenTest('10 échec ${variant.name}', (tester) async {
      final calls = await tester.runAsync(() => callsAt([DateTime(2026, 11, 3, 15, 2)]));
      await pumpVariant(tester, variant, scope(failure(), calls: calls));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Encore 1 appel, à partir de 15:07.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/10_echec/${variant.name}.png'));
    });

    goldenTest('10 échec prêt ${variant.name}', (tester) async {
      final calls = await tester.runAsync(() => callsAt([DateTime(2026, 11, 3, 14, 56), DateTime(2026, 11, 3, 15, 2)]));
      await pumpVariant(tester, variant, scope(failure(), calls: calls));
      await settle(tester);
      final context = tester.element(find.byType(FailureScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.ensureVisible(find.text('Photo du lieu · obligatoire'));
      await tester.tap(find.text('Photo du lieu · obligatoire'));
      await settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Appels suffisants.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/10_echec_pret/${variant.name}.png'));
    });

    goldenTest('11 retour ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(returning()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Échec · Client absent'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/11_retour/${variant.name}.png'));
    });

    goldenTest('11 retour chez le vendeur ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scope(returning()));
      await settle(tester);
      final context = tester.element(find.byType(ReturnScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.tap(find.text('Je suis chez le vendeur'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, '5521');
      await tester.ensureVisible(find.text('Photographier le colis rendu').last);
      await tester.tap(find.text('Photographier le colis rendu').last);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Photo du retour · prise à 15:41'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/11_retour_vendeur/${variant.name}.png'));
    });

    goldenTest('11 retour frais à encaisser ${variant.name}', (tester) async {
      final api = FakeRiderApi()..collections = [const Collection(total: 750, complete: false)];
      await pumpVariant(tester, variant, scope(returning(), api: api));
      await settle(tester);
      await tester.tap(find.text('Je suis chez le vendeur'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Frais de retour à encaisser'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/11_retour_frais/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    final variant = Variant(brightness, ScreenSize.regular, 1);

    goldenTest('08 enlèvement gros objet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        variant,
        scope(pickup(order(packageSize: 'BULKY', loadingHelp: true, collectAtPickup: 0))),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Gros objet, aide au chargement payée par l’expéditeur : venez à deux.'), findsOneWidget);
      expect(find.text('Colis non conforme'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement_gros_objet/${brightness.name}.png'));
    });

    goldenTest('08 enlèvement colis numéroté ${brightness.name}', (tester) async {
      // L'expéditeur envoie plusieurs colis : celui-ci porte le numéro 2.
      await pumpVariant(
        tester,
        variant,
        scope(pickup(order(batchNumber: 2, packageDescription: '2 paires de chaussures', collectAtPickup: 0))),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('COLIS À RÉCUPÉRER · N° 2'), findsOneWidget);
      expect(find.text('2 paires de chaussures'), findsOneWidget);
      expect(find.text('Pour Paul · Bonapriso'), findsOneWidget);
      expect(find.text('Numéro 2 bien visible'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement_numero/${brightness.name}.png'));
    });

    goldenTest('08 colis non conforme prêt ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, scope(refusal()));
      await settle(tester);
      final context = tester.element(find.byType(RefuseParcelScreen));
      await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
      await tester.tap(find.text('Trop grand pour mon véhicule'));
      await tester.enterText(find.byType(EditableText).first, 'Armoire 3 portes au lieu d’un frigo');
      await tester.ensureVisible(find.text('Photographier le colis'));
      await tester.tap(find.text('Photographier le colis'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Photo du colis · prise à 14:34'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNotNull);
      await expectLater(capture, matchesGoldenFile('goldens/08_colis_non_conforme/pret_${brightness.name}.png'));
    });
  }

  testWidgets('retour : pas de paiement, pas de colis ; espèces reçues, puis le colis peut être rendu', (tester) async {
    final api = FakeRiderApi()..collections = [const Collection(total: 750, complete: false)];
    await pumpVariant(tester, Variant.matrix.first, scope(returning(), api: api), surface: const Size(390, 1400));
    await settle(tester);
    await tester.tap(find.text('Je suis chez le vendeur'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText).first, '5521');
    await tester.tap(find.text('Photographier le colis rendu').last);
    await settle(tester);
    // Code et photo prêts, mais frais non réglés : le bouton reste inactif.
    final returned = find.widgetWithText(PrimaryButton, 'Colis rendu');
    expect(tester.widget<PrimaryButton>(returned).onPressed, isNull);

    await tester.tap(find.text('Espèces reçues · 750 F'));
    await settle(tester);
    expect(api.cashCollected, ['00000000-0000-4000-8000-000000000002']);
    expect(find.text('Frais de retour réglés : vous pouvez rendre le colis.'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(returned).onPressed, isNotNull);
    expect(sounds.played, contains(TaraSound.cash));
  });

  testWidgets('attente : « Je suis arrivé » démarre le temps, payé au-delà de 10 min', (tester) async {
    final api = noReturnFees()..arrivedAt = DateTime(2026, 11, 3, 14, 32).toUtc().toIso8601String();
    await pumpVariant(tester, Variant.matrix.first, scope(pickup(order(collectAtPickup: 0)), api: api));
    await settle(tester);
    expect(
      find.text(
        'Sur place, touchez « Je suis arrivé » : l’expéditeur est prévenu. Attente gratuite 10 min, '
        'puis 100\u00a0F par 5 min (400\u00a0F au plus), dont 70\u00a0F pour vous.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Je suis arrivé'));
    await tester.tap(find.text('Je suis arrivé'));
    await settle(tester);
    expect(api.arrivals, ['00000000-0000-4000-8000-000000000002']);
    // Arrivé à 14 h 32, l'écran est à 14 h 32 : rien à payer encore.
    expect(
      find.text('Vous attendez depuis 0 min · gratuit encore 10 min. Ensuite 100\u00a0F par 5 min pour l’expéditeur.', findRichText: true),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    // Arrivé 17 minutes plus tôt (14 h 15) : 2 tranches de 5 min, 70 % pour le livreur.
    final late = PickupScreen(
      order: RiderOrder.fromJson({...orderJson(collectAtPickup: 0), 'arrivedPickupAt': '2026-11-03T13:15:00Z'}),
      onBack: () {},
      onSos: () {},
      onPickedUp: (_) {},
      onRefuse: () {},
      now: () => DateTime.utc(2026, 11, 3, 13, 32).toLocal(),
    );
    await pumpVariant(tester, Variant.matrix.first, scope(late));
    await settle(tester);
    expect(
      find.text('Vous attendez depuis 17 min · 200\u00a0F d’attente pour l’expéditeur, dont 140\u00a0F pour vous.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expéditeur absent : après 30 min et 2 appels, le livreur part, payé', (tester) async {
    // Arrivé à 14 h 00, l'écran est à 14 h 31 ; deux appels à l'expéditeur depuis l'arrivée.
    var clock = DateTime(2026, 11, 3, 14, 5);
    final journal = CallJournal(store: MemoryKeyValueStore(), dial: (_) async {}, now: () => clock);
    final id = order().id;
    await journal.call(id, to: 'SENDER', phone: '+237690000101');
    clock = DateTime(2026, 11, 3, 14, 20);
    await journal.call(id, to: 'SENDER', phone: '+237690000101');
    final api = noReturnFees();
    var left = false;
    final screen = PickupScreen(
      order: RiderOrder.fromJson({
        ...orderJson(collectAtPickup: 0),
        'arrivedPickupAt': DateTime(2026, 11, 3, 14).toUtc().toIso8601String(),
      }),
      onBack: () {},
      onSos: () {},
      onPickedUp: (_) {},
      onRefuse: () {},
      onSenderAbsent: () => left = true,
      now: () => DateTime(2026, 11, 3, 14, 31),
    );
    await pumpVariant(tester, Variant.matrix.first, scope(screen, api: api, calls: journal));
    await settle(tester);
    await tester.ensureVisible(find.text('L’expéditeur ne vient pas'));
    await tester.tap(find.text('L’expéditeur ne vient pas'));
    await settle(tester);
    expect(api.absences, isEmpty);
    expect(
      find.text(
        'La course sera annulée. L’expéditeur paiera 700\u00a0F, dont 480\u00a0F pour vous. Touchez encore pour confirmer.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('L’expéditeur ne vient pas'));
    await settle(tester);
    expect(api.absences, [(id, 2)]);
    expect(left, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expéditeur absent : avant 30 min, l’app dit quand le livreur pourra partir', (tester) async {
    final screen = PickupScreen(
      order: RiderOrder.fromJson({
        ...orderJson(collectAtPickup: 0),
        'arrivedPickupAt': DateTime(2026, 11, 3, 14).toUtc().toIso8601String(),
      }),
      onBack: () {},
      onSos: () {},
      onPickedUp: (_) {},
      onRefuse: () {},
      now: () => DateTime(2026, 11, 3, 14, 12),
    );
    await pumpVariant(tester, Variant.matrix.first, scope(screen));
    await settle(tester);
    expect(find.text('Il ne vient pas ? Dans 18 min, vous pourrez partir : 480\u00a0F pour vous.'), findsOneWidget);
    expect(find.text('L’expéditeur ne vient pas'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('colis seul : ce qu’il faut récupérer et pour qui, sans numéro', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, scope(pickup(order(collectAtPickup: 0))));
    await settle(tester);
    expect(find.text('COLIS À RÉCUPÉRER'), findsOneWidget);
    expect(find.text('Colis moyen'), findsOneWidget);
    expect(find.text('Pour Paul · Bonapriso'), findsOneWidget);
    expect(find.text('Colis entier, bien visible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deux colis à bord : la livraison rappelle le numéro du colis à remettre', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      scope(delivery(order(status: 'IN_DELIVERY', batchNumber: 2, packageDescription: '2 paires de chaussures'))),
      surface: const Size(390, 1100),
    );
    await settle(tester);
    expect(find.text('COLIS À REMETTRE · N° 2'), findsOneWidget);
    expect(find.text('2 paires de chaussures'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    goldenTest('08 enlèvement d’une tournée ${brightness.name}', (tester) async {
      await pumpVariant(tester, Variant(brightness, ScreenSize.regular, 1), scope(tourPickup()));
      await settle(tester);
      await tester.ensureVisible(find.text('COLIS À RÉCUPÉRER · 0 SUR 3 COCHÉS'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/08_enlevement_tournee/${brightness.name}.png'));
    });
  }

  testWidgets('tournée : le bouton attend que chaque colis soit coché', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, scope(tourPickup()), surface: const Size(390, 1400));
    await settle(tester);
    final context = tester.element(find.byType(PickupScreen));
    await tester.runAsync(() => precacheImage(ResizeImage(FileImage(File(photo)), width: 168), context));
    // Photo à prendre : les 3 colis ensemble.
    expect(find.text('Les 3 colis ensemble, numéros visibles'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '7302');
    await tester.ensureVisible(find.text('Photographier le colis'));
    await tester.tap(find.text('Photographier le colis'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(find.text('N° 9'), findsOneWidget);
    expect(find.text('Pour Brice · Bonapriso · Colis moyen'), findsOneWidget);

    SwipeButton swipe() => tester.widget<SwipeButton>(find.byType(SwipeButton));
    // Code et photo prêts, mais seulement 2 colis sur 3 cochés : rien ne part.
    for (final number in ['N° 4', 'N° 9']) {
      await tester.ensureVisible(find.text(number));
      await tester.tap(find.text(number));
      await settle(tester);
    }
    expect(find.text('COLIS À RÉCUPÉRER · 2 SUR 3 COCHÉS'), findsOneWidget);
    expect(swipe().onConfirmed, isNull);

    await tester.ensureVisible(find.text('N° 12'));
    await tester.tap(find.text('N° 12'));
    await settle(tester);
    expect(find.text('COLIS À RÉCUPÉRER · 3 SUR 3 COCHÉS'), findsOneWidget);
    expect(swipe().onConfirmed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
