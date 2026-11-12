import 'package:tara_core/api/support_api.dart';

/// Service client en mémoire pour les tests des apps : demandes ouvertes, réponses, et
/// réponse de l'équipe Tara simulée avec [answer].
class FakeSupportBackend implements SupportBackend {
  FakeSupportBackend({List<SupportTicket>? tickets}) : _tickets = [...?tickets];

  final List<SupportTicket> _tickets;

  /// Demandes envoyées (motif, titre, message, commande).
  final opened = <({SupportCategory category, String subject, String message, String? orderId})>[];
  final replies = <(String id, String body)>[];

  /// Heure des messages créés (fixe : captures reproductibles).
  DateTime now = DateTime.utc(2026, 11, 12, 9, 30);
  int _next = 1001;

  @override
  Future<List<SupportTicket>> tickets() async => [..._tickets.reversed];

  @override
  Future<SupportTicket> ticket(String id) async => _tickets.firstWhere((ticket) => ticket.id == id);

  @override
  Future<SupportTicket> open({
    required SupportCategory category,
    required String subject,
    required String message,
    String? orderId,
  }) async {
    opened.add((category: category, subject: subject, message: message, orderId: orderId));
    final number = _next++;
    final ticket = SupportTicket(
      id: 'ticket-$number',
      reference: 'SUP-$number',
      category: category,
      status: SupportStatus.open,
      subject: subject,
      orderId: orderId,
      orderReference: orderId == null ? null : 'TR-48301',
      createdAt: now,
      updatedAt: now,
      messages: [SupportMessage(id: 'm-$number-1', fromTara: false, body: message, at: now)],
    );
    _tickets.add(ticket);
    return ticket;
  }

  @override
  Future<SupportTicket> reply(String id, String body) async {
    replies.add((id, body));
    return _update(
      id,
      (ticket) => [
        ...ticket.messages,
        SupportMessage(id: 'm-$id-${ticket.messages.length + 1}', fromTara: false, body: body, at: now),
      ],
      status: _statusAfterReply(id),
    );
  }

  /// Comme le serveur : une demande résolue est rouverte par la réponse du client.
  SupportStatus _statusAfterReply(String id) {
    final status = _tickets.firstWhere((ticket) => ticket.id == id).status;
    return status == SupportStatus.resolved ? SupportStatus.open : status;
  }

  /// L'équipe Tara répond : la demande passe « en cours ».
  SupportTicket answer(String id, String body, {SupportStatus status = SupportStatus.inProgress}) => _update(
    id,
    (ticket) => [
      ...ticket.messages,
      SupportMessage(id: 'm-$id-${ticket.messages.length + 1}', fromTara: true, body: body, at: now),
    ],
    status: status,
  );

  SupportTicket _update(
    String id,
    List<SupportMessage> Function(SupportTicket ticket) messages, {
    required SupportStatus status,
  }) {
    final index = _tickets.indexWhere((ticket) => ticket.id == id);
    final old = _tickets[index];
    final updated = SupportTicket(
      id: old.id,
      reference: old.reference,
      category: old.category,
      status: status,
      subject: old.subject,
      orderId: old.orderId,
      orderReference: old.orderReference,
      createdAt: old.createdAt,
      updatedAt: now,
      messages: messages(old),
    );
    _tickets[index] = updated;
    return updated;
  }
}
