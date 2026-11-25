import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:tara_core/api/order_chat_api.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/order_chat.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// Messages avec l'expéditeur d'une commande.
final orderChatApiProvider = Provider<OrderChatApi>((ref) => OrderChatApi(ref.watch(apiClientProvider)));

/// Messages reçus en direct : non lus par commande (pastille sur « Écrire »), et relayés à
/// la conversation ouverte.
final chatInboxProvider = ChangeNotifierProvider<ChatInbox>((ref) {
  // Le fournisseur libère la boîte lui-même à sa fermeture.
  return ChatInbox(ref.watch(realtimeProvider).stream);
});

class ChatInbox extends ChangeNotifier {
  ChatInbox(Stream<RealtimeEvent> events) {
    _events = events.listen((event) {
      if (event.name != 'order.message') return;
      final orderId = event.payload['orderId'];
      final message = event.payload['message'];
      if (orderId is! String || message is! Map) return;
      _incoming.add((orderId: orderId, message: OrderChatMessage.fromJson(Map<String, Object?>.from(message))));
      if (orderId != _openFor) {
        _unread[orderId] = (_unread[orderId] ?? 0) + 1;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<RealtimeEvent> _events;
  final _incoming = StreamController<({String orderId, OrderChatMessage message})>.broadcast();
  final _unread = <String, int>{};
  String? _openFor;

  int unread(String orderId) => _unread[orderId] ?? 0;

  Stream<OrderChatMessage> messagesFor(String orderId) =>
      _incoming.stream.where((item) => item.orderId == orderId).map((item) => item.message);

  void opened(String? orderId) {
    _openFor = orderId;
    if (orderId != null && _unread.remove(orderId) != null) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    unawaited(_incoming.close());
    super.dispose();
  }
}

/// Ouvre la conversation avec l'expéditeur de la commande.
Future<void> openOrderChat(BuildContext context, WidgetRef ref, RiderOrder order) async {
  final l = AppLocalizations.of(context);
  final api = ref.read(orderChatApiProvider);
  final inbox = ref.read(chatInboxProvider)..opened(order.id);
  final name = order.sender.name ?? order.pickup.contactName ?? order.reference;
  final when = DateFormat('HH:mm', l.localeName);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => OrderChatScreen(
        load: () => api.conversation(order.id),
        send: (body) => api.send(order.id, body),
        incoming: inbox.messagesFor(order.id),
        onBack: () => Navigator.of(context).pop(),
        strings: OrderChatStrings(
          back: l.back,
          title: name,
          subtitle: l.chatSubtitle(order.reference),
          hint: l.chatHint,
          send: l.chatSend,
          empty: l.chatEmpty,
          closed: l.chatClosed,
          read: l.chatRead,
          quickReplies: [l.chatQuick1, l.chatQuick2, l.chatQuick3, l.chatQuick4],
          when: when.format,
          errorText: (error) => errorMessage(context, error),
        ),
      ),
    ),
  );
  inbox.opened(null);
}

/// Message reçu hors de la conversation : son discret (la pastille reste sur « Écrire »).
void chatChime(BuildContext context) => TaraFeedback.play(context, TaraSound.received);
