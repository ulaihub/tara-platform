import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../offline/action_queue.dart';
import 'active_order.dart';

/// Livraison préparée à l'écran 09, envoyée juste après l'encaissement (12).
@immutable
class DeliveryDraft {
  const DeliveryDraft({required this.photoPath, this.code, this.receivedBy, this.retryActionId});

  final String photoPath;
  final String? code;
  final String? receivedBy;

  /// Livraison refusée à corriger (code faux).
  final String? retryActionId;
}

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
  CourseActions({
    required this.queue,
    required this.activeOrder,
    this.locate,
    this.settleTimeout = const Duration(seconds: 8),
  });

  final ActionQueue queue;
  final ActiveOrderController activeOrder;

  /// Position du moment, jointe aux actions (dernière connue, sinon mesurée).
  final Future<GeoPoint?> Function()? locate;

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
    final action = await _send(
      order,
      kind: 'pickup',
      body: {'pickupCode': code, ...position},
      photoPath: photoPath,
      retryActionId: retryActionId,
    );
    if (action != null && action.failed) return _refusal(action);
    // Un départ déjà en file (enlèvement corrigé après un refus) n'est pas doublé.
    final departQueued = queue.forOrder(order.id).any((item) => item.kind == 'depart' && !item.failed);
    if (!departQueued) await queue.enqueue(orderId: order.id, kind: 'depart', body: position);
    await activeOrder.update(order.withStatus('IN_DELIVERY'));
    return ActionResult(action == null ? ActionOutcome.sent : ActionOutcome.queued);
  }

  /// Livraison (E4) : code du destinataire, ou sans code le nom de la personne qui reçoit
  /// (le support appelle le client avant de valider) ; photo de remise dans les deux cas.
  Future<ActionResult> deliver(
    RiderOrder order, {
    String? code,
    String? receivedBy,
    required String photoPath,
    required GeoPoint at,
    String? retryActionId,
  }) async {
    final action = await _send(
      order,
      kind: 'deliver',
      body: {'deliveryCode': ?code, 'receivedBy': ?receivedBy, 'latitude': at.latitude, 'longitude': at.longitude},
      photoPath: photoPath,
      retryActionId: retryActionId,
      // Passage avec ou sans code : la nouvelle action remplace l'ancienne.
      sameMode: (previous) => previous.body.containsKey('deliveryCode') == (code != null),
    );
    if (action != null && action.failed) return _refusal(action);
    if (action == null && code != null) {
      // Reçue avec le code : la course est livrée et quitte le téléphone.
      await activeOrder.update(order.withStatus('DELIVERED'));
      return const ActionResult(ActionOutcome.sent);
    }
    await activeOrder.update(
      order.withChanges({
        if (code == null) 'awaitingSupportValidation': true,
        if (action != null) RiderOrder.deliveryQueuedKey: true,
      }),
    );
    return ActionResult(action == null ? ActionOutcome.sent : ActionOutcome.queued);
  }

  /// Encaissement en espèces puis livraison, dans cet ordre : le serveur refuse une livraison
  /// tant que tout n'est pas encaissé. Sans réseau, les deux partent ensemble au retour du
  /// réseau, l'encaissement d'abord.
  Future<ActionResult> collectCashAndDeliver(RiderOrder order, DeliveryDraft draft, {required GeoPoint at}) async {
    final pending = queue.forOrder(order.id).where((action) => action.kind == 'collect' && !action.failed).firstOrNull;
    final id =
        pending?.id ??
        (await queue.enqueue(
          orderId: order.id,
          kind: 'collect',
          body: {'method': 'CASH', 'latitude': at.latitude, 'longitude': at.longitude},
        )).id;
    final collect = await _settle(id);
    if (collect != null && collect.failed) {
      // Déjà payé (Mobile Money confirmé entre-temps) : rien à encaisser, on livre.
      if (collect.failureCode != 'COLLECTION_NOT_EXPECTED') return _refusal(collect);
      await queue.discard(collect.id);
    }
    return deliverDraft(order, draft, at: at);
  }

  /// Livraison préparée (après un encaissement Mobile Money confirmé, ou sans argent dû).
  Future<ActionResult> deliverDraft(RiderOrder order, DeliveryDraft draft, {required GeoPoint at}) => deliver(
    order,
    code: draft.code,
    receivedBy: draft.receivedBy,
    photoPath: draft.photoPath,
    at: at,
    retryActionId: draft.retryActionId,
  );

  /// Échec de livraison (E6) : motif, photo du lieu et journal des appels. L'expéditeur
  /// choisit ensuite nouvelle tentative ou retour ; sans réponse, retour automatique.
  Future<ActionResult> fail(
    RiderOrder order, {
    required String reason,
    String? note,
    required List<Json> callLog,
    required String photoPath,
    required GeoPoint at,
    Duration decisionTimeout = const Duration(minutes: 15),
    String? retryActionId,
  }) async {
    final action = await _send(
      order,
      kind: 'fail',
      body: {'reason': reason, 'note': ?note, 'callLog': callLog, 'latitude': at.latitude, 'longitude': at.longitude},
      photoPath: photoPath,
      retryActionId: retryActionId,
    );
    if (action != null && action.failed) return _refusal(action);
    final now = DateTime.now();
    await activeOrder.update(
      order.withChanges({
        'status': 'DELIVERY_FAILED',
        'failureReason': reason,
        'failureDecision': null,
        'failedAt': isoUtc(now),
        'failureDecisionDueAt': isoUtc(now.add(decisionTimeout)),
      }),
    );
    return ActionResult(action == null ? ActionOutcome.sent : ActionOutcome.queued);
  }

  /// Nouvelle tentative demandée par l'expéditeur : retour vers le destinataire (écran 09).
  Future<ActionResult> retryDelivery(RiderOrder order, {required GeoPoint at}) async {
    final action = await queue.enqueue(
      orderId: order.id,
      kind: 'retry',
      body: {'latitude': at.latitude, 'longitude': at.longitude},
    );
    final settled = await _settle(action.id);
    if (settled != null && settled.failed) return _refusal(settled);
    await activeOrder.update(order.withChanges({'status': 'IN_DELIVERY', 'failureDecision': null}));
    return ActionResult(settled == null ? ActionOutcome.sent : ActionOutcome.queued);
  }

  /// Colis rendu à l'expéditeur (écran 11) : code de retour qu'il a reçu par SMS, photo.
  Future<ActionResult> returnToSender(
    RiderOrder order, {
    required String code,
    required String photoPath,
    required GeoPoint at,
    String? retryActionId,
  }) async {
    final action = await _send(
      order,
      kind: 'return',
      body: {'senderCode': code, 'latitude': at.latitude, 'longitude': at.longitude},
      photoPath: photoPath,
      retryActionId: retryActionId,
    );
    if (action != null && action.failed) return _refusal(action);
    if (action == null) {
      // Reçu : la course est terminée et quitte le téléphone.
      await activeOrder.update(order.withStatus('RETURNED'));
      return const ActionResult(ActionOutcome.sent);
    }
    await activeOrder.update(order.withChanges({RiderOrder.returnQueuedKey: true}));
    return const ActionResult(ActionOutcome.queued);
  }

  /// Action refusée de cette sorte encore dans la file (écran rouvert, app relancée).
  QueuedAction? refused(String orderId, String kind) =>
      queue.forOrder(orderId).where((action) => action.kind == kind && action.failed).lastOrNull;

  /// Position jointe aux actions.
  Future<GeoPoint?> position() async => locate?.call();

  /// Envoie une action (ou la corrige après un refus) puis attend la réponse du serveur.
  Future<QueuedAction?> _send(
    RiderOrder order, {
    required String kind,
    required Json body,
    required String photoPath,
    String? retryActionId,
    bool Function(QueuedAction previous)? sameMode,
  }) async {
    final previous = queue.items.where((action) => action.id == retryActionId).firstOrNull;
    String id;
    if (previous != null && previous.photoPath == photoPath && (sameMode?.call(previous) ?? true)) {
      // Même photo (déjà envoyée) : seul le code change.
      await queue.retry(previous.id, body: body);
      id = previous.id;
    } else {
      // Photo reprise ou mode changé : l'ancienne action est abandonnée, une nouvelle part.
      // Même photo : elle est gardée, et réutilisée telle quelle si elle a déjà été envoyée.
      final samePhoto = previous?.photoPath == photoPath;
      final uploaded = samePhoto ? previous?.body['photoKey'] : null;
      if (previous != null) await queue.discard(previous.id, keepPhoto: samePhoto);
      id = (await queue.enqueue(
        orderId: order.id,
        kind: kind,
        body: {...body, 'photoKey': ?uploaded},
        photoPath: photoPath,
      )).id;
    }
    return _settle(id);
  }

  static ActionResult _refusal(QueuedAction action) => ActionResult(
    ActionOutcome.refused,
    actionId: action.id,
    code: action.failureCode,
    message: action.failureMessage,
  );

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
}
