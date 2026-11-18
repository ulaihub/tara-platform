import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
} from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { PayoutsService } from '../src/finance/payouts.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../src/payments/payment.provider.js';
import { createTestApp, signIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, setupDouala, type TestMerchant } from './helpers/orders.js';

/**
 * Solde Tara des boutiques : les recharges y arrivent et paient les livraisons avant les
 * ventes ; il n'est jamais reversé d'office ; la réserve choisie y est gardée chaque soir.
 */
describe('Solde Tara des boutiques et réserve pour les livraisons', () => {
  let ctx: TestContext;
  let ledger: LedgerService;
  let provider: FakePaymentProvider;

  beforeAll(async () => {
    ctx = await createTestApp();
    ledger = ctx.app.get(LedgerService);
    provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
    const admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  const key = () => randomUUID();

  async function profileOf(shop: TestMerchant) {
    return ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } });
  }

  /** Recharge par Mobile Money, confirmée par le prestataire. */
  async function topUp(shop: TestMerchant, amount: number): Promise<void> {
    const res = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(shop.auth)
      .set('Idempotency-Key', key())
      .send({ amount, phone: shop.phone, operator: 'MTN' })
      .expect(201);
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: res.body.id } });
    const { body, signature } = await provider.settle(payment.providerReference ?? '', 'SUCCEEDED');
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
  }

  /** Ventes encaissées pour la boutique (comme après des livraisons). */
  async function sales(shop: TestMerchant, amount: number): Promise<void> {
    const profile = await profileOf(shop);
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'COD_COLLECTED',
        description: 'Ventes encaissées (test)',
        idempotencyKey: `test-sales:${profile.id}:${key()}`,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount },
          { account: merchantPayable(profile.id), amount: -amount },
        ],
      }),
    );
  }

  async function balances(shop: TestMerchant): Promise<{ tara: number; sales: number }> {
    const profile = await profileOf(shop);
    return {
      tara: await ledger.balance(customerWallet(shop.userId)),
      sales: await ledger.balance(merchantPayable(profile.id)),
    };
  }

  function order(shop: TestMerchant) {
    return request(ctx.http).post('/v1/orders').set(shop.auth).send({
      pickupAddressId: shop.pickupId,
      dropoffAddressId: shop.dropoffId,
      recipientName: 'Client Bonamoussadi',
      recipientPhone: '+237677000222',
      packageSize: 'S',
      feePaymentMethod: 'WALLET',
    });
  }

  it('la recharge d’une boutique arrive sur son solde Tara et paie ses livraisons', async () => {
    const shop = await merchant(ctx);
    await topUp(shop, 5_000);
    expect(await balances(shop)).toEqual({ tara: 5_000, sales: 0 });
    const wallet = await request(ctx.http).get('/v1/me/wallet').set(shop.auth).expect(200);
    expect(wallet.body).toMatchObject({
      customer: { balance: 5_000 },
      merchant: { balance: 0, payoutReserve: 0 },
    });

    const placed = await order(shop).expect(201);
    const price = placed.body.order.pricing.totalPrice as number;
    expect(placed.body.order.status).toBe('SEARCHING_RIDER');
    expect(await balances(shop)).toEqual({ tara: 5_000 - price, sales: 0 });
  });

  it('solde Tara d’abord, puis les ventes ; l’annulation rend à chacun ce qu’il a payé', async () => {
    const shop = await merchant(ctx);
    await topUp(shop, 500);
    await sales(shop, 2_000);
    const placed = await order(shop).expect(201);
    const price = placed.body.order.pricing.totalPrice as number;
    expect(await balances(shop)).toEqual({ tara: 0, sales: 2_000 - (price - 500) });

    await request(ctx.http)
      .post(`/v1/orders/${placed.body.order.id}/cancel`)
      .set(shop.auth)
      .send({ reason: 'Client injoignable' })
      .expect(200);
    expect(await balances(shop)).toEqual({ tara: 500, sales: 2_000 });
  });

  it('les deux soldes ensemble ne suffisent pas : la commande est refusée', async () => {
    const shop = await merchant(ctx);
    await topUp(shop, 300);
    await sales(shop, 400);
    const refused = await order(shop).expect(422);
    expect(refused.body.error).toMatchObject({ code: 'INSUFFICIENT_BALANCE' });
    expect(refused.body.error.message).toContain('700');
    expect(await balances(shop)).toEqual({ tara: 300, sales: 400 });
  });

  it('réserve : gardée des ventes au reversement du soir, une seule fois par jour', async () => {
    const shop = await merchant(ctx);
    await request(ctx.http)
      .put('/v1/me/wallet/reserve')
      .set(shop.auth)
      .send({ amount: 100_001 })
      .expect(400);
    await request(ctx.http)
      .put('/v1/me/wallet/reserve')
      .set(shop.auth)
      .send({ amount: 5_000 })
      .expect(204);
    await topUp(shop, 1_000);
    await sales(shop, 12_000);

    const payouts = ctx.app.get(PayoutsService);
    await payouts.dailyMerchantPayouts();
    // 4 000 F gardés (le solde Tara avait déjà 1 000 F) ; le reste, 8 000 F, est reversé.
    expect(await balances(shop)).toEqual({ tara: 5_000, sales: 0 });
    const profile = await profileOf(shop);
    const payout = await ctx.prisma.payout.findFirstOrThrow({ where: { merchantId: profile.id } });
    expect(payout.amount).toBe(8_000);

    // Deuxième passage du même jour : rien de plus.
    await sales(shop, 3_000);
    await payouts.dailyMerchantPayouts();
    expect((await balances(shop)).tara).toBe(5_000);

    // Un client sans boutique n'a pas de réserve.
    const customer = await signIn(ctx);
    await request(ctx.http)
      .put('/v1/me/wallet/reserve')
      .set(customer.auth)
      .send({ amount: 5_000 })
      .expect(404);
  });
});
