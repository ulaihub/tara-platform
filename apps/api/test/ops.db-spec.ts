import type { Redis } from 'ioredis';
import request from 'supertest';
import { REDIS } from '../src/redis/redis.constants.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, resetPresence } from './helpers/riders.js';

const HERE = nearAkwa(0.001);
const MINUTE = 60_000;

interface LiveRider {
  id: string;
  state: string;
  signalLost: boolean;
  position: { latitude: number; longitude: number } | null;
  orderIds: string[];
}
interface LiveOrder {
  id: string;
  status: string;
  riderId: string | null;
  delay: { kind: string; minutes: number } | null;
  pickup: { latitude: number; landmark: string };
}

describe('Carte en direct du back-office (H1)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let dispatcher: SignedIn;
  let shop: TestMerchant;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    dispatcher = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    await resetPresence();
  });
  afterAll(async () => {
    // Livreurs mis en ligne ici : retirés, pour ne pas recevoir les commandes des autres tests.
    await resetPresence();
    await ctx.app.close();
  });

  it('est réservée au dispatch, au support et aux administrateurs', async () => {
    const finance = await staffUser(ctx, ['FINANCE']);
    await request(ctx.http).get('/v1/admin/live-map').set(finance.auth).expect(403);
    await request(ctx.http).get('/v1/admin/live-map').set(shop.auth).expect(403);
    await request(ctx.http).get('/v1/admin/live-map').expect(401);
  });

  it('montre les livreurs libres, en course et hors ligne, les commandes et leurs retards', async () => {
    // Livreur en course : il accepte la première commande.
    const busy = await activeRider(ctx);
    await goOnline(ctx, busy, HERE);
    const first = await placeOrder(ctx, shop);
    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: first.id, riderId: busy.riderId },
    });
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(busy.auth).expect(200);
    // Livreur libre, et livreur validé qui ne s'est pas connecté.
    const free = await activeRider(ctx);
    await goOnline(ctx, free, nearAkwa(0.002));
    const away = await activeRider(ctx);
    // Commande sans livreur depuis 10 minutes ; livreur attendu chez le vendeur depuis 40.
    const second = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: second.id },
      data: { searchingSince: new Date(Date.now() - 10 * MINUTE) },
    });
    await ctx.prisma.order.update({
      where: { id: first.id },
      data: { assignedAt: new Date(Date.now() - 40 * MINUTE) },
    });

    const res = await request(ctx.http).get('/v1/admin/live-map').set(dispatcher.auth).expect(200);
    const riders = new Map((res.body.riders as LiveRider[]).map((rider) => [rider.id, rider]));
    expect(riders.get(busy.riderId)).toMatchObject({
      state: 'ON_COURSE',
      signalLost: false,
      orderIds: [first.id],
      position: { latitude: HERE.latitude, longitude: HERE.longitude },
    });
    expect(riders.get(free.riderId)).toMatchObject({ state: 'FREE', orderIds: [] });
    expect(riders.get(away.riderId)).toMatchObject({ state: 'OFFLINE', position: null });

    const orders = new Map((res.body.orders as LiveOrder[]).map((order) => [order.id, order]));
    expect(orders.get(first.id)).toMatchObject({
      status: 'ASSIGNED',
      riderId: busy.riderId,
      delay: { kind: 'PICKUP', minutes: 15 },
    });
    expect(orders.get(second.id)).toMatchObject({
      status: 'SEARCHING_RIDER',
      riderId: null,
      delay: { kind: 'NO_RIDER', minutes: 5 },
    });
    expect(orders.get(first.id)?.pickup.landmark).toEqual(expect.any(String));
    expect(res.body.rules).toEqual({
      searchingMinutes: 5,
      pickupMinutes: 25,
      deliveryMarginMinutes: 15,
    });
  });

  it('signale un livreur en ligne dont le téléphone ne répond plus', async () => {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, HERE);
    const redis = ctx.app.get<Redis>(REDIS);
    await redis.hset(`rider:${rider.riderId}:pos`, 'at', String(Date.now() - 5 * MINUTE));
    const res = await request(ctx.http).get('/v1/admin/live-map').set(dispatcher.auth).expect(200);
    const live = (res.body.riders as LiveRider[]).find((item) => item.id === rider.riderId);
    expect(live).toMatchObject({ state: 'FREE', signalLost: true });
  });

  it('remonte les alertes de sécurité ouvertes', async () => {
    const rider = await activeRider(ctx);
    const alert = await ctx.prisma.safetyAlert.create({
      data: { riderId: rider.riderId, latitude: HERE.latitude, longitude: HERE.longitude },
    });
    const res = await request(ctx.http).get('/v1/admin/live-map').set(admin.auth).expect(200);
    const ids = (res.body.safetyAlerts as { id: string }[]).map((item) => item.id);
    expect(ids).toContain(alert.id);
    await ctx.prisma.safetyAlert.update({
      where: { id: alert.id },
      data: { resolvedAt: new Date() },
    });
    const after = await request(ctx.http).get('/v1/admin/live-map').set(admin.auth).expect(200);
    expect((after.body.safetyAlerts as { id: string }[]).map((item) => item.id)).not.toContain(
      alert.id,
    );
  });
});
