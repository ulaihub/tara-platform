import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/order_chat_api.dart';
import 'package:tara_ui/components/order_chat.dart';

import 'helpers/harness.dart';

/// Conversation avec le livreur : bulles, « Lu », réponses rapides, message reçu en direct.
void main() {
  setUpAll(loadAppFonts);

  final at = DateTime(2026, 11, 25, 10, 5);
  OrderChatMessage message(String id, String body, {required bool mine, int minutes = 0, bool read = false}) =>
      OrderChatMessage(id: id, mine: mine, body: body, at: at.add(Duration(minutes: minutes)), read: read);

  for (final brightness in [Brightness.dark, Brightness.light]) {
    goldenTest('discussion avec le livreur ${brightness.name}', (tester) async {
      final live = StreamController<OrderChatMessage>.broadcast();
      final sent = <String>[];
      // Le serveur garde tout : la conversation relue montre aussi les nouveaux messages.
      final stored = [
        message('1', 'Le colis est au comptoir, demandez Awa.', mine: true, read: true),
        message('2', 'D’accord, j’arrive dans 5 min.', mine: false, minutes: 1),
      ];
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        OrderChatScreen(
          load: () async => OrderChat(open: true, messages: [...stored]),
          send: (body) async {
            sent.add(body);
            final created = message('3', body, mine: true, minutes: 2);
            stored.add(created);
            return created;
          },
          incoming: live.stream,
          onBack: () {},
          strings: OrderChatStrings(
            back: 'Retour',
            title: 'Jean M.',
            subtitle: 'Livreur · TR-48301',
            hint: 'Votre message…',
            send: 'Envoyer',
            empty: 'Aucun message.',
            closed: 'Conversation fermée.',
            read: 'Lu',
            quickReplies: const ['Le colis est prêt', 'Je descends', 'Appelez-moi en arrivant'],
            when: (at) => '${at.hour}:${at.minute.toString().padLeft(2, '0')}',
            errorText: (error) => '$error',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('10:05 · Lu'), findsOneWidget);

      // Réponse rapide : envoyée telle quelle.
      await tester.tap(find.text('Je descends'));
      await settle(tester);
      expect(sent, ['Je descends']);

      // Message du livreur reçu en direct : il apparaît sans recharger.
      final incoming = message('4', 'Je suis devant le portail.', mine: false, minutes: 3);
      stored.add(incoming);
      live.add(incoming);
      await settle(tester);
      expect(find.text('Je suis devant le portail.'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/07_discussion_livreur/${brightness.name}.png'));
      await live.close();
    });
  }
}
