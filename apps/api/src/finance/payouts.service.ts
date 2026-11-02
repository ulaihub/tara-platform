import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { CAMEROON_TIME_ZONE, cameroonDate, cameroonHour } from '../common/time.js';
import { Prisma, type Payout } from '../generated/prisma/client.js';
import type { MobileMoneyOperator, PayoutBeneficiary } from '../generated/prisma/enums.js';
import { NotificationService } from '../notifications/notification.service.js';
import {
  PAYMENT_PROVIDER,
  type PaymentProvider,
  type ProviderEvent,
  ProviderUnavailableError,
} from '../payments/payment.provider.js';
import { PaymentsService } from '../payments/payments.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { QueueService } from '../redis/queue.service.js';
import {
  type AccountSpec,
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
  riderPayable,
} from './ledger.accounts.js';
import { LedgerService } from './ledger.service.js';

export interface PayoutRequest {
  beneficiary: PayoutBeneficiary;
  /** Marchand, livreur ou utilisateur selon le bénéficiaire. */
  ownerId: string;
  /** Montant demandé ; par défaut tout le disponible. */
  amount?: number | undefined;
  phone: string;
  operator: MobileMoneyOperator;
  idempotencyKey: string;
}

const isUniqueViolation = (error: unknown): boolean =>
  error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';

/** Une réponse perdue n'est réexaminée qu'après ce délai (le prestataire peut être lent). */
const RECHECK_AFTER_MS = 60_000;

/**
 * Reversements vers Mobile Money (G3, G4, G8) : marchands chaque jour à heure fixe ou à la
 * demande (offres Pro), livreurs à la demande, clients remboursés de leur solde.
 *
 * Aucun reversement en double :
 * - une seule demande en cours par bénéficiaire (index unique en base) ;
 * - le montant quitte le portefeuille à la demande, sous verrou, et n'y revient qu'en cas
 *   d'échec certain ;
 * - le passage « en cours → envoyé » est conditionnel : une notification répétée est sans effet ;
 * - si la réponse du prestataire se perd, on lui redemande le statut par NOTRE référence avant
 *   tout nouvel envoi ; on ne renvoie que s'il n'a jamais reçu la demande.
 */
@Injectable()
export class PayoutsService implements OnModuleInit {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly payments: PaymentsService,
    private readonly queue: QueueService,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
    private readonly audit: AuditService,
    @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  onModuleInit(): void {
    this.payments.addEventSink((event) => this.onProviderEvent(event));
    this.queue.register('payouts', (job) => this.process((job.data as { id: string }).id), 5);
  }

  private account(beneficiary: PayoutBeneficiary, ownerId: string): AccountSpec {
    switch (beneficiary) {
      case 'MERCHANT':
        return merchantPayable(ownerId);
      case 'RIDER':
        return riderPayable(ownerId);
      case 'CUSTOMER':
        return customerWallet(ownerId);
    }
  }

