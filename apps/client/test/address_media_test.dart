import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_client/core/media/address_media.dart';
import 'package:tara_client/features/order/address_editor.dart';
import 'package:tara_client/features/order/address_media_section.dart';

import 'helpers/fake_client_api.dart';
import 'helpers/harness.dart';
import 'screens_new_order_golden_test.dart' show orderApi, overrides;

class _Recorder implements VoiceRecorder {
  _Recorder({this.allowed = true});
  final bool allowed;
  int started = 0;

  @override
  Future<bool> start() async {
    if (allowed) started++;
    return allowed;
  }

  @override
  Future<String?> stop() async => '/tmp/tara-note-$started.m4a';

  @override
  Future<void> cancel() async {}
}

class _Player implements NotePlayer {
  final played = <String>[];

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async {}

  @override
  Stream<void> get completed => const Stream.empty();
}

late String photoPath;

Widget editor(FakeClientApi api, {VoiceRecorder? recorder, NotePlayer? player, List<Address>? saved}) => ProviderScope(
  overrides: [
    ...overrides(api),
    takeFacadePhotoProvider.overrideWithValue(() async => photoPath),
    voiceRecorderProvider.overrideWithValue(recorder ?? _Recorder()),
    notePlayerProvider.overrideWithValue(player ?? _Player()),
  ],
  child: AddressEditor(title: 'Adresse de livraison', onBack: () {}, onSaved: (a) => saved?.add(a)),
);

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text).first, 80, scrollable: find.byType(Scrollable).last);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final file = File('${Directory.systemTemp.createTempSync('tara').path}/facade.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
    photoPath = file.path;
  });

  testWidgets('photo et note vocale envoyées avec l’adresse', (tester) async {
    final api = orderApi();
    final player = _Player();
    await pumpVariant(tester, Variant.matrix.first, editor(api, player: player));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Portail bleu après la pharmacie');
    await reveal(tester, 'Photo de la façade');
    await tester.tap(find.byKey(facadePhotoKey));
    await settle(tester);
    expect(find.bySemanticsLabel('Photo de la façade prise, Reprendre'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsOneWidget);

    await reveal(tester, 'Enregistrer une note vocale');
    await tester.tap(find.byKey(voiceNoteKey));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Enregistrement… 0:04 / 0:30'), findsOneWidget);
    await tester.tap(find.byKey(voiceNoteKey));
    await settle(tester);
    expect(find.text('Note vocale · 0:04'), findsOneWidget);
    await tester.tap(find.byKey(voiceNoteKey));
    await settle(tester);
    expect(player.played, ['/tmp/tara-note-1.m4a']);

    await tester.tap(find.text('Valider ce point'));
    await settle(tester);
    expect(api.uploads, [(photoPath, 'ADDRESS_PHOTO'), ('/tmp/tara-note-1.m4a', 'VOICE_NOTE')]);
    expect(api.createdAddresses.single['photoKey'], 'address/address_photo-1');
    expect(api.createdAddresses.single['voiceNoteKey'], 'address/voice_note-2');
  });

  for (final variant in [Variant.matrix.first, const Variant(Brightness.light, ScreenSize.regular, 1)]) {
    goldenTest('photo prise et note enregistrée ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, editor(orderApi()));
      await settle(tester);
      await reveal(tester, 'Photo de la façade');
      await tester.tap(find.byKey(facadePhotoKey));
      // Lecture du fichier et décodage de l'image : en temps réel, hors de l'horloge du test.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      await reveal(tester, 'Enregistrer une note vocale');
      await tester.tap(find.byKey(voiceNoteKey));
      await tester.pump(const Duration(seconds: 12));
      await tester.tap(find.byKey(voiceNoteKey));
      await settle(tester);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/05_adresse_carte/medias_${variant.name}.png'));
    });
  }

  testWidgets('la note s’arrête d’elle-même à 30 secondes', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, editor(orderApi()));
    await settle(tester);
    await reveal(tester, 'Enregistrer une note vocale');
    await tester.tap(find.byKey(voiceNoteKey));
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);
    expect(find.textContaining('Enregistrement…'), findsNothing);
    expect(find.text('Note vocale · 0:30'), findsOneWidget);
  });

  testWidgets('sans photo ni note, l’adresse s’enregistre comme avant ; micro refusé expliqué', (tester) async {
    final api = orderApi();
    await pumpVariant(tester, Variant.matrix.first, editor(api, recorder: _Recorder(allowed: false)));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Portail bleu');
    await reveal(tester, 'Enregistrer une note vocale');
    await tester.tap(find.byKey(voiceNoteKey));
    await settle(tester);
    expect(find.textContaining('Micro refusé'), findsOneWidget);
    await tester.tap(find.text('Valider ce point'));
    await settle(tester);
    expect(api.uploads, isEmpty);
    expect(api.createdAddresses.single.containsKey('photoKey'), isFalse);
  });
}
