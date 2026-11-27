import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import type { OrderChange } from '../events/order-events.bus.js';
import {
  OrderTransitionHooks,
  type TransitionHookContext,
} from '../events/order-transition.hooks.js';
import type { Order, Payment, Prisma } from '../generated/prisma/client.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PaymentsService } from '../payments/payments.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import {
  type AccountSpec,
  codFee,
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
  riderPayable,
} from './ledger.accounts.js';
import { mobileMoneySurcharge } from '../payments/mobile-money-fees.js';
import { cancellationFee } from '../orders/cancellation-fee.js';
import { waitingFeeFor, waitingFeeMax } from '../orders/waiting-fee.js';
import type { ActorRole } from '../generated/prisma/enums.js';
import { LedgerService, type PostingInput } from './ledger.service.js';
import { RiderBalanceService } from './rider-balance.service.js';

export interface CollectionDue {
  /** Frais de livraison à payer par le destinataire. */
  fee: number;
  /** Contre-remboursement à reverser au marchand. */
  cod: number;
  total: number;
}

export interface CollectionState {
  due: CollectionDue;
  /** Frais Mobile Money payés en plus si le client règle par Mobile Money. */
  mobileMoneyFee: number;
  reason: 'DELIVERY' | 'RETURN';
  /** Tout ce qui devait être encaissé l'a été. */
  complete: boolean;
  /** Demande Mobile Money en attente ; `total` : montant demandé au téléphone, frais compris. */
  payment: { id: string; status: string; amount: number; total: number } | null;
}

function pendingPayment(payment: Payment): NonNullable<CollectionState['payment']> {
  const { id, status, amount, surcharge } = payment;
  return { id, status, amount, total: amount + surcharge };
}

/** Colis qui repart chez l'expéditeur (retour décidé, pas encore rendu). */
export function isReturning(order: Pick<Order, 'status' | 'failureDecision'>): boolean {
  return order.status === 'DELIVERY_FAILED' && order.failureDecision === 'RETURN';
}

/** Ce que coûte le retour à l'expéditeur : frais de retour, plus la course si impayée. */
export function returnCharges(
  order: Pick<Order, 'returnFee' | 'feePaidAt' | 'totalPrice'>,
): number {
  return order.returnFee + (order.feePaidAt ? 0 : order.totalPrice);
}

/** Retour sans dette : ce que le solde paie et ce qui reste à payer maintenant. */
export interface ReturnQuote {
  fee: number;
  fromBalance: number;
  toPay: number;
}

/** Compte qui paie pour l'expéditeur : portefeuille marchand ou solde client. */
export function senderAccount(order: Pick<Order, 'merchantId' | 'senderId'>): AccountSpec {
  return order.merchantId ? merchantPayable(order.merchantId) : customerWallet(order.senderId);
}

/**
 * Comptes qui paient pour l'expéditeur, dans l'ordre où ils sont pris : une boutique paie
 * d'abord avec son solde Tara (recharges et réserve, jamais reversé d'office), puis avec ses
 * ventes, qui peuvent seules passer en dette (dans la limite MERCHANT_DEBT_LIMIT).
 */
export function payingAccounts(order: Pick<Order, 'merchantId' | 'senderId'>): AccountSpec[] {
  return order.merchantId
    ? [customerWallet(order.senderId), merchantPayable(order.merchantId)]
    : [customerWallet(order.senderId)];
}

/**
 * Argent des commandes (G1, G2, G4, E5). Chaque mouvement est une écriture du grand livre,
 * passée dans la transaction du changement de statut ou du paiement qui la justifie :
 *
 * - prépaiement (Mobile Money, solde) : crédité sur « livraisons payées » jusqu'à la fin ;
 * - espèces : débitées sur le compte « espèces détenues » du livreur ;
 * - contre-remboursement : crédité au marchand, moins 2 % (minimum 250 FCFA) ;
 * - fin de course : part du livreur et commission ; le livreur garde sa part sur les
 *   espèces qu'il détient ; annulation : frais rendus au solde de l'expéditeur.
 */
