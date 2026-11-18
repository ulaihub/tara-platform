import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/app/providers.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/core/location.dart';
import 'package:tara_client/features/home/home_flow.dart';
import 'package:tara_client/features/tracking/tracking_screen.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/push/push_service.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/harness.dart';
import 'screens_home_golden_test.dart' show homeNow, shopApi, shopOwner;
import 'screens_new_order_golden_test.dart' show storeWithMobileMoneyFee;

const orderId = '00000000-0000-4000-8000-000000000501';

/// Commande d'Akwa à Bonapriso, à l'étape [status] ; après un échec, [decision] est le
/// choix de l'expéditeur (null : à décider).
TrackedOrder tracked(
  String status, {
  bool withRider = true,
  int cod = 12500,
  String? decision,
  int? rated,
  bool retryAllowed = true,
  String? refusalReason,
  String feePaymentMethod = 'CASH',
  bool feePaid = true,
  int? batchNumber,
  int cancellationFee = 0,
}) {
  DateTime at(int h, int m) => DateTime(2026, 11, 4, h, m);
  const ridden = ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED', 'DELIVERED'];
  final reached = <String, DateTime>{
    'CREATED': at(10, 2),
    if (status != 'CREATED') 'SEARCHING_RIDER': at(10, 2),
    if (ridden.contains(status)) 'ASSIGNED': at(10, 4),
    if (ridden.skip(1).contains(status)) 'PICKED_UP': at(10, 12),
    if (ridden.skip(2).contains(status)) 'IN_DELIVERY': at(10, 12),
    if (status == 'DELIVERY_FAILED') 'DELIVERY_FAILED': at(10, 18),
    if (status == 'DELIVERED') 'DELIVERED': at(10, 35),
  };
  final riderOn = withRider && reached.containsKey('ASSIGNED');
  return TrackedOrder(
    id: orderId,
    reference: 'TR-48301',
    status: status,
    trackingUrl: 'https://tara.cm/t/abc',
    scheduledFor: null,
    pickup: fakeAddress(
      '1',
      'Rue Joss, immeuble Socar',
      label: 'Boutique',
      neighborhood: 'Akwa',
      latitude: 4.0496,
      longitude: 9.6996,
    ),
    dropoff: fakeAddress(
      '4',
      'Face pharmacie du Rond-point',
      neighborhood: 'Bonapriso',
      latitude: 4.0318,
      longitude: 9.6905,
    ),
    recipientName: 'Marie Ngo',
    recipientPhone: '+237690112233',
    contents: 'CLOTHING',
    size: 'M',
    totalPrice: 1500,
    codAmount: cod,
    rider: riderOn
        ? OrderRider(
            name: 'Jean M.',
            phone: status == 'DELIVERED' ? null : '+237677445566',
            vehicleType: 'MOTORBIKE',
            plateNumber: 'LT 482 KQ',
          )
        : null,
    timeline: [for (final MapEntry(:key, :value) in reached.entries) (status: key, at: value)],
    createdAt: at(10, 2),
    failure: status == 'DELIVERY_FAILED'
        ? OrderFailure(
            reason: 'RECIPIENT_ABSENT',
            note: null,
            at: at(10, 18),
            decision: decision,
            decisionDueAt: decision == null ? at(10, 33) : null,
            retryAllowed: retryAllowed,
          )
        : null,
    retryFee: 500,
    returnFee: 750,
    cancellationFee: cancellationFee,
    refusalReason: refusalReason,
    feePaymentMethod: feePaymentMethod,
    feePaid: feePaid,
    batchNumber: batchNumber,
    batchSize: batchNumber == null ? null : 3,
    rating: rated == null ? null : OrderRating(score: rated, comment: null, at: at(10, 40)),
  );
}

List<Object> launched = [];
List<(String, bool)> shared = [];

Widget screen(FakeClientApi api, FakeRealtime realtime, {VoidCallback? onBack, MemoryKeyValueStore? store}) =>
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
        clientApiProvider.overrideWithValue(api),
        realtimeProvider.overrideWithValue(realtime),
        realMapProvider.overrideWithValue(false),
        launcherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
        shareProvider.overrideWithValue((text, png) async => shared.add((text, png != null))),
      ],
      child: TrackingScreen(orderId: orderId, onBack: onBack ?? () {}, now: () => DateTime(2026, 11, 4, 10, 20)),
    );

