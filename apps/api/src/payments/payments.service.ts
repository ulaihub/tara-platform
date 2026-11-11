import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { maskPhone } from '../common/phone.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import { PLATFORM_ACCOUNTS } from '../finance/ledger.accounts.js';
import { LedgerService } from '../finance/ledger.service.js';
import { Prisma, type Payment } from '../generated/prisma/client.js';
import type { PaymentPurpose } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import {
  PAYMENT_PROVIDER,
  type PaymentProvider,
  type ProviderEvent,
  ProviderUnavailableError,
} from './payment.provider.js';

/**
 * Effets d'un paiement réussi, exécutés dans la transaction qui le confirme. Renvoie les
 * changements de statut de commande à publier une fois la transaction validée.
 */
export type PaymentSucceededHandler = (
  tx: Prisma.TransactionClient,
  payment: Payment,
) => Promise<OrderChange[] | void>;
/** Suite d'un paiement échoué, après validation (prévenir l'utilisateur). */
export type PaymentFailedHandler = (payment: Payment) => Promise<void>;
/** Autre destinataire des notifications du prestataire (reversements). */
export type ProviderEventSink = (event: ProviderEvent) => Promise<boolean>;

export interface CollectionInput {
  purpose: PaymentPurpose;
  amount: number;
  phone: string;
  idempotencyKey: string;
  description: string;
  orderId?: string | null;
  /** Lot de livraisons payé en une fois (C4). */
  batchId?: string | null;
  riderId?: string | null;
  payerId?: string | null;
  method?: 'MOMO_MTN' | 'MOMO_ORANGE';
}

/** Invites sans succès vers un même numéro sur la fenêtre, avant blocage. */
const MAX_UNANSWERED_PROMPTS = 5;
const UNANSWERED_WINDOW_MS = 10 * 60_000;

const isUniqueViolation = (error: unknown): boolean =>
  error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';

/**
 * Paiements entrants Mobile Money (G1, E5, G5) : demande envoyée au téléphone du payeur,
 * confirmation par notification du prestataire ou par interrogation régulière.
 *
 * Garanties : un paiement ne passe à « réussi » qu'une fois (mise à jour conditionnelle),
 * avec ses écritures dans la même transaction ; une notification déjà reçue est ignorée ;
 * un montant différent de celui demandé n'est jamais accepté ; un paiement confirmé après
 * son abandon est tout de même enregistré (l'argent n'est jamais perdu).
 */
