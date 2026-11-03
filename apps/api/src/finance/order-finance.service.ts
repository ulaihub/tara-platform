import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
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
import { LedgerService, type PostingInput } from './ledger.service.js';

export interface CollectionDue {
  /** Frais de livraison à payer par le destinataire. */
  fee: number;
  /** Contre-remboursement à reverser au marchand. */
  cod: number;
  total: number;
}

export interface CollectionState {
  due: CollectionDue;
  /** Tout ce qui devait être encaissé l'a été. */
  complete: boolean;
  payment: { id: string; status: string; amount: number } | null;
}

/** Compte qui paie pour l'expéditeur : portefeuille marchand ou solde client. */
export function senderAccount(order: Pick<Order, 'merchantId' | 'senderId'>): AccountSpec {
  return order.merchantId ? merchantPayable(order.merchantId) : customerWallet(order.senderId);
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
  ) {}

  onModuleInit(): void {
    this.hooks.register('finance', (context) => this.onTransition(context));
    this.payments.on('DELIVERY_FEE', (tx, payment) => this.onFeePaid(tx, payment));
    this.payments.on('COD', (tx, payment) => this.onCollectionPaid(tx, payment));
  }

  private onTransition({ tx, after, to }: TransitionHookContext): Promise<void> {
    switch (to) {
      case 'CREATED':
        return this.onCreated(tx, after);
      case 'PICKED_UP':
        return this.onPickedUp(tx, after);
      case 'DELIVERED':
        return this.onCompleted(tx, after, false);
      case 'RETURNED':
        return this.onCompleted(tx, after, true);
      case 'CANCELLED':
        return this.onCancelled(tx, after);
      default:
        return Promise.resolve();
    }
  }

  // --- Création : prépaiement par le solde ---------------------------------------------------

  private async onCreated(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    const wallet = senderAccount(order);
    if (order.feePayer === 'SENDER' && order.feePaymentMethod === 'WALLET') {
      await this.ledger.lock(tx, [wallet]);
      const balance = await this.ledger.balance(wallet, tx);
      if (balance < order.totalPrice)
        throw AppError.unprocessable('INSUFFICIENT_BALANCE', { balance });
      await this.ledger.post(tx, {
        kind: 'ORDER_CHARGED',
        description: `Frais de livraison ${order.reference} payés par le solde`,
        idempotencyKey: `order:${order.id}:charge`,
        orderId: order.id,
        postings: [
          { account: wallet, amount: order.totalPrice },
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
      return;
    }
    // Un client qui doit de l'argent à Tara (frais d'un retour) règle d'abord sa dette.
    if (!order.merchantId && (await this.ledger.balance(wallet, tx)) < 0) {
      throw AppError.unprocessable('WALLET_IN_DEBT');
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

  /** Frais payés par Mobile Money : d'avance par l'expéditeur, ou à la porte par le destinataire. */
  private async onFeePaid(tx: Prisma.TransactionClient, payment: Payment): Promise<OrderChange[]> {
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
    if (order.feePayer !== 'SENDER' || order.feePaymentMethod !== 'CASH' || order.feePaidAt) return;
    if (!order.riderId) throw new Error(`Enlèvement sans livreur (${order.reference})`);
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: `Frais de livraison ${order.reference} payés en espèces à l'enlèvement`,
      idempotencyKey: `order:${order.id}:fee-cash`,
      orderId: order.id,
      postings: [
        { account: riderCashHeld(order.riderId), amount: order.totalPrice },
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
      ],
    });
    await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
  }

  // --- Encaissement à la livraison (E5) -----------------------------------------------------

  async collectionState(
    order: Order,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<CollectionState> {
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
      complete: fee + cod === 0,
      payment: payment ? { id: payment.id, status: payment.status, amount: payment.amount } : null,
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
    if (order.status !== 'IN_DELIVERY') {
      throw AppError.conflict('ORDER_TRANSITION_INVALID', { from: order.status, to: 'DELIVERED' });
    }
    const state = await this.collectionState(order);
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
      await this.postCollection(tx, fresh, due, riderCashHeld(rider.id), {
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
  ): Promise<void> {
    if (!order.riderId) throw new Error(`Course terminée sans livreur (${order.reference})`);
    if (!order.feePaidAt) {
      if (!returned) {
        throw AppError.conflict('COLLECTION_REQUIRED', { amount: order.totalPrice });
      }
      // Retour : le destinataire n'a rien payé, l'expéditeur règle la course (solde, au besoin négatif).
      await this.ledger.post(tx, {
        kind: 'ORDER_CHARGED',
        description: `Frais de livraison ${order.reference} facturés à l'expéditeur (retour)`,
        idempotencyKey: `order:${order.id}:charge`,
        orderId: order.id,
        postings: [
          { account: senderAccount(order), amount: order.totalPrice },
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -order.totalPrice },
        ],
      });
      await tx.order.update({ where: { id: order.id }, data: { feePaidAt: new Date() } });
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
    await this.ledger.post(tx, {
      kind: 'DELIVERY_COMPLETED',
      description: `Course ${order.reference} ${returned ? 'retournée' : 'livrée'}`,
      idempotencyKey: `order:${order.id}:complete`,
      orderId: order.id,
      postings,
    });

    // Le livreur garde sa part sur les espèces encaissées pour cette course (G4).
    const cash = await this.orderSum(tx, order.id, riderCashHeld(order.riderId).code);
    const kept = Math.min(order.riderEarning, Math.max(0, cash));
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

  // --- Annulation ---------------------------------------------------------------------------

  private async onCancelled(tx: Prisma.TransactionClient, order: Order): Promise<void> {
    // Solde de la commande sur « livraisons payées » (crédit = montant négatif).
    const held = -(await this.orderSum(tx, order.id, PLATFORM_ACCOUNTS.ordersPrepaid.code));
    if (held <= 0) return;
    await this.ledger.post(tx, {
      kind: 'ORDER_RELEASED',
      description: `Commande ${order.reference} annulée : frais rendus au solde`,
      idempotencyKey: `order:${order.id}:release`,
      orderId: order.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: held },
        { account: senderAccount(order), amount: -held },
      ],
    });
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
