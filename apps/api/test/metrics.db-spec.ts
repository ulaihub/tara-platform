import request from 'supertest';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { merchant, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

/** Indicateurs du back-office (H7) : période, livraisons par jour, réussite, délais. */
describe('Back-office · indicateurs (H7)', () => {
  let ctx: TestContext;
  let support: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    support = await staffUser(ctx, ['SUPPORT']);
    await setupDouala(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('compte livraisons, retours et délais de la période, jour par jour', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const now = Date.now();
    const delivered = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: delivered.id },
      data: {
        status: 'DELIVERED',
        riderId: rider.riderId,
        createdAt: new Date(now - 50 * 60_000),
        assignedAt: new Date(now - 48 * 60_000),
        pickedUpAt: new Date(now - 30 * 60_000),
        deliveredAt: new Date(now - 5 * 60_000),
      },
    });
    const returned = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: returned.id },
      data: { status: 'RETURNED', returnedAt: new Date(now - 60_000) },
    });

    const res = await request(ctx.http)
      .get('/v1/admin/metrics?days=7')
      .set(support.auth)
      .expect(200);
    expect(res.body.period.days).toBe(7);
    expect(res.body.daily).toHaveLength(7);
    expect(res.body.daily.at(-1).delivered).toBeGreaterThanOrEqual(1);
    expect(res.body.deliveries.delivered).toBeGreaterThanOrEqual(1);
    expect(res.body.deliveries.returned).toBeGreaterThanOrEqual(1);
    expect(res.body.deliveries.successRate).toBeGreaterThan(0);
    expect(res.body.deliveries.successRate).toBeLessThan(1);
    expect(res.body.delays.delivery.median).toEqual(expect.any(Number));
    // Les autres fichiers de test partagent la base : au moins notre livreur est compté.
    expect(res.body.riders.active).toBeGreaterThanOrEqual(1);
    expect(res.body.riders.top[0]).toMatchObject({ delivered: expect.any(Number) });
    expect(res.body.merchants.active).toBeGreaterThanOrEqual(1);

    await request(ctx.http).get('/v1/admin/metrics?days=5').set(support.auth).expect(400);
    const customer = await signIn(ctx);
    await request(ctx.http).get('/v1/admin/metrics').set(customer.auth).expect(403);
  });
});
