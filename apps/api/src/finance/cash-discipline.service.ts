import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AuditService } from '../audit/audit.service.js';
import { CAMEROON_TIME_ZONE } from '../common/time.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { riderCashHeld, riderPayable } from './ledger.accounts.js';
import { LedgerService } from './ledger.service.js';

const HOUR_MS = 3_600_000;

/**
 * Espèces encore dues par un livreur (ancien fonctionnement, avant le solde prépayé de la
 * décision 36 : les nouvelles courses n'en créent plus). À déposer sous 24 h (Mobile Money
 * ou bureau) ; rappel à 18 h ; en retard, plus de courses tant qu'elles ne sont pas
 * déposées ; 72 h de retard : compte suspendu, gains retenus sur la dette, équipe prévenue.
 * Les dépôts soldent d'abord les espèces les plus anciennes.
 */
@Injectable()
export class CashDisciplineService {
  private readonly logger = new Logger(CashDisciplineService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly notifications: NotificationService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Espèces détenues, heure de l'encaissement le plus ancien non déposé et heure limite de
   * dépôt (null sans espèces).
   */
  async dueBy(
    riderId: string,
  ): Promise<{ cashHeld: number; since: Date | null; dueBy: Date | null }> {
    const account = riderCashHeld(riderId);
    const cashHeld = await this.ledger.balance(account);
    if (cashHeld <= 0) return { cashHeld: 0, since: null, dueBy: null };
    const since = await this.oldestUnsettled(account.code, cashHeld);
    return { cashHeld, since, dueBy: since ? new Date(since.getTime() + this.deadlineMs) : null };
  }

  private get deadlineMs(): number {
    return this.env.CASH_DEPOSIT_DEADLINE_HOURS * HOUR_MS;
  }

  /** Encaissements les plus récents qui couvrent le solde : le plus ancien d'entre eux. */
  private async oldestUnsettled(code: string, cashHeld: number): Promise<Date | null> {
    const postings = await this.prisma.ledgerPosting.findMany({
      where: { account: { code }, amount: { gt: 0 } },
      orderBy: { createdAt: 'desc' },
      select: { amount: true, createdAt: true },
      take: 1_000,
    });
    let covered = 0;
    for (const posting of postings) {
      covered += posting.amount;
      if (covered >= cashHeld) return posting.createdAt;
    }
    return postings.at(-1)?.createdAt ?? null;
  }

  @Cron('0 */10 * * * *', { name: 'cash-discipline' })
  async scheduledSweep(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.sweep();
  }

  @Cron('0 0 18 * * *', { name: 'cash-reminder', timeZone: CAMEROON_TIME_ZONE })
  async scheduledReminder(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.remind();
  }

  /** Livreurs qui détiennent des espèces, avec leur solde ([only] : ceux-là seulement). */
  private async holders(only?: string[]): Promise<Map<string, number>> {
    const rows = await this.prisma.$queryRaw<{ riderId: string; balance: number }[]>`
      SELECT a.owner_id AS "riderId", SUM(p.amount)::int AS balance
        FROM ledger_accounts a
        JOIN ledger_postings p ON p.account_id = a.id
       WHERE a.owner_type = 'RIDER' AND a.code LIKE 'rider:%:cash_held'
       GROUP BY a.owner_id
      HAVING SUM(p.amount) > 0`;
    return new Map(
      rows
        .filter((row) => !only || only.includes(row.riderId))
        .map((row) => [row.riderId, row.balance]),
    );
  }

  /** Rappel de fin de journée : espèces à déposer avant l'heure limite. */
  async remind(now = new Date(), only?: string[]): Promise<number> {
    let sent = 0;
    for (const [riderId] of await this.holders(only)) {
      const rider = await this.prisma.riderProfile.findUnique({ where: { id: riderId } });
      if (!rider || rider.cashOverdueSince) continue;
      const { cashHeld, dueBy } = await this.dueBy(riderId);
      if (!dueBy || dueBy <= now) continue;
      await this.notifications.toUser(rider.userId, {
        template: 'RIDER_CASH_REMINDER',
        params: { amount: cashHeld, time: clock(dueBy) },
        data: { type: 'cash.reminder' },
      });
      sent++;
    }
    return sent;
  }

  /** Passage régulier : retards, suspensions, dépôts faits (blocage levé). */
  async sweep(
    now = new Date(),
    only?: string[],
  ): Promise<{ overdue: number; suspended: number; cleared: number }> {
    const holders = await this.holders(only);
    let overdue = 0;
    let suspended = 0;
    let cleared = 0;
    for (const [riderId] of holders) {
      const { cashHeld, dueBy } = await this.dueBy(riderId);
      if (!dueBy || dueBy > now) continue;
      const rider = await this.prisma.riderProfile.findUniqueOrThrow({ where: { id: riderId } });
      if (!rider.cashOverdueSince) {
        await this.markOverdue(rider.id, rider.userId, dueBy, cashHeld, now);
        overdue++;
      }
      const lateSince = rider.cashOverdueSince ?? dueBy;
      const suspendAt = lateSince.getTime() + this.env.CASH_OVERDUE_SUSPEND_HOURS * HOUR_MS;
      if (!rider.cashSuspendedAt && now.getTime() >= suspendAt) {
        await this.suspend(riderId, lateSince, now);
        suspended++;
      }
    }
    // Espèces déposées : le blocage tombe (une suspension reste à lever par la finance).
    const late = await this.prisma.riderProfile.findMany({
      where: { cashOverdueSince: { not: null }, ...(only ? { id: { in: only } } : {}) },
      select: { id: true },
    });
    for (const { id } of late) {
      if (holders.has(id)) {
        const { dueBy } = await this.dueBy(id);
        if (dueBy && dueBy > now) {
          await this.prisma.riderProfile.update({
            where: { id },
            data: { cashOverdueSince: null },
          });
          cleared++;
        }
        continue;
      }
      await this.prisma.riderProfile.update({ where: { id }, data: { cashOverdueSince: null } });
      cleared++;
    }
    return { overdue, suspended, cleared };
  }

  private async markOverdue(
    riderId: string,
    userId: string,
    dueBy: Date,
    cashHeld: number,
    now: Date,
  ): Promise<void> {
    await this.prisma.riderProfile.update({
      where: { id: riderId },
      data: { cashOverdueSince: dueBy, lastCashLateAt: now },
    });
    await this.notifications.toUser(userId, {
      template: 'RIDER_CASH_OVERDUE',
      params: { amount: cashHeld },
      data: { type: 'cash.overdue' },
    });
    await this.audit.record({
      actor: null,
      action: 'rider.cash_overdue',
      entityType: 'rider',
      entityId: riderId,
      after: { cashHeld, dueBy: dueBy.toISOString() },
    });
  }

  /**
   * Suspension faute de dépôt : les gains dus au livreur remboursent d'abord sa dette
   * d'espèces ; l'équipe est prévenue avec les coordonnées du garant.
   */
  private async suspend(riderId: string, lateSince: Date, now: Date): Promise<void> {
    const rider = await this.prisma.riderProfile.findUniqueOrThrow({
      where: { id: riderId },
      include: { user: { select: { id: true, fullName: true, phone: true } } },
    });
    const cash = riderCashHeld(riderId);
    const payable = riderPayable(riderId);
    const offset = await this.prisma.$transaction(async (tx) => {
      await this.ledger.lock(tx, [cash, payable]);
      const held = await this.ledger.balance(cash, tx);
      const earnings = await this.ledger.balance(payable, tx);
      const amount = Math.max(0, Math.min(held, earnings));
      if (amount > 0) {
        await this.ledger.post(tx, {
          kind: 'CASH_COMPENSATED',
          description: 'Gains retenus sur les espèces non déposées',
          idempotencyKey: `cash-offset:${riderId}:${lateSince.toISOString()}`,
          postings: [
            { account: payable, amount },
            { account: cash, amount: -amount },
          ],
        });
      }
      await tx.riderProfile.update({
        where: { id: riderId },
        data: { status: 'SUSPENDED', cashSuspendedAt: now },
      });
      return { amount, remaining: held - amount };
    });
    const days = Math.max(1, Math.round((now.getTime() - lateSince.getTime()) / (24 * HOUR_MS)));
    await this.notifications.toUser(rider.userId, {
      template: 'RIDER_CASH_SUSPENDED',
      params: { amount: offset.remaining },
      data: { type: 'cash.suspended' },
    });
    await this.notifications.toOps('OPS_CASH_OVERDUE', {
      rider: rider.user.fullName ?? 'Livreur',
      phone: rider.user.phone,
      amount: String(offset.remaining),
      offset: String(offset.amount),
      days: String(days),
      guarantor: rider.guarantorName ?? '-',
      guarantorPhone: rider.guarantorPhone ?? '-',
    });
    await this.audit.record({
      actor: null,
      action: 'rider.cash_suspended',
      entityType: 'rider',
      entityId: riderId,
      before: { status: rider.status },
      after: { status: 'SUSPENDED', offset: offset.amount, remaining: offset.remaining },
    });
    this.logger.warn(`Livreur ${riderId} suspendu : ${offset.remaining} FCFA non déposés`);
  }
}

/** Heure du Cameroun (18:42). */
function clock(date: Date): string {
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: CAMEROON_TIME_ZONE,
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}
