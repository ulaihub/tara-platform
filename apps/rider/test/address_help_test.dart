import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/course/address_help.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_course_golden_test.dart' show delivery, scope;

class FakeNotePlayer implements VoiceNotePlayer {
  final played = <Uint8List>[];
  int stops = 0;

  @override
  Future<void> play(Uint8List bytes) async => played.add(bytes);

  @override
  Future<void> stop() async => stops++;

  @override
  Stream<void> get completed => const Stream.empty();
}

/// Lecteur factice dans une portée enfant : le reste (API factice…) vient de [scope].
Widget withMedia(FakeRiderApi api, FakeNotePlayer player) => scope(
  ProviderScope(
    overrides: [voiceNotePlayerProvider.overrideWithValue(player)],
    child: delivery(order(status: 'IN_DELIVERY', dropoffMedia: true)),
  ),
  api: api,
);

void main() {
  setUpAll(loadAppFonts);

  goldenTest('09 livraison avec photo et note de l’adresse', (tester) async {
    const variant = Variant(Brightness.dark, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, withMedia(FakeRiderApi(), FakeNotePlayer()));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(capture, matchesGoldenFile('goldens/09_livraison/medias_${variant.name}.png'));
  });

  testWidgets('photo de la façade en grand, téléchargée une seule fois', (tester) async {
    final api = FakeRiderApi();
    await pumpVariant(tester, Variant.matrix.first, withMedia(api, FakeNotePlayer()));
    await settle(tester);
    await tester.tap(find.text('Voir la façade'));
    await settle(tester);
    expect(find.bySemanticsLabel('Façade · Paul Ekwalla'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await settle(tester);
    await tester.tap(find.text('Voir la façade'));
    await settle(tester);
    expect(api.mediaFetched, [('00000000-0000-4000-8000-000000000002', 'dropoff', 'photo')]);
  });

  testWidgets('note vocale écoutée puis arrêtée', (tester) async {
    final api = FakeRiderApi();
    final player = FakeNotePlayer();
    await pumpVariant(tester, Variant.matrix.first, withMedia(api, player));
    await settle(tester);
    await tester.tap(find.text('Écouter la note'));
    await settle(tester);
    expect(player.played, hasLength(1));
    await tester.tap(find.text('Arrêter la note'));
    await settle(tester);
    expect(player.stops, 1);
    expect(find.text('Écouter la note'), findsOneWidget);
  });

  testWidgets('sans photo ni note : rien de plus à l’écran', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, scope(delivery(order(status: 'IN_DELIVERY'))));
    await settle(tester);
    expect(find.text('Voir la façade'), findsNothing);
    expect(find.text('Écouter la note'), findsNothing);
  });
}
