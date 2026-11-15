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
import { cashCarried } from '../src/dispatch/rider-scoring.js';
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
import {
  merchant,
  type PlacedOrder,
  placeOrder,
  setupDouala,
  RIDER_SHARE_BPS,
} from './helpers/orders.js';
import { activeRider, RIDER_START_BALANCE, type TestRider } from './helpers/riders.js';

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

  it('espèces : frais à l’enlèvement et contre-remboursement pris sur le solde prépayé', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 10_000 });
    await toTheDoor(placed, rider);
    const o = await order(placed.id);
    expect(o.feePaidAt).not.toBeNull();
    // Le livreur garde les espèces des frais : le montant est pris sur son solde, et l'argent
    // de la course reste mis de côté jusqu'à la fin.
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(0);
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(
      RIDER_START_BALANCE - o.totalPrice,
    );
    const during = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(during.body.reserved).toBe(10_000 + o.totalPrice);

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
      .send({
        method: 'CASH',
        clientEventId: 'encaissement-0001',
        occurredAt: new Date().toISOString(),
      })
      .expect(200);
    // Renvoyé par la file hors connexion (réponse perdue) : sans effet, rien n'est compté deux fois.
    const replay = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH', clientEventId: 'encaissement-0001' })
      .expect(200);
    expect(replay.body.complete).toBe(true);
    expect(
      await ctx.prisma.journalEntry.count({
        where: { idempotencyKey: `order:${placed.id}:collect-cash` },
      }),
    ).toBe(1);
    await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to: 'DELIVERED' })
      .expect(200);

    // Marchand payé tout de suite : 10 000 − 2 % (minimum 250). Livreur : espèces en main,
    // montant pris sur son solde, gain crédité ; rien ne reste dû, rien n'est mis de côté.
    const expected = RIDER_START_BALANCE - o.totalPrice - 10_000 + o.riderEarning;
    expect(await ledger.balance(merchantPayable(o.merchantId ?? ''))).toBe(9_750);
    // Accueil du marchand : encaissé aujourd'hui et livraisons du jour.
    const shopWallet = await request(ctx.http).get('/v1/me/wallet').set(shop.auth).expect(200);
    expect(shopWallet.body.merchant).toMatchObject({ todaySales: 10_000, todayDeliveries: 1 });
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(expected);
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(0);
    // Historique du livreur : montant encaissé et moyen.
    const done = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}`)
      .set(rider.auth)
      .expect(200);
    expect(done.body.collected).toEqual({ amount: 10_000, method: 'CASH' });
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(wallet.body).toMatchObject({
      earnings: expected,
      reserved: 0,
      cashHeld: 0,
      available: expected,
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

  it('lot payé par Mobile Money en une fois : chaque commande réglée, le reste au solde', async () => {
    const shop = await merchant(ctx);
    const item = (n: number) => ({
      dropoffAddressId: shop.dropoffId,
      recipientName: `Client ${n}`,
      recipientPhone: `+2376770000${n}${n}`,
      packageSize: 'M',
    });
    const created = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'MOMO_MTN',
        items: [1, 2, 3].map(item),
      })
      .expect(201);
    const batchId = created.body.batchId as string;
    const [a, b, c] = created.body.orders as {
      id: string;
      status: string;
      pricing: { totalPrice: number };
    }[];
    expect([a, b, c].map((o) => o?.status)).toEqual(['CREATED', 'CREATED', 'CREATED']);
    // Annulée avant la demande : elle n'en fait plus partie.
    await request(ctx.http)
      .post(`/v1/orders/${c?.id}/cancel`)
      .set(shop.auth)
      .send({ reason: 'Client absent' })
      .expect(200);

    const pay = await request(ctx.http)
      .post(`/v1/orders/batches/${batchId}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(201);
    expect(pay.body).toMatchObject({
      status: 'PENDING',
      batchId,
      orderId: null,
      amount: (a?.pricing.totalPrice ?? 0) + (b?.pricing.totalPrice ?? 0),
    });
    // Pas deux invites en même temps sur le téléphone.
    const twice = await request(ctx.http)
      .post(`/v1/orders/batches/${batchId}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(409);
    expect(twice.body.error.code).toBe('PAYMENT_ALREADY_PENDING');
    // Lot d'un autre : introuvable.
    const stranger = await merchant(ctx);
    await request(ctx.http)
      .post(`/v1/orders/batches/${batchId}/pay`)
      .set(stranger.auth)
      .send({ phone: stranger.phone, operator: 'MTN' })
      .expect(404);

    // Annulée pendant que le client valide : son montant revient à son solde.
    await request(ctx.http)
      .post(`/v1/orders/${b?.id}/cancel`)
      .set(shop.auth)
      .send({ reason: 'Client absent' })
      .expect(200);
    const reference = await pendingReference(pay.body.id);
    await settle(reference, 'SUCCEEDED');

    const paidA = await order(a?.id ?? '');
    expect(paidA).toMatchObject({ status: 'SEARCHING_RIDER', feePaidAt: expect.any(Date) });
    expect((await order(b?.id ?? '')).status).toBe('CANCELLED');
    expect(await ledger.balance(merchantPayable(paidA.merchantId ?? ''))).toBe(
      b?.pricing.totalPrice,
    );
    expect(await ctx.prisma.journalEntry.count({ where: { paymentId: pay.body.id } })).toBe(2);
    // Plus rien à payer dans ce lot.
    await request(ctx.http)
      .post(`/v1/orders/batches/${batchId}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(409);
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
    // Rien en espèces : solde intact plus le gain ; l'argent mis de côté est libéré.
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(
      RIDER_START_BALANCE + o.riderEarning,
    );
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
    // La course et les frais de retour (E6), pris sur le portefeuille de la boutique ; le
    // livreur touche sa part des deux.
    expect(await ledger.balance(merchantPayable(o.merchantId ?? ''))).toBe(
      -(o.totalPrice + o.returnFee),
    );
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(
      RIDER_START_BALANCE + o.riderEarning + Math.floor((o.returnFee * RIDER_SHARE_BPS) / 10_000),
    );
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

  it('offre gratuite : pas de reversement à la demande, sauf un petit solde versé en entier', async () => {
    const shop = await merchant(ctx);
    const merchantId = (
      await ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } })
    ).id;
    const credit = (amount: number) =>
      request(ctx.http)
        .post(`/v1/admin/finance/users/${shop.userId}/credits`)
        .set(finance.auth)
        .set('Idempotency-Key', key())
        .send({ amount, reason: 'Geste commercial (test)' })
        .expect(201);
    await credit(300);
    // 300 F : sous le minimum du reversement de 18 h, il ne partirait jamais seul.
    const small = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(201);
    expect(small.body).toMatchObject({ amount: 300 });
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(0);

    await credit(1000);
    const refused = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(403);
    expect(refused.body.error.code).toBe('PAYOUT_NOT_ALLOWED');
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

  it('livreur : solde prépayé rechargé sans frais, réservé à l’acceptation, retrait du disponible (G4, G5)', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx, { balance: 0 });
    const placed = await placeOrder(ctx, shop, { codAmount: 15_000 });
    const o = await order(placed.id);
    const carried = cashCarried(o);

    // Solde vide : pas de course avec encaissement.
    const refused = await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to: 'ASSIGNED', riderId: rider.riderId })
      .expect(422);
    expect(refused.body.error.code).toBe('RIDER_BALANCE_TOO_LOW');

    // Recharge Mobile Money : crédité du montant entier, Tara paie les frais.
    const fees = await ledger.balance(PLATFORM_ACCOUNTS.providerFees);
    const topUp = await request(ctx.http)
      .post('/v1/rider/topups')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 30_000, phone: rider.phone, operator: 'MTN' })
      .expect(201);
    expect(topUp.body).toMatchObject({ purpose: 'RIDER_TOPUP', status: 'PENDING' });
    await settle(await pendingReference(topUp.body.id), 'SUCCEEDED');
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(30_000);
    expect(await ledger.balance(PLATFORM_ACCOUNTS.providerFees)).toBeGreaterThanOrEqual(fees);

    // Course acceptée : l'argent à encaisser est mis de côté ; seul le reste se retire.
    await toTheDoor(placed, rider);
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(wallet.body.reserved).toBe(carried);
    const tooMuch = await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: wallet.body.available + 1, phone: rider.phone, operator: 'MTN' })
      .expect(422);
    expect(tooMuch.body.error.code).toBe('INSUFFICIENT_BALANCE');

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
    // Espèces en main ; solde = recharge − argent encaissé + gain ; rien ne reste dû.
    const after = 30_000 - carried + o.riderEarning;
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(after);
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(0);
    const done = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(done.body).toMatchObject({ earnings: after, reserved: 0, available: after });

    // Recharge au bureau, rejouée : comptée une fois, tracée.
    const officeKey = key();
    for (let i = 0; i < 2; i += 1) {
      await request(ctx.http)
        .post(`/v1/admin/finance/riders/${rider.riderId}/topups`)
        .set(finance.auth)
        .set('Idempotency-Key', officeKey)
        .send({ amount: 5_000, note: 'Remis au bureau d’Akwa' })
        .expect(201);
    }
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(after + 5_000);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: rider.riderId, action: 'rider.balance_topped_up' },
    });
    expect(audit).not.toBeNull();

    // Livreur suspendu (colis disparu, enquête) : son solde reste chez Tara.
    await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(admin.auth)
      .send({ decision: 'SUSPEND', reason: 'Colis non livré, enquête en cours' })
      .expect(200);
    const frozen = await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ phone: rider.phone, operator: 'MTN' })
      .expect(403);
    expect(frozen.body.error.code).toBe('PAYOUT_FROZEN');
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(after + 5_000);
  });

  it('espèces d’avant le solde prépayé : dépôt Mobile Money ou au bureau, jamais plus que le dû', async () => {
    const rider = await activeRider(ctx, { balance: 0 });
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'COD_COLLECTED',
        description: 'Espèces encaissées avant le solde prépayé (test)',
        idempotencyKey: `test-legacy-cash:${rider.riderId}`,
        postings: [
          { account: riderCashHeld(rider.riderId), amount: 12_000 },
          { account: PLATFORM_ACCOUNTS.codFees, amount: -12_000 },
        ],
      }),
    );
    const tooMuch = await request(ctx.http)
      .post('/v1/rider/cash-deposits')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 12_001, phone: rider.phone, operator: 'MTN' })
      .expect(422);
    expect(tooMuch.body.error.code).toBe('DEPOSIT_TOO_LARGE');
    const deposit = await request(ctx.http)
      .post('/v1/rider/cash-deposits')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 10_000, phone: rider.phone, operator: 'MTN' });
    await settle(await pendingReference(deposit.body.id), 'SUCCEEDED');
    await request(ctx.http)
      .post(`/v1/admin/finance/riders/${rider.riderId}/cash-deposits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 2_000, note: 'Remis au bureau' })
      .expect(201);
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(0);
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

    // Il reste de l'argent : la suppression du compte attend qu'il soit retiré.
    const withMoney = await request(ctx.http)
      .post('/v1/me/deletion/code')
      .set(customer.auth)
      .expect(422);
    expect(withMoney.body.error).toMatchObject({ code: 'ACCOUNT_HAS_BALANCE' });
    expect(withMoney.body.error.message).toContain('2000');
    // Sous le minimum (500 F), un retrait partiel est refusé.
    const tiny = await request(ctx.http)
      .post('/v1/me/wallet/refund')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 200, phone: customer.phone, operator: 'ORANGE' })
      .expect(422);
    expect(tiny.body.error.code).toBe('PAYOUT_TOO_SMALL');

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
    // La dette ne disparaît pas avec le compte : suppression refusée tant qu'elle reste.
    const deletion = await request(ctx.http)
      .post('/v1/me/deletion/code')
      .set(customer.auth)
      .expect(422);
    expect(deletion.body.error).toMatchObject({ code: 'ACCOUNT_HAS_DEBT' });
    expect(deletion.body.error.message).toContain('1000');
  });

  it('petit solde : retiré en entier même sous le minimum, puis le compte peut être supprimé', async () => {
    const customer = await signIn(ctx);
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'ADJUSTMENT',
        description: 'Avoir de test',
        idempotencyKey: `test-credit:${customer.userId}`,
        postings: [
          { account: customerWallet(customer.userId), amount: -300 },
          { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: 300 },
        ],
      }),
    );
    expect(await ledger.balance(customerWallet(customer.userId))).toBe(300);
    const all = await request(ctx.http)
      .post('/v1/me/wallet/refund')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 300, phone: customer.phone, operator: 'MTN' })
      .expect(201);
    expect(all.body).toMatchObject({ status: 'SUCCEEDED', amount: 300, withdrawalFee: 0 });
    expect(await ledger.balance(customerWallet(customer.userId))).toBe(0);
    // Code de connexion récent : délai entre deux codes levé pour le test.
    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: customer.phone } });
    await request(ctx.http).post('/v1/me/deletion/code').set(customer.auth).expect(201);
  });

  it('marchand : dette tolérée jusqu’au plafond (3 000 F), puis nouvelles commandes bloquées', async () => {
    const shop = await merchant(ctx);
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: shop.userId },
    });
    const owe = (amount: number, tag: string) =>
      ctx.prisma.$transaction((tx) =>
        ledger.post(tx, {
          kind: 'ADJUSTMENT',
          description: 'Dette de test',
          idempotencyKey: `test-debt:${profile.id}:${tag}`,
          postings: [
            { account: merchantPayable(profile.id), amount },
            { account: PLATFORM_ACCOUNTS.ordersPrepaid, amount: -amount },
          ],
        }),
      );
    await owe(2_999, 'a');
    await placeOrder(ctx, shop);
    await owe(1, 'b');
    const blocked = await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        dropoffAddressId: shop.dropoffId,
        recipientName: 'Client',
        recipientPhone: '+237677000333',
        packageSize: 'S',
        feePaymentMethod: 'CASH',
      })
      .expect(422);
    expect(blocked.body.error).toMatchObject({ code: 'MERCHANT_DEBT_LIMIT' });
  });

  it('vire de la trésorerie du bureau vers l’agrégateur, une seule fois par clé', async () => {
    const before = await ledger.balance(PLATFORM_ACCOUNTS.mobileMoney);
    const transferKey = key();
    for (let i = 0; i < 2; i += 1) {
      await request(ctx.http)
        .post('/v1/admin/finance/treasury-transfers')
        .set(finance.auth)
        .set('Idempotency-Key', transferKey)
        .send({
          direction: 'OFFICE_TO_MOBILE_MONEY',
          amount: 100_000,
          note: 'Alimentation avant reversements',
        })
        .expect(201);
    }
    expect(await ledger.balance(PLATFORM_ACCOUNTS.mobileMoney)).toBe(before + 100_000);
    await request(ctx.http)
      .post('/v1/admin/finance/treasury-transfers')
      .set(finance.auth)
      .send({ direction: 'OFFICE_TO_MOBILE_MONEY', amount: 100, note: 'Sans clé' })
      .expect(400);
  });

  it('gèle les reversements après un changement de numéro et prévient l’ancien numéro', async () => {
    const shop = await merchant(ctx);
    await ctx.prisma.merchantProfile.update({
      where: { userId: shop.userId },
      data: { plan: 'PRO' },
    });
    await request(ctx.http)
      .post(`/v1/admin/finance/users/${shop.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 5_000, reason: 'Solde de test' })
      .expect(201);
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: shop.userId },
    });
    await request(ctx.http)
      .put('/v1/me/merchant')
      .set(shop.auth)
      .send({ shopName: profile.shopName, payoutPhone: '699 11 22 33', payoutOperator: 'ORANGE' })
      .expect(200);
    expect(ctx.sms.lastTo(profile.payoutPhone)?.text).toContain('numero de reversement');
    const held = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .expect(422);
    expect(held.body.error.code).toBe('PAYOUT_ON_HOLD');
    const daily = await ctx.app.get(PayoutsService).dailyMerchantPayouts();
    expect(daily.skipped).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.payout.count({ where: { merchantId: profile.id } })).toBe(0);
  });

  it('n’envoie l’argent d’un client ou d’un livreur que vers le numéro de son compte', async () => {
    const customer = await signIn(ctx);
    await request(ctx.http)
      .post(`/v1/admin/finance/users/${customer.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 3_000, reason: 'Solde de test' })
      .expect(201);
    const elsewhere = await request(ctx.http)
      .post('/v1/me/wallet/refund')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 1_000, phone: '+237699000999', operator: 'ORANGE' })
      .expect(422);
    expect(elsewhere.body.error.code).toBe('PAYOUT_PHONE_NOT_ALLOWED');
  });

  it('interdit à l’équipe de se servir elle-même', async () => {
    const self = await request(ctx.http)
      .post(`/v1/admin/finance/users/${finance.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 10_000, reason: 'Essai' })
      .expect(403);
    expect(self.body.error.code).toBe('SELF_APPROVAL_FORBIDDEN');
  });

  it('cesse de solliciter un numéro qui ne répond pas aux demandes de paiement', async () => {
    const customer = await signIn(ctx);
    const target = `+2376${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
    for (let i = 0; i < 5; i += 1) {
      await request(ctx.http)
        .post('/v1/me/wallet/topup')
        .set(customer.auth)
        .set('Idempotency-Key', key())
        .send({ amount: 1_000, phone: target, operator: 'MTN' })
        .expect(201);
    }
    const blocked = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 1_000, phone: target, operator: 'MTN' })
      .expect(429);
    expect(blocked.body.error.code).toBe('RATE_LIMITED');
    // Les demandes restées sans réponse sont abandonnées : le rapprochement reste juste.
    await ctx.app.get(PaymentsService).refreshPending(new Date(Date.now() + 3_600_000));
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
