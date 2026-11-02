import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { addDays, CAMEROON_TIME_ZONE, cameroonDate } from '../common/time.js';
import type { Prisma, ReconciliationReport } from '../generated/prisma/client.js';
import {
  PAYMENT_PROVIDER,
  type PaymentProvider,
  type ProviderTransaction,
} from '../payments/payment.provider.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { PLATFORM_ACCOUNTS } from './ledger.accounts.js';
import { LedgerService } from './ledger.service.js';

export type DiscrepancyType =
  | 'LEDGER_UNBALANCED'
  | 'PAYMENT_NOT_RECORDED'
  | 'PAYMENT_AMOUNT_MISMATCH'
  | 'PAYMENT_STUCK'
  | 'PAYOUT_NOT_RECORDED'
  | 'PAYOUT_AMOUNT_MISMATCH'
  | 'PAYOUT_STUCK'
  | 'PROVIDER_ONLY'
  | 'LEDGER_ONLY'
  | 'PROVIDER_AMOUNT_MISMATCH'
  | 'PROVIDER_STATUS_MISMATCH'
  | 'COD_NOT_RECORDED'
  | 'ORDER_NOT_CLEARED';

export interface Discrepancy {
  type: DiscrepancyType;
  reference: string;
  detail: string;
  expected?: number;
  actual?: number;
}

export interface ReconciliationTotals {
  mobileMoneyCollected: number;
  cashCollected: number;
  cashDepositedMobileMoney: number;
  cashDepositedOffice: number;
  payoutsSent: number;
  providerFees: number;
  commission: number;
  codFees: number;
  codCollected: number;
  ordersCompleted: number;
  /** Soldes en fin de journée du rapprochement (calculés à l'exécution). */
  mobileMoneyBalance: number;
  ordersPrepaidBalance: number;
  payoutsInTransitBalance: number;
}

/** Bornes d'une journée à l'heure du Cameroun (UTC+1, sans heure d'été). */
export function cameroonDay(day: string): { from: Date; to: Date } {
  const from = new Date(Date.parse(`${day}T00:00:00Z`) - 3_600_000);
  return { from, to: new Date(from.getTime() + 86_400_000) };
}

/** Une heure : au-delà, une opération « en cours » est anormale. */
const STUCK_AFTER_MS = 3_600_000;

/**
 * Rapprochement quotidien automatique (G6). Pour la journée donnée, vérifie que :
 * - le grand livre est équilibré ;
 * - chaque paiement et chaque reversement réussi a ses écritures, au franc près ;
 * - le relevé du prestataire Mobile Money correspond, opération par opération ;
 * - chaque contre-remboursement déclaré est crédité au marchand ;
 * - chaque commande terminée ou annulée a soldé ses frais payés d'avance.
 * Les écarts sont listés ; l'équipe financière est alertée s'il y en a.
 */
