import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

/// Motif d'une demande au service client (même liste que le serveur).
enum SupportCategory {
  lostParcel('LOST_PARCEL'),
  damagedParcel('DAMAGED_PARCEL'),
  lateDelivery('LATE_DELIVERY'),
  payment('PAYMENT'),
  riderBehavior('RIDER_BEHAVIOR'),
  appBug('APP_BUG'),
  other('OTHER');

  const SupportCategory(this.code);
  final String code;

  static SupportCategory fromCode(String code) =>
      values.firstWhere((category) => category.code == code, orElse: () => SupportCategory.other);
}

/// État d'une demande vu par l'utilisateur.
enum SupportStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  closed('CLOSED');

  const SupportStatus(this.code);
  final String code;

  static SupportStatus fromCode(String code) =>
      values.firstWhere((status) => status.code == code, orElse: () => SupportStatus.open);

  /// Une demande close n'accepte plus de réponse (on en ouvre une nouvelle).
  bool get acceptsReplies => this != SupportStatus.closed;
}

@immutable
class SupportMessage {
  const SupportMessage({required this.id, required this.fromTara, required this.body, required this.at});
  factory SupportMessage.fromJson(Json json) => SupportMessage(
    id: json['id']! as String,
    fromTara: json['fromTara']! as bool,
    body: json['body']! as String,
    at: DateTime.parse(json['at']! as String),
  );
  static const fields = ['id', 'fromTara', 'body', 'at'];

  final String id;

  /// Réponse de l'équipe Tara (sinon, message de l'utilisateur).
  final bool fromTara;
  final String body;
  final DateTime at;
}

/// Demande au service client (schéma `Ticket` du contrat de l'API).
@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.category,
    required this.status,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.orderId,
    this.orderReference,
  });

  factory SupportTicket.fromJson(Json json) {
    final order = json['order'] as Json?;
    return SupportTicket(
      id: json['id']! as String,
      reference: json['reference']! as String,
      category: SupportCategory.fromCode(json['category']! as String),
      status: SupportStatus.fromCode(json['status']! as String),
      subject: json['subject']! as String,
      orderId: order?['id'] as String?,
      orderReference: order?['reference'] as String?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      messages: [for (final item in json['messages']! as List<Object?>) SupportMessage.fromJson(item! as Json)],
    );
  }
  static const fields = [
    'id',
    'reference',
    'category',
    'status',
    'subject',
    'order',
    'createdAt',
    'updatedAt',
    'messages',
  ];

  final String id;

  /// Numéro à donner au téléphone : SUP-1024.
  final String reference;
  final SupportCategory category;
  final SupportStatus status;
  final String subject;
  final String? orderId;
  final String? orderReference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessage> messages;

  /// La dernière réponse vient de Tara et l'utilisateur ne l'a pas encore commentée.
  bool get answered => messages.isNotEmpty && messages.last.fromTara;
}

/// Ce dont les écrans du service client ont besoin (remplacé par un faux dans les tests).
abstract interface class SupportBackend {
  Future<List<SupportTicket>> tickets();
  Future<SupportTicket> ticket(String id);
  Future<SupportTicket> open({
    required SupportCategory category,
    required String subject,
    required String message,
    String? orderId,
  });
  Future<SupportTicket> reply(String id, String body);
}

/// Demandes au service client : ouverture (sur une commande ou non), suivi, réponses.
class SupportApi implements SupportBackend {
  SupportApi(this._api);

  final ApiClient _api;

  @override
  Future<List<SupportTicket>> tickets() async => [
    for (final item in await _api.get('/support/tickets') as List<Object?>) SupportTicket.fromJson(item! as Json),
  ];

  @override
  Future<SupportTicket> ticket(String id) async =>
      SupportTicket.fromJson(await _api.get('/support/tickets/$id') as Json);

  @override
  Future<SupportTicket> open({
    required SupportCategory category,
    required String subject,
    required String message,
    String? orderId,
  }) async => SupportTicket.fromJson(
    await _api.post(
      '/support/tickets',
      body: {'category': category.code, 'subject': subject, 'message': message, 'orderId': ?orderId},
    ) as Json,
  );

  @override
  Future<SupportTicket> reply(String id, String body) async =>
      SupportTicket.fromJson(await _api.post('/support/tickets/$id/messages', body: {'body': body}) as Json);
}
