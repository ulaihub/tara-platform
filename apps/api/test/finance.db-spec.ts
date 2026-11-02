import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
  riderPayable,
} from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { PaymentsService } from '../src/payments/payments.service.js';
import { PayoutsService } from '../src/finance/payouts.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../src/payments/payment.provider.js';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { createAddress, PLACES } from './helpers/geo.js';
import { merchant, type PlacedOrder, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider, type TestRider } from './helpers/riders.js';

describe('Argent : paiements, encaissements, portefeuilles, reversements (G1 à G8)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;
  let finance: SignedIn;
  let ledger: LedgerService;
  let provider: FakePaymentProvider;

  beforeAll(async () => {
    ctx = await createTestApp({ PAYOUT_APPROVAL_THRESHOLD: '50000' });
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    finance = await staffUser(ctx, ['FINANCE']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const key = (): string => randomUUID();

  async function order(id: string) {
    return ctx.prisma.order.findUniqueOrThrow({ where: { id } });
  }

  /** Commande attribuée, enlevée et en route, par le dispatch (sans passer par l'attribution). */
  async function toTheDoor(placed: PlacedOrder, rider: TestRider): Promise<void> {
    const go = (to: string, extra: Record<string, unknown> = {}) =>
      request(ctx.http)
        .post(`/v1/admin/orders/${placed.id}/transition`)
        .set(ops.auth)
        .send({ to, ...extra })
        .expect(200);
    await go('ASSIGNED', { riderId: rider.riderId });
    await go('PICKED_UP');
    await go('IN_DELIVERY');
  }

  /** Le prestataire confirme : notification signée envoyée au webhook. */
  async function settle(providerReference: string, status: 'SUCCEEDED' | 'FAILED') {
    const { body, signature } = await provider.settle(providerReference, status);
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
    return { body, signature };
  }

  async function pendingReference(paymentId: string): Promise<string> {
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    return payment.providerReference ?? '';
  }

  it('espèces : frais à l’enlèvement, contre-remboursement à la porte, part du livreur gardée', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 10_000 });
    await toTheDoor(placed, rider);
    const o = await order(placed.id);
    expect(o.feePaidAt).not.toBeNull();
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(o.totalPrice);

    const due = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}/collection`)
      .set(rider.auth)
      .expect(200);
    expect(due.body).toMatchObject({
      due: { fee: 0, cod: 10_000, total: 10_000 },
      complete: false,
    });
    await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(409);
    await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to: 'DELIVERED' })
      .expect(200);

    // Marchand : 10 000 − 2 % (minimum 250) ; livreur : sa part prise sur les espèces.
    expect(await ledger.balance(merchantPayable(o.merchantId ?? ''))).toBe(9_750);
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(0);
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(
      o.totalPrice + 10_000 - o.riderEarning,
    );
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(wallet.body).toMatchObject({
      earnings: 0,
      cashHeld: o.totalPrice + 10_000 - o.riderEarning,
      available: 0,
    });

    const lines = await request(ctx.http)
      .get('/v1/me/wallet/transactions?account=merchant')
      .set(shop.auth)
      .expect(200);
    expect(lines.body.items[0]).toMatchObject({
      amount: 9_750,
      kind: 'COD_COLLECTED',
      orderReference: placed.reference,
    });
  });

  it('prépaiement Mobile Money : la commande part à la confirmation, une seule fois', async () => {
    const shop = await merchant(ctx);
    const placed = await placeOrder(ctx, shop, { feePaymentMethod: 'MOMO_MTN' });
    expect(placed.status).toBe('CREATED');

    const pay = await request(ctx.http)
      .post(`/v1/orders/${placed.id}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(201);
    expect(pay.body).toMatchObject({ status: 'PENDING', purpose: 'DELIVERY_FEE' });
    await request(ctx.http)
      .post(`/v1/orders/${placed.id}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(409);

    const reference = await pendingReference(pay.body.id);
    const { body, signature } = await settle(reference, 'SUCCEEDED');
    // Notification répétée : aucun effet.
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
    // Notification falsifiée : refusée.
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', '0'.repeat(64))
      .send(body)
      .expect(401);

    const paid = await order(placed.id);
    expect(paid).toMatchObject({ status: 'SEARCHING_RIDER', feePaidAt: expect.any(Date) });
    expect(await ctx.prisma.journalEntry.count({ where: { paymentId: pay.body.id } })).toBe(1);
    const status = await request(ctx.http)
      .get(`/v1/payments/${pay.body.id}`)
      .set(shop.auth)
      .expect(200);
    expect(status.body.status).toBe('SUCCEEDED');

    // Annulation avant enlèvement : les frais reviennent au portefeuille (avoir)…
    await request(ctx.http)
      .post(`/v1/orders/${placed.id}/cancel`)
      .set(shop.auth)
      .send({ reason: 'Client injoignable' })
      .expect(200);
    expect(await ledger.balance(merchantPayable(paid.merchantId ?? ''))).toBe(paid.totalPrice);
    // …et paient la commande suivante.
    const next = await placeOrder(ctx, shop, { feePaymentMethod: 'WALLET' });
    expect(next.status).toBe('SEARCHING_RIDER');
    expect(await ledger.balance(merchantPayable(paid.merchantId ?? ''))).toBe(0);
    const broke = await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        dropoffAddressId: shop.dropoffId,
        recipientName: 'Client',
        recipientPhone: '+237677000111',
        packageSize: 'S',
        feePaymentMethod: 'WALLET',
      })
      .expect(422);
    expect(broke.body.error.code).toBe('INSUFFICIENT_BALANCE');
  });

  it('refuse un paiement d’un autre montant que celui demandé', async () => {
    const shop = await merchant(ctx);
    const placed = await placeOrder(ctx, shop, { feePaymentMethod: 'MOMO_ORANGE' });
    const pay = await request(ctx.http)
      .post(`/v1/orders/${placed.id}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'ORANGE' })
      .expect(201);
    const operation = provider.operations.get(await pendingReference(pay.body.id));
    if (!operation) throw new Error('opération absente');
    operation.amount -= 100; // Le prestataire annonce moins que prévu.
    await settle(operation.providerReference, 'SUCCEEDED');
    expect(
      (await ctx.prisma.payment.findUniqueOrThrow({ where: { id: pay.body.id } })).status,
    ).toBe('PENDING');
    expect((await order(placed.id)).status).toBe('CREATED');
    // L'interrogation régulière contrôle aussi le montant…
    const payments = ctx.app.get(PaymentsService);
    await payments.refreshPending(new Date(Date.now() + 60_000));
    expect((await order(placed.id)).status).toBe('CREATED');
    // …et applique le paiement une fois le bon montant confirmé par le prestataire.
    operation.amount += 100;
    await provider.settle(operation.providerReference, 'SUCCEEDED');
    await payments.refreshPending(new Date(Date.now() + 60_000));
    expect((await order(placed.id)).status).toBe('SEARCHING_RIDER');
  });

  it('Mobile Money à la porte : frais du destinataire et contre-remboursement en une demande (E5)', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 20_000, feePayer: 'RECIPIENT' });
    await toTheDoor(placed, rider);
    const o = await order(placed.id);
    const asked = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'MOBILE_MONEY', phone: placed.recipientPhone, operator: 'MTN' })
      .expect(200);
    expect(asked.body).toMatchObject({
      due: { fee: o.totalPrice, cod: 20_000, total: 20_000 + o.totalPrice },
      complete: false,
      payment: { status: 'PENDING', amount: 20_000 + o.totalPrice },
    });
    await settle(await pendingReference(asked.body.payment.id), 'SUCCEEDED');
    const done = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}/collection`)
      .set(rider.auth)
      .expect(200);
    expect(done.body.complete).toBe(true);
    await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to: 'DELIVERED' })
      .expect(200);
    // Rien en espèces : le livreur a tout son gain à retirer.
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(o.riderEarning);
    expect(await ledger.balance(merchantPayable(o.merchantId ?? ''))).toBe(20_000 - 400);
  });

  it('retour d’un colis que le destinataire devait payer : l’expéditeur règle la course', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { feePayer: 'RECIPIENT' });
    await toTheDoor(placed, rider);
    const go = (to: string, extra: Record<string, unknown> = {}) =>
      request(ctx.http)
        .post(`/v1/admin/orders/${placed.id}/transition`)
        .set(ops.auth)
        .send({ to, ...extra })
        .expect(200);
    await go('DELIVERY_FAILED', { failureReason: 'REFUSED' });
    await go('RETURNED');
    const o = await order(placed.id);
    expect(await ledger.balance(merchantPayable(o.merchantId ?? ''))).toBe(-o.totalPrice);
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(o.riderEarning);
  });

  it('reversement : réponse perdue puis rattrapée sans double envoi, notification répétée sans effet (G3)', async () => {
    const shop = await merchant(ctx);
    const merchantId = (
      await ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } })
    ).id;
    await request(ctx.http)
      .post(`/v1/admin/finance/users/${shop.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 12_345, reason: 'Geste commercial (test)' })
      .expect(201);
    const payouts = ctx.app.get(PayoutsService);

    // Le prestataire exécute l'envoi mais sa réponse se perd.
    const originalDisburse = provider.disburse.bind(provider);
    let reference = '';
    provider.disburse = (request) => {
      // Les autres marchands des tests sont reversés normalement.
      if (request.amount !== 12_345) return originalDisburse(request);
      reference = request.reference;
      provider.loseResponseOnce.add(request.reference);
      provider.disburse = originalDisburse;
      return originalDisburse(request);
    };
    const result = await payouts.dailyMerchantPayouts();
    expect(result.requested).toBeGreaterThanOrEqual(1);
    const payout = await ctx.prisma.payout.findUniqueOrThrow({ where: { id: reference } });
    expect(payout).toMatchObject({ merchantId, status: 'PROCESSING', amount: 12_345 });
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(0);

    // Deuxième passage du même jour : rien de plus (même clé).
    await payouts.dailyMerchantPayouts();
    // Le contrôle retrouve l'envoi par notre référence : réglé, pas renvoyé.
    await payouts.checkProcessing(new Date(Date.now() + 120_000));
    expect((await ctx.prisma.payout.findUniqueOrThrow({ where: { id: reference } })).status).toBe(
      'SUCCEEDED',
    );
    expect(provider.disbursementsFor(reference)).toBe(1);

    // La notification du prestataire arrive ensuite, deux fois : sans effet.
    const operation = [...provider.operations.values()].find((op) => op.reference === reference);
    if (!operation) throw new Error('envoi absent');
    for (let i = 0; i < 2; i += 1) {
      const { body, signature } = provider.webhookFor(operation);
      await request(ctx.http)
        .post('/v1/webhooks/payments/fake')
        .set('Content-Type', 'application/json')
        .set('X-Fake-Signature', signature)
        .send(body)
        .expect(200);
    }
    expect(
      await ctx.prisma.journalEntry.count({ where: { payoutId: reference, kind: 'PAYOUT_SENT' } }),
    ).toBe(1);
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(0);
  });

  it('gros montant : validé par la finance ; refusé, il revient au portefeuille', async () => {
    const shop = await merchant(ctx);
    await ctx.prisma.merchantProfile.update({
      where: { userId: shop.userId },
      data: { plan: 'PRO' },
    });
    const merchantId = (
      await ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } })
    ).id;
    await request(ctx.http)
      .post(`/v1/admin/finance/users/${shop.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 60_000, reason: 'Litige réglé (test)' })
      .expect(201);
    const first = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(201);
    expect(first.body).toMatchObject({ status: 'AWAITING_APPROVAL', amount: 60_000 });
    // Une seule demande en cours à la fois.
    const second = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(422);
    expect(second.body.error.code).toBe('PAYOUT_TOO_SMALL');

    await request(ctx.http)
      .post(`/v1/admin/finance/payouts/${first.body.id}/reject`)
      .set(finance.auth)
      .send({ reason: 'Numéro à vérifier' })
      .expect(200);
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(60_000);

    const again = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(201);
    await request(ctx.http)
      .post(`/v1/admin/finance/payouts/${again.body.id}/approve`)
      .set(ops.auth)
      .expect(403);
    const approved = await request(ctx.http)
      .post(`/v1/admin/finance/payouts/${again.body.id}/approve`)
      .set(finance.auth)
      .expect(200);
    expect(approved.body.status).toBe('SUCCEEDED');
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(0);
    expect(
      await ctx.prisma.auditLog.count({
        where: { entityId: again.body.id, action: 'payout.approved' },
      }),
    ).toBe(1);
  });

  it('livreur : dépôt d’espèces, plafond, retrait du disponible seulement (G4, G5)', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 15_000 });
    await toTheDoor(placed, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to: 'DELIVERED' })
      .expect(200);
    const cash = await ledger.balance(riderCashHeld(rider.riderId));
    expect(cash).toBeGreaterThan(15_000);

    const tooMuch = await request(ctx.http)
      .post('/v1/rider/cash-deposits')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: cash + 1, phone: rider.phone, operator: 'MTN' })
      .expect(422);
    expect(tooMuch.body.error.code).toBe('DEPOSIT_TOO_LARGE');
    const deposit = await request(ctx.http)
      .post('/v1/rider/cash-deposits')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 10_000, phone: rider.phone, operator: 'MTN' });
    expect(deposit.body).toMatchObject({ status: 'PENDING' });
    await settle(await pendingReference(deposit.body.id), 'SUCCEEDED');
    const officeKey = key();
    for (let i = 0; i < 2; i += 1) {
      await request(ctx.http)
        .post(`/v1/admin/finance/riders/${rider.riderId}/cash-deposits`)
        .set(finance.auth)
        .set('Idempotency-Key', officeKey)
        .send({ amount: cash - 10_000, note: 'Remis au bureau d’Akwa' })
        .expect(201);
    }
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(0);
    expect(await ledger.balance(PLATFORM_ACCOUNTS.officeCash)).toBeGreaterThanOrEqual(
      cash - 10_000,
    );

    // Rien à retirer : sa part a déjà été gardée sur les espèces.
    const empty = await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ phone: rider.phone, operator: 'MTN' })
      .expect(422);
    expect(empty.body.error.code).toBe('PAYOUT_TOO_SMALL');
  });

  it('solde client : recharge, prépaiement refusé si dette, remboursement vers Mobile Money (G1, G8)', async () => {
    const customer = await signIn(ctx);
    const pickup = await createAddress(ctx, customer, PLACES.akwa);
    const dropoff = await createAddress(ctx, customer, PLACES.bonapriso);
    const topUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 5_000, phone: customer.phone, operator: 'ORANGE' })
      .expect(201);
    await settle(await pendingReference(topUp.body.id), 'SUCCEEDED');
    const wallet = await request(ctx.http).get('/v1/me/wallet').set(customer.auth).expect(200);
    expect(wallet.body).toMatchObject({ customer: { balance: 5_000 }, merchant: null });

    const refund = await request(ctx.http)
      .post('/v1/me/wallet/refund')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 3_000, phone: customer.phone, operator: 'ORANGE' })
      .expect(201);
    expect(refund.body).toMatchObject({ status: 'SUCCEEDED', beneficiary: 'CUSTOMER' });
    expect(await ledger.balance(customerWallet(customer.userId))).toBe(2_000);

    // Dette envers Tara (retour non payé) : pas de nouvelle commande.
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'ADJUSTMENT',
        description: 'Dette de test',
        idempotencyKey: `test-debt:${customer.userId}`,
        postings: [
          { account: customerWallet(customer.userId), amount: 3_000 },
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -3_000 },
        ],
      }),
    );
    const blocked = await request(ctx.http)
      .post('/v1/orders')
      .set(customer.auth)
      .send({
        pickupAddressId: pickup.id,
        dropoffAddressId: dropoff.id,
        recipientName: 'Ami',
        recipientPhone: '+237677000222',
        packageSize: 'S',
        feePaymentMethod: 'CASH',
      })
      .expect(422);
    expect(blocked.body.error.code).toBe('WALLET_IN_DEBT');
  });

  it('expose les soldes de la plateforme à la finance seulement', async () => {
    const overview = await request(ctx.http)
      .get('/v1/admin/finance/overview')
      .set(finance.auth)
      .expect(200);
    expect(overview.body.accounts.map((a: { code: string }) => a.code)).toContain(
      'platform:mobile_money',
    );
    await request(ctx.http).get('/v1/admin/finance/overview').set(ops.auth).expect(403);
    // Grand livre toujours équilibré.
    const [row] = await ctx.prisma.$queryRaw<
      { total: bigint }[]
    >`SELECT COALESCE(SUM(amount), 0)::bigint AS total FROM ledger_postings`;
    expect(Number(row?.total)).toBe(0);
  });
});
