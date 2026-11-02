import { Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { OrderEventsBus } from '../events/order-events.bus.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { RiderOrdersService } from './rider-orders.service.js';

/**
 * Décisions humaines sur une course en cours : validation d'une livraison sans code par le
 * support (E4) et choix de l'expéditeur après un échec de livraison (E6).
 */
@Injectable()
export class OrderSupportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly transitions: OrderTransitionsService,
    private readonly riderOrders: RiderOrdersService,
    private readonly bus: OrderEventsBus,
    private readonly notifications: NotificationService,
    private readonly realtime: RealtimeService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Le support a appelé le destinataire et confirme la remise. Au-delà de
   * SUPPORT_VALIDATION_LIMIT à encaisser, seul un administrateur peut valider.
   */
  async validateDelivery(user: AuthUser, orderId: string, note: string, request: Request): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const awaiting = await this.riderOrders.awaitingValidation([orderId]);
    if (!awaiting.has(orderId)) throw AppError.conflict('NO_DELIVERY_VALIDATION_REQUEST');
    const toCollect = order.codAmount + (order.feePayer === 'RECIPIENT' ? order.totalPrice : 0);
    if (toCollect > this.env.SUPPORT_VALIDATION_LIMIT && !user.roles.includes('ADMIN')) {
      throw AppError.forbidden('DELIVERY_VALIDATION_ADMIN_REQUIRED');
    }
    const change = await this.prisma.$transaction(async (tx) => {
      const proof = await tx.deliveryProof.findFirstOrThrow({
        where: { orderId, kind: 'DELIVERY', codeVerified: false, supportValidatorId: null },
        orderBy: { recordedAt: 'desc' },
      });
      await tx.deliveryProof.update({ where: { id: proof.id }, data: { supportValidatorId: user.id } });
      const result = await this.transitions.applyIn(
        tx,
        order,
        'DELIVERED',
        { id: user.id, role: 'SUPPORT' },
        { note, latitude: proof.latitude, longitude: proof.longitude, occurredAt: proof.occurredAt },
      );
      await this.audit.record(
        {
          actor: user,
          action: 'order.delivery-validated',
          entityType: 'order',
          entityId: orderId,
          before: { status: order.status },
          after: { status: 'DELIVERED', proofId: proof.id, note, toCollect },
          request,
        },
        tx,
      );
      return result.change;
    });
    await this.bus.publish(change);
  }

  /** L'expéditeur choisit, après un échec : nouvelle tentative ou retour du colis. */
  async failureDecision(user: AuthUser, orderId: string, decision: 'RETRY' | 'RETURN'): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { rider: { select: { userId: true } } },
    });
    if (order?.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    const { count } = await this.prisma.order.updateMany({
      where: { id: orderId, status: 'DELIVERY_FAILED' },
      data: { failureDecision: decision },
    });
    if (count !== 1) throw AppError.conflict('FAILURE_DECISION_NOT_EXPECTED');
    const event = {
      orderId,
      reference: order.reference,
      status: 'DELIVERY_FAILED',
      failureDecision: decision,
      at: new Date().toISOString(),
    };
    this.realtime.toOrder(orderId, 'order.status', event);
    if (order.rider) {
      this.realtime.toUser(order.rider.userId, 'order.status', event);
      await this.notifications.toUser(order.rider.userId, {
        template: 'RIDER_FAILURE_DECISION',
        params: {
          reference: order.reference,
          decision: decision === 'RETRY' ? 'nouvelle tentative' : 'retour à l’expéditeur',
        },
        data: { type: 'order.failure-decision', orderId, decision },
        orderId,
      });
    }
  }
}
