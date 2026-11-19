import request from 'supertest';
import { createTestApp, staffUser, type TestContext } from './helpers/app.js';
import { createAddress, PLACES } from './helpers/geo.js';
import { merchant, nearAkwa, setupDouala, type TestMerchant } from './helpers/orders.js';
import { activeRider, goOnline, proofPhoto, resetPresence } from './helpers/riders.js';

/**
 * Tournée (2c) : les colis d'un même envoi partent ensemble avec un seul livreur, dans la
 * limite de ce que porte son véhicule ; primes une fois ; enlèvement en un code et une photo.
 */
describe('Tournée : plusieurs colis, un livreur', () => {
  let ctx: TestContext;
  let shop: TestMerchant;
  let dropoffs: string[];

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    dropoffs = [
      shop.dropoffId,
      (await createAddress(ctx, shop, PLACES.bonapriso, { contactName: 'Marie' })).id,
      (await createAddress(ctx, shop, nearAkwa(0.01), { contactName: 'Paul' })).id,
    ];
    await resetPresence();
  });
  afterAll(async () => {
    await resetPresence();
    await ctx.app.close();
  });

  let phone = 677_100_000;
  const item = (dropoffAddressId: string, packageSize: string) => ({
    dropoffAddressId,
    recipientName: 'Client Tournée',
    recipientPhone: `+237${(phone += 1)}`,
    packageSize,
  });

  it('une moto reçoit les petits colis ensemble ; le grand part seul', async () => {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.002));
    const batch = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'CASH',
        items: [
          item(dropoffs[0] ?? '', 'S'),
          item(dropoffs[1] ?? '', 'M'),
          item(dropoffs[2] ?? '', 'S'),
          item(dropoffs[1] ?? '', 'XL'),
        ],
      })
      .expect(201);
    const ids = (batch.body.orders as { id: string }[]).map((order) => order.id);

    const offers = await request(ctx.http).get('/v1/rider/offers').set(rider.auth).expect(200);
    expect(offers.body).toHaveLength(1);
    const [offer] = offers.body;
    expect(offer.tourParcels).toHaveLength(3);
    const parcels = await ctx.prisma.order.findMany({ where: { id: { in: ids.slice(0, 3) } } });
    const shares = parcels.reduce((sum, parcel) => sum + parcel.riderEarning, 0);
    expect(offer.riderEarning).toBe(shares + offer.approachBonus + offer.boostBonus);
    // Le premier arrêt est le client le plus proche de la boutique.
    expect(offer.tourParcels[0].orderId).toBe(ids[2]);

    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    const assigned = await ctx.prisma.order.findMany({
      where: { id: { in: ids } },
      orderBy: { batchNumber: 'asc' },
    });
    const tour = assigned.slice(0, 3);
    expect(tour.map((order) => order.status)).toEqual(['ASSIGNED', 'ASSIGNED', 'ASSIGNED']);
    expect(new Set(tour.map((order) => order.tourId))).toEqual(new Set([offer.id]));
    expect(tour.map((order) => order.stopSeq ?? 0).sort((a, b) => a - b)).toEqual([1, 2, 3]);
    // Primes une seule fois par tournée.
    const bonuses = tour.filter((order) => order.approachBonus + order.boostBonus > 0);
    expect(bonuses.length).toBeLessThanOrEqual(1);
    // Le grand colis attend un autre livreur : celui-ci est occupé.
    expect(assigned[3]?.status).toBe('SEARCHING_RIDER');

    // Enlèvement : les 3 colis cochés, un code et une photo.
    const photoKey = await proofPhoto(ctx, rider);
    const picked = await request(ctx.http)
      .post(`/v1/rider/tours/${offer.id}/pickup`)
      .set(rider.auth)
      .send({
        orderIds: ids.slice(0, 3),
        pickupCode: batch.body.pickupCode,
        photoKey,
        ...nearAkwa(0.001),
      })
      .expect(200);
    expect(picked.body.map((order: { status: string }) => order.status)).toEqual([
      'PICKED_UP',
      'PICKED_UP',
      'PICKED_UP',
    ]);
    expect(picked.body.map((order: { stopSeq: number }) => order.stopSeq)).toEqual([1, 2, 3]);
  });

  it('un livreur déjà en course ne reçoit pas de tournée', async () => {
    await resetPresence();
    const busy = await activeRider(ctx);
    await goOnline(ctx, busy, nearAkwa(0.002));
    const first = await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        ...item(dropoffs[0] ?? '', 'S'),
        feePaymentMethod: 'CASH',
      })
      .expect(201);
    const single = await request(ctx.http).get('/v1/rider/offers').set(busy.auth).expect(200);
    expect(single.body[0].orderId).toBe(first.body.order.id);
    expect(single.body[0].tourParcels).toEqual([]);
    await request(ctx.http)
      .post(`/v1/rider/offers/${single.body[0].id}/accept`)
      .set(busy.auth)
      .expect(200);

    await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'CASH',
        items: [item(dropoffs[0] ?? '', 'S'), item(dropoffs[1] ?? '', 'S')],
      })
      .expect(201);
    const none = await request(ctx.http).get('/v1/rider/offers').set(busy.auth).expect(200);
    expect(none.body).toEqual([]);
  });
});
