import 'dart:async';

import '../api/models.dart';
import '../offline/action_queue.dart';
import 'active_order.dart';

/// Issue d'une action de course.
enum ActionOutcome {
  /// Reçue par le serveur.
  sent,

  /// Sans réseau : gardée sur le téléphone, envoyée au retour du réseau.
  queued,

  /// Refusée par le serveur (code incorrect, code bloqué) : à corriger par le livreur.
  refused,
}

class ActionResult {
  const ActionResult(this.outcome, {this.actionId, this.code, this.message});

  final ActionOutcome outcome;

  /// Action refusée restée dans la file : la correction la renvoie.
  final String? actionId;
  final String? code;
  final String? message;
}

/// Actions du livreur sur sa course, passées par la file hors connexion : envoyées tout de
/// suite quand le réseau le permet, sinon gardées et rejouées sans doublon. L'état de la
/// course sur le téléphone avance aussitôt ; le serveur le confirme ensuite.
class CourseActions {
  CourseActions({required this.queue, required this.activeOrder, this.settleTimeout = const Duration(seconds: 8)});

  final ActionQueue queue;
  final ActiveOrderController activeOrder;

  /// Attente maximale de la réponse du serveur avant de continuer hors ligne.
  final Duration settleTimeout;

  /// Enlèvement (E3) : code de l'expéditeur et photo du colis, puis départ vers le
  /// destinataire. [retryActionId] : enlèvement refusé à renvoyer avec un code corrigé.
  Future<ActionResult> pickUp(
    RiderOrder order, {
    required String code,
    required String photoPath,
    required GeoPoint at,
    String? retryActionId,
  }) async {
    final position = {'latitude': at.latitude, 'longitude': at.longitude};
    final body = {'pickupCode': code, ...position};
    final previous = queue.items.where((action) => action.id == retryActionId).firstOrNull;
    String id;
    if (previous != null && previous.photoPath == photoPath) {
      // Même photo (déjà envoyée) : seul le code change.
      await queue.retry(previous.id, body: body);
      id = previous.id;
    } else {
      // Photo reprise : l'ancienne action est abandonnée, une nouvelle part.
      if (previous != null) await queue.discard(previous.id);
      id = (await queue.enqueue(orderId: order.id, kind: 'pickup', body: body, photoPath: photoPath)).id;
    }
    final action = await _settle(id);
    if (action != null && action.failed) {
      return ActionResult(
        ActionOutcome.refused,
        actionId: action.id,
        code: action.failureCode,
        message: action.failureMessage,
      );
    }
    // Un départ déjà en file (enlèvement corrigé après un refus) n'est pas doublé.
    final departQueued = queue.forOrder(order.id).any((item) => item.kind == 'depart' && !item.failed);
    if (!departQueued) await queue.enqueue(orderId: order.id, kind: 'depart', body: position);
    await activeOrder.update(order.withStatus('IN_DELIVERY'));
    return ActionResult(action == null ? ActionOutcome.sent : ActionOutcome.queued);
  }

  /// Attend l'envoi de l'action. Un envoi déjà en cours a pu partir sans elle : un second
  /// passage la prend. Renvoie l'action si elle est encore dans la file (sans réseau, ou
  /// refusée), null si le serveur l'a reçue.
  Future<QueuedAction?> _settle(String id) async {
    QueuedAction? find() => queue.items.where((item) => item.id == id).firstOrNull;
    Future<QueuedAction?> attempt() async {
      await queue.flush();
      final pending = find();
      if (pending != null && !pending.failed) await queue.flush();
      return find();
    }

    // Réseau très lent : on n'attend pas plus de quelques secondes, l'envoi continue.
    return attempt().timeout(settleTimeout, onTimeout: find);
  }

  /// Enlèvement refusé encore dans la file (écran rouvert, app relancée).
  QueuedAction? refusedPickup(String orderId) =>
      queue.forOrder(orderId).where((action) => action.kind == 'pickup' && action.failed).lastOrNull;
}
