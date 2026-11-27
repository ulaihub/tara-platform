import { Inject, Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { OrderEventsBus } from '../events/order-events.bus.js';
import { OrderFinanceService } from '../finance/order-finance.service.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { RiderOrdersService } from './rider-orders.service.js';

type Decision = 'RETRY' | 'RETURN' | 'OFFICE';

const DECISION_TEXT = {
  SENDER: {
    RETRY: 'nouvelle tentative',
    RETURN: 'retour à l’expéditeur (payé)',
    OFFICE: 'colis gardé au bureau Tara',
  },
  SUPPORT: {
    RETRY: 'nouvelle tentative, choisie par le support Tara',
    RETURN: 'retour à l’expéditeur (payé), choisi par le support Tara',
    OFFICE: 'le colis part au bureau Tara, choisi par le support Tara',
  },
  SYSTEM: {
    RETRY: 'nouvelle tentative',
    RETURN: 'retour à l’expéditeur (payé par son solde), sans réponse dans le délai',
    OFFICE: 'retour non payé dans le délai : le colis part au bureau Tara',
  },
} as const;

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
    private readonly finance: OrderFinanceService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Le support a appelé le destinataire et confirme la remise. Au-delà de
   * SUPPORT_VALIDATION_LIMIT à encaisser, seul un administrateur peut valider.
   */
  async validateDelivery(
    user: AuthUser,
    orderId: string,
    note: string,
    request: Request,
  ): Promise<void> {
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
      await tx.deliveryProof.update({
        where: { id: proof.id },
        data: { supportValidatorId: user.id },
      });
      const result = await this.transitions.applyIn(
        tx,
        order,
        'DELIVERED',
        { id: user.id, role: 'SUPPORT' },
        {
          note,
          latitude: proof.latitude,
          longitude: proof.longitude,
          occurredAt: proof.occurredAt,
        },
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

  /** Choix de l'expéditeur après un échec : nouvelle tentative ou retour (E6). */
  async failureDecision(
    user: AuthUser,
    orderId: string,
    decision: 'RETRY' | 'RETURN',
  ): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (order?.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    await this.decide(orderId, decision, 'SENDER');
  }

  /**
   * Le support choisit à la place de l'expéditeur (expéditeur joint par téléphone, ou
   * injoignable alors que le livreur attend avec le colis). Action tracée.
   */
  async failureDecisionForSender(
    user: AuthUser,
    orderId: string,
    decision: Decision,
    request: Request,
  ): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    await this.decide(orderId, decision, 'SUPPORT');
    await this.audit.record({
      actor: user,
      action: 'order.failure-decision',
      entityType: 'order',
      entityId: orderId,
      before: { failureDecision: order.failureDecision },
      after: { failureDecision: decision },
      request,
    });
  }

  @Cron('*/30 * * * * *', { name: 'failure-decision-sweep' })
  async scheduledSweep(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.sweepFailures();
  }

  /**
   * Sans décision de l'expéditeur dans le délai (FAILURE_DECISION_TIMEOUT_MINUTES) : retour
   * chez lui si son solde le paie, sinon colis au bureau Tara ; le livreur n'attend pas.
   */
  async sweepFailures(now = new Date()): Promise<number> {
    const due = await this.prisma.order.findMany({
      where: {
        status: 'DELIVERY_FAILED',
        failureDecision: null,
        failedAt: {
          lte: new Date(now.getTime() - this.env.FAILURE_DECISION_TIMEOUT_MINUTES * 60_000),
        },
      },
      select: { id: true },
      take: 100,
    });
    let returned = 0;
    for (const { id } of due) {
      if (await this.decide(id, 'RETURN', 'SYSTEM')) returned++;
    }
    return returned;
  }

  /**
   * Enregistre la décision, puis prévient le livreur (et l'expéditeur s'il n'a pas choisi).
   * Retour sans dette : ses frais sont pris d'avance sur l'argent disponible ; s'il ne suffit
   * pas, l'expéditeur paie le reste par Mobile Money (rien n'est enregistré), et sans
   * paiement à temps (retour automatique, support) le colis part au bureau Tara.
   */
  private async decide(
    orderId: string,
    wanted: Decision,
    by: 'SENDER' | 'SUPPORT' | 'SYSTEM',
  ): Promise<boolean> {
    const decision = await this.prisma.$transaction(async (tx): Promise<Decision | null> => {
      await tx.$executeRaw`SELECT id FROM orders WHERE id = ${orderId}::uuid FOR UPDATE`;
      const current = await tx.order.findUnique({ where: { id: orderId } });
      if (current?.status !== 'DELIVERY_FAILED') return null;
      // Un choix fait est définitif pour l'expéditeur et le retour automatique (le livreur
      // est déjà reparti) ; seul le support peut le changer, tant que rien n'est payé.
      if (current.failureDecision !== null && by !== 'SUPPORT') return null;
      if (current.returnPaidAt && wanted !== 'RETURN') {
        throw AppError.conflict('RETURN_ALREADY_PAID');
      }
      // Une seule nouvelle tentative : au deuxième échec, le colis revient (le support peut
      // passer outre).
      if (wanted === 'RETRY' && by === 'SENDER' && current.attemptCount >= 2) {
        throw AppError.conflict('RETRY_LIMIT_REACHED');
      }
      let chosen: Decision = wanted;
      if (wanted === 'RETURN' && !(await this.finance.prepayReturn(tx, current))) {
        if (by === 'SENDER') {
          const quote = await this.finance.returnQuote(current, tx);
          throw AppError.unprocessable(
            'RETURN_PAYMENT_REQUIRED',
            { amount: quote.toPay, fee: quote.fee },
            // L'app propose le paiement Mobile Money de ce montant.
            { amount: quote.toPay, fee: quote.fee, fromBalance: quote.fromBalance },
          );
        }
        chosen = 'OFFICE';
      }
      await tx.order.update({ where: { id: orderId }, data: { failureDecision: chosen } });
      // Frais de la nouvelle tentative, pris sur le solde de l'expéditeur : s'il ne suffit
      // pas, rien n'est enregistré et il recharge d'abord.
      if (chosen === 'RETRY') {
        await this.finance.chargeRetry(tx, current, by === 'SENDER');
      }
      return chosen;
    });
    if (!decision) {
      if (by === 'SYSTEM') return false;
      throw AppError.conflict('FAILURE_DECISION_NOT_EXPECTED');
    }
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      include: { rider: { select: { userId: true } } },
    });
    const event = {
      orderId,
      reference: order.reference,
      status: 'DELIVERY_FAILED',
      failureDecision: decision,
      at: new Date().toISOString(),
    };
    this.realtime.toOrder(orderId, 'order.status', event);
    // L'accueil de l'expéditeur suit aussi la décision (retour automatique, support).
    this.realtime.toUser(order.senderId, 'order.status', event);
    const text = DECISION_TEXT[by][decision];
    if (order.rider) {
      this.realtime.toUser(order.rider.userId, 'order.status', event);
      await this.notifications.toUser(order.rider.userId, {
        template: 'RIDER_FAILURE_DECISION',
        params: { reference: order.reference, decision: text },
        data: { type: 'order.failure-decision', orderId, decision },
        orderId,
      });
    }
    if (by !== 'SENDER') {
      await this.notifications.toUser(order.senderId, {
        template: 'SENDER_FAILURE_DECISION',
        params: { reference: order.reference, decision: text },
        data: { type: 'order.status', orderId, status: 'DELIVERY_FAILED' },
        orderId,
      });
    }
    return true;
  }
}