@Injectable()
export class ReconciliationService {
  private readonly logger = new Logger(ReconciliationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly realtime: RealtimeService,
    @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron('0 30 1 * * *', { name: 'reconciliation', timeZone: CAMEROON_TIME_ZONE })
  async scheduled(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    const yesterday = cameroonDate(addDays(new Date(), -1));
    const report = await this.run(yesterday);
    this.logger.log(`Rapprochement du ${yesterday} : ${report.status}`);
  }

  async run(
    day: string,
    ranById: string | null = null,
    now = new Date(),
  ): Promise<ReconciliationReport> {
    const { from, to } = cameroonDay(day);
    const discrepancies: Discrepancy[] = [];
    const within = { gte: from, lt: to };

    // 1. Grand livre équilibré.
    const [ledgerSum] = await this.prisma.$queryRaw<{ total: bigint }[]>`
      SELECT COALESCE(SUM(amount), 0)::bigint AS total FROM ledger_postings`;
    if (Number(ledgerSum?.total ?? 0) !== 0) {
      discrepancies.push({
        type: 'LEDGER_UNBALANCED',
        reference: 'ledger',
        detail: 'La somme de toutes les lignes du grand livre n’est pas nulle',
        expected: 0,
        actual: Number(ledgerSum?.total ?? 0),
      });
    }

    // 2. Paiements réussis : écritures présentes, au franc près.
    const payments = await this.prisma.payment.findMany({
      where: { status: 'SUCCEEDED', confirmedAt: within },
    });
    const momoByPayment = await this.mobileMoneyBy(
      'payment_id',
      payments.map((payment) => payment.id),
    );
    for (const payment of payments) {
      const recorded = momoByPayment.get(payment.id);
      if (recorded === undefined) {
        discrepancies.push({
          type: 'PAYMENT_NOT_RECORDED',
          reference: payment.id,
          detail: 'Paiement réussi sans écriture',
        });
      } else if (recorded !== payment.amount - payment.fee) {
        discrepancies.push({
          type: 'PAYMENT_AMOUNT_MISMATCH',
          reference: payment.id,
          detail: 'Écritures différentes du montant encaissé',
          expected: payment.amount - payment.fee,
          actual: recorded,
        });
      }
    }
    const stuckPayments = await this.prisma.payment.findMany({
      where: {
        status: 'PENDING',
        createdAt: { lt: new Date(Math.min(to.getTime(), now.getTime() - STUCK_AFTER_MS)) },
      },
    });
    for (const payment of stuckPayments) {
      discrepancies.push({
        type: 'PAYMENT_STUCK',
        reference: payment.id,
        detail: 'Paiement en attente depuis plus d’une heure',
      });
    }

    // 3. Reversements : envoyés avec leurs écritures, aucun bloqué.
    const payouts = await this.prisma.payout.findMany({
      where: { status: 'SUCCEEDED', completedAt: within },
    });
    const momoByPayout = await this.mobileMoneyBy(
      'payout_id',
      payouts.map((payout) => payout.id),
    );
    for (const payout of payouts) {
      const recorded = momoByPayout.get(payout.id);
      if (recorded === undefined) {
        discrepancies.push({
          type: 'PAYOUT_NOT_RECORDED',
          reference: payout.id,
          detail: 'Reversement envoyé sans écriture',
        });
      } else if (recorded !== -(payout.amount + payout.fee)) {
        discrepancies.push({
          type: 'PAYOUT_AMOUNT_MISMATCH',
          reference: payout.id,
          detail: 'Écritures différentes du montant envoyé',
          expected: -(payout.amount + payout.fee),
          actual: recorded,
        });
      }
    }
    const stuckPayouts = await this.prisma.payout.findMany({
      where: {
        status: { in: ['PENDING', 'PROCESSING'] },
        requestedAt: { lt: new Date(Math.min(to.getTime(), now.getTime() - STUCK_AFTER_MS)) },
      },
    });
    for (const payout of stuckPayouts) {
      discrepancies.push({
        type: 'PAYOUT_STUCK',
        reference: payout.id,
        detail: `Reversement ${payout.status} depuis plus d’une heure`,
      });
    }

    // 4. Relevé du prestataire, opération par opération (fenêtre élargie pour les opérations à cheval sur minuit).
    discrepancies.push(...(await this.compareWithProvider(from, to, payments, payouts)));

    // 5. Contre-remboursements déclarés : crédités au marchand.
    const collections = await this.prisma.codCollection.findMany({
      where: { collectedAt: within },
      include: { order: true },
    });
    for (const collection of collections) {
      const entries = await this.prisma.journalEntry.count({
        where: { orderId: collection.orderId, kind: 'COD_COLLECTED' },
      });
      if (entries !== 1) {
        discrepancies.push({
          type: 'COD_NOT_RECORDED',
          reference: collection.order.reference,
          detail: `Encaissement déclaré avec ${entries} écriture(s)`,
          expected: 1,
          actual: entries,
        });
      }
    }

    // 6. Commandes terminées ou annulées : plus rien sur « livraisons payées ».
    const closed = await this.prisma.order.findMany({
      where: { status: { in: ['DELIVERED', 'RETURNED', 'CANCELLED'] }, updatedAt: within },
      select: { id: true, reference: true, status: true },
    });
    const open = await this.ordersPrepaidBy(closed.map((order) => order.id));
    for (const order of closed) {
      const balance = open.get(order.id) ?? 0;
      if (balance !== 0) {
        discrepancies.push({
          type: 'ORDER_NOT_CLEARED',
          reference: order.reference,
          detail: `Commande ${order.status} avec des frais encore en attente`,
          expected: 0,
          actual: -balance,
        });
      }
    }

    const totals = await this.totals(
      from,
      to,
      payments,
      payouts,
      collections.length > 0 ? collections : [],
      closed.length,
    );
    const status = discrepancies.length === 0 ? 'BALANCED' : 'DISCREPANCIES';
    const data = {
      status,
      totals: totals as unknown as Prisma.InputJsonObject,
      discrepancies: discrepancies as unknown as Prisma.InputJsonArray,
      ranById,
    } as const;
    const report = await this.prisma.reconciliationReport.upsert({
      where: { day: new Date(`${day}T00:00:00Z`) },
      create: { day: new Date(`${day}T00:00:00Z`), ...data },
      update: data,
    });
    if (status === 'DISCREPANCIES') {
      this.logger.error(`Rapprochement du ${day} : ${discrepancies.length} écart(s)`);
      this.realtime.toOps('ops.finance-alert', {
        type: 'RECONCILIATION_DISCREPANCIES',
        day,
        count: discrepancies.length,
      });
    }
    return report;
  }

  private async compareWithProvider(
    from: Date,
    to: Date,
    payments: { id: string; amount: number; providerReference: string | null; provider: string }[],
    payouts: { id: string; amount: number; providerReference: string | null; provider: string }[],
  ): Promise<Discrepancy[]> {
    const discrepancies: Discrepancy[] = [];
    let statement: ProviderTransaction[];
    try {
      statement = await this.provider.transactions(
        new Date(from.getTime() - 86_400_000),
        new Date(to.getTime() + 86_400_000),
      );
    } catch (error) {
      this.logger.warn(`Relevé du prestataire indisponible : ${String(error)}`);
      return [
        {
          type: 'PROVIDER_STATUS_MISMATCH',
          reference: this.provider.name,
          detail: 'Relevé du prestataire indisponible',
        },
      ];
    }
    const byReference = new Map(statement.map((item) => [item.providerReference, item]));
    const ours = [
      ...payments
        .filter((p) => p.provider === this.provider.name)
        .map((p) => ({ ...p, kind: 'COLLECT' as const })),
      ...payouts
        .filter((p) => p.provider === this.provider.name)
        .map((p) => ({ ...p, kind: 'DISBURSE' as const })),
    ];
    const known = new Set<string>();
    for (const item of ours) {
      const theirs = item.providerReference ? byReference.get(item.providerReference) : undefined;
      if (item.providerReference) known.add(item.providerReference);
      if (!theirs) {
        discrepancies.push({
          type: 'LEDGER_ONLY',
          reference: item.id,
          detail: 'Opération absente du relevé du prestataire',
        });
      } else if (theirs.status !== 'SUCCEEDED') {
        discrepancies.push({
          type: 'PROVIDER_STATUS_MISMATCH',
          reference: item.id,
          detail: `Statut ${theirs.status} chez le prestataire`,
        });
      } else if (theirs.amount !== item.amount) {
        discrepancies.push({
          type: 'PROVIDER_AMOUNT_MISMATCH',
          reference: item.id,
          detail: 'Montant différent chez le prestataire',
          expected: item.amount,
          actual: theirs.amount,
        });
      }
    }
    // Opérations réussies chez le prestataire, dans la journée, inconnues de nos écritures.
    for (const item of statement) {
      if (
        item.status !== 'SUCCEEDED' ||
        item.at < from ||
        item.at >= to ||
        known.has(item.providerReference)
      )
        continue;
      const recorded =
        item.kind === 'COLLECT'
          ? await this.prisma.payment.findFirst({
              where: {
                OR: [
                  { providerReference: item.providerReference },
                  ...(item.reference ? [{ id: item.reference }] : []),
                ],
                status: 'SUCCEEDED',
              },
            })
          : await this.prisma.payout.findFirst({
              where: {
                OR: [
                  { providerReference: item.providerReference },
                  ...(item.reference ? [{ id: item.reference }] : []),
                ],
                status: 'SUCCEEDED',
              },
            });
      if (!recorded) {
        discrepancies.push({
          type: 'PROVIDER_ONLY',
          reference: item.providerReference,
          detail: `${item.kind === 'COLLECT' ? 'Encaissement' : 'Envoi'} chez le prestataire sans écriture chez Tara`,
          actual: item.amount,
        });
      }
    }
    return discrepancies;
  }

  /** Mouvement net du compte Mobile Money par paiement ou par reversement. */
  private async mobileMoneyBy(
    column: 'payment_id' | 'payout_id',
    ids: string[],
  ): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows =
      column === 'payment_id'
        ? await this.prisma.$queryRaw<{ id: string; total: bigint }[]>`
            SELECT e.payment_id AS id, SUM(p.amount)::bigint AS total
              FROM journal_entries e
              JOIN ledger_postings p ON p.entry_id = e.id
              JOIN ledger_accounts a ON a.id = p.account_id AND a.code = ${PLATFORM_ACCOUNTS.mobileMoney.code}
             WHERE e.payment_id = ANY(${ids}::uuid[])
             GROUP BY e.payment_id`
        : await this.prisma.$queryRaw<{ id: string; total: bigint }[]>`
            SELECT e.payout_id AS id, SUM(p.amount)::bigint AS total
              FROM journal_entries e
              JOIN ledger_postings p ON p.entry_id = e.id
              JOIN ledger_accounts a ON a.id = p.account_id AND a.code = ${PLATFORM_ACCOUNTS.mobileMoney.code}
             WHERE e.payout_id = ANY(${ids}::uuid[])
             GROUP BY e.payout_id`;
    return new Map(rows.map((row) => [row.id, Number(row.total)]));
  }

