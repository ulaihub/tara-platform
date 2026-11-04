import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { cameroonDate } from '../../src/common/time.js';
import {
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
} from '../../src/finance/ledger.accounts.js';
import { LedgerService } from '../../src/finance/ledger.service.js';
import { PayoutsService } from '../../src/finance/payouts.service.js';
import { ReconciliationService } from '../../src/finance/reconciliation.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../../src/payments/payment.provider.js';
import { PaymentsService } from '../../src/payments/payments.service.js';
import { createTestApp, staffUser, type TestContext } from '../helpers/app.js';
import { merchant, setupDouala, type TestMerchant } from '../helpers/orders.js';
import { activeRider, type TestRider } from '../helpers/riders.js';
import { random } from './simulation.js';

/**
 * Simulateur financier (critère de sortie de la phase 3) : des commandes aux paiements et
 * issues variés traversent toute la chaîne d'argent par l'API, avec les incidents réels du
 * Mobile Money (refus, notifications perdues ou répétées, réponses perdues après envoi).
 * À la fin : rapprochement de la journée, et contrôle qu'aucun reversement n'est parti deux fois.
 */
export interface FinanceSimulationOptions {
  orders: number;
  merchants: number;
  riders: number;
  seed: number;
  /** Commandes traitées en parallèle. */
  concurrency: number;
  log?: (line: string) => void;
}

export interface FinanceSimulationReport {
  orders: number;
  outcomes: Record<string, number>;
  payments: {
    succeeded: number;
    failed: number;
    duplicateNotifications: number;
    lostNotifications: number;
  };
  payouts: {
    succeeded: number;
    lostResponses: number;
    duplicateRequests: number;
    awaitingApproval: number;
  };
  /** Envois Mobile Money exécutés en double par le prestataire (doit être 0). */
  duplicateDisbursements: number;
  reconciliation: { status: string; discrepancies: unknown[] };
  ledgerTotal: number;
  realDurationSeconds: number;
}

