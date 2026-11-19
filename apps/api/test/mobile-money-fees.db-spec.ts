import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderPayable,
} from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { cameroonDate } from '../src/common/time.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../src/payments/payment.provider.js';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { merchant, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider, RIDER_START_BALANCE } from './helpers/riders.js';

/**
 * Frais Mobile Money répercutés (choix du fondateur) : le client paie une ligne « Frais
 * Mobile Money » en plus ; les retraits des boutiques et des livreurs supportent les frais de
 * retrait sous leur seuil de retrait gratuit. Tara reçoit et verse toujours le montant entier.
 */
describe('Frais Mobile Money payés par le client', () => {
  let ctx: TestContext;
  let finance: SignedIn;
  let ops: SignedIn;
  let ledger: LedgerService;
  let provider: FakePaymentProvider;

  beforeAll(async () => {
    ctx = await createTestApp({
      MOBILE_MONEY_FEE_BPS: '600',
      PAYOUT_FEE_BPS: '250',
      PAYOUT_FEE_SHARE_PERCENT: '50',
      FREE_PAYOUT_FROM: '20000',
    });
    const admin = await staffUser(ctx, ['ADMIN']);
    finance = await staffUser(ctx, ['FINANCE']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const key = (): string => randomUUID();

  async function settle(paymentId: string): Promise<void> {
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    const { body, signature } = await provider.settle(payment.providerReference ?? '', 'SUCCEEDED');
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
  }

  const providerAmount = async (providerReference: string | null): Promise<number | undefined> =>
    (await provider.lookup('COLLECT', providerReference ?? ''))?.amount ??
    (await provider.lookup('DISBURSE', providerReference ?? ''))?.amount;

  it('le taux est donné à l’app, qui annonce les frais avant de payer', async () => {
    const config = await request(ctx.http).get('/v1/public/config').expect(200);
    expect(config.body.mobileMoneyFeeBps).toBe(600);
  });

  it('course payée par Mobile Money : frais en plus, Tara reçoit la course entière', async () => {
    const shop = await merchant(ctx);
    const placed = await placeOrder(ctx, shop, { feePaymentMethod: 'MOMO_MTN' });
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    const fee = Math.ceil((stored.totalPrice * 600) / 9400);
    const charged = await ledger.balance(PLATFORM_ACCOUNTS.mobileMoneyFeesCharged);

    const pay = await request(ctx.http)
      .post(`/v1/orders/${placed.id}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(201);
    expect(pay.body).toMatchObject({
      amount: stored.totalPrice,
      mobileMoneyFee: fee,
      total: stored.totalPrice + fee,
    });
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: pay.body.id } });
    // La demande envoyée au téléphone porte le total, frais compris.
    expect(await providerAmount(payment.providerReference)).toBe(stored.totalPrice + fee);

    await settle(pay.body.id);
    expect(await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } })).toMatchObject({
      status: 'SEARCHING_RIDER',
    });
    expect(await ledger.balance(PLATFORM_ACCOUNTS.mobileMoneyFeesCharged)).toBe(charged + fee);
  });

  it('recharge du solde client : frais en plus, solde crédité du montant demandé', async () => {
    const customer = await signIn(ctx);
    const topUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(customer.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 6000, phone: customer.phone, operator: 'MTN' })
      .expect(201);
    expect(topUp.body).toMatchObject({ amount: 6000, mobileMoneyFee: 383, total: 6383 });
    await settle(topUp.body.id);
    expect(await ledger.balance(customerWallet(customer.userId))).toBe(6000);
  });

  it('recharge du solde d’un livreur : frais payés par Tara, rien en plus', async () => {
    const rider = await activeRider(ctx, { balance: 0 });
    const topUp = await request(ctx.http)
      .post('/v1/rider/topups')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 5000, phone: rider.phone, operator: 'MTN' })
      .expect(201);
    expect(topUp.body).toMatchObject({ amount: 5000, mobileMoneyFee: 0, total: 5000 });
  });

  it('à la porte : le livreur voit les frais si le client paie par Mobile Money', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 10_000 });
    for (const [to, extra] of [
      ['ASSIGNED', { riderId: rider.riderId }],
      ['PICKED_UP', {}],
      ['IN_DELIVERY', {}],
    ] as const) {
      await request(ctx.http)
        .post(`/v1/admin/orders/${placed.id}/transition`)
        .set(ops.auth)
        .send({ to, ...extra })
        .expect(200);
    }
    const state = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}/collection`)
      .set(rider.auth)
      .expect(200);
    expect(state.body).toMatchObject({ due: { total: 10_000 }, mobileMoneyFee: 639 });
    const order = await request(ctx.http).get(`/v1/orders/${placed.id}`).set(shop.auth).expect(200);
    const token = (order.body.trackingUrl as string).split('/t/')[1];
    const page = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(page.body).toMatchObject({
      due: { total: 10_000 },
      mobileMoneyFee: 639,
      paymentPending: null,
    });

    // Le livreur envoie la demande : 10 639 F arrivent sur le téléphone du client.
    const asked = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'MOBILE_MONEY', phone: '677001122', operator: 'MTN' })
      .expect(200);
    expect(asked.body.payment).toMatchObject({ amount: 10_000, total: 10_639 });
    const pending = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(pending.body.paymentPending).toEqual({ amount: 10_639 });
    // Même taux dans les réglages de l'app livreur, gardés pour le hors connexion.
    const config = await request(ctx.http).get('/v1/rider/config').set(rider.auth).expect(200);
    expect(config.body.mobileMoneyFeeBps).toBe(600);
  });

  it('retrait sous le seuil : frais retenus ; au-dessus du seuil fixé par l’équipe : gratuit', async () => {
    const shop = await merchant(ctx);
    // Retrait à la demande (tout le disponible) : offre Pro ; les autres le soir, d'office.
    const merchantId = (
      await ctx.prisma.merchantProfile.update({
        where: { userId: shop.userId },
        data: { plan: 'PRO' },
      })
    ).id;
    const credit = (amount: number) =>
      request(ctx.http)
        .post(`/v1/admin/finance/users/${shop.userId}/credits`)
        .set(finance.auth)
        .set('Idempotency-Key', key())
        .send({ amount, reason: 'Ventes encaissées (test)' })
        .expect(201);
    const withdraw = () =>
      request(ctx.http)
        .post('/v1/me/merchant/payouts')
        .set(shop.auth)
        .set('Idempotency-Key', key())
        .expect(201);
    await credit(10_000);
    const charged = await ledger.balance(PLATFORM_ACCOUNTS.mobileMoneyFeesCharged);

    // 10 000 F, sous le seuil général de 20 000 F : frais Mobile Money (244 F) partagés
    // moitié-moitié, la boutique paie 122 F, Tara le reste.
    const small = await withdraw();
    expect(small.body).toMatchObject({
      status: 'SUCCEEDED',
      amount: 10_000,
      withdrawalFee: 122,
      received: 9878,
    });
    const sent = await ctx.prisma.payout.findUniqueOrThrow({ where: { id: small.body.id } });
    expect(await providerAmount(sent.providerReference)).toBe(9878);
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(0);
    expect(await ledger.balance(PLATFORM_ACCOUNTS.mobileMoneyFeesCharged)).toBe(charged + 122);

    // L'équipe fixe le seuil de cette boutique d'après ses transactions : 5 000 F.
    const settings = await request(ctx.http)
      .get(`/v1/admin/finance/merchants/${merchantId}/free-payout`)
      .set(finance.auth)
      .expect(200);
    expect(settings.body).toEqual({
      freeFrom: 20_000,
      custom: null,
      default: 20_000,
      averageMonthlyPayouts: Math.round(10_000 / 3),
      feeBps: 250,
      feeSharePercent: 50,
    });
    await request(ctx.http)
      .put(`/v1/admin/finance/merchants/${merchantId}/free-payout`)
      .set(ops.auth)
      .send({ freeFrom: 5000 })
      .expect(403);
    const set = await request(ctx.http)
      .put(`/v1/admin/finance/merchants/${merchantId}/free-payout`)
      .set(finance.auth)
      .send({ freeFrom: 5000 })
      .expect(200);
    expect(set.body).toMatchObject({ freeFrom: 5000, custom: 5000 });
    expect(
      await ctx.prisma.auditLog.count({
        where: { entityId: merchantId, action: 'finance.free_payout_set' },
      }),
    ).toBe(1);

    await credit(10_000);
    const free = await withdraw();
    expect(free.body).toMatchObject({ amount: 10_000, withdrawalFee: 0, received: 10_000 });
  });

  it('solde Tara : retrait gratuit pour un particulier, règle des reversements pour une boutique', async () => {
    async function topUpAndWithdraw(user: SignedIn) {
      const topUp = await request(ctx.http)
        .post('/v1/me/wallet/topup')
        .set(user.auth)
        .set('Idempotency-Key', key())
        .send({ amount: 10_000, phone: user.phone, operator: 'MTN' })
        .expect(201);
      await settle(topUp.body.id);
      const out = await request(ctx.http)
        .post('/v1/me/wallet/refund')
        .set(user.auth)
        .set('Idempotency-Key', key())
        .send({ amount: 10_000, phone: user.phone, operator: 'MTN' })
        .expect(201);
      return out.body;
    }
    const customer = await signIn(ctx);
    expect(await topUpAndWithdraw(customer)).toMatchObject({
      amount: 10_000,
      withdrawalFee: 0,
      received: 10_000,
    });
    // Sinon la réserve, gardée des ventes, sortirait sans les frais de retrait.
    const shop = await merchant(ctx);
    expect(await topUpAndWithdraw(shop)).toMatchObject({
      amount: 10_000,
      withdrawalFee: 122,
      received: 9878,
    });
  });

  it('retrait d’un livreur sous le seuil général : frais retenus sur ses gains retirés', async () => {
    const rider = await activeRider(ctx);
    const out = await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', key())
      .send({ amount: 4000, phone: rider.phone, operator: 'MTN' })
      .expect(201);
    // Frais de 98 F partagés : 49 F pour le livreur (arrondi en sa faveur), le reste pour Tara.
    expect(out.body).toMatchObject({ amount: 4000, withdrawalFee: 49, received: 3951 });
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    // Prestataire factice : pas de minimum d'envoi.
    expect(wallet.body.withdrawal).toEqual({
      freeFrom: 20_000,
      feeBps: 250,
      feeSharePercent: 50,
      minimum: 0,
    });
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(RIDER_START_BALANCE - 4000);
  });

  it('le contrôle quotidien des comptes tombe juste, frais compris', async () => {
    const report = await request(ctx.http)
      .post(`/v1/admin/finance/reconciliations/${cameroonDate(new Date())}/run`)
      .set(finance.auth)
      .expect(200);
    const ours = new Set(
      [
        ...(await ctx.prisma.payment.findMany({ where: { surcharge: { gt: 0 } } })),
        ...(await ctx.prisma.payout.findMany({ where: { charge: { gt: 0 } } })),
      ].map((item) => item.id),
    );
    const mine = (report.body.discrepancies as { reference: string }[]).filter((d) =>
      ours.has(d.reference),
    );
    expect(mine).toEqual([]);
  });
});