  private async ordersPrepaidBy(orderIds: string[]): Promise<Map<string, number>> {
    if (orderIds.length === 0) return new Map();
    const rows = await this.prisma.$queryRaw<{ id: string; total: bigint }[]>`
      SELECT e.order_id AS id, SUM(p.amount)::bigint AS total
        FROM journal_entries e
        JOIN ledger_postings p ON p.entry_id = e.id
        JOIN ledger_accounts a ON a.id = p.account_id AND a.code = ${PLATFORM_ACCOUNTS.ordersPrepaid.code}
       WHERE e.order_id = ANY(${orderIds}::uuid[])
       GROUP BY e.order_id`;
    return new Map(rows.map((row) => [row.id, Number(row.total)]));
  }

  private async totals(
    from: Date,
    to: Date,
    payments: { purpose: string; amount: number; fee: number }[],
    payouts: { amount: number; fee: number }[],
    collections: { collectedAmount: number; feeAmount: number }[],
    ordersCompleted: number,
  ): Promise<ReconciliationTotals> {
    const flows = await this.prisma.$queryRaw<{ code: string; debit: bigint; credit: bigint }[]>`
      SELECT a.code,
             COALESCE(SUM(CASE WHEN p.amount > 0 THEN p.amount END), 0)::bigint AS debit,
             COALESCE(SUM(CASE WHEN p.amount < 0 THEN -p.amount END), 0)::bigint AS credit
        FROM ledger_postings p
        JOIN journal_entries e ON e.id = p.entry_id
        JOIN ledger_accounts a ON a.id = p.account_id
       WHERE e.posted_at >= ${from} AND e.posted_at < ${to}
       GROUP BY a.code`;
    const flow = (predicate: (code: string) => boolean, side: 'debit' | 'credit'): number =>
      flows.filter((row) => predicate(row.code)).reduce((sum, row) => sum + Number(row[side]), 0);
    const balances = await this.ledger.balances([
      PLATFORM_ACCOUNTS.mobileMoney,
      PLATFORM_ACCOUNTS.ordersPrepaid,
      PLATFORM_ACCOUNTS.payoutsInTransit,
    ]);
    const deposits = await this.prisma.$queryRaw<{ code: string; total: bigint }[]>`
      SELECT a.code, COALESCE(SUM(p.amount), 0)::bigint AS total
        FROM ledger_postings p
        JOIN journal_entries e ON e.id = p.entry_id AND e.kind = 'CASH_DEPOSITED'
        JOIN ledger_accounts a ON a.id = p.account_id
       WHERE e.posted_at >= ${from} AND e.posted_at < ${to} AND p.amount > 0
       GROUP BY a.code`;
    const deposited = (code: string): number =>
      Number(deposits.find((row) => row.code === code)?.total ?? 0);
    return {
      mobileMoneyCollected: payments.reduce((sum, payment) => sum + payment.amount, 0),
      cashCollected: flow((code) => code.endsWith(':cash_held'), 'debit'),
      cashDepositedMobileMoney: deposited(PLATFORM_ACCOUNTS.mobileMoney.code),
      cashDepositedOffice: deposited(PLATFORM_ACCOUNTS.officeCash.code),
      payoutsSent: payouts.reduce((sum, payout) => sum + payout.amount, 0),
      providerFees:
        payments.reduce((sum, payment) => sum + payment.fee, 0) +
        payouts.reduce((sum, payout) => sum + payout.fee, 0),
      commission:
        flow((code) => code === PLATFORM_ACCOUNTS.commission.code, 'credit') -
        flow((code) => code === PLATFORM_ACCOUNTS.commission.code, 'debit'),
      codFees: collections.reduce((sum, collection) => sum + collection.feeAmount, 0),
      codCollected: collections.reduce((sum, collection) => sum + collection.collectedAmount, 0),
      ordersCompleted,
      mobileMoneyBalance: balances.get(PLATFORM_ACCOUNTS.mobileMoney.code) ?? 0,
      ordersPrepaidBalance: balances.get(PLATFORM_ACCOUNTS.ordersPrepaid.code) ?? 0,
      payoutsInTransitBalance: balances.get(PLATFORM_ACCOUNTS.payoutsInTransit.code) ?? 0,
    };
  }
}
