import { Injectable, type OnModuleInit } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import type { Payment, Prisma } from '../generated/prisma/client.js';
import { PaymentsService } from '../payments/payments.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  type AccountSpec,
  customerWallet,
  merchantPayable,
  naturalBalance,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
  riderPayable,
} from './ledger.accounts.js';
import { CashDisciplineService } from './cash-discipline.service.js';
import { LedgerService } from './ledger.service.js';
import { PayoutsService } from './payouts.service.js';

export interface WalletLine {
  id: string;
  at: string;
  kind: string;
  description: string;
  /** Mouvement vu par le titulaire : positif = crédit sur son solde. */
  amount: number;
  orderReference: string | null;
}

/**
 * Portefeuilles (G2, G4, G5, G8) : soldes et historiques ligne par ligne, recharge du solde,
 * dépôt des espèces des livreurs (Mobile Money ou bureau), avoirs accordés par l'équipe.
 */
@Injectable()
export class WalletsService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly payments: PaymentsService,
    private readonly payouts: PayoutsService,
    private readonly audit: AuditService,
    private readonly cash: CashDisciplineService,
  ) {}

  onModuleInit(): void {
    this.payments.on('WALLET_TOPUP', (tx, payment) => this.onTopUp(tx, payment));
    this.payments.on('RIDER_CASH_DEPOSIT', (tx, payment) => this.onCashDeposit(tx, payment));
    this.payments.on('RIDER_TOPUP', (tx, payment) => this.onRiderTopUp(tx, payment));
  }

  /** Solde utilisé par l'utilisateur pour payer : portefeuille marchand s'il en a un. */
  async spendingAccount(userId: string): Promise<AccountSpec> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId } });
    return merchant ? merchantPayable(merchant.id) : customerWallet(userId);
  }

  async overview(userId: string) {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId } });
    const customer = await this.ledger.balance(customerWallet(userId));
    const openPayout = await this.prisma.payout.findFirst({
      where: {
        OR: [{ userId }, ...(merchant ? [{ merchantId: merchant.id }] : [])],
        status: { in: ['PENDING', 'AWAITING_APPROVAL', 'PROCESSING'] },
      },
    });
    return {
      currency: 'XAF' as const,
      customer: { balance: customer },
      merchant: merchant
        ? {
            balance: await this.ledger.balance(merchantPayable(merchant.id)),
            payoutSchedule: merchant.payoutSchedule,
            plan: merchant.plan,
            payoutPhone: merchant.payoutPhone,
          }
        : null,
      openPayout: openPayout
        ? { id: openPayout.id, amount: openPayout.amount, status: openPayout.status }
        : null,
    };
  }

  async riderOverview(userId: string) {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const balances = await this.ledger.balances([riderPayable(rider.id), riderCashHeld(rider.id)]);
    const openPayout = await this.prisma.payout.findFirst({
      where: { riderId: rider.id, status: { in: ['PENDING', 'AWAITING_APPROVAL', 'PROCESSING'] } },
    });
    return {
      currency: 'XAF' as const,
      earnings: balances.get(riderPayable(rider.id).code) ?? 0,
      reserved: await this.prisma.riderBalanceHold
        .aggregate({ where: { riderId: rider.id, releasedAt: null }, _sum: { amount: true } })
        .then((sum) => sum._sum.amount ?? 0),
      cashHeld: balances.get(riderCashHeld(rider.id).code) ?? 0,
      cashLimit: rider.cashLimit,
      cashDueBy: (await this.cash.dueBy(rider.id)).dueBy?.toISOString() ?? null,
      cashOverdue: rider.cashOverdueSince !== null,
      available: await this.payouts.available('RIDER', rider.id),
      openPayout: openPayout
        ? { id: openPayout.id, amount: openPayout.amount, status: openPayout.status }
        : null,
    };
  }

  /** Historique ligne par ligne d'un compte, du plus récent au plus ancien. */
  async history(
    spec: AccountSpec,
    page: { limit: number; cursor?: string | undefined },
  ): Promise<{ items: WalletLine[]; nextCursor: string | null }> {
    const account = await this.prisma.ledgerAccount.findUnique({ where: { code: spec.code } });
    if (!account) return { items: [], nextCursor: null };
    const rows = await this.prisma.ledgerPosting.findMany({
      where: { accountId: account.id, ...(page.cursor ? { id: { lt: page.cursor } } : {}) },
      include: { entry: { include: { order: { select: { reference: true } } } } },
      orderBy: { id: 'desc' },
      take: page.limit + 1,
    });
    const items = rows.slice(0, page.limit).map((row) => ({
      id: row.id,
      at: row.entry.postedAt.toISOString(),
      kind: row.entry.kind,
      description: row.entry.description,
      amount: naturalBalance(account.type, row.amount),
      orderReference: row.entry.order?.reference ?? null,
    }));
    return { items, nextCursor: rows.length > page.limit ? (items.at(-1)?.id ?? null) : null };
  }

  // --- Recharge du solde (G1) ---------------------------------------------------------------

  async topUp(
    userId: string,
    amount: number,
    phone: string,
    operator: 'MTN' | 'ORANGE',
    key: string,
  ): Promise<Payment> {
    return this.payments.request({
      purpose: 'WALLET_TOPUP',
      amount,
      phone,
      method: operator === 'ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN',
      payerId: userId,
      idempotencyKey: `topup:${userId}:${key}`,
      description: 'Tara recharge du solde',
    });
  }

  private async onTopUp(tx: Prisma.TransactionClient, payment: Payment): Promise<void> {
    if (!payment.payerId) throw new Error(`Recharge sans payeur (${payment.id})`);
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: 'Recharge du solde par Mobile Money',
      idempotencyKey: `payment:${payment.id}`,
      paymentId: payment.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: payment.amount },
        { account: await this.spendingAccountIn(tx, payment.payerId), amount: -payment.amount },
      ],
    });
  }

  private async spendingAccountIn(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<AccountSpec> {
    const merchant = await tx.merchantProfile.findUnique({ where: { userId } });
    return merchant ? merchantPayable(merchant.id) : customerWallet(userId);
  }

  // --- Solde prépayé des livreurs (G5, décision 36) ----------------------------------------

  /**
   * Recharge du solde prépayé depuis le téléphone du livreur. Il est crédité du montant
   * entier : Tara paie les frais Mobile Money.
   */
  async topUpRider(
    userId: string,
    amount: number,
    phone: string,
    operator: 'MTN' | 'ORANGE',
    key: string,
  ): Promise<Payment> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    return this.payments.request({
      purpose: 'RIDER_TOPUP',
      amount,
      phone,
      method: operator === 'ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN',
      payerId: userId,
      riderId: rider.id,
      idempotencyKey: `rider-topup:${rider.id}:${key}`,
      description: 'Tara recharge du solde livreur',
    });
  }

  private async onRiderTopUp(tx: Prisma.TransactionClient, payment: Payment): Promise<void> {
    if (!payment.riderId) throw new Error(`Recharge sans livreur (${payment.id})`);
    await this.ledger.post(tx, {
      kind: 'PAYMENT_RECEIVED',
      description: 'Recharge du solde livreur par Mobile Money',
      idempotencyKey: `payment:${payment.id}`,
      paymentId: payment.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: payment.amount },
        { account: riderPayable(payment.riderId), amount: -payment.amount },
      ],
    });
  }

  /** Recharge du solde avec des espèces remises au bureau, enregistrée par la finance (tracé). */
  async topUpRiderAtOffice(
    staff: AuthUser,
    riderId: string,
    amount: number,
    note: string,
    key: string,
    request: Request,
  ) {
    const rider = await this.prisma.riderProfile.findUnique({ where: { id: riderId } });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    if (rider.userId === staff.id) throw AppError.forbidden('SELF_APPROVAL_FORBIDDEN');
    const entry = await this.prisma.$transaction(async (tx) => {
      const posted = await this.ledger.post(tx, {
        kind: 'PAYMENT_RECEIVED',
        description: `Recharge du solde livreur au bureau : ${note}`,
        idempotencyKey: `office-topup:${riderId}:${key}`,
        postedById: staff.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount },
          { account: riderPayable(riderId), amount: -amount },
        ],
      });
      if (!posted.created) return posted;
      await this.audit.record(
        {
          actor: staff,
          action: 'rider.balance_topped_up',
          entityType: 'rider',
          entityId: riderId,
          after: { amount, note, entryId: posted.entryId },
          request,
        },
        tx,
      );
      return posted;
    });
    return { entryId: entry.entryId, balance: await this.ledger.balance(riderPayable(riderId)) };
  }

  // --- Espèces des livreurs (G5, ancien fonctionnement) -----------------------------------

  /** Le livreur dépose ses espèces par Mobile Money depuis son téléphone. */
  async depositByMobileMoney(
    userId: string,
    amount: number,
    phone: string,
    operator: 'MTN' | 'ORANGE',
    key: string,
  ): Promise<Payment> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const cashHeld = await this.ledger.balance(riderCashHeld(rider.id));
    if (amount > cashHeld) throw AppError.unprocessable('DEPOSIT_TOO_LARGE', { cashHeld });
    return this.payments.request({
      purpose: 'RIDER_CASH_DEPOSIT',
      amount,
      phone,
      method: operator === 'ORANGE' ? 'MOMO_ORANGE' : 'MOMO_MTN',
      payerId: userId,
      riderId: rider.id,
      idempotencyKey: `deposit:${rider.id}:${key}`,
      description: 'Tara dépôt des espèces',
    });
  }

  private async onCashDeposit(tx: Prisma.TransactionClient, payment: Payment): Promise<void> {
    if (!payment.riderId) throw new Error(`Dépôt sans livreur (${payment.id})`);
    await this.ledger.post(tx, {
      kind: 'CASH_DEPOSITED',
      description: 'Dépôt des espèces par Mobile Money',
      idempotencyKey: `payment:${payment.id}`,
      paymentId: payment.id,
      postings: [
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: payment.amount },
        { account: riderCashHeld(payment.riderId), amount: -payment.amount },
      ],
    });
  }

  /** Espèces remises au bureau, enregistrées par la finance (tracé). */
  async depositAtOffice(
    staff: AuthUser,
    riderId: string,
    amount: number,
    note: string,
    key: string,
    request: Request,
  ) {
    const rider = await this.prisma.riderProfile.findUnique({ where: { id: riderId } });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    if (rider.userId === staff.id) throw AppError.forbidden('SELF_APPROVAL_FORBIDDEN');
    const account = riderCashHeld(riderId);
    // Requête rejouée (double clic, coupure) : on renvoie le premier résultat, sans contrôle.
    const replay = await this.prisma.journalEntry.findUnique({
      where: { idempotencyKey: `office-deposit:${riderId}:${key}` },
    });
    if (replay) return { entryId: replay.id, cashHeld: await this.ledger.balance(account) };
    const entry = await this.prisma.$transaction(async (tx) => {
      await this.ledger.lock(tx, [account]);
      const cashHeld = await this.ledger.balance(account, tx);
      if (amount > cashHeld) throw AppError.unprocessable('DEPOSIT_TOO_LARGE', { cashHeld });
      const posted = await this.ledger.post(tx, {
        kind: 'CASH_DEPOSITED',
        description: `Dépôt d'espèces au bureau : ${note}`,
        idempotencyKey: `office-deposit:${riderId}:${key}`,
        postedById: staff.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount },
          { account, amount: -amount },
        ],
      });
      if (!posted.created) return posted; // Requête rejouée : rien de plus.
      await this.audit.record(
        {
          actor: staff,
          action: 'rider.cash_deposited',
          entityType: 'rider',
          entityId: riderId,
          after: { amount, note, entryId: posted.entryId },
          request,
        },
        tx,
      );
      return posted;
    });
    return { entryId: entry.entryId, cashHeld: await this.ledger.balance(account) };
  }

  // --- Trésorerie ---------------------------------------------------------------------------

  /**
   * Virement entre les espèces du bureau et le compte de l'agrégateur (alimentation avant
   * les reversements, ou retrait). Tracé et rejouable sans double écriture.
   */
  async treasuryTransfer(
    staff: AuthUser,
    direction: 'OFFICE_TO_MOBILE_MONEY' | 'MOBILE_MONEY_TO_OFFICE',
    amount: number,
    note: string,
    key: string,
    request: Request,
  ): Promise<{ entryId: string }> {
    const toMobileMoney = direction === 'OFFICE_TO_MOBILE_MONEY';
    const posted = await this.prisma.$transaction(async (tx) => {
      const entry = await this.ledger.post(tx, {
        kind: 'ADJUSTMENT',
        description: `Virement de trésorerie ${toMobileMoney ? 'bureau → Mobile Money' : 'Mobile Money → bureau'} : ${note}`,
        idempotencyKey: `treasury:${key}`,
        postedById: staff.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.mobileMoney, amount: toMobileMoney ? amount : -amount },
          { account: PLATFORM_ACCOUNTS.officeCash, amount: toMobileMoney ? -amount : amount },
        ],
      });
      if (entry.created) {
        await this.audit.record(
          {
            actor: staff,
            action: 'finance.treasury_transfer',
            entityType: 'journal',
            entityId: entry.entryId,
            after: { direction, amount, note },
            request,
          },
          tx,
        );
      }
      return entry;
    });
    return { entryId: posted.entryId };
  }

  // --- Avoirs (G8) --------------------------------------------------------------------------

  /** Avoir accordé par l'équipe (geste commercial, litige), crédité sur le solde. */
  async grantCredit(
    staff: AuthUser,
    userId: string,
    amount: number,
    reason: string,
    key: string,
    request: Request,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw AppError.notFound();
    if (userId === staff.id) throw AppError.forbidden('SELF_APPROVAL_FORBIDDEN');
    const account = await this.spendingAccount(userId);
    const replay = await this.prisma.journalEntry.findUnique({
      where: { idempotencyKey: `credit:${userId}:${key}` },
    });
    if (replay) return { entryId: replay.id, balance: await this.ledger.balance(account) };
    const entry = await this.prisma.$transaction(async (tx) => {
      const posted = await this.ledger.post(tx, {
        kind: 'CREDIT_GRANTED',
        description: `Avoir : ${reason}`,
        idempotencyKey: `credit:${userId}:${key}`,
        postedById: staff.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.goodwill, amount },
          { account, amount: -amount },
        ],
      });
      if (!posted.created) return posted;
      await this.audit.record(
        {
          actor: staff,
          action: 'wallet.credit_granted',
          entityType: 'user',
          entityId: userId,
          after: { amount, reason, account: account.code },
          request,
        },
        tx,
      );
      return posted;
    });
    return { entryId: entry.entryId, balance: await this.ledger.balance(account) };
  }
}
