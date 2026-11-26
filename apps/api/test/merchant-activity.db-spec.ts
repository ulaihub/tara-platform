import request from 'supertest';
import { MerchantActivityService } from '../src/orders/merchant-activity.js';
import { createTestApp, signIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, placeOrder, setupDouala, type TestMerchant } from './helpers/orders.js';

/** Mercredi 18 novembre 2026, 15 h au Cameroun. */
const NOW = new Date('2026-11-18T14:00:00Z');

describe('« Mon activité » d’une boutique', () => {
  let ctx: TestContext;
  let shop: TestMerchant;
  let zoneName: string;

  beforeAll(async () => {
    ctx = await createTestApp();
    await setupDouala(ctx, await staffUser(ctx, ['ADMIN']));
    shop = await merchant(ctx);
    // Quartier du point de livraison de la boutique.
    const neighborhood = await ctx.prisma.zone.findFirst({
      where: { name: 'Bonamoussadi' },
    });
    const area = neighborhood ?? (await ctx.prisma.zone.findFirstOrThrow());
    await ctx.prisma.address.update({
      where: { id: shop.dropoffId },
      data: { neighborhoodId: area.id },
    });
    zoneName = area.name;
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function finished(
    status: 'DELIVERED' | 'RETURNED',
    at: string,
    codAmount: number,
    createdAt?: string,
  ): Promise<void> {
    const order = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: order.id },
      data: {
        status,
        codAmount,
        createdAt: new Date(
          createdAt ?? new Date(new Date(at).getTime() - 50 * 60_000).toISOString(),
        ),
        ...(status === 'DELIVERED' ? { deliveredAt: new Date(at) } : { returnedAt: new Date(at) }),
      },
    });
  }

  it('compte livraisons, ventes, réussite et délai, comparés au même moment d’hier', async () => {
    // Aujourd'hui : deux livrées (11 h et 14 h 30, heure locale), une retournée.
    await finished('DELIVERED', '2026-11-18T10:00:00Z', 12_250);
    await finished('DELIVERED', '2026-11-18T13:30:00Z', 15_450);
    await finished('RETURNED', '2026-11-18T12:00:00Z', 8_000);
    // Plus tard dans la journée qu'en ce moment hier : pas comptée dans la comparaison.
    await finished('DELIVERED', '2026-11-17T09:00:00Z', 10_000);
    await finished('DELIVERED', '2026-11-17T18:00:00Z', 99_000);

    const activity = await ctx.app.get(MerchantActivityService).activity(shop.userId, 'day', NOW);
    expect(activity).toMatchObject({
      period: 'day',
      from: '2026-11-17T23:00:00.000Z',
      deliveries: 2,
      collected: 27_700,
      successRate: 67,
      deliveriesChange: 100,
      collectedChange: 177,
      successRateChange: -33,
      averageMinutes: 50,
    });
    expect(activity.buckets).toHaveLength(7);
    // 11 h → tranche 10 h-12 h ; 14 h 30 → tranche 14 h-16 h.
    expect(activity.buckets.map((b) => b.deliveries)).toEqual([0, 1, 0, 1, 0, 0, 0]);
    expect(activity.buckets[1]!.sales).toBe(12_250);
    expect(activity.zones).toEqual([{ name: zoneName, share: 100 }]);

    const week = await ctx.app.get(MerchantActivityService).activity(shop.userId, 'week', NOW);
    // Lundi 16 → dimanche 22 novembre.
    expect(week.buckets).toHaveLength(7);
    expect(week.from).toBe('2026-11-15T23:00:00.000Z');
    expect(week.buckets.map((b) => b.deliveries)).toEqual([0, 2, 2, 0, 0, 0, 0]);

    const month = await ctx.app.get(MerchantActivityService).activity(shop.userId, 'month', NOW);
    expect(month.buckets).toHaveLength(5);
    expect(month.deliveries).toBe(4);
  });

  it('réservé aux boutiques', async () => {
    const person = await signIn(ctx);
    await request(ctx.http).get('/v1/me/merchant/activity').set(person.auth).expect(404);
    const res = await request(ctx.http)
      .get('/v1/me/merchant/activity?period=month')
      .set(shop.auth)
      .expect(200);
    expect(res.body.period).toBe('month');
  });
});
