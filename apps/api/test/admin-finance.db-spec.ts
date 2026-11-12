import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createTestApp, staffUser, type SignedIn, type TestContext } from './helpers/app.js';
import { merchant, setupDouala } from './helpers/orders.js';

/**
 * Écran Finance du back-office (H5) : reversements par vue avec le bénéficiaire, validation
 * d'un gros reversement, et qui l'a validé.
 */
describe('Back-office · finance (H5)', () => {
  let ctx: TestContext;
  let finance: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp({ PAYOUT_APPROVAL_THRESHOLD: '50000' });
    const admin = await staffUser(ctx, ['ADMIN']);
    finance = await staffUser(ctx, ['FINANCE']);
    await ctx.prisma.user.update({
      where: { id: finance.userId },
      data: { fullName: 'Rose Finance' },
    });
    await setupDouala(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('montre le bénéficiaire d’un gros reversement à valider, puis qui l’a validé', async () => {
    const shop = await merchant(ctx);
    await ctx.prisma.user.update({ where: { id: shop.userId }, data: { fullName: 'Mama Ngono' } });
    const profile = await ctx.prisma.merchantProfile.update({
      where: { userId: shop.userId },
      data: { plan: 'PRO', shopName: 'Chez Mama Ngono' },
    });
    await request(ctx.http)
      .post(`/v1/admin/finance/users/${shop.userId}/credits`)
      .set(finance.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 60_000, reason: 'Ventes encaissées (test)' })
      .expect(201);
    const asked = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('Idempotency-Key', randomUUID())
      .expect(201);
    expect(asked.body.status).toBe('AWAITING_APPROVAL');

    const toApprove = await request(ctx.http)
      .get('/v1/admin/finance/payouts?view=TO_APPROVE')
      .set(finance.auth)
      .expect(200);
    expect(toApprove.body.items.find((p: { id: string }) => p.id === asked.body.id)).toMatchObject({
      beneficiary: 'MERCHANT',
      amount: 60_000,
      owner: { id: profile.id, name: 'Mama Ngono', shopName: 'Chez Mama Ngono', phone: shop.phone },
      approvedBy: null,
    });
    expect(toApprove.body.counts.TO_APPROVE).toBeGreaterThanOrEqual(1);
    expect(
      toApprove.body.items.every((p: { status: string }) => p.status === 'AWAITING_APPROVAL'),
    ).toBe(true);

    await request(ctx.http)
      .post(`/v1/admin/finance/payouts/${asked.body.id}/approve`)
      .set(finance.auth)
      .expect(200);
    const all = await request(ctx.http)
      .get('/v1/admin/finance/payouts?view=ALL')
      .set(finance.auth)
      .expect(200);
    expect(all.body.items.find((p: { id: string }) => p.id === asked.body.id)).toMatchObject({
      approvedBy: 'Rose Finance',
      approvedAt: expect.any(String),
    });

    // Le dispatch n'a pas accès à la finance.
    const dispatch = await staffUser(ctx, ['DISPATCHER']);
    await request(ctx.http).get('/v1/admin/finance/payouts').set(dispatch.auth).expect(403);
  });
});
