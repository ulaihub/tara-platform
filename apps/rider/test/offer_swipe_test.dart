import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/features/home/home_summary.dart';
import 'package:tara_rider/features/map/tara_map.dart';
import 'package:tara_rider/features/offer/offer_screen.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_home_golden_test.dart' show summary;
import 'screens_online_golden_test.dart' show expiresAt, offer;

void main() {
  late FakeRiderApi api;
  late List<Object> accepted;

  Future<void> pumpOffer(WidgetTester tester) async {
    api = FakeRiderApi();
    accepted = [];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          realMapProvider.overrideWithValue(false),
          homeSummaryProvider.overrideWith((ref) async => summary),
          riderApiProvider.overrideWithValue(api),
        ],
        child: OfferScreen(
          offer: offer,
          onAccepted: accepted.add,
          onClosed: (_) {},
          now: () => expiresAt.subtract(const Duration(seconds: 18)),
        ),
      ),
    );
    await settle(tester);
  }

  final swipe = find.byType(SwipeButton);

  double knobLeft(WidgetTester tester) =>
      tester.getTopLeft(find.descendant(of: swipe, matching: find.byType(Container)).last).dx;

  testWidgets('un toucher ne fait que montrer le geste', (tester) async {
    await pumpOffer(tester);
    await tester.tap(swipe);
    await settle(tester);
    expect(api.accepted, isEmpty);
    expect(accepted, isEmpty);
  });

  testWidgets('glissée à moitié, la pastille revient sans accepter', (tester) async {
    await pumpOffer(tester);
    final start = knobLeft(tester);
    await tester.drag(swipe, Offset(tester.getSize(swipe).width * .4, 0));
    await settle(tester);
    expect(api.accepted, isEmpty);
    expect(knobLeft(tester), moreOrLessEquals(start, epsilon: .5));
  });

  testWidgets('glissée jusqu’au bout, la course est acceptée une fois', (tester) async {
    await pumpOffer(tester);
    // La sonnerie de la nouvelle course tourne jusqu'à la réponse.
    expect(sounds.looping, {TaraSound.offer});
    await tester.drag(swipe, Offset(tester.getSize(swipe).width, 0));
    await settle(tester);
    expect(api.accepted, [offer.id]);
    expect(accepted, hasLength(1));
    expect(sounds.looping, isEmpty);
    expect(sounds.played, [TaraSound.offer, TaraSound.accepted]);
  });

  testWidgets('acceptation refusée : message, pastille revenue, nouvel essai possible', (tester) async {
    await pumpOffer(tester);
    final start = knobLeft(tester);
    api.acceptError = Exception('réseau');
    await tester.drag(swipe, Offset(tester.getSize(swipe).width, 0));
    await settle(tester);
    expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
    expect(knobLeft(tester), moreOrLessEquals(start, epsilon: .5));
    expect(accepted, isEmpty);

    await tester.drag(swipe, Offset(tester.getSize(swipe).width, 0));
    await settle(tester);
    expect(api.accepted, hasLength(2));
    expect(accepted, hasLength(1));
  });

  testWidgets('les lecteurs d’écran acceptent d’un double toucher', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOffer(tester);
    expect(find.bySemanticsLabel('Glisser pour accepter'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Glisser pour accepter'));
    await settle(tester);
    expect(api.accepted, [offer.id]);
    semantics.dispose();
  });
}