  /** Disponible au reversement ; pour un livreur, ses gains moins les espèces qu'il détient. */
  async available(
    beneficiary: PayoutBeneficiary,
    ownerId: string,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<number> {
    const balance = await this.ledger.balance(this.account(beneficiary, ownerId), db);
    if (beneficiary !== 'RIDER') return Math.max(0, balance);
    const cash = await this.ledger.balance(riderCashHeld(ownerId), db);
    return Math.max(0, balance - Math.max(0, cash));
  }

  // --- Demande ------------------------------------------------------------------------------

  async request(input: PayoutRequest): Promise<Payout> {
    const replay = await this.prisma.payout.findUnique({
      where: { idempotencyKey: input.idempotencyKey },
    });
    if (replay) return replay;
    const account = this.account(input.beneficiary, input.ownerId);
    let payout: Payout;
    try {
      payout = await this.prisma.$transaction(async (tx) => {
        const locked =
          input.beneficiary === 'RIDER' ? [account, riderCashHeld(input.ownerId)] : [account];
        await this.ledger.lock(tx, locked);
        const available = await this.available(input.beneficiary, input.ownerId, tx);
        const amount = input.amount ?? available;
        if (amount < this.env.PAYOUT_MIN_AMOUNT) {
          throw AppError.unprocessable('PAYOUT_TOO_SMALL', { min: this.env.PAYOUT_MIN_AMOUNT });
        }
        if (amount > available)
          throw AppError.unprocessable('INSUFFICIENT_BALANCE', { balance: available });
        const created = await tx.payout.create({
          data: {
            beneficiary: input.beneficiary,
            merchantId: input.beneficiary === 'MERCHANT' ? input.ownerId : null,
            riderId: input.beneficiary === 'RIDER' ? input.ownerId : null,
            userId: input.beneficiary === 'CUSTOMER' ? input.ownerId : null,
            amount,
            phone: input.phone,
            operator: input.operator,
            provider: this.provider.name,
            idempotencyKey: input.idempotencyKey,
            // Gros montant : un responsable financier valide avant l'envoi.
            status: amount >= this.env.PAYOUT_APPROVAL_THRESHOLD ? 'AWAITING_APPROVAL' : 'PENDING',
          },
        });
        await this.ledger.post(tx, {
          kind: 'PAYOUT_REQUESTED',
          description: `Reversement de ${amount} FCFA demandé`,
          idempotencyKey: `payout:${created.id}:request`,
          payoutId: created.id,
          postings: [
            { account, amount },
            { account: PLATFORM_ACCOUNTS.payoutsInTransit, amount: -amount },
          ],
        });
        return created;
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const existing = await this.prisma.payout.findUnique({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (existing) return existing;
      throw AppError.conflict('PAYOUT_IN_PROGRESS');
    }
    if (payout.status === 'AWAITING_APPROVAL') {
      this.realtime.toOps('ops.finance-alert', {
        type: 'PAYOUT_AWAITING_APPROVAL',
        payoutId: payout.id,
        amount: payout.amount,
      });
      return payout;
    }
    await this.dispatch(payout.id);
    return this.prisma.payout.findUniqueOrThrow({ where: { id: payout.id } });
  }

  private async dispatch(id: string): Promise<void> {
    if (this.queue.workersEnabled) {
      await this.queue.add('payouts', 'process', { id }, { jobId: `payout-${id}`, attempts: 1 });
      return;
    }
    await this.process(id);
  }

  // --- Envoi --------------------------------------------------------------------------------

  /** Envoie un reversement en attente. Sans effet s'il a déjà été pris en charge. */
  async process(id: string): Promise<void> {
    const { count } = await this.prisma.payout.updateMany({
      where: { id, status: 'PENDING' },
      data: { status: 'PROCESSING', lastCheckedAt: new Date() },
    });
    if (count !== 1) return;
    await this.send(await this.prisma.payout.findUniqueOrThrow({ where: { id } }));
  }

  private async send(payout: Payout): Promise<void> {
    try {
      const operation = await this.provider.disburse({
        reference: payout.id,
        amount: payout.amount,
        phone: payout.phone,
        description: `Tara reversement ${payout.id.slice(0, 8)}`,
      });
      await this.prisma.payout.update({
        where: { id: payout.id },
        data: { providerReference: operation.providerReference },
      });
      if (operation.status !== 'PENDING') {
        await this.settle(payout.id, operation.status, operation);
      }
    } catch (error) {
      if (error instanceof ProviderUnavailableError) {
        // Issue inconnue : surtout ne pas renvoyer. Le contrôle régulier tranchera.
        this.logger.warn(`Reversement ${payout.id} : réponse du prestataire perdue`);
        return;
      }
      await this.settle(payout.id, 'FAILED', { failureReason: String(error).slice(0, 300) });
    }
  }

  /** Clôture un reversement en cours ; une seconde clôture est sans effet. */
  async settle(
    id: string,
    status: 'SUCCEEDED' | 'FAILED',
    details: { providerReference?: string; fee?: number; failureReason?: string } = {},
  ): Promise<boolean> {
    const payout = await this.prisma.$transaction(async (tx) => {
      const current = await tx.payout.findUnique({ where: { id } });
      if (!current) return null;
      const fee = Math.max(0, details.fee ?? 0);
      const { count } = await tx.payout.updateMany({
        where: { id, status: 'PROCESSING' },
        data: {
          status,
          completedAt: new Date(),
          fee: status === 'SUCCEEDED' ? fee : 0,
          failureReason:
            status === 'FAILED' ? (details.failureReason ?? 'Refusé par le prestataire') : null,
          ...(details.providerReference ? { providerReference: details.providerReference } : {}),
        },
      });
      if (count !== 1) return null;
      const account = this.account(
        current.beneficiary,
        current.merchantId ?? current.riderId ?? current.userId ?? '',
      );
      if (status === 'SUCCEEDED') {
        await this.ledger.post(tx, {
          kind: 'PAYOUT_SENT',
          description: `Reversement de ${current.amount} FCFA envoyé`,
          idempotencyKey: `payout:${id}:sent`,
          payoutId: id,
          postings: [
            { account: PLATFORM_ACCOUNTS.payoutsInTransit, amount: current.amount },
            { account: PLATFORM_ACCOUNTS.mobileMoney, amount: -current.amount },
            { account: PLATFORM_ACCOUNTS.providerFees, amount: fee },
            { account: PLATFORM_ACCOUNTS.mobileMoney, amount: -fee },
          ],
        });
      } else {
        await this.ledger.post(tx, {
          kind: 'PAYOUT_FAILED',
          description: `Reversement de ${current.amount} FCFA échoué : montant rendu`,
          idempotencyKey: `payout:${id}:failed`,
          payoutId: id,
          postings: [
            { account: PLATFORM_ACCOUNTS.payoutsInTransit, amount: current.amount },
            { account, amount: -current.amount },
          ],
        });
      }
      return tx.payout.findUniqueOrThrow({ where: { id } });
    });
    if (!payout) return false;
    await this.announce(payout);
    return true;
  }

  private async announce(payout: Payout): Promise<void> {
    const userId = await this.ownerUserId(payout);
    if (!userId) return;
    this.realtime.toUser(userId, 'payout.status', {
      payoutId: payout.id,
      status: payout.status,
      amount: payout.amount,
    });
    if (payout.status === 'SUCCEEDED' || payout.status === 'FAILED') {
      await this.notifications
        .toUser(userId, {
          template: payout.status === 'SUCCEEDED' ? 'PAYOUT_SENT' : 'PAYOUT_FAILED',
          params: { amount: payout.amount.toLocaleString('fr-FR') },
          data: { type: 'payout.status', payoutId: payout.id },
        })
        .catch(() => undefined);
    }
  }

  private async ownerUserId(payout: Payout): Promise<string | null> {
    if (payout.userId) return payout.userId;
    if (payout.merchantId) {
      return (
        (await this.prisma.merchantProfile.findUnique({ where: { id: payout.merchantId } }))
          ?.userId ?? null
      );
    }
    if (payout.riderId) {
      return (
        (await this.prisma.riderProfile.findUnique({ where: { id: payout.riderId } }))?.userId ??
        null
      );
    }
    return null;
  }

  private async onProviderEvent(event: ProviderEvent): Promise<boolean> {
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const payout =
      (event.reference && uuid.test(event.reference)
        ? await this.prisma.payout.findUnique({ where: { id: event.reference } })
        : null) ??
      (await this.prisma.payout.findFirst({
        where: { provider: this.provider.name, providerReference: event.providerReference },
      }));
    if (!payout) return false;
    if (event.status !== 'PENDING') {
      await this.settle(payout.id, event.status, {
        providerReference: event.providerReference,
        ...(event.fee !== undefined ? { fee: event.fee } : {}),
        ...(event.failureReason ? { failureReason: event.failureReason } : {}),
      });
    }
    return true;
  }

  // --- Contrôles réguliers ------------------------------------------------------------------

  @Cron('15 * * * * *', { name: 'payouts-check' })
  async scheduledCheck(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.checkProcessing();
  }

  /**
   * Reversements « en cours » sans réponse : statut redemandé par notre référence. S'il n'a
   * jamais reçu la demande, et seulement dans ce cas, le prestataire la reçoit à nouveau.
   */
  async checkProcessing(now = new Date()): Promise<void> {
    const stuck = await this.prisma.payout.findMany({
      where: {
        status: 'PROCESSING',
        OR: [
          { lastCheckedAt: null },
          { lastCheckedAt: { lt: new Date(now.getTime() - RECHECK_AFTER_MS) } },
        ],
      },
      take: 100,
    });
    for (const payout of stuck) {
      try {
        await this.prisma.payout.update({ where: { id: payout.id }, data: { lastCheckedAt: now } });
        const operation = await this.provider.disburseStatus(payout.id);
        if (!operation) {
          this.logger.warn(
            `Reversement ${payout.id} jamais reçu par le prestataire : nouvel envoi`,
          );
          await this.send(payout);
        } else if (operation.status !== 'PENDING') {
          await this.settle(payout.id, operation.status, operation);
        }
      } catch (error) {
        this.logger.warn(`Contrôle du reversement ${payout.id} impossible : ${String(error)}`);
      }
    }
  }

  @Cron('0 0 * * * *', { name: 'payouts-daily', timeZone: CAMEROON_TIME_ZONE })
  async scheduledDaily(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    if (cameroonHour(new Date()) !== this.env.PAYOUT_DAILY_HOUR) return;
    await this.dailyMerchantPayouts();
  }

  /** Reversement quotidien des marchands (G3) : une seule fois par jour et par marchand. */
  async dailyMerchantPayouts(now = new Date()): Promise<{ requested: number; skipped: number }> {
    const merchants = await this.prisma.merchantProfile.findMany({
      where: { payoutSchedule: 'DAILY' },
    });
    const day = cameroonDate(now);
    let requested = 0;
    let skipped = 0;
    for (const merchant of merchants) {
      const available = await this.available('MERCHANT', merchant.id);
      if (available < this.env.PAYOUT_MIN_AMOUNT) {
        skipped += 1;
        continue;
      }
      try {
        await this.request({
          beneficiary: 'MERCHANT',
          ownerId: merchant.id,
          phone: merchant.payoutPhone,
          operator: merchant.payoutOperator,
          idempotencyKey: `merchant:${merchant.id}:daily:${day}`,
        });
        requested += 1;
      } catch (error) {
        skipped += 1;
        if (!(error instanceof AppError))
          this.logger.error(`Reversement quotidien ${merchant.id}`, error);
      }
    }
    return { requested, skipped };
  }

  // --- Validation par la finance ------------------------------------------------------------

  async approve(id: string, staff: AuthUser, request: Request): Promise<Payout> {
    const { count } = await this.prisma.payout.updateMany({
      where: { id, status: 'AWAITING_APPROVAL' },
      data: { status: 'PENDING', approvedById: staff.id, approvedAt: new Date() },
    });
    if (count !== 1) throw AppError.conflict('PAYOUT_NOT_AWAITING_APPROVAL');
    await this.audit.record({
      actor: staff,
      action: 'payout.approved',
      entityType: 'payout',
      entityId: id,
      request,
    });
    await this.dispatch(id);
    return this.prisma.payout.findUniqueOrThrow({ where: { id } });
  }

  async reject(id: string, staff: AuthUser, reason: string, request: Request): Promise<Payout> {
    const payout = await this.prisma.$transaction(async (tx) => {
      const current = await tx.payout.findUnique({ where: { id } });
      const { count } = await tx.payout.updateMany({
        where: { id, status: 'AWAITING_APPROVAL' },
        data: {
          status: 'CANCELLED',
          failureReason: reason,
          approvedById: staff.id,
          approvedAt: new Date(),
        },
      });
      if (count !== 1 || !current) throw AppError.conflict('PAYOUT_NOT_AWAITING_APPROVAL');
      await this.ledger.post(tx, {
        kind: 'PAYOUT_FAILED',
        description: `Reversement de ${current.amount} FCFA refusé par la finance : montant rendu`,
        idempotencyKey: `payout:${id}:cancelled`,
        payoutId: id,
        postedById: staff.id,
        postings: [
          { account: PLATFORM_ACCOUNTS.payoutsInTransit, amount: current.amount },
          {
            account: this.account(
              current.beneficiary,
              current.merchantId ?? current.riderId ?? current.userId ?? '',
            ),
            amount: -current.amount,
          },
        ],
      });
      return tx.payout.findUniqueOrThrow({ where: { id } });
    });
    await this.audit.record({
      actor: staff,
      action: 'payout.rejected',
      entityType: 'payout',
      entityId: id,
      after: { reason },
      request,
    });
    await this.announce(payout);
    return payout;
  }
}