@Injectable()
export class OrderFinanceService implements OnModuleInit {
  private readonly logger = new Logger(OrderFinanceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly payments: PaymentsService,
    private readonly hooks: OrderTransitionHooks,
    private readonly transitions: OrderTransitionsService,
    private readonly realtime: RealtimeService,
    private readonly riderBalance: RiderBalanceService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  onModuleInit(): void {
    this.hooks.register('finance', (context) => this.onTransition(context));
    this.payments.on('DELIVERY_FEE', (tx, payment) => this.onFeePaid(tx, payment));
    this.payments.on('COD', (tx, payment) => this.onCollectionPaid(tx, payment));
  }

  private onTransition({ tx, before, after, to, actor }: TransitionHookContext): Promise<void> {
    switch (to) {
      case 'CREATED':
        return this.onCreated(tx, after);
      case 'PICKED_UP':
        return this.onPickedUp(tx, after);
      case 'DELIVERED':
        return this.onCompleted(tx, after, false, actor.role);
      case 'RETURNED':
        // Rendu au bureau : la course a été réglée au dépôt, il faut seulement être payé.
        if (before?.status === 'HELD_AT_OFFICE') {
          if (!after.officePaidAt) {
            throw AppError.conflict('OFFICE_PAYMENT_REQUIRED', { amount: after.officeDue });
          }
          return Promise.resolve();
        }
        return this.onCompleted(tx, after, true, actor.role);
      case 'HELD_AT_OFFICE':
        return this.onHeldAtOffice(tx, after, actor.role);
      case 'UNCLAIMED':
        return this.onUnclaimed(tx, after);
      case 'CANCELLED':
        return this.onCancelled(tx, after, before, actor.role);
      default:
        return Promise.resolve();
    }
  }

  // --- Création : prépaiement par le solde ---------------------------------------------------

  private async onCreated(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    if (order.feePayer === 'SENDER' && order.feePaymentMethod === 'WALLET') {
      await this.ledger.lock(tx, payingAccounts(order));
      // Boutique : solde Tara et ventes ensemble (le solde Tara d'abord).
      const balance = await this.funds(order, tx);
      if (balance < order.totalPrice)
        throw AppError.unprocessable('INSUFFICIENT_BALANCE', { balance });
      await this.ledger.post(tx, {
        kind: 'ORDER_CHARGED',
        description: `Frais de livraison ${order.reference} payés par le solde`,
        idempotencyKey: `order:${order.id}:charge`,
        orderId: order.id,
        postings: [
          ...(await this.debitPostings(tx, order, order.totalPrice)),
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
      return;
    }
    // Un client qui doit de l'argent à Tara (frais d'un retour) règle d'abord sa dette ; un
    // marchand peut devoir jusqu'au plafond (MERCHANT_DEBT_LIMIT), pas au-delà.
    const balance = await this.funds(order, tx);
    if (!order.merchantId && balance < 0) throw AppError.unprocessable('WALLET_IN_DEBT');
    if (order.merchantId && balance <= -this.env.MERCHANT_DEBT_LIMIT) {
      throw AppError.unprocessable('MERCHANT_DEBT_LIMIT', {
        debt: -balance,
        limit: this.env.MERCHANT_DEBT_LIMIT,
      });
    }
  }

  // --- Prépaiement par Mobile Money ---------------------------------------------------------

  /** Demande de paiement des frais d'une commande prépayée (G1). */
  async pay(userId: string, orderId: string, phone: string): Promise<Payment> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (order?.senderId !== userId) throw AppError.notFound('ORDER_NOT_FOUND');
    if (
      order.status !== 'CREATED' ||
      order.feePaidAt ||
      order.feePayer !== 'SENDER' ||
      !order.feePaymentMethod.startsWith('MOMO_')
    ) {
      throw AppError.conflict('PAYMENT_NOT_EXPECTED');
    }
    const attempts = await this.prisma.payment.count({
      where: { orderId, purpose: 'DELIVERY_FEE' },
    });
    return this.payments.request({
      purpose: 'DELIVERY_FEE',
      amount: order.totalPrice,
      phone,
      method: order.feePaymentMethod === 'MOMO_ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN',
      payerId: userId,
      orderId,
      idempotencyKey: `order:${orderId}:prepay:${attempts + 1}`,
      description: `Tara ${order.reference}`,
    });
  }

  /**
   * Un seul paiement Mobile Money pour tout un lot (C4) : la somme des frais des commandes
   * du lot encore à payer (les annulées n'en font plus partie).
   */
  async payBatch(userId: string, batchId: string, phone: string): Promise<Payment> {
    const batch = await this.prisma.orderBatch.findUnique({
      where: { id: batchId },
      include: { orders: true },
    });
    if (batch?.senderId !== userId) throw AppError.notFound('ORDER_NOT_FOUND');
    const payable = batch.orders.filter(
      (order) =>
        order.status === 'CREATED' &&
        !order.feePaidAt &&
        order.feePayer === 'SENDER' &&
        order.feePaymentMethod.startsWith('MOMO_'),
    );
    if (payable.length === 0) throw AppError.conflict('PAYMENT_NOT_EXPECTED');
    const attempts = await this.prisma.payment.count({
      where: { batchId, purpose: 'DELIVERY_FEE' },
    });
    const method = payable[0]?.feePaymentMethod === 'MOMO_ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN';
    return this.payments.request({
      purpose: 'DELIVERY_FEE',
      amount: payable.reduce((sum, order) => sum + order.totalPrice, 0),
      phone,
      method,
      payerId: userId,
      batchId,
      idempotencyKey: `batch:${batchId}:prepay:${attempts + 1}`,
      description: `Tara ${payable.length} livraisons`,
    });
  }

  /** Frais payés par Mobile Money : d'avance par l'expéditeur, ou à la porte par le destinataire. */
  private async onFeePaid(tx: Prisma.TransactionClient, payment: Payment): Promise<OrderChange[]> {
    if (payment.batchId) return this.onBatchPaid(tx, payment, payment.batchId);
    const order = payment.orderId
      ? await tx.order.findUnique({ where: { id: payment.orderId } })
      : null;
    if (
      !order ||
      order.feePaidAt ||
      ['CANCELLED', 'DELIVERED', 'RETURNED'].includes(order.status)
    ) {
      await this.unallocated(tx, payment, order);
      return [];
    }
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: `Frais de livraison ${order.reference} payés par Mobile Money`,
      idempotencyKey: `payment:${payment.id}`,
      orderId: order.id,
      paymentId: payment.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: payment.amount },
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -payment.amount },
      ],
    });
    const paid = await tx.order.update({
      where: { id: order.id },
      data: { feePaidAt: new Date() },
    });
    if (paid.status !== 'CREATED' || paid.scheduledFor) return [];
    const { change } = await this.transitions.applyIn(tx, paid, 'SEARCHING_RIDER', {
      id: null,
      role: 'SYSTEM',
    });
    return [change];
  }

  /**
   * Lot payé : les frais de chaque commande encore à payer sont réglés et elles partent en
   * recherche de livreur. Ce qui reste (commande annulée entre-temps) revient au solde de
   * l'expéditeur, comme tout paiement sans emploi.
   */
  private async onBatchPaid(
    tx: Prisma.TransactionClient,
    payment: Payment,
    batchId: string,
  ): Promise<OrderChange[]> {
    const orders = await tx.order.findMany({
      where: { batchId, feePaidAt: null, status: 'CREATED', feePayer: 'SENDER' },
      orderBy: { createdAt: 'asc' },
    });
    const due = orders.reduce((sum, order) => sum + order.totalPrice, 0);
    if (orders.length === 0 || due > payment.amount) {
      const first = await tx.order.findFirst({ where: { batchId } });
      await this.unallocated(tx, payment, first);
      return [];
    }
    const changes: OrderChange[] = [];
    for (const order of orders) {
      await this.ledger.post(tx, {
        kind: 'PAYMENT_RECEIVED',
        description: `Frais de livraison ${order.reference} payés par Mobile Money (lot)`,
        idempotencyKey: `payment:${payment.id}:${order.id}`,
        orderId: order.id,
        paymentId: payment.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.mobileMoney, amount: order.totalPrice },
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      const paid = await tx.order.update({
        where: { id: order.id },
        data: { feePaidAt: new Date() },
      });
      if (paid.scheduledFor) continue;
      const { change } = await this.transitions.applyIn(tx, paid, 'SEARCHING_RIDER', {
        id: null,
        role: 'SYSTEM',
      });
      changes.push(change);
    }
    const rest = payment.amount - due;
    const first = orders[0];
    if (rest > 0 && first) {
      await this.ledger.post(tx, {
        kind: 'PAYMENT_RECEIVED',
        description: `Paiement ${payment.id} : reste du lot crédité au solde`,
        idempotencyKey: `payment:${payment.id}:rest`,
        orderId: null,
        paymentId: payment.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.mobileMoney, amount: rest },
          { account: senderAccount(first), amount: -rest },
        ],
      });
    }
    return changes;
  }

  /**
   * Argent reçu sans emploi (commande annulée entre-temps, payée deux fois) : gardé sur
   * le solde de l'expéditeur s'il en est le payeur, sinon mis en attente d'affectation et
   * signalé à la finance. Il n'est jamais perdu.
   */
  private async unallocated(
    tx: Prisma.TransactionClient,
    payment: Payment,
    order: Order | null,
  ): Promise<void> {
    const toSender = order && payment.payerId === order.senderId;
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: toSender
        ? `Paiement ${payment.id} sans emploi, crédité au solde`
        : `Paiement ${payment.id} sans emploi, à affecter`,
      idempotencyKey: `payment:${payment.id}`,
      orderId: order?.id ?? null,
      paymentId: payment.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: payment.amount },
        {
          account: toSender ? senderAccount(order) : PLATFORM_ACCOUNTS.unallocated,
          amount: -payment.amount,
        },
      ],
    });
    if (!toSender) {
      this.logger.warn(`Paiement ${payment.id} sans emploi (${payment.amount} FCFA) : à affecter`);
      this.realtime.toOps('ops.finance-alert', {
        type: 'PAYMENT_UNALLOCATED',
        paymentId: payment.id,
        orderId: order?.id ?? null,
        amount: payment.amount,
      });
    }
  }

  // --- Enlèvement : frais en espèces ----------------------------------------------------------

  private async onPickedUp(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    await this.chargeWaiting(tx, order);
    if (order.feePayer !== 'SENDER' || order.feePaymentMethod !== 'CASH' || order.feePaidAt) return;
    if (!order.riderId) throw new Error(`Enlèvement sans livreur (${order.reference})`);
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: `Frais de livraison ${order.reference} payés en espèces à l'enlèvement`,
      idempotencyKey: `order:${order.id}:fee-cash`,
      orderId: order.id,
      // Solde prépayé : le livreur garde les espèces, le montant est pris sur son solde.
      postings: [
        { account: riderPayable(order.riderId), amount: order.totalPrice },
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
      ],
    });
    await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
  }

  /**
   * Attente au point d'enlèvement (D), comptée depuis l'arrivée signalée par le livreur :
   * payée par l'expéditeur, partagée avec le livreur. Une seule fois pour un envoi groupé.
   */
  private async chargeWaiting(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    if (!order.riderId) return;
    const fee = waitingFeeFor(order.arrivedPickupAt, order.pickedUpAt, this.env);
    if (fee <= 0) return;
    const key = `waiting:${order.batchId ?? order.id}:${order.riderId}`;
    if (await tx.journalEntry.findUnique({ where: { idempotencyKey: key } })) return;
    await this.chargeSplit(tx, order, order.riderId, {
      kind: 'WAITING_FEE_CHARGED',
      description: `Attente du livreur à l'enlèvement de ${order.reference}`,
      key,
      fee,
      riderPart: Math.floor((fee * this.env.WAITING_RIDER_PERCENT) / 100),
    });
    await tx.order.update({ where: { id: order.id }, data: { waitingFee: fee } });
  }

  // --- Encaissement à la livraison (E5) -----------------------------------------------------

  async collectionState(
    order: Order,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<CollectionState> {
    // Retour sans dette : payé d'avance par l'expéditeur, rien n'est encaissé à la porte.
    if (
      order.status === 'DELIVERY_FAILED' &&
      order.failureDecision !== null &&
      order.failureDecision !== 'RETRY'
    ) {
      return {
        due: { fee: 0, cod: 0, total: 0 },
        mobileMoneyFee: 0,
        reason: 'RETURN',
        complete: true,
        payment: null,
      };
    }
    // Une requête après l'autre : `db` peut être une transaction (une seule connexion).
    const collection = await db.codCollection.findUnique({ where: { orderId: order.id } });
    const payment = await db.payment.findFirst({
      where: { orderId: order.id, purpose: { in: ['COD', 'DELIVERY_FEE'] }, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
    const fee = order.feePayer === 'RECIPIENT' && !order.feePaidAt ? order.totalPrice : 0;
    const cod = order.codAmount > 0 && !collection ? order.codAmount : 0;
    return {
      due: { fee, cod, total: fee + cod },
      mobileMoneyFee: mobileMoneySurcharge(fee + cod, this.env.MOBILE_MONEY_FEE_BPS),
      reason: 'DELIVERY',
      complete: fee + cod === 0,
      payment: payment ? pendingPayment(payment) : null,
    };
  }

  /**
   * Le livreur encaisse à la porte : en espèces (enregistré tout de suite) ou par Mobile
   * Money (demande envoyée au téléphone du destinataire, confirmation automatique).
   */
  async collect(
    riderUserId: string,
    orderId: string,
    method: { kind: 'CASH' } | { kind: 'MOBILE_MONEY'; phone: string; operator: 'MTN' | 'ORANGE' },
  ): Promise<CollectionState> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: riderUserId } });
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!rider || order?.riderId !== rider.id) throw AppError.notFound('ORDER_NOT_FOUND');
    // Encaissement en espèces renvoyé par la file hors connexion (réponse perdue) : déjà
    // enregistré, il est sans effet et ne bloque pas la livraison qui suit.
    if (method.kind === 'CASH') {
      const recorded = await this.prisma.journalEntry.findUnique({
        where: { idempotencyKey: `order:${orderId}:collect-cash` },
        select: { id: true },
      });
      if (recorded) return this.collectionState(order);
    }
    // Retour sans dette : plus rien n'est encaissé à la porte de l'expéditeur.
    const state = await this.collectionState(order);
    if (state.reason === 'RETURN') throw AppError.conflict('COLLECTION_NOT_EXPECTED');
    if (order.status !== 'IN_DELIVERY') {
      throw AppError.conflict('ORDER_TRANSITION_INVALID', { from: order.status, to: 'DELIVERED' });
    }
    if (state.complete) throw AppError.conflict('COLLECTION_NOT_EXPECTED');

    if (method.kind === 'MOBILE_MONEY') {
      const attempts = await this.prisma.payment.count({
        where: { orderId, purpose: { in: ['COD', 'DELIVERY_FEE'] } },
      });
      await this.payments.request({
        purpose: state.due.cod > 0 ? 'COD' : 'DELIVERY_FEE',
        amount: state.due.total,
        phone: method.phone,
        method: method.operator === 'ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN',
        orderId,
        riderId: rider.id,
        idempotencyKey: `order:${orderId}:collect:${attempts + 1}`,
        description: `Tara ${order.reference}`,
      });
      return this.collectionState(
        await this.prisma.order.findUniqueOrThrow({ where: { id: orderId } }),
      );
    }

    await this.prisma.$transaction(async (tx) => {
      // Le verrou de la commande empêche deux encaissements simultanés.
      await tx.$executeRaw`SELECT id FROM orders WHERE id = ${orderId}::uuid FOR UPDATE`;
      const fresh = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
      const due = (await this.collectionState(fresh, tx)).due;
      if (due.total === 0) throw AppError.conflict('ALREADY_COLLECTED');
      // Solde prépayé : le livreur garde les espèces, le montant est pris sur son solde
      // (mis de côté à l'acceptation) et le marchand est crédité aussitôt.
      await this.postCollection(tx, fresh, due, riderPayable(rider.id), {
        idempotencyKey: `order:${orderId}:collect-cash`,
        paymentId: null,
        method: 'CASH',
        riderId: rider.id,
      });
    });
    return this.collectionState(
      await this.prisma.order.findUniqueOrThrow({ where: { id: orderId } }),
    );
  }

  private async onCollectionPaid(tx: Prisma.TransactionClient, payment: Payment): Promise<void> {
    const order = payment.orderId
      ? await tx.order.findUnique({ where: { id: payment.orderId } })
      : null;
    if (!order) {
      await this.unallocated(tx, payment, null);
      return;
    }
    await tx.$executeRaw`SELECT id FROM orders WHERE id = ${order.id}::uuid FOR UPDATE`;
    const due = (await this.collectionState(order, tx)).due;
    if (due.total !== payment.amount || !order.riderId) {
      await this.unallocated(tx, payment, order);
      return;
    }
    await this.postCollection(tx, order, due, PLATFORM_ACCOUNTS.mobileMoney, {
      idempotencyKey: `payment:${payment.id}`,
      paymentId: payment.id,
      method: payment.method,
      riderId: order.riderId,
    });
  }

  private async postCollection(
    tx: Prisma.TransactionClient,
    order: Order,
    due: CollectionDue,
    debit: AccountSpec,
    context: {
      idempotencyKey: string;
      paymentId: string | null;
      method: Payment['method'];
      riderId: string;
    },
  ): Promise<void> {
    const fee = codFee(due.cod);
    const postings: PostingInput[] = [{ account: debit, amount: due.total }];
    if (due.fee > 0) postings.push({ account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -due.fee });
    if (due.cod > 0) {
      if (!order.merchantId)
        throw new Error(`Contre-remboursement sans marchand (${order.reference})`);
      postings.push(
        { account: merchantPayable(order.merchantId), amount: -(due.cod - fee) },
        { account: PLATFORM_ACCOUNTS.codFees, amount: -fee },
      );
    }
    await this.ledger.post(tx, {
      kind: due.cod > 0 ? 'COD_COLLECTED' : 'PAYMENT_RECEIVED',
      description: `Encaissement ${order.reference} (${context.method === 'CASH' ? 'espèces' : 'Mobile Money'})`,
      idempotencyKey: context.idempotencyKey,
      orderId: order.id,
      paymentId: context.paymentId,
      postings,
    });
    if (due.cod > 0) {
      await tx.codCollection.create({
        data: {
          orderId: order.id,
          riderId: context.riderId,
          expectedAmount: order.codAmount,
          collectedAmount: due.cod,
          method: context.method,
          paymentId: context.paymentId,
          feeAmount: fee,
          collectedAt: new Date(),
        },
      });
    }
    if (due.fee > 0)
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
  }

  // --- Fin de course ------------------------------------------------------------------------

  private async onCompleted(
    tx: Prisma.TransactionClient,
    order: Order,
    returned: boolean,
    actorRole: string,
  ): Promise<void> {
    if (!order.riderId) throw new Error(`Course terminée sans livreur (${order.reference})`);
    void actorRole;
    if (!order.feePaidAt) {
      if (!returned) {
        throw AppError.conflict('COLLECTION_REQUIRED', { amount: order.totalPrice });
      }
      // Retour : le destinataire n'a rien payé, l'expéditeur règle la course.
      await this.ledger.post(tx, {
        kind: 'ORDER_CHARGED',
        description: `Frais de livraison ${order.reference} facturés à l'expéditeur (retour)`,
        idempotencyKey: `order:${order.id}:charge`,
        orderId: order.id,
        postings: [
          ...(await this.debitPostings(tx, order, order.totalPrice)),
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
    }
    if (returned && order.returnFee > 0) {
      await this.ledger.post(tx, {
        kind: 'FAILURE_FEE_CHARGED',
        description: `Frais de retour ${order.reference}`,
        idempotencyKey: `order:${order.id}:return-fee`,
        orderId: order.id,
        postings: [
          ...(await this.debitPostings(tx, order, order.returnFee)),
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.returnFee },
        ],
      });
    }
    if (!returned && order.codAmount > 0) {
      const collected = await tx.codCollection.findUnique({ where: { orderId: order.id } });
      if (!collected) throw AppError.conflict('COLLECTION_REQUIRED', { amount: order.codAmount });
    }

    const postings: PostingInput[] = [
      { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: order.totalPrice },
      { account: riderPayable(order.riderId), amount: -order.riderEarning },
    ];
    if (order.platformFee >= 0) {
      postings.push({ account: PLATFORM_ACCOUNTS.commission, amount: -order.platformFee });
    } else {
      postings.push({ account: PLATFORM_ACCOUNTS.promotions, amount: -order.platformFee });
    }
    // Primes d'approche et de renfort (H4) : payées par Tara, en plus de la part du livreur.
    const bonus = order.approachBonus + order.boostBonus;
    if (bonus > 0) {
      postings.push(
        { account: riderPayable(order.riderId), amount: -bonus },
        { account: PLATFORM_ACCOUNTS.riderBonuses, amount: bonus },
      );
    }
    await this.ledger.post(tx, {
      kind: 'DELIVERY_COMPLETED',
      description: `Course ${order.reference} ${returned ? 'retournée' : 'livrée'}`,
      idempotencyKey: `order:${order.id}:complete`,
      orderId: order.id,
      postings,
    });
    await this.shareFailureFees(tx, order);

    // Le livreur garde sa part sur les espèces encaissées pour cette course (G4).
    const cash = await this.orderSum(tx, order.id, riderCashHeld(order.riderId).code);
    const kept = Math.min(order.riderEarning + bonus, Math.max(0, cash));
    if (kept > 0) {
      await this.ledger.post(tx, {
        kind: 'CASH_COMPENSATED',
        description: `Part du livreur gardée sur les espèces de ${order.reference}`,
        idempotencyKey: `order:${order.id}:compensate`,
        orderId: order.id,
        postings: [
          { account: riderPayable(order.riderId), amount: kept },
          { account: riderCashHeld(order.riderId), amount: -kept },
        ],
      });
    }
  }

  // --- Frais d'échec (E6) ------------------------------------------------------------------

  /** Dette tolérée : rien pour un particulier, MERCHANT_DEBT_LIMIT pour une boutique. */
  private debtLimit(order: Pick<Order, 'merchantId'>): number {
    return order.merchantId ? this.env.MERCHANT_DEBT_LIMIT : 0;
  }

  /**
   * Nouvelle tentative : ses frais sont pris sur le solde de l'expéditeur, jusqu'à son
   * plafond de dette. Au-delà, il recharge d'abord son solde (RETRY_PAYMENT_REQUIRED) ; le
   * support, qui décide à sa place, n'est pas bloqué.
   */
  async chargeRetry(tx: Prisma.TransactionClient, order: Order, checkBalance: boolean) {
    if (order.retryFee === 0) return;
    await this.ledger.lock(tx, payingAccounts(order));
    if (checkBalance) {
      const balance = await this.funds(order, tx);
      const missing = order.retryFee - balance - this.debtLimit(order);
      if (missing > 0) {
        throw AppError.unprocessable(
          'RETRY_PAYMENT_REQUIRED',
          { amount: missing, fee: order.retryFee },
          // L'app propose la recharge de ce montant.
          { amount: missing },
        );
      }
    }
    await this.ledger.post(tx, {
      kind: 'FAILURE_FEE_CHARGED',
      description: `Nouvelle tentative ${order.reference}`,
      idempotencyKey: `order:${order.id}:retry-fee:${order.attemptCount}`,
      orderId: order.id,
      postings: [
        ...(await this.debitPostings(tx, order, order.retryFee)),
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.retryFee },
      ],
    });
  }

  /**
   * Colis refusé à l'enlèvement (non conforme à la commande) : l'expéditeur paie le
   * déplacement du livreur, au prix d'une nouvelle tentative, partagé comme une course
   * entre le livreur et Tara. Le reste de ce qu'il avait payé lui est rendu par
   * l'annulation. Pris sur son solde, même au-delà de la dette tolérée.
   */
  async chargeRefusedParcel(
    tx: Prisma.TransactionClient,
    order: Order,
    riderId: string,
  ): Promise<void> {
    const fee = order.retryFee;
    if (fee <= 0) return;
    await this.ledger.lock(tx, payingAccounts(order));
    await this.ledger.post(tx, {
      kind: 'FAILURE_FEE_CHARGED',
      description: `Déplacement pour un colis non conforme ${order.reference}`,
      idempotencyKey: `order:${order.id}:refused-fee`,
      orderId: order.id,
      postings: [
        ...(await this.debitPostings(tx, order, fee)),
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -fee },
      ],
    });
    const grid = await tx.pricingGrid.findUniqueOrThrow({
      where: { id: order.pricingGridId },
      select: { riderShareBps: true },
    });
    const riderPart = Math.floor((fee * grid.riderShareBps) / 10_000);
    await this.ledger.post(tx, {
      kind: 'DELIVERY_COMPLETED',
      description: `Déplacement de ${order.reference} partagé`,
      idempotencyKey: `order:${order.id}:refused-fee-share`,
      orderId: order.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: fee },
        { account: riderPayable(riderId), amount: -riderPart },
        { account: PLATFORM_ACCOUNTS.commission, amount: -(fee - riderPart) },
      ],
    });
  }

  // --- Retour sans dette ------------------------------------------------------------------

  /**
   * Argent de l'expéditeur utilisable sans dette : son solde Tara puis ses ventes (boutique),
   * seulement ce qui est positif. Un retour ne fait jamais passer un compte sous zéro.
   */
  async available(
    order: Pick<Order, 'merchantId' | 'senderId'>,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<number> {
    const accounts = payingAccounts(order);
    const balances = await this.ledger.balances(accounts, db);
    return accounts.reduce((sum, account) => sum + Math.max(0, balances.get(account.code) ?? 0), 0);
  }

  /** Lignes qui prennent [amount] sur l'argent disponible, compte après compte, sans dette. */
  private async noDebtPostings(
    tx: Prisma.TransactionClient,
    order: Pick<Order, 'merchantId' | 'senderId'>,
    amount: number,
  ): Promise<PostingInput[]> {
    const postings: PostingInput[] = [];
    let left = amount;
    for (const account of payingAccounts(order)) {
      const part = Math.min(left, Math.max(0, await this.ledger.balance(account, tx)));
      if (part > 0) postings.push({ account, amount: part });
      left -= part;
    }
    if (left > 0)
      throw AppError.unprocessable('RETURN_PAYMENT_REQUIRED', { amount: left }, { amount: left });
    return postings;
  }

  /**
   * Ce que le retour coûte, ce que le solde paie, ce qui reste à payer (Mobile Money dans
   * l'app ou au bureau). Colis au bureau : le montant fixé au dépôt, tant qu'il est dû.
   */
  async returnQuote(
    order: Order,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<ReturnQuote> {
    const fee =
      order.status === 'HELD_AT_OFFICE'
        ? order.officePaidAt
          ? 0
          : order.officeDue
        : order.returnPaidAt
          ? 0
          : returnCharges(order);
    const fromBalance = Math.min(fee, await this.available(order, db));
    return { fee, fromBalance, toPay: fee - fromBalance };
  }

  /**
   * Retour choisi : ses frais sont pris tout de suite sur l'argent disponible de
   * l'expéditeur, sans dette. Renvoie false (rien n'est pris) s'il ne suffit pas : l'expéditeur
   * paie le reste par Mobile Money, sinon le colis part au bureau Tara.
   */
  async prepayReturn(tx: Prisma.TransactionClient, order: Order): Promise<boolean> {
    if (order.returnPaidAt) return true;
    await this.ledger.lock(tx, payingAccounts(order));
    if ((await this.available(order, tx)) < returnCharges(order)) return false;
    await this.postReturnCharges(tx, order, (amount) => this.noDebtPostings(tx, order, amount));
    await tx.order.update({ where: { id: order.id }, data: { returnPaidAt: new Date() } });
    return true;
  }

  /**
   * Course et frais de retour passés sur « livraisons payées », pris à [from] ; mêmes clés
   * que la fin de course, qui ne les reprend donc pas.
   */
  private async postReturnCharges(
    tx: Prisma.TransactionClient,
    order: Order,
    from: (amount: number) => Promise<PostingInput[]>,
  ): Promise<void> {
    if (!order.feePaidAt) {
      await this.ledger.post(tx, {
        kind: 'ORDER_CHARGED',
        description: `Frais de livraison ${order.reference} facturés à l'expéditeur (retour)`,
        idempotencyKey: `order:${order.id}:charge`,
        orderId: order.id,
        postings: [
          ...(await from(order.totalPrice)),
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
    }
    if (order.returnFee > 0) {
      await this.ledger.post(tx, {
        kind: 'FAILURE_FEE_CHARGED',
        description: `Frais de retour ${order.reference}`,
        idempotencyKey: `order:${order.id}:return-fee`,
        orderId: order.id,
        postings: [
          ...(await from(order.returnFee)),
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.returnFee },
        ],
      });
    }
  }

  /**
   * Colis déposé au bureau Tara : le livreur est payé comme pour un retour, Tara avance les
   * frais (à recevoir) ; l'expéditeur les paiera pour récupérer son colis, sans dette.
   */
  private async onHeldAtOffice(
    tx: Prisma.TransactionClient,
    order: Order,
    actorRole: string,
  ): Promise<void> {
    const due = order.returnPaidAt ? 0 : returnCharges(order);
    if (!order.returnPaidAt) {
      await this.postReturnCharges(tx, order, (amount) =>
        Promise.resolve([{ account: PLATFORM_ACCOUNTS.officeReceivables, amount }]),
      );
    }
    const now = new Date();
    const fresh = await tx.order.update({
      where: { id: order.id },
      data: {
        officeAt: now,
        officeUntil: new Date(now.getTime() + this.env.OFFICE_HOLD_DAYS * 86_400_000),
        officeDue: due,
        officePaidAt: due === 0 ? now : null,
      },
    });
    await this.onCompleted(tx, fresh, true, actorRole);
  }

  /**
   * Colis gardé au bureau : l'expéditeur paie pour le récupérer, avec son solde (rechargé
   * par Mobile Money au besoin) ou en espèces au bureau. Une seule fois.
   */
  async payOffice(
    tx: Prisma.TransactionClient,
    order: Order,
    via: { kind: 'BALANCE' } | { kind: 'CASH'; staffId: string },
  ): Promise<void> {
    if (order.status !== 'HELD_AT_OFFICE') throw AppError.conflict('ORDER_NOT_AT_OFFICE');
    if (order.officePaidAt) throw AppError.conflict('ALREADY_COLLECTED');
    const due = order.officeDue;
    if (due > 0) {
      let postings: PostingInput[];
      if (via.kind === 'BALANCE') {
        await this.ledger.lock(tx, payingAccounts(order));
        postings = await this.noDebtPostings(tx, order, due);
      } else {
        postings = [{ account: PLATFORM_ACCOUNTS.officeCash, amount: due }];
      }
      await this.ledger.post(tx, {
        kind: 'OFFICE_RETURN_PAID',
        description: `Frais de retour ${order.reference} payés (${via.kind === 'CASH' ? 'espèces au bureau' : 'solde Tara'})`,
        idempotencyKey: `order:${order.id}:office-paid`,
        orderId: order.id,
        postedById: via.kind === 'CASH' ? via.staffId : null,
        postings: [...postings, { account: PLATFORM_ACCOUNTS.officeReceivables, amount: -due }],
      });
    }
    await tx.order.update({ where: { id: order.id }, data: { officePaidAt: new Date() } });
  }

  /**
   * Garde finie sans que l'expéditeur vienne : Tara dispose du colis (conditions) et abandonne
   * les frais. Rien ne reste dû, aucune dette.
   */
  private async onUnclaimed(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    if (order.officePaidAt) throw AppError.conflict('OFFICE_ALREADY_PAID');
    if (!order.officeUntil || order.officeUntil.getTime() > Date.now()) {
      throw AppError.conflict('OFFICE_HOLD_NOT_OVER', {
        until: order.officeUntil?.toISOString() ?? '',
      });
    }
    if (order.officeDue > 0) {
      await this.ledger.post(tx, {
        kind: 'OFFICE_RETURN_WRITTEN_OFF',
        description: `Colis ${order.reference} non réclamé : frais de retour abandonnés`,
        idempotencyKey: `order:${order.id}:office-written-off`,
        orderId: order.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.unpaidReturns, amount: order.officeDue },
          { account: PLATFORM_ACCOUNTS.officeReceivables, amount: -order.officeDue },
        ],
      });
    }
    await tx.order.update({ where: { id: order.id }, data: { unclaimedAt: new Date() } });
  }

  /** Frais d'échec gardés pour la course, partagés comme elle entre le livreur et Tara. */
  private async shareFailureFees(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    if (!order.riderId) return;
    const held = -(await this.orderSum(tx, order.id, PLATFORM_ACCOUNTS.ordersPrepaid.code));
    if (held <= 0) return;
    const grid = await tx.pricingGrid.findUniqueOrThrow({
      where: { id: order.pricingGridId },
      select: { riderShareBps: true },
    });
    const riderPart = Math.floor((held * grid.riderShareBps) / 10_000);
    await this.ledger.post(tx, {
      kind: 'DELIVERY_COMPLETED',
      description: `Frais d'échec de ${order.reference} partagés`,
      idempotencyKey: `order:${order.id}:complete-fees`,
      orderId: order.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: held },
        { account: riderPayable(order.riderId), amount: -riderPart },
        { account: PLATFORM_ACCOUNTS.commission, amount: -(held - riderPart) },
      ],
    });
  }

  // --- Annulation ---------------------------------------------------------------------------

  private async onCancelled(
    tx: Prisma.TransactionClient,
    order: Order,
    before: Order | null,
    by: ActorRole,
  ): Promise<void> {
    await this.releasePrepaid(tx, order);
    if (by === 'SENDER' && before) await this.chargeCancellation(tx, before);
  }

  /**
   * Frais d'annulation (C) : l'expéditeur annule alors que le livreur est déjà en route vers
   * l'enlèvement. Le livreur est payé pour son déplacement, Tara garde le reste.
   */
  private async chargeCancellation(tx: Prisma.TransactionClient, before: Order): Promise<void> {
    const fee = await cancellationFee(before, this.env, tx);
    if (fee <= 0 || !before.riderId) return;
    await this.chargeSplit(tx, before, before.riderId, {
      kind: 'CANCELLATION_FEE_CHARGED',
      description: `Commande ${before.reference} annulée, livreur en route : déplacement payé`,
      key: `order:${before.id}:cancel-fee`,
      fee,
      riderPart: Math.min(fee, this.env.CANCELLATION_FEE_RIDER_PART),
    });
  }

  /**
   * Expéditeur absent (D) : le livreur a attendu le temps maximal, sur place, et l'a appelé.
   * L'expéditeur paie l'annulation et l'attente maximale ; le livreur reçoit sa part des deux.
   * Une seule fois pour un envoi groupé (la commande sur laquelle le livreur a agi).
   */
  async chargeSenderAbsent(
    tx: Prisma.TransactionClient,
    order: Order,
    riderId: string,
  ): Promise<void> {
    const cancel = this.env.CANCELLATION_FEE;
    if (cancel > 0) {
      await this.chargeSplit(tx, order, riderId, {
        kind: 'CANCELLATION_FEE_CHARGED',
        description: `Commande ${order.reference} annulée : expéditeur absent après l'attente`,
        key: `order:${order.id}:cancel-fee`,
        fee: cancel,
        riderPart: Math.min(cancel, this.env.CANCELLATION_FEE_RIDER_PART),
      });
    }
    const waiting = waitingFeeMax(this.env);
    const key = `waiting:${order.batchId ?? order.id}:${riderId}`;
    if (waiting <= 0 || (await tx.journalEntry.findUnique({ where: { idempotencyKey: key } })))
      return;
    await this.chargeSplit(tx, order, riderId, {
      kind: 'WAITING_FEE_CHARGED',
      description: `Attente du livreur à l'enlèvement de ${order.reference}`,
      key,
      fee: waiting,
      riderPart: Math.floor((waiting * this.env.WAITING_RIDER_PERCENT) / 100),
    });
    await tx.order.update({ where: { id: order.id }, data: { waitingFee: waiting } });
  }

  /** Frais pris à l'expéditeur, partagés entre le livreur et Tara. */
  private async chargeSplit(
    tx: Prisma.TransactionClient,
    order: Order,
    riderId: string,
    charge: {
      kind: 'CANCELLATION_FEE_CHARGED' | 'WAITING_FEE_CHARGED';
      description: string;
      key: string;
      fee: number;
      riderPart: number;
    },
  ): Promise<void> {
    await this.ledger.lock(tx, payingAccounts(order));
    await this.ledger.post(tx, {
      kind: charge.kind,
      description: charge.description,
      idempotencyKey: charge.key,
      orderId: order.id,
      postings: [
        ...(await this.debitPostings(tx, order, charge.fee)),
        { account: riderPayable(riderId), amount: -charge.riderPart },
        ...(charge.fee > charge.riderPart
          ? [{ account: PLATFORM_ACCOUNTS.commission, amount: -(charge.fee - charge.riderPart) }]
          : []),
      ],
    });
  }

  /** Commande annulée : ce qui avait été payé d'avance revient à l'expéditeur. */
  private async releasePrepaid(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    // Solde de la commande sur « livraisons payées » (crédit = montant négatif).
    const held = -(await this.orderSum(tx, order.id, PLATFORM_ACCOUNTS.ordersPrepaid.code));
    if (held <= 0) return;
    // Chaque compte retrouve ce qu'il avait payé (solde Tara d'une boutique, puis ses
    // ventes) ; payé par Mobile Money, l'argent revient au compte habituel.
    const refunds = await this.refundPostings(tx, order, held);
    await this.ledger.post(tx, {
      kind: 'ORDER_RELEASED',
      description: `Commande ${order.reference} annulée : frais rendus au solde`,
      idempotencyKey: `order:${order.id}:release`,
      orderId: order.id,
      postings: [{ account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: held }, ...refunds],
    });
  }

  /** Ce que l'expéditeur peut payer : ses soldes ensemble (une dette compte en moins). */
  private async funds(
    order: Pick<Order, 'merchantId' | 'senderId'>,
    db: Prisma.TransactionClient | PrismaService,
  ): Promise<number> {
    const accounts = payingAccounts(order);
    const balances = await this.ledger.balances(accounts, db);
    return accounts.reduce((sum, account) => sum + (balances.get(account.code) ?? 0), 0);
  }

  /**
   * Lignes qui prennent [amount] à l'expéditeur : son solde Tara tant qu'il en a (boutique),
   * le reste sur ses ventes, qui peuvent passer en dette (limite vérifiée par l'appelant).
   */
  private async debitPostings(
    tx: Prisma.TransactionClient,
    order: Pick<Order, 'merchantId' | 'senderId'>,
    amount: number,
  ): Promise<PostingInput[]> {
    const accounts = payingAccounts(order);
    const [prepaid, sales] = accounts;
    if (!prepaid) return [];
    if (!sales) return [{ account: prepaid, amount }];
    const fromPrepaid = Math.min(amount, Math.max(0, await this.ledger.balance(prepaid, tx)));
    return [
      ...(fromPrepaid > 0 ? [{ account: prepaid, amount: fromPrepaid }] : []),
      ...(amount > fromPrepaid ? [{ account: sales, amount: amount - fromPrepaid }] : []),
    ];
  }

  /** Remboursement d'une commande annulée, compte par compte, comme elle a été payée. */
  private async refundPostings(
    tx: Prisma.TransactionClient,
    order: Order,
    held: number,
  ): Promise<PostingInput[]> {
    const charge = await tx.journalEntry.findUnique({
      where: { idempotencyKey: `order:${order.id}:charge` },
      include: { postings: { include: { account: { select: { code: true } } } } },
    });
    const byCode = new Map(payingAccounts(order).map((account) => [account.code, account]));
    const paid = (charge?.postings ?? []).flatMap((posting) => {
      const account = byCode.get(posting.account.code);
      return account && posting.amount > 0 ? [{ account, amount: posting.amount }] : [];
    });
    if (paid.length === 0) return [{ account: senderAccount(order), amount: -held }];
    const postings: PostingInput[] = [];
    let left = held;
    for (const { account, amount } of paid) {
      const part = Math.min(left, amount);
      if (part > 0) postings.push({ account, amount: -part });
      left -= part;
    }
    // Plus que la course (frais pris ensuite) : le reste au compte habituel.
    if (left > 0) postings.push({ account: senderAccount(order), amount: -left });
    return postings;
  }

  /** Somme signée des lignes d'une commande sur un compte. */
  private async orderSum(
    tx: Prisma.TransactionClient,
    orderId: string,
    code: string,
  ): Promise<number> {
    const [row] = await tx.$queryRaw<{ total: bigint | null }[]>`
      SELECT SUM(p.amount)::bigint AS total
        FROM ledger_postings p
        JOIN journal_entries e ON e.id = p.entry_id
        JOIN ledger_accounts a ON a.id = p.account_id
       WHERE e.order_id = ${orderId}::uuid AND a.code = ${code}`;
    return Number(row?.total ?? 0);
  }
}
