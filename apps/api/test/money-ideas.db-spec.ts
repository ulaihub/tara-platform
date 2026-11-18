import request from 'supertest';
import { createTestApp, staffUser, type TestContext } from './helpers/app.js';
import { merchant, placeOrder, setupDouala, type TestMerchant } from './helpers/orders.js';

/**
 * Revenus validés par le fondateur : garantie de la valeur déclarée (A), frais d'annulation
 * quand le livreur est en route (C), frais d'attente au point d'enlèvement (D).
 */
describe('Garantie, annulation et attente payantes', () => {
  let ctx: TestContext;
  let shop: TestMerchant;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  describe('A · garantie de la valeur déclarée', () => {
    it('annoncée au devis, comprise dans le prix, tout pour Tara', async () => {
      const quote = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(shop.auth)
        .send({
          pickup: { addressId: shop.pickupId },
          dropoff: { addressId: shop.dropoffId },
          packageSize: 'S',
          declaredValue: 150_000,
        })
        .expect(200);
      const free = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(shop.auth)
        .send({
          pickup: { addressId: shop.pickupId },
          dropoff: { addressId: shop.dropoffId },
          packageSize: 'S',
          declaredValue: 25_000,
        })
        .expect(200);
      expect(quote.body.valueFee).toBe(1250);
      expect(free.body.valueFee).toBe(0);
      expect(quote.body.totalPrice).toBe(free.body.totalPrice + 1250);

      const placed = await placeOrder(ctx, shop, { packageSize: 'S', declaredValue: 150_000 });
      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(stored.valueFee).toBe(1250);
      expect(stored.totalPrice).toBe(free.body.totalPrice + 1250);
      // La part du livreur ne change pas : la garantie revient à Tara, qui en porte le risque.
      const plain = await placeOrder(ctx, shop, { packageSize: 'S' });
      const plainStored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: plain.id } });
      expect(stored.riderEarning).toBe(plainStored.riderEarning);
      expect(stored.platformFee).toBe(plainStored.platformFee + 1250);

      const detail = await request(ctx.http)
        .get(`/v1/orders/${placed.id}`)
        .set(shop.auth)
        .expect(200);
      expect(detail.body.pricing.valueFee).toBe(1250);
    });

    it('envoi en masse : prix de chaque colis avec sa garantie', async () => {
      const res = await request(ctx.http)
        .post('/v1/orders/quotes')
        .set(shop.auth)
        .send({
          pickupAddressId: shop.pickupId,
          items: [
            { dropoffAddressId: shop.dropoffId, packageSize: 'S', declaredValue: 100_000 },
            { dropoffAddressId: shop.dropoffId, packageSize: 'S' },
          ],
        })
        .expect(200);
      expect(res.body.items.map((i: { quote: { valueFee: number } }) => i.quote.valueFee)).toEqual([
        750, 0,
      ]);
    });
  });
});