export async function runFinanceSimulation(
  options: FinanceSimulationOptions,
): Promise<FinanceSimulationReport> {
  const log = options.log ?? (() => undefined);
  const rng = random(options.seed);
  const pick = <T>(items: T[]): T => items[Math.floor(rng() * items.length)] as T;
  const started = Date.now();
  const ctx: TestContext = await createTestApp({ PAYOUT_APPROVAL_THRESHOLD: '300000' });
  const outcomes: Record<string, number> = {};
  const count = (key: string): void => {
    outcomes[key] = (outcomes[key] ?? 0) + 1;
  };
  const stats = {
    duplicateNotifications: 0,
    lostNotifications: 0,
    lostResponses: 0,
    duplicateRequests: 0,
  };

  try {
    // Serveur à l'écoute : les requêtes parallèles partagent la même connexion d'écoute.
    await ctx.app.listen(0);
    const admin = await staffUser(ctx, ['ADMIN']);
    const ops = await staffUser(ctx, ['DISPATCHER']);
    const finance = await staffUser(ctx, ['FINANCE']);
    await setupDouala(ctx, admin);
    const provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
    const payments = ctx.app.get(PaymentsService);
    const payouts = ctx.app.get(PayoutsService);
    const ledger = ctx.app.get(LedgerService);

    const shops: TestMerchant[] = [];
    for (let i = 0; i < options.merchants; i += 1) {
      const shop = await merchant(ctx);
      // Solde de départ pour les commandes payées par le solde.
      await request(ctx.http)
        .post(`/v1/admin/finance/users/${shop.userId}/credits`)
        .set(finance.auth)
        .set('Idempotency-Key', randomUUID())
        .send({ amount: 50_000, reason: 'Crédit de départ (simulation)' })
        .expect(201);
      shops.push(shop);
    }
    const riders: TestRider[] = [];
    // Solde prépayé confortable : chaque livreur peut porter deux courses avec encaissement.
    for (let i = 0; i < options.riders; i += 1)
      riders.push(await activeRider(ctx, { balance: 1_000_000 }));
    log(`${shops.length} marchands, ${riders.length} livreurs ; ${options.orders} commandes`);

    /** Notification du prestataire : parfois perdue (rattrapée par l'interrogation), parfois répétée. */
    const notify = async (
      providerReference: string,
      status: 'SUCCEEDED' | 'FAILED',
    ): Promise<void> => {
      const { body, signature } = await provider.settle(providerReference, status);
      const roll = rng();
      if (roll < 0.08) {
        stats.lostNotifications += 1;
        return;
      }
      const times = roll < 0.4 ? 2 : 1;
      if (times === 2) stats.duplicateNotifications += 1;
      for (let i = 0; i < times; i += 1) {
        await request(ctx.http)
          .post('/v1/webhooks/payments/fake')
          .set('Content-Type', 'application/json')
          .set('X-Fake-Signature', signature)
          .send(body)
          .expect(200);
      }
    };

    /** Paiement Mobile Money jusqu'au succès : un payeur sur dix refuse d'abord. */
    const payUntilDone = async (
      ask: (phone: string) => Promise<{ id: string; status: string }>,
      phone: string,
    ): Promise<void> => {
      if (rng() < 0.1) {
        provider.decliningPhones.add(phone);
        const declined = await ask(phone);
        provider.decliningPhones.delete(phone);
        if (declined.status !== 'FAILED') throw new Error('Refus attendu');
      }
      const payment = await ask(phone);
      const reference = (await ctx.prisma.payment.findUniqueOrThrow({ where: { id: payment.id } }))
        .providerReference;
      if (!reference) throw new Error('Paiement sans référence');
      await notify(reference, 'SUCCEEDED');
      const stored = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      if (stored.status === 'PENDING') await payments.refreshPending(new Date(Date.now() + 60_000));
    };

    const transition = async (orderId: string, to: string, extra: Record<string, unknown> = {}) => {
      const res = await request(ctx.http)
        .post(`/v1/admin/orders/${orderId}/transition`)
        .set(ops.auth)
        .send({ to, ...extra });
      if (res.status !== 200) {
        const order = await ctx.prisma.order.findUnique({ where: { id: orderId } });
        throw new Error(
          `${to} refusé (${res.status}) : ${JSON.stringify(res.body)} ; commande ${order?.status}, ${order?.feePaymentMethod}, payée ${String(order?.feePaidAt)}`,
        );
      }
      return res;
    };

    const processOrder = async (): Promise<void> => {
      const shop = pick(shops);
      const roll = rng();
      const feePayer = roll < 0.4 ? 'RECIPIENT' : 'SENDER';
      const method =
        feePayer === 'RECIPIENT'
          ? 'CASH'
          : pick(['CASH', 'CASH', 'MOMO_MTN', 'MOMO_ORANGE', 'WALLET']);
      const codAmount = rng() < 0.5 ? Math.round((2_000 + rng() * 48_000) / 50) * 50 : 0;
      const recipientPhone = `+2376${String(Math.floor(rng() * 1e8)).padStart(8, '0')}`;
      const created = await request(ctx.http)
        .post('/v1/orders')
        .set(shop.auth)
        .send({
          pickupAddressId: shop.pickupId,
          dropoffAddressId: shop.dropoffId,
          recipientName: 'Client simulé',
          recipientPhone,
          packageSize: pick(['S', 'M', 'L']),
          feePayer,
          feePaymentMethod: method,
          codAmount,
        });
      if (created.status === 422 && created.body.error?.code === 'INSUFFICIENT_BALANCE') {
        count('refused-balance');
        return;
      }
      if (created.status !== 201)
        throw new Error(`Commande refusée : ${JSON.stringify(created.body)}`);
      const orderId = created.body.order.id as string;
      count(`method:${feePayer === 'RECIPIENT' ? 'RECIPIENT' : method}`);

      if (method.startsWith('MOMO_')) {
        await payUntilDone(
          async (phone) => {
            const res = await request(ctx.http)
              .post(`/v1/orders/${orderId}/pay`)
              .set(shop.auth)
              .send({ phone, operator: method === 'MOMO_ORANGE' ? 'ORANGE' : 'MTN' })
              .expect(201);
            return res.body as { id: string; status: string };
            // Un payeur par commande : les refus simulés ne débordent pas sur une autre commande.
          },
          `+2376${String(Math.floor(rng() * 1e8)).padStart(8, '0')}`,
        );
      }

      const outcome = rng();
      if (outcome < 0.08) {
        await request(ctx.http)
          .post(`/v1/orders/${orderId}/cancel`)
          .set(shop.auth)
          .send({ reason: 'Annulée par le client' })
          .expect(200);
        count('cancelled');
        return;
      }
      const rider = pick(riders);
      await transition(orderId, 'ASSIGNED', { riderId: rider.riderId });
      await transition(orderId, 'PICKED_UP');
      await transition(orderId, 'IN_DELIVERY');

      if (outcome < 0.15) {
        await transition(orderId, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' });
        await transition(orderId, 'RETURNED');
        count('returned');
        return;
      }
      if (outcome < 0.2) {
        await transition(orderId, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_UNREACHABLE' });
        await transition(orderId, 'IN_DELIVERY');
        count('retried');
      }

      const due = await request(ctx.http)
        .get(`/v1/rider/orders/${orderId}/collection`)
        .set(rider.auth)
        .expect(200);
      if (!due.body.complete) {
        if (rng() < 0.6) {
          await request(ctx.http)
            .post(`/v1/rider/orders/${orderId}/collect`)
            .set(rider.auth)
            .send({ method: 'CASH' })
            .expect(200);
          count('collected:cash');
        } else {
          await payUntilDone(async (phone) => {
            const res = await request(ctx.http)
              .post(`/v1/rider/orders/${orderId}/collect`)
              .set(rider.auth)
              .send({ method: 'MOBILE_MONEY', phone, operator: 'MTN' })
              .expect(200);
            const paymentRow = await ctx.prisma.payment.findFirstOrThrow({
              where: { orderId, purpose: { in: ['COD', 'DELIVERY_FEE'] } },
              orderBy: { createdAt: 'desc' },
            });
            return { id: paymentRow.id, status: res.body.payment ? 'PENDING' : paymentRow.status };
          }, recipientPhone);
          count('collected:momo');
        }
      }
      await transition(orderId, 'DELIVERED');
      count('delivered');
    };

    for (let done = 0; done < options.orders; done += options.concurrency) {
      const batch = Math.min(options.concurrency, options.orders - done);
      await Promise.all(Array.from({ length: batch }, () => processOrder()));
      if ((done + batch) % 100 === 0) log(`${done + batch} commandes traitées`);
    }

    // Espèces des livreurs : moitié déposées au bureau, moitié par Mobile Money.
    for (const rider of riders) {
      const cash = await ledger.balance(riderCashHeld(rider.riderId));
      if (cash <= 0) continue;
      if (rng() < 0.5) {
        await request(ctx.http)
          .post(`/v1/admin/finance/riders/${rider.riderId}/cash-deposits`)
          .set(finance.auth)
          .set('Idempotency-Key', randomUUID())
          .send({ amount: cash, note: 'Dépôt au bureau (simulation)' })
          .expect(201);
      } else {
        await payUntilDone(async (phone) => {
          const res = await request(ctx.http)
            .post('/v1/rider/cash-deposits')
            .set(rider.auth)
            .set('Idempotency-Key', randomUUID())
            .send({ amount: cash, phone, operator: 'MTN' })
            .expect(201);
          return res.body as { id: string; status: string };
        }, rider.phone);
      }
    }

    // Retraits des livreurs : chaque demande envoyée deux fois (double clic, coupure).
    for (const rider of riders) {
      if ((await payouts.available('RIDER', rider.riderId)) < 500) continue;
      const key = randomUUID();
      stats.duplicateRequests += 1;
      await Promise.all(
        [0, 1].map(() =>
          request(ctx.http)
            .post('/v1/rider/withdrawals')
            .set(rider.auth)
            .set('Idempotency-Key', key)
            .send({ phone: rider.phone, operator: 'MTN' }),
        ),
      );
    }

    // Reversements quotidiens des marchands : le premier envoi, puis un sur cinq, perd sa
    // réponse (au moins une coupure à chaque passage, quel que soit l'ordre des tirages).
    const original = provider.disburse.bind(provider);
    provider.disburse = (disbursement) => {
      if (stats.lostResponses === 0 || rng() < 0.2) {
        provider.loseResponseOnce.add(disbursement.reference);
        stats.lostResponses += 1;
      }
      return original(disbursement);
    };
    await payouts.dailyMerchantPayouts();
    await payouts.dailyMerchantPayouts(); // Tâche relancée le même jour : sans effet.
    const awaiting = await ctx.prisma.payout.findMany({
      where: {
        status: 'AWAITING_APPROVAL',
        merchant: { userId: { in: shops.map((shop) => shop.userId) } },
      },
    });
    for (const payout of awaiting) {
      await request(ctx.http)
        .post(`/v1/admin/finance/payouts/${payout.id}/approve`)
        .set(finance.auth)
        .expect(200);
    }
    await payouts.checkProcessing(new Date(Date.now() + 120_000));
    await payouts.checkProcessing(new Date(Date.now() + 240_000));
    provider.disburse = original;

    // Notifications de reversement répétées après coup : sans effet.
    const simulated = await ctx.prisma.payout.findMany({
      where: {
        OR: [
          { merchant: { userId: { in: shops.map((shop) => shop.userId) } } },
          { riderId: { in: riders.map((rider) => rider.riderId) } },
        ],
      },
    });
    for (const payout of simulated.filter((p) => p.providerReference)) {
      const operation = provider.operations.get(payout.providerReference ?? '');
      if (!operation) continue;
      const { body, signature } = provider.webhookFor(operation);
      await request(ctx.http)
        .post('/v1/webhooks/payments/fake')
        .set('Content-Type', 'application/json')
        .set('X-Fake-Signature', signature)
        .send(body)
        .expect(200);
    }

    await payments.refreshPending(new Date(Date.now() + 3_600_000));
    const duplicateDisbursements = simulated.reduce(
      (sum, payout) => sum + Math.max(0, provider.disbursementsFor(payout.id) - 1),
      0,
    );
    const finalPayouts = await ctx.prisma.payout.findMany({
      where: { id: { in: simulated.map((p) => p.id) } },
    });
    const report = await ctx.app.get(ReconciliationService).run(cameroonDate(new Date()));
    const [total] = await ctx.prisma.$queryRaw<
      { total: bigint }[]
    >`SELECT COALESCE(SUM(amount), 0)::bigint AS total FROM ledger_postings`;
    const paymentRows = await ctx.prisma.payment.groupBy({ by: ['status'], _count: true });
    const merchantBalances = await ledger.balances(
      await Promise.all(
        shops.map(async (shop) =>
          merchantPayable(
            (await ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } }))
              .id,
          ),
        ),
      ),
    );
    log(`Soldes marchands après reversement : ${[...merchantBalances.values()].join(', ')}`);
    log(`Mobile Money (grand livre) : ${await ledger.balance(PLATFORM_ACCOUNTS.mobileMoney)} FCFA`);

    return {
      orders: options.orders,
      outcomes,
      payments: {
        succeeded: paymentRows.find((row) => row.status === 'SUCCEEDED')?._count ?? 0,
        failed: paymentRows.find((row) => row.status === 'FAILED')?._count ?? 0,
        duplicateNotifications: stats.duplicateNotifications,
        lostNotifications: stats.lostNotifications,
      },
      payouts: {
        succeeded: finalPayouts.filter((payout) => payout.status === 'SUCCEEDED').length,
        lostResponses: stats.lostResponses,
        duplicateRequests: stats.duplicateRequests,
        awaitingApproval: awaiting.length,
      },
      duplicateDisbursements,
      reconciliation: { status: report.status, discrepancies: report.discrepancies as unknown[] },
      ledgerTotal: Number(total?.total ?? 0),
      realDurationSeconds: Math.round((Date.now() - started) / 100) / 10,
    };
  } finally {
    await ctx.app.close();
  }
}
