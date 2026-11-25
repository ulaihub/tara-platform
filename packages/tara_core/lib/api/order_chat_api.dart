import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

/// Message entre l'expéditeur et le livreur d'une commande (schéma `OrderMessage`).
@immutable
class OrderChatMessage {
  const OrderChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.at,
    required this.read,
  });

  factory OrderChatMessage.fromJson(Json json) => OrderChatMessage(
    id: json['id']! as String,
    mine: json['mine']! as bool,
    body: json['body']! as String,
    at: DateTime.parse(json['createdAt']! as String),
    read: json['readAt'] != null,
  );
  static const fields = ['id', 'mine', 'authorRole', 'body', 'createdAt', 'readAt'];

  final String id;

  /// Écrit par la personne qui lit.
  final bool mine;
  final String body;
  final DateTime at;

  /// Lu par l'autre personne.
  final bool read;
}

/// Conversation d'une commande : messages, et si l'on peut encore écrire.
@immutable
class OrderChat {
  const OrderChat({required this.open, required this.messages});
  factory OrderChat.fromJson(Json json) => OrderChat(
    open: json['open']! as bool,
    messages: [
      for (final item in json['messages']! as List<Object?>) OrderChatMessage.fromJson(item! as Json),
    ],
  );

  final bool open;
  final List<OrderChatMessage> messages;
}

/// Messages d'une commande : même adresse pour l'expéditeur et pour le livreur.
class OrderChatApi {
  const OrderChatApi(this._api);
  final ApiClient _api;

  Future<OrderChat> conversation(String orderId) async =>
      OrderChat.fromJson(await _api.get('/orders/$orderId/messages') as Json);

  Future<OrderChatMessage> send(String orderId, String body) async =>
      OrderChatMessage.fromJson(await _api.post('/orders/$orderId/messages', body: {'body': body}) as Json);
}
