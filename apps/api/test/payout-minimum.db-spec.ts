import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { merchantPayable } from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { PayoutsService } from '../src/finance/payouts.service.js';
import { payoutCharge } from '../src/payments/mobile-money-fees.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, setupDouala } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

/**
 * Minimum d'envoi du prestataire (Sebpay : 30 000 F) : sous ce montant reçu, rien ne part.
 * Le reversement du soir attend, les retraits sont refusés avant l'envoi, les apps le savent.
 */
describe('Reversements : minimum du prestataire', () => {
  const MINIMUM = 30_000;
  const FEE_BPS = 200;
  let ctx: TestContext;
  let finance: SignedIn;
  let ledger: LedgerService;
  let payouts: PayoutsService;

  beforeAll(async () => {
    ctx = await createTestApp({
      PAYOUT_PROVIDER_MIN_AMOUNT: String(MINIMUM),
      PAYOUT_FEE_BPS: String(FEE_BPS),
      PAYOUT_FEE_SHARE_PERCENT: '50',
      FREE_PAYOUT_FROM: '50000',
    });
    const admin = await staffUser(ctx, ['ADMIN']);
    finance = await staffUser(ctx, ['FINANCE']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    payouts = ctx.app.get(PayoutsService);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const credit = (userId: string, amount: number) =>
    request(ctx.http)
      .post(`/v1/admin/finance/users/${userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount, reason: 'Ventes du jour (test)' })
      .expect(201);
  /** Ce que reçoit le bénéficiaire, frais de retrait (moitié pour lui) déduits. */
  const received = (amount: number) => amount - Math.floor(payoutCharge(amount, FEE_BPS) / 2);

  it('les ventes sous le minimum attendent sur le solde, puis partent le soir où elles l’atteignent', async () => {
    const shop = await merchant(ctx);
    const merchantId = (
      await ctx.prisma.merchantProfile.findUniqueOrThrow({ where: { userId: shop.userId } })
    ).id;
    await credit(shop.userId, 1_100);

    // L'app sait à partir de quand ses ventes partent : reçu, frais déduits, au moins 30 000 F.
    const wallet = await request(ctx.http).get('/v1/me/wallet').set(shop.auth).expect(200);
    const minimum = wallet.body.merchant.withdrawal.minimum as number;
    expect(received(minimum)).toBeGreaterThanOrEqual(MINIMUM);
    expect(received(minimum - 1)).toBeLessThan(MINIMUM);
    // Solde Tara d'une boutique : mêmes frais de retrait que ses ventes, même minimum.
    expect(wallet.body.customer.withdrawalMinimum).toBe(minimum);

    // 18 h : 1 100 F ne partent pas (Sebpay les refuserait) et restent sur le solde.
    await payouts.dailyMerchantPayouts();
    expect(await ctx.prisma.payout.count({ where: { merchantId } })).toBe(0);
    expect(await ledger.balance(merchantPayable(merchantId))).toBe(1_100);

    // Les ventes atteignent le minimum : elles partent le soir même, en entier.
    await credit(shop.userId, minimum - 1_100);
    await payouts.dailyMerchantPayouts(new Date(Date.now() + 86_400_000));
    const sent = await ctx.prisma.payout.findFirstOrThrow({ where: { merchantId } });
    expect(sent).toMatchObject({ amount: minimum, status: 'SUCCEEDED' });
    expect(sent.amount - sent.charge).toBeGreaterThanOrEqual(MINIMUM);
  });

  it('un retrait sous le minimum est refusé avant l’envoi, avec le montant à atteindre', async () => {
    const rider = await activeRider(ctx);
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    const minimum = wallet.body.withdrawal.minimum as number;
    expect(received(minimum)).toBeGreaterThanOrEqual(MINIMUM);

    const before = await ctx.prisma.payout.count({ where: { riderId: rider.riderId } });
    const refused = await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 5_000, phone: rider.phone, operator: 'MTN' })
      .expect(422);
    expect(refused.body.error.code).toBe('PAYOUT_TOO_SMALL');
    // Message : « Montant minimal d'un reversement : {min} FCFA. »
    expect(refused.body.error.message.replace(/\D/g, '')).toBe(String(minimum));
    expect(await ctx.prisma.payout.count({ where: { riderId: rider.riderId } })).toBe(before);
  });
});