@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly succeeded = new Map<PaymentPurpose, PaymentSucceededHandler>();
  private readonly failed = new Map<PaymentPurpose, PaymentFailedHandler>();
  private readonly sinks: ProviderEventSink[] = [];

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly realtime: RealtimeService,
    private readonly bus: OrderEventsBus,
    @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  get providerName(): string {
    return this.provider.name;
  }

  on(
    purpose: PaymentPurpose,
    onSucceeded: PaymentSucceededHandler,
    onFailed?: PaymentFailedHandler,
  ): void {
    this.succeeded.set(purpose, onSucceeded);
    if (onFailed) this.failed.set(purpose, onFailed);
  }

  addEventSink(sink: ProviderEventSink): void {
    this.sinks.push(sink);
  }

  // --- Demande de paiement ------------------------------------------------------------------

  async request(input: CollectionInput): Promise<Payment> {
    const existing = await this.prisma.payment.findUnique({
      where: { idempotencyKey: input.idempotencyKey },
    });
    if (existing) {
      if (existing.purpose !== input.purpose || existing.amount !== input.amount) {
        throw AppError.conflict('IDEMPOTENCY_CONFLICT');
      }
      return existing;
    }
    // Invites restées sans réponse ou refusées vers ce numéro : au-delà, on arrête de le
    // solliciter (une personne malveillante ne peut pas faire sonner le téléphone d'autrui).
    const unanswered = await this.prisma.payment.count({
      where: {
        payerPhone: input.phone,
        status: { in: ['PENDING', 'FAILED'] },
        createdAt: { gt: new Date(Date.now() - UNANSWERED_WINDOW_MS) },
      },
    });
    if (unanswered >= MAX_UNANSWERED_PROMPTS) throw AppError.tooMany('RATE_LIMITED');
    let payment: Payment;
    try {
      payment = await this.prisma.payment.create({
        data: {
          purpose: input.purpose,
          method: input.method ?? 'MOMO_MTN',
          amount: input.amount,
          payerPhone: input.phone,
          payerId: input.payerId ?? null,
          orderId: input.orderId ?? null,
          batchId: input.batchId ?? null,
          riderId: input.riderId ?? null,
          provider: this.provider.name,
          idempotencyKey: input.idempotencyKey,
        },
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const replay = await this.prisma.payment.findUnique({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (replay) return replay;
      // Une autre demande est déjà en attente pour cette commande.
      throw AppError.conflict('PAYMENT_ALREADY_PENDING');
    }

    try {
      const operation = await this.provider.collect({
        reference: payment.id,
        amount: payment.amount,
        phone: input.phone,
        // Opérateur choisi par le payeur ; sinon le prestataire le déduit du numéro.
        ...(input.method ? { operator: input.method === 'MOMO_ORANGE' ? 'ORANGE' : 'MTN' } : {}),
        description: input.description,
      });
      payment = await this.prisma.payment.update({
        where: { id: payment.id },
        data: { providerReference: operation.providerReference },
      });
      if (operation.status !== 'PENDING') {
        await this.applyStatus(payment.id, operation.status, operation);
        return this.prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      }
    } catch (error) {
      if (error instanceof ProviderUnavailableError) {
        // Issue inconnue : la demande a peut-être atteint le téléphone. La notification ou
        // l'interrogation régulière tranchera ; rien n'est renvoyé au payeur entre-temps.
        this.logger.warn(`Demande de paiement ${payment.id} sans réponse du prestataire`);
        return payment;
      }
      await this.applyStatus(payment.id, 'FAILED', { failureReason: String(error).slice(0, 300) });
      return this.prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
    }
    this.logger.log(
      `Paiement ${payment.id} demandé à ${maskPhone(input.phone)} (${payment.amount} FCFA)`,
    );
    return payment;
  }

  // --- Confirmation -------------------------------------------------------------------------

  /**
   * Applique un statut du prestataire. Sans effet si le paiement l'a déjà ; un succès
   * tardif (après abandon) est accepté, un échec après succès ignoré.
   */
  async applyStatus(
    paymentId: string,
    status: 'PENDING' | 'SUCCEEDED' | 'FAILED',
    details: {
      providerReference?: string;
      fee?: number;
      failureReason?: string;
      amount?: number | null;
    } = {},
  ): Promise<boolean> {
    if (status === 'PENDING') return false;
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment) return false;

    if (status === 'FAILED') {
      const { count } = await this.prisma.payment.updateMany({
        where: { id: paymentId, status: 'PENDING' },
        data: { status: 'FAILED', failureReason: details.failureReason ?? 'Refusé par le payeur' },
      });
      if (count !== 1) return false;
      const updated = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
      this.announce(updated);
      await this.failed
        .get(updated.purpose)?.(updated)
        .catch((error: unknown) => {
          this.logger.error(`Suite d'échec du paiement ${paymentId}`, error);
        });
      return true;
    }

    if (
      details.amount !== undefined &&
      details.amount !== null &&
      details.amount !== payment.amount
    ) {
      // Montant différent de celui demandé : jamais accepté, signalé au rapprochement.
      this.logger.error(
        `Paiement ${paymentId} : ${details.amount} FCFA reçus pour ${payment.amount} demandés`,
      );
      this.realtime.toOps('ops.finance-alert', {
        type: 'PAYMENT_AMOUNT_MISMATCH',
        paymentId,
        expected: payment.amount,
        received: details.amount,
      });
      return false;
    }

    const fee = Math.max(0, Math.min(payment.amount, details.fee ?? 0));
    const confirmed = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.payment.updateMany({
        where: { id: paymentId, status: { in: ['PENDING', 'FAILED', 'CANCELLED'] } },
        data: {
          status: 'SUCCEEDED',
          confirmedAt: new Date(),
          fee,
          ...(details.providerReference ? { providerReference: details.providerReference } : {}),
        },
      });
      if (count !== 1) return null;
      const updated = await tx.payment.findUniqueOrThrow({ where: { id: paymentId } });
      const handler = this.succeeded.get(updated.purpose);
      if (!handler) throw new Error(`Aucun traitement pour les paiements ${updated.purpose}`);
      const changes = (await handler(tx, updated)) ?? [];
      if (fee > 0) {
        await this.ledger.post(tx, {
          kind: 'ADJUSTMENT',
          description: `Frais Mobile Money du paiement ${updated.id}`,
          idempotencyKey: `payment:${updated.id}:provider-fee`,
          paymentId: updated.id,
          orderId: updated.orderId,
          postings: [
            { account: PLATFORM_ACCOUNTS.providerFees, amount: fee },
            { account: PLATFORM_ACCOUNTS.mobileMoney, amount: -fee },
          ],
        });
      }
      return { payment: updated, changes };
    });
    if (!confirmed) return false;
    this.announce(confirmed.payment);
    await this.bus.publishAll(confirmed.changes);
    return true;
  }

  private announce(payment: Payment): void {
    const event = {
      paymentId: payment.id,
      purpose: payment.purpose,
      status: payment.status,
      amount: payment.amount,
      orderId: payment.orderId,
    };
    if (payment.payerId) this.realtime.toUser(payment.payerId, 'payment.status', event);
    if (payment.orderId) this.realtime.toOrder(payment.orderId, 'payment.status', event);
  }

  // --- Notifications du prestataire ---------------------------------------------------------

  /**
   * Traite une notification déjà authentifiée. Chaque notification n'est traitée qu'une
   * fois (clé unique prestataire + identifiant), même si elle est renvoyée.
   */
  async handleEvent(
    event: ProviderEvent,
    payload: unknown,
  ): Promise<'processed' | 'duplicate' | 'unknown'> {
    try {
      await this.prisma.providerWebhookEvent.create({
        data: {
          provider: this.provider.name,
          eventId: event.eventId,
          signatureValid: true,
          payload: payload as Prisma.InputJsonValue,
        },
      });
    } catch (error) {
      if (isUniqueViolation(error)) return 'duplicate';
      throw error;
    }
    let handled = false;
    let failure: string | null = null;
    try {
      // Le statut est redemandé au prestataire quand sa signature ne garantit pas le contenu.
      if (this.provider.confirmEvent) event = await this.provider.confirmEvent(event);
      const payment = await this.findPayment(event);
      if (payment) {
        await this.applyStatus(payment.id, event.status, {
          providerReference: event.providerReference,
          ...(event.fee !== undefined ? { fee: event.fee } : {}),
          ...(event.failureReason ? { failureReason: event.failureReason } : {}),
          amount: event.amount,
        });
        handled = true;
      } else {
        for (const sink of this.sinks) {
          if (await sink(event)) {
            handled = true;
            break;
          }
        }
      }
    } catch (error) {
      failure = String(error).slice(0, 500);
      this.logger.error(`Notification ${event.eventId} en échec`, error);
    }
    await this.prisma.providerWebhookEvent.update({
      where: { provider_eventId: { provider: this.provider.name, eventId: event.eventId } },
      data: { processedAt: new Date(), error: failure ?? (handled ? null : 'Opération inconnue') },
    });
    return handled ? 'processed' : 'unknown';
  }

  private async findPayment(event: ProviderEvent): Promise<Payment | null> {
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (event.reference && uuid.test(event.reference)) {
      const byReference = await this.prisma.payment.findUnique({ where: { id: event.reference } });
      if (byReference) return byReference;
    }
    return this.prisma.payment.findFirst({
      where: { provider: this.provider.name, providerReference: event.providerReference },
    });
  }

  // --- Rattrapage ---------------------------------------------------------------------------

  @Cron('30 * * * * *', { name: 'payments-refresh' })
  async scheduledRefresh(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.refreshPending();
  }

  /**
   * Paiements en attente : statut redemandé au prestataire (notification perdue), puis
   * abandon après PAYMENT_REQUEST_TIMEOUT_MINUTES.
   */
  async refreshPending(now = new Date()): Promise<void> {
    const pending = await this.prisma.payment.findMany({
      where: {
        status: 'PENDING',
        provider: this.provider.name,
        createdAt: { lt: new Date(now.getTime() - 20_000) },
      },
      orderBy: { createdAt: 'asc' },
      take: 200,
    });
    const expiry = now.getTime() - this.env.PAYMENT_REQUEST_TIMEOUT_MINUTES * 60_000;
    for (const payment of pending) {
      try {
        if (payment.providerReference) {
          const operation = await this.provider.collectStatus(payment.providerReference);
          await this.prisma.payment.update({
            where: { id: payment.id },
            data: { lastCheckedAt: now },
          });
          if (operation.status !== 'PENDING') {
            await this.applyStatus(payment.id, operation.status, operation);
            continue;
          }
        }
        if (payment.createdAt.getTime() < expiry) {
          await this.applyStatus(payment.id, 'FAILED', {
            failureReason: 'Délai de validation dépassé',
          });
        }
      } catch (error) {
        this.logger.warn(`Statut du paiement ${payment.id} indisponible : ${String(error)}`);
      }
    }
  }
}
