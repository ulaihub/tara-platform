import { Injectable } from '@nestjs/common';
import type { Namespace } from 'socket.io';

export const userRoom = (userId: string): string => `user:${userId}`;
export const orderRoom = (orderId: string): string => `order:${orderId}`;
/** Équipe des opérations connectée au back-office (dispatch, support). */
export const OPS_ROOM = 'ops';

/** Événements envoyés aux applications. Les noms font partie du contrat (docs/API.md). */
export type RealtimeEvent =
  | 'order.status'
  | 'order.message'
  | 'support.message'
  | 'ops.support-message'
  | 'rider.position'
  | 'offer.new'
  | 'offer.closed'
  | 'ops.dispatch-alert'
  | 'ops.safety-alert'
  | 'ops.delivery-validation'
  | 'ops.rider-position'
  | 'ops.sms-volume'
  | 'ops.finance-alert'
  | 'ops.course-alert'
  | 'payment.status'
  | 'payout.status'
  | 'safety-alert.status'
  | 'location-link.submitted'
  | 'session.expired';

/**
 * Envoi d'événements temps réel depuis n'importe quel service. Grâce à l'adaptateur Redis,
 * l'événement atteint les clients connectés à toutes les instances. Sans serveur temps réel
 * (génération de l'OpenAPI, scripts), les envois sont ignorés.
 */
@Injectable()
export class RealtimeService {
  private server: Namespace | null = null;

  attach(server: Namespace): void {
    this.server = server;
  }

  toUser(userId: string, event: RealtimeEvent, payload: object): void {
    this.server?.to(userRoom(userId)).emit(event, payload);
  }

  toOrder(orderId: string, event: RealtimeEvent, payload: object): void {
    this.server?.to(orderRoom(orderId)).emit(event, payload);
  }

  toOps(event: RealtimeEvent, payload: object): void {
    this.server?.to(OPS_ROOM).emit(event, payload);
  }
}