FakeClientApi apiAt(String status) => FakeClientApi()..tracked[orderId] = tracked(status);

/// Livreur à mi-chemin entre l'enlèvement et la livraison.
const halfway = {'latitude': 4.0405, 'longitude': 9.6950, 'heading': 200};

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    launched = [];
    shared = [];
  });

  for (final variant in Variant.matrix) {
    goldenTest('06 suivi en route ${variant.name}', (tester) async {
      final realtime = FakeRealtime()..ack = const {'ok': true, 'position': halfway};
      await pumpVariant(tester, variant, screen(apiAt('IN_DELIVERY'), realtime));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('En route vers Marie'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_en_route/${variant.name}.png'));
    });
  }

  for (final variant in Variant.matrix) {
    goldenTest('06 suivi échec ${variant.name}', (tester) async {
      final realtime = FakeRealtime()
        ..ack = const {
          'ok': true,
          'position': {'latitude': 4.0320, 'longitude': 9.6908},
        };
      await pumpVariant(tester, variant, screen(apiAt('DELIVERY_FAILED'), realtime));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Livraison impossible'), findsOneWidget);
      expect(find.text('Avant 10:33'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_echec/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    final variant = Variant(brightness, ScreenSize.regular, 1);

    goldenTest('06 suivi recherche ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, screen(apiAt('SEARCHING_RIDER'), FakeRealtime()));
      await settle(tester);
      expect(find.text('Recherche d’un livreur…'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_recherche/${brightness.name}.png'));
    });

    goldenTest('06 suivi paiement attendu ${brightness.name}', (tester) async {
      final api = FakeClientApi()..tracked[orderId] = tracked('CREATED', feePaymentMethod: 'MOMO_MTN', feePaid: false);
      await pumpVariant(tester, variant, screen(api, FakeRealtime()));
      await settle(tester);
      await tester.enterText(find.byType(EditableText), '677 12 34 56');
      await settle(tester);
      expect(find.text('En attente du paiement'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_paiement/${brightness.name}.png'));
    });

    goldenTest('06 suivi livreur trouvé ${brightness.name}', (tester) async {
      final realtime = FakeRealtime()
        ..ack = const {
          'ok': true,
          'position': {'latitude': 4.0560, 'longitude': 9.7040},
        };
      await pumpVariant(tester, variant, screen(apiAt('ASSIGNED'), realtime));
      await settle(tester);
      expect(find.text('Jean M. vient chercher le colis'), findsOneWidget);
      expect(find.text('Moto · LT 482 KQ'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_livreur/${brightness.name}.png'));
    });

    goldenTest('06 suivi colis refusé ${brightness.name}', (tester) async {
      final api = FakeClientApi()
        ..tracked[orderId] = tracked('CANCELLED', refusalReason: 'Colis non conforme : trop lourd · Armoire 3 portes');
      await pumpVariant(tester, variant, screen(api, FakeRealtime()));
      await settle(tester);
      expect(find.text('Colis refusé à l’enlèvement'), findsOneWidget);
      expect(
        find.text(
          'Colis non conforme : trop lourd · Armoire 3 portes. La commande est annulée ; le déplacement du '
          'livreur (500 F) est à votre charge. Un désaccord ? Appelez le service client.',
        ),
        findsOneWidget,
      );
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_refuse/${brightness.name}.png'));
    });

    goldenTest('06 suivi retour en cours ${brightness.name}', (tester) async {
      final realtime = FakeRealtime()..ack = const {'ok': true, 'position': halfway};
      final api = FakeClientApi()..tracked[orderId] = tracked('DELIVERY_FAILED', decision: 'RETURN');
      await pumpVariant(tester, variant, screen(api, realtime));
      await settle(tester);
      expect(find.text('Retour du colis'), findsOneWidget);
      expect(find.text('Jean M. vous rapporte le colis.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_retour/${brightness.name}.png'));
    });

    goldenTest('06 suivi livré étoiles ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, screen(apiAt('DELIVERED'), FakeRealtime()), surface: const Size(390, 1000));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('5 étoiles'));
      await settle(tester);
      expect(find.text('Parfait !'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_etoiles/${brightness.name}.png'));
    });

    goldenTest('06 suivi livré noté ${brightness.name}', (tester) async {
      final api = FakeClientApi()..tracked[orderId] = tracked('DELIVERED', rated: 5);
      await pumpVariant(tester, variant, screen(api, FakeRealtime()), surface: const Size(390, 1100));
      await settle(tester);
      expect(find.text('Merci pour votre note !'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_note/${brightness.name}.png'));
    });

    goldenTest('06 suivi livré ${brightness.name}', (tester) async {
      await pumpVariant(tester, variant, screen(apiAt('DELIVERED'), FakeRealtime()));
      await settle(tester);
      expect(find.text('Colis livré !'), findsNWidgets(2));
      expect(find.text('12 500 F encaissés'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/06_suivi_livre/${brightness.name}.png'));
    });
  }

  testWidgets('en direct : livreur trouvé, colis récupéré, livré — chaque étape s’annonce', (tester) async {
    final api = apiAt('SEARCHING_RIDER');
    final realtime = FakeRealtime();
    await pumpVariant(tester, Variant.matrix.first, screen(api, realtime));
    await settle(tester);
    expect(realtime.subscribed, [orderId]);
    expect(sounds.played, isEmpty);

    api.tracked[orderId] = tracked('ASSIGNED');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'ASSIGNED'});
    await settle(tester);
    expect(find.text('Jean M. vient chercher le colis'), findsOneWidget);
    expect(sounds.played, [TaraSound.received]);

    // Position du livreur : arrivée estimée à l'enlèvement (≈ 1,2 km).
    realtime.emit('rider.position', {'orderId': orderId, 'latitude': 4.0560, 'longitude': 9.7040});
    await settle(tester);
    expect(find.text('Environ 3 min'), findsOneWidget);
    // Une autre commande ne change rien.
    realtime.emit('order.status', {'orderId': 'autre', 'status': 'DELIVERED'});
    await settle(tester);

    api.tracked[orderId] = tracked('PICKED_UP');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'PICKED_UP'});
    await settle(tester);
    expect(find.text('En route vers Marie'), findsOneWidget);
    expect(sounds.played, [TaraSound.received, TaraSound.pickedUp]);

    api.tracked[orderId] = tracked('DELIVERED');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'DELIVERED'});
    await settle(tester);
    expect(sounds.played, [TaraSound.received, TaraSound.pickedUp, TaraSound.delivered]);
    expect(find.text('10:35 · en 23 min · Livré par Jean M.'), findsOneWidget);

    await tester.tap(find.text('Partager'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(shared.single.$1, 'Colis livré par Tara · TR-48301 · Marie Ngo · 10:35');

    await tester.pumpWidget(const SizedBox());
    expect(realtime.subscribed, isEmpty);
  });

  testWidgets('livré : noter le livreur, avec un mot pour l’équipe (F4)', (tester) async {
    final api = apiAt('DELIVERED');
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1200));
    await settle(tester);
    expect(find.text('Comment s’est passée la livraison ?'), findsOneWidget);
    expect(find.text('Envoyer ma note'), findsNothing);

    await tester.ensureVisible(find.bySemanticsLabel('4 étoiles'));
    await tester.tap(find.bySemanticsLabel('4 étoiles'));
    await settle(tester);
    expect(find.text('Bien'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('5 étoiles'));
    await settle(tester);
    expect(find.text('Parfait !'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '  Très aimable  ');
    await tester.ensureVisible(find.text('Envoyer ma note'));
    await tester.tap(find.text('Envoyer ma note'));
    await settle(tester);
    expect(api.ratings, [(orderId, 5, 'Très aimable')]);
    expect(sounds.played, [TaraSound.sent]);
    expect(find.text('Merci pour votre note !'), findsOneWidget);
    expect(find.text('Envoyer ma note'), findsNothing);
  });

  testWidgets('appeler le livreur, demander un nouveau code d’enlèvement', (tester) async {
    await pumpVariant(
      tester,
      Variant.matrix.first,
      screen(apiAt('ASSIGNED'), FakeRealtime()),
      surface: const Size(390, 1000),
    );
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Appeler Jean M.'));
    await settle(tester);
    expect(launched.single, Uri(scheme: 'tel', path: '+237677445566'));

    await tester.ensureVisible(find.text('Nouveau code d’enlèvement'));
    await tester.tap(find.text('Nouveau code d’enlèvement'));
    await settle(tester);
    expect(find.text('Code d’enlèvement : 5 1 9 0'), findsOneWidget);
  });

  testWidgets('annuler pendant la recherche : confirmation, puis annulée', (tester) async {
    final api = apiAt('SEARCHING_RIDER');
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1000));
    await settle(tester);
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, isEmpty);
    expect(find.text('Touchez encore pour confirmer l’annulation.'), findsOneWidget);
    api.tracked[orderId] = tracked('CANCELLED');
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, [orderId]);
    expect(find.text('Livraison annulée'), findsOneWidget);
  });

  testWidgets('livreur en route : l’annulation annonce son déplacement avant de confirmer', (tester) async {
    final api = FakeClientApi()..tracked[orderId] = tracked('ASSIGNED', cancellationFee: 300);
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1000));
    await settle(tester);
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, isEmpty);
    expect(
      find.text(
        'Le livreur est déjà en route : annuler coûte 300\u00a0F, pour son déplacement. Touchez encore pour confirmer.',
      ),
      findsOneWidget,
    );
    api.tracked[orderId] = tracked('CANCELLED');
    await tester.ensureVisible(find.text('Annuler la livraison'));
    await tester.tap(find.text('Annuler la livraison'));
    await settle(tester);
    expect(api.cancelled, [orderId]);
  });

  testWidgets('frais Mobile Money pas encore payés : relancer le paiement, puis la recherche démarre', (tester) async {
    final api = FakeClientApi()
      ..tracked[orderId] = tracked('CREATED', feePaymentMethod: 'MOMO_ORANGE', feePaid: false)
      ..paymentStatuses = ['PENDING', 'FAILED'];
    // Frais Mobile Money à 6 % : 1 500 F de course + 96 F de frais, comme à la commande.
    await pumpVariant(
      tester,
      Variant.matrix.first,
      screen(api, FakeRealtime(), store: storeWithMobileMoneyFee()),
      surface: const Size(390, 1000),
    );
    await settle(tester);
    expect(find.text('En attente du paiement'), findsOneWidget);
    expect(find.text('La demande de paiement part vers ce numéro Orange Money.'), findsOneWidget);
    expect(find.text('Annuler la livraison'), findsOneWidget);

    // Numéro incomplet : refusé avant toute demande.
    await tester.enterText(find.byType(EditableText), '655 44');
    await tester.tap(find.text('Payer 1\u00a0596 F par Mobile Money'));
    await settle(tester);
    expect(api.paid, isEmpty);

    // Première demande refusée sur le téléphone : on le dit, le bouton revient.
    await tester.enterText(find.byType(EditableText), '655 44 33 22');
    await tester.tap(find.text('Payer 1\u00a0596 F par Mobile Money'));
    await settle(tester);
    expect(api.paid, [(orderId: orderId, phone: '+237655443322', operator: 'ORANGE')]);
    expect(find.text('Validez la demande de paiement sur votre téléphone…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text('Paiement non abouti. Réessayez, ou annulez la livraison.'), findsOneWidget);

    // Deuxième demande validée : la commande est payée et cherche un livreur.
    api.paymentStatuses = ['SUCCEEDED'];
    api.tracked[orderId] = tracked('SEARCHING_RIDER', feePaymentMethod: 'MOMO_ORANGE');
    await tester.tap(find.text('Payer 1\u00a0596 F par Mobile Money'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(api.paid, hasLength(2));
    expect(find.text('Recherche d’un livreur…'), findsOneWidget);
    expect(find.textContaining('par Mobile Money'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('envoi de plusieurs colis : le suivi dit quel colis donner au livreur', (tester) async {
    final api = FakeClientApi()..tracked[orderId] = tracked('ASSIGNED', batchNumber: 2);
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1000));
    await settle(tester);
    expect(find.text('TR-48301 · n° 2'), findsOneWidget);
    expect(find.text('Jean M. vient chercher le colis n° 2'), findsOneWidget);
    expect(find.text('Donnez-lui le colis n° 2 et le code d’enlèvement à son arrivée.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('échec : motif, appeler le destinataire, choisir le retour et glisser', (tester) async {
    final api = apiAt('IN_DELIVERY');
    final realtime = FakeRealtime();
    await pumpVariant(tester, Variant.matrix.first, screen(api, realtime), surface: const Size(390, 1100));
    await settle(tester);

    // Le livreur déclare l'échec : son d'alerte, motif et heure limite.
    api.tracked[orderId] = tracked('DELIVERY_FAILED');
    realtime.emit('order.status', {'orderId': orderId, 'status': 'DELIVERY_FAILED'});
    await settle(tester);
    expect(sounds.played, [TaraSound.error]);
    expect(find.text('Destinataire absent · signalé par Jean M. à 10:18'), findsOneWidget);
    expect(find.text('Avant 10:33'), findsOneWidget);
    expect(find.text('Échec'), findsOneWidget);

    // Rien n'est choisi : glisser ne fait rien.
    expect(find.text('Choisissez une option'), findsOneWidget);
    await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
    await settle(tester);
    expect(api.decisions, isEmpty);

    await tester.ensureVisible(find.text('Pour Marie Ngo'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Appeler Marie'));
    await settle(tester);
    expect(launched.single, Uri(scheme: 'tel', path: '+237690112233'));

    await tester.tap(find.text('Retour du colis · 750\u00a0F'));
    await settle(tester);
    expect(find.text('Confirmer le retour'), findsOneWidget);
    api.tracked[orderId] = tracked('DELIVERY_FAILED', decision: 'RETURN');
    await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
    await settle(tester);
    expect(api.decisions, [(orderId, 'RETURN')]);
    expect(sounds.played, [TaraSound.error, TaraSound.sent]);
    expect(find.text('Jean M. vous rapporte le colis.'), findsOneWidget);
    expect(find.byType(SwipeButton), findsNothing);

    // Code de retour perdu : un nouveau.
    await tester.ensureVisible(find.text('Nouveau code de retour'));
    await tester.tap(find.text('Nouveau code de retour'));
    await settle(tester);
    expect(find.text('Code de retour : 5 1 9 0'), findsOneWidget);
  });

  testWidgets('échec : solde insuffisant, recharge Mobile Money puis nouvelle tentative', (tester) async {
    final api = apiAt('DELIVERY_FAILED')
      ..decisionError = const ApiException(
        code: 'RETRY_PAYMENT_REQUIRED',
        message: 'Solde insuffisant',
        status: 422,
        details: {'amount': 500},
      )
      ..paymentStatuses = ['PENDING', 'SUCCEEDED'];
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1100));
    await settle(tester);
    expect(find.text('Nouvelle tentative · 500\u00a0F'), findsOneWidget);
    expect(find.text('Retour du colis · 750\u00a0F'), findsOneWidget);
    await tester.tap(find.text('Nouvelle tentative · 500\u00a0F'));
    await settle(tester);
    await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
    await settle(tester);
    expect(api.decisions, isEmpty);
    expect(find.text('Rechargez 500 F pour la nouvelle tentative'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '677 11 22 33');
    await tester.tap(find.text('Payer 500 F'));
    await settle(tester);
    expect(api.topUps, [(500, '677112233', 'MTN')]);
    expect(find.textContaining('Validez le paiement de 500 F'), findsOneWidget);

    // Paiement validé : la nouvelle tentative est confirmée sans autre geste.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(api.decisions, [(orderId, 'RETRY')]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deuxième échec : plus de nouvelle tentative, seul le retour reste', (tester) async {
    final api = FakeClientApi()..tracked[orderId] = tracked('DELIVERY_FAILED', retryAllowed: false);
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1100));
    await settle(tester);
    expect(find.textContaining('Nouvelle tentative ·'), findsNothing);
    expect(find.textContaining('Une seule nouvelle tentative est possible'), findsOneWidget);
    expect(find.text('Retour du colis · 750\u00a0F'), findsOneWidget);
  });

  testWidgets('échec : déjà décidé ailleurs, l’écran montre la décision prise', (tester) async {
    final api = apiAt('DELIVERY_FAILED')..decisionError = Exception('conflit');
    await pumpVariant(tester, Variant.matrix.first, screen(api, FakeRealtime()), surface: const Size(390, 1100));
    await settle(tester);
    await tester.tap(find.text('Nouvelle tentative · 500\u00a0F'));
    await settle(tester);
    expect(find.text('Confirmer la tentative'), findsOneWidget);
    // Retour automatique passé entre-temps : la décision relue remplace le choix.
    api.tracked[orderId] = tracked('DELIVERY_FAILED', decision: 'RETURN');
    await tester.drag(find.byType(SwipeButton), const Offset(600, 0));
    await settle(tester);
    expect(api.decisions, isEmpty);
    expect(find.text('Jean M. vous rapporte le colis.'), findsOneWidget);
  });

  testWidgets('une livraison de l’accueil ouvre son suivi', (tester) async {
    final api = shopApi()..tracked['00000000-0000-4000-8000-000000000001'] = tracked('IN_DELIVERY');
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientApiProvider.overrideWithValue(api),
          realtimeProvider.overrideWithValue(FakeRealtime()),
          realMapProvider.overrideWithValue(false),
        ],
        child: HomeFlow(me: shopOwner, now: () => homeNow),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Marie Ngo · Bonapriso'));
    await settle(tester);
    expect(find.byType(TrackingScreen), findsOneWidget);
    expect(find.text('TR-48301'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await settle(tester);
    expect(find.byType(TrackingScreen), findsNothing);
  });

  testWidgets('au retour du réseau, la liste en erreur se recharge seule', (tester) async {
    final api = shopApi()..offline = true;
    final realtime = FakeRealtime();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientApiProvider.overrideWithValue(api),
          realtimeProvider.overrideWithValue(realtime),
          realMapProvider.overrideWithValue(false),
        ],
        child: HomeFlow(me: shopOwner, now: () => homeNow),
      ),
    );
    await settle(tester);
    // Coupure longue : les nouveaux essais automatiques s'arrêtent, l'erreur reste affichée.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 10));
    }
    expect(find.text('Impossible de charger vos livraisons.'), findsOneWidget);

    // Coupure puis retour du temps réel : réseau revenu.
    api.offline = false;
    realtime.connected.value = true;
    realtime.connected.value = false;
    realtime.connected.value = true;
    await settle(tester);
    expect(find.text('Impossible de charger vos livraisons.'), findsNothing);
    expect(find.text('Marie Ngo · Bonapriso'), findsOneWidget);
  });

  testWidgets('une notification touchée ouvre le suivi de sa commande', (tester) async {
    final api = shopApi()..tracked['00000000-0000-4000-8000-000000000001'] = tracked('IN_DELIVERY');
    final push = _FakePush();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientApiProvider.overrideWithValue(api),
          realtimeProvider.overrideWithValue(FakeRealtime()),
          realMapProvider.overrideWithValue(false),
          pushServiceProvider.overrideWithValue(push),
        ],
        child: HomeFlow(me: shopOwner, now: () => homeNow),
      ),
    );
    await settle(tester);
    expect(push.started, isTrue);
    expect(find.byType(TrackingScreen), findsNothing);

    push.tap({'type': 'order.status', 'orderId': '00000000-0000-4000-8000-000000000001'});
    await settle(tester);
    expect(find.byType(TrackingScreen), findsOneWidget);
    expect(find.text('TR-48301'), findsOneWidget);
  });
}

/// Notifications sans Firebase : on déclenche à la main le toucher d'une notification.
class _FakePush extends PushService {
  _FakePush() : super(register: (_) async {});

  final _tapped = StreamController<Json>.broadcast();
  bool started = false;

  void tap(Json data) => _tapped.add(data);

  @override
  Stream<Json> get opened => _tapped.stream;

  @override
  Future<void> start() async => started = true;
}
