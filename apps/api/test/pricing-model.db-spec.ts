import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { riderPayable } from '../src/finance/ledger.accounts.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  RIDER_SHARE_BPS,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, resetPresence } from './helpers/riders.js';

/**
 * Modèle de prix validé (H4) : tarif pro des boutiques selon leurs livraisons du mois, pris
 * sur la part de Tara ; prime d'approche et prime de renfort des livreurs, annoncées dans la
 * proposition et payées par Tara à la livraison. Tout se règle au back-office.
 */
describe('Modèle de prix (H4) : tarif pro et primes des livreurs', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    // Les autres fichiers de test partagent la base : retour aux valeurs validées.
    await ctx.prisma.pricingSettings.deleteMany({ where: { city: 'Douala' } });
    await ctx.prisma.riderBoost.updateMany({
      where: { cancelledAt: null },
      data: { cancelledAt: new Date() },
    });
    await ctx.app.close();
  });

  const quote = (shop: TestMerchant, promoCode?: string) =>
    request(ctx.http)
      .post('/v1/orders/quote')
      .set(shop.auth)
      .send({
        pickup: { addressId: shop.pickupId },
        dropoff: { addressId: shop.dropoffId },
        packageSize: 'S',
        ...(promoCode ? { promoCode } : {}),
      })
      .expect(200);

  it('donne les valeurs validées tant que rien n’a été réglé, et refuse des paliers incohérents', async () => {
    const settings = await request(ctx.http)
      .get('/v1/admin/pricing-settings/Douala')
      .set(admin.auth)
      .expect(200);
    expect(settings.body).toMatchObject({
      volumeDiscounts: [
        { fromDeliveries: 100, percentBps: 1000 },
        { fromDeliveries: 300, percentBps: 1500 },
      ],
      approachBonusAmount: 200,
      approachBonusFromMeters: 3000,
      updatedAt: null,
    });
    await request(ctx.http)
      .put('/v1/admin/pricing-settings/Douala')
      .set(admin.auth)
      .send({
        volumeDiscounts: [
          { fromDeliveries: 100, percentBps: 1500 },
          { fromDeliveries: 300, percentBps: 1000 },
        ],
        approachBonusAmount: 200,
        approachBonusFromMeters: 3000,
      })
      .expect(400);
    // Le dispatch règle les primes de renfort, pas les tarifs.
    await request(ctx.http).get('/v1/admin/pricing-settings/Douala').set(ops.auth).expect(403);
  });

  it('applique le tarif pro sur la part de Tara, sans le cumuler avec un code promo', async () => {
    await request(ctx.http)
      .put('/v1/admin/pricing-settings/Douala')
      .set(admin.auth)
      .send({
        volumeDiscounts: [{ fromDeliveries: 1, percentBps: 1000 }],
        approachBonusAmount: 200,
        approachBonusFromMeters: 3000,
      })
      .expect(200);
    const shop = await merchant(ctx);
    const before = await quote(shop);
    expect(before.body).toMatchObject({
      discountSource: null,
      proDiscountBps: 0,
      discountTotal: 0,
    });

    // Une livraison réussie ce mois-ci : le palier « dès 1 livraison » est atteint.
    const first = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: first.id },
      data: { status: 'DELIVERED', deliveredAt: new Date() },
    });
    const pro = await quote(shop);
    const subtotal = before.body.totalPrice as number;
    const discount = Math.round(subtotal / 10 / 50) * 50;
    expect(pro.body).toMatchObject({
      discountSource: 'VOLUME',
      proDiscountBps: 1000,
      discountTotal: discount,
      totalPrice: subtotal - discount,
      promoCode: null,
    });

    // Un code promo plus avantageux l'emporte ; un code moins avantageux n'est pas consommé.
    const big = `PRO30-${randomUUID().slice(0, 6).toUpperCase()}`;
    const small = `PRO5-${randomUUID().slice(0, 6).toUpperCase()}`;
    await request(ctx.http)
      .post('/v1/admin/promo-codes')
      .set(admin.auth)
      .send({ code: big, kind: 'PERCENT', value: 3000 })
      .expect(201);
    await request(ctx.http)
      .post('/v1/admin/promo-codes')
      .set(admin.auth)
      .send({ code: small, kind: 'PERCENT', value: 500 })
      .expect(201);
    expect((await quote(shop, big)).body).toMatchObject({
      discountSource: 'PROMO',
      proDiscountBps: 0,
      promoCode: big,
    });
    expect((await quote(shop, small)).body).toMatchObject({
      discountSource: 'VOLUME',
      promoCode: null,
    });

    // La commande garde le tarif pro ; la part du livreur n'est pas réduite.
    const placed = await placeOrder(ctx, shop);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    expect(stored).toMatchObject({
      proDiscountBps: 1000,
      discountTotal: discount,
      totalPrice: subtotal - discount,
      riderEarning: Math.floor((subtotal * RIDER_SHARE_BPS) / 10_000),
    });
    expect(stored.riderEarning + stored.platformFee).toBe(stored.totalPrice);
  });

  it('annonce la prime d’approche et la prime de renfort, puis les paie à la livraison', async () => {
    const boost = await request(ctx.http)
      .post('/v1/admin/rider-boosts')
      .set(ops.auth)
      .send({
        amount: 300,
        reason: 'Forte pluie',
        endsAt: new Date(Date.now() + 3_600_000).toISOString(),
      })
      .expect(201);
    expect(boost.body).toMatchObject({ status: 'ACTIVE', amount: 300, orders: 0 });

    const shop = await merchant(ctx);
    // Environ 3,9 km du vendeur : au-delà du seuil de 3 km.
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.035));
    const placed = await placeOrder(ctx, shop);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });

    const offers = await request(ctx.http).get('/v1/rider/offers').set(rider.auth).expect(200);
    expect(offers.body[0]).toMatchObject({
      orderId: placed.id,
      approachBonus: 200,
      boostBonus: 300,
      riderEarning: stored.riderEarning + 500,
    });
    await request(ctx.http)
      .post(`/v1/rider/offers/${offers.body[0].id as string}/accept`)
      .set(rider.auth)
      .expect(200);
    const assigned = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    expect(assigned).toMatchObject({ approachBonus: 200, boostBonus: 300 });

    for (const to of ['PICKED_UP', 'IN_DELIVERY', 'DELIVERED']) {
      await request(ctx.http)
        .post(`/v1/admin/orders/${placed.id}/transition`)
        .set(ops.auth)
        .send({ to })
        .expect(200);
    }
    // Écriture de la livraison : part du livreur plus 500 F de primes, prises en charge par
    // Tara (les espèces encaissées passent, elles, par le solde prépayé du livreur).
    const lines = await ctx.prisma.ledgerPosting.findMany({
      where: { entry: { idempotencyKey: `order:${placed.id}:complete` } },
      include: { account: { select: { code: true } } },
    });
    const amountOn = (code: string) => lines.find((line) => line.account.code === code)?.amount;
    expect(amountOn(riderPayable(rider.riderId).code)).toBe(-(stored.riderEarning + 500));
    expect(amountOn('platform:expense:rider_bonuses')).toBe(500);

    const listed = await request(ctx.http).get('/v1/admin/rider-boosts').set(ops.auth).expect(200);
    expect(listed.body.find((b: { id: string }) => b.id === boost.body.id)).toMatchObject({
      orders: 1,
      paid: 300,
    });
    const stopped = await request(ctx.http)
      .post(`/v1/admin/rider-boosts/${boost.body.id as string}/cancel`)
      .set(ops.auth)
      .expect(200);
    expect(stopped.body.status).toBe('CANCELLED');
  });

  it('simule une grille pour quelques distances avant de l’enregistrer', async () => {
    const res = await request(ctx.http)
      .post('/v1/admin/pricing-grids/simulate')
      .set(admin.auth)
      .set('Idempotency-Key', randomUUID())
      .send({
        riderShareBps: 7000,
        perKmBeyondLastTier: 50,
        tiers: [
          { upToMeters: 5000, price: 1000 },
          { upToMeters: 6000, price: 1100 },
          { upToMeters: 7000, price: 1200 },
          { upToMeters: 8000, price: 1300 },
          { upToMeters: 9000, price: 1400 },
          { upToMeters: 10_000, price: 1500 },
        ],
        distancesMeters: [3000, 16_800, 28_400],
      })
      .expect(200);
    // Bonapriso → Logbessou et Bonabéri → Yassa, distances par la route.
    expect(res.body.rows).toEqual([
      { distanceMeters: 3000, price: 1000, riderEarning: 700, platformShare: 300 },
      { distanceMeters: 16_800, price: 1850, riderEarning: 1295, platformShare: 555 },
      { distanceMeters: 28_400, price: 2450, riderEarning: 1715, platformShare: 735 },
    ]);
  });

  it('liste les boutiques les plus actives du mois avec leur tarif pro et leur solde', async () => {
    const busy = await merchant(ctx);
    const placed = await placeOrder(ctx, busy);
    await ctx.prisma.order.update({
      where: { id: placed.id },
      data: { status: 'DELIVERED', deliveredAt: new Date() },
    });
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: busy.userId },
    });
    const page = await request(ctx.http)
      .get(`/v1/admin/merchants?q=${encodeURIComponent(profile.shopName)}`)
      .set(admin.auth)
      .expect(200);
    expect(page.body.items[0]).toMatchObject({
      id: profile.id,
      deliveriesThisMonth: 1,
      balance: expect.any(Number),
      lastOrderAt: expect.any(String),
    });
    const sheet = await request(ctx.http)
      .get(`/v1/admin/merchants/${profile.id}`)
      .set(admin.auth)
      .expect(200);
    expect(sheet.body).toMatchObject({
      last30Days: { delivered: 1 },
      recentOrders: [{ reference: placed.reference }],
      // Réglage du test précédent (un seul palier, dès 1 livraison) : atteint, pas de suivant.
      proDiscountBps: 1000,
      nextTier: null,
    });
    await request(ctx.http).get('/v1/admin/merchants').set(ops.auth).expect(403);
    // Toutes les zones, y compris coupées, pour l'écran Zones.
    const zones = await request(ctx.http).get('/v1/admin/zones').set(admin.auth).expect(200);
    expect(zones.body.some((zone: { kind: string }) => zone.kind === 'SERVICE_AREA')).toBe(true);
    // Contours de toutes les zones pour la carte du back-office, puis une zone dessinée.
    const map = await request(ctx.http).get('/v1/admin/zones/map').set(admin.auth).expect(200);
    expect(map.body.features[0]).toMatchObject({
      properties: { kind: expect.any(String), active: expect.any(Boolean) },
      geometry: { type: expect.stringMatching(/Polygon/) },
    });
    const drawn = await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: `Marché Central ${Date.now()}`,
        city: 'Douala',
        kind: 'NO_MOTORBIKE',
        geometry: {
          type: 'Polygon',
          coordinates: [
            [
              [9.701, 4.046],
              [9.705, 4.046],
              [9.705, 4.049],
              [9.701, 4.049],
              [9.701, 4.046],
            ],
          ],
        },
      })
      .expect(201);
    await request(ctx.http)
      .patch(`/v1/admin/zones/${drawn.body.id as string}`)
      .set(admin.auth)
      .send({ active: false })
      .expect(200);
  });
});
