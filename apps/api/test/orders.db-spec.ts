import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  createTestApp,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { createAddress, ensureDoualaServiceArea, PLACES } from './helpers/geo.js';
import { PLATFORM_ACCOUNTS, riderPayable } from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';

/** Grille du business plan (C2). */
const DOUALA_GRID = {
  name: 'Douala moto',
  city: 'Douala',
  perKmBeyondLastTier: 150,
  tiers: [
    { upToMeters: 5_000, price: 1000 },
    { upToMeters: 10_000, price: 1500 },
    { upToMeters: 15_000, price: 2000 },
  ],
  surcharges: [
    { code: 'EXPRESS', amount: 500 },
    { code: 'HEAVY_PARCEL', amount: 1000 },
    { code: 'NIGHT', amount: 500 },
    { code: 'WEATHER', amount: 300, active: false },
    { code: 'FAILED_ATTEMPT', percentBps: 5000 },
    { code: 'RETURN', percentBps: 5000 },
  ],
  activate: true,
};

/** Demain à 10 h, heure du Cameroun : créneau de jour valide, sans supplément de nuit. */
function tomorrowDaytime(): string {
  const at = new Date(Date.now() + 86_400_000);
  return `${at.toISOString().slice(0, 10)}T09:00:00.000Z`;
}

describe('Tarification et commandes (C1 à C7)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;
  let gridId: string;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await ensureDoualaServiceArea(ctx, admin);
    const grid = await request(ctx.http)
      .post('/v1/admin/pricing-grids')
      .set(admin.auth)
      .send(DOUALA_GRID)
      .expect(201);
    gridId = grid.body.id;
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function merchant(): Promise<SignedIn & { pickupId: string; dropoffId: string }> {
    const user = await signIn(ctx);
    await request(ctx.http)
      .put('/v1/me/merchant')
      .set(user.auth)
      .send({
        shopName: `Boutique ${randomUUID().slice(0, 4)}`,
        payoutPhone: '677000003',
        payoutOperator: 'MTN',
      })
      .expect(200);
    const pickup = await createAddress(ctx, user, PLACES.akwa, { label: 'Boutique' });
    const dropoff = await createAddress(ctx, user, PLACES.bonamoussadi, { contactName: 'Client' });
    return { ...user, pickupId: pickup.id, dropoffId: dropoff.id };
  }

  function orderBody(
    m: { pickupId: string; dropoffId: string },
    extra: Record<string, unknown> = {},
  ) {
    return {
      pickupAddressId: m.pickupId,
      dropoffAddressId: m.dropoffId,
      recipientName: 'Client Bonamoussadi',
      recipientPhone: '655 44 33 22',
      packageSize: 'M',
      feePaymentMethod: 'CASH',
      ...extra,
    };
  }

  describe('grilles tarifaires (C7)', () => {
    it('refuse une grille incohérente et réserve l’administration aux administrateurs', async () => {
      const res = await request(ctx.http)
        .post('/v1/admin/pricing-grids')
        .set(admin.auth)
        .send({
          ...DOUALA_GRID,
          tiers: [
            { upToMeters: 5_000, price: 2000 },
            { upToMeters: 10_000, price: 1500 },
          ],
        })
        .expect(400);
      expect(res.body.error.details[0].message).toMatch(/ne peut pas baisser/);
      await request(ctx.http)
        .post('/v1/admin/pricing-grids')
        .set(ops.auth)
        .send(DOUALA_GRID)
        .expect(403);
    });

    it('archive l’ancienne grille quand une nouvelle est activée', async () => {
      const next = await request(ctx.http)
        .post('/v1/admin/pricing-grids')
        .set(admin.auth)
        .send({ ...DOUALA_GRID, name: 'Douala moto v2' })
        .expect(201);
      const previous = await ctx.prisma.pricingGrid.findUniqueOrThrow({ where: { id: gridId } });
      expect(previous).toMatchObject({ active: false, validTo: expect.any(Date) });
      gridId = next.body.id;
      const audit = await ctx.prisma.auditLog.count({
        where: { entityId: gridId, action: 'pricing_grid.activated' },
      });
      expect(audit).toBe(1);
    });
  });

  describe('devis (C2, C6)', () => {
    it('calcule le prix par palier et les suppléments', async () => {
      const m = await merchant();
      const base = {
        pickup: { addressId: m.pickupId },
        dropoff: { addressId: m.dropoffId },
        scheduledFor: tomorrowDaytime(),
      };
      const simple = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({ ...base, packageSize: 'M' })
        .expect(200);
      expect(simple.body).toMatchObject({
        city: 'Douala',
        currency: 'XAF',
        distanceSource: 'estimate',
        basePrice: 1500,
        surcharges: [],
        totalPrice: 1500,
      });
      expect(simple.body.distanceMeters).toBeGreaterThan(5_000);
      expect(simple.body.distanceMeters).toBeLessThanOrEqual(10_000);

      const heavy = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({ ...base, packageSize: 'XL', isExpress: true })
        .expect(200);
      expect(heavy.body.totalPrice).toBe(3000);

      const nearby = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({
          pickup: PLACES.akwa,
          dropoff: PLACES.bonapriso,
          packageSize: 'S',
          scheduledFor: tomorrowDaytime(),
        })
        .expect(200);
      expect(nearby.body.totalPrice).toBe(1000);
    });

    it('applique le supplément pluie quand les opérations l’activent', async () => {
      const m = await merchant();
      const body = {
        pickup: PLACES.akwa,
        dropoff: PLACES.bonapriso,
        packageSize: 'S',
        scheduledFor: tomorrowDaytime(),
      };
      await request(ctx.http)
        .patch(`/v1/admin/pricing-grids/${gridId}/surcharges/WEATHER`)
        .set(admin.auth)
        .send({ active: true })
        .expect(200);
      const rainy = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send(body)
        .expect(200);
      await request(ctx.http)
        .patch(`/v1/admin/pricing-grids/${gridId}/surcharges/WEATHER`)
        .set(admin.auth)
        .send({ active: false })
        .expect(200);
      expect(rainy.body.surcharges).toEqual([{ code: 'WEATHER', amount: 300 }]);
      expect(rainy.body.totalPrice).toBe(1300);
    });

    it('refuse un point hors zone, un créneau trop proche et un code promo inconnu', async () => {
      const m = await merchant();
      const outside = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({ pickup: PLACES.akwa, dropoff: PLACES.yaounde, packageSize: 'S' })
        .expect(422);
      expect(outside.body.error.code).toBe('OUT_OF_SERVICE_AREA');

      const soon = new Date(Date.now() + 10 * 60_000).toISOString();
      const early = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({
          pickup: PLACES.akwa,
          dropoff: PLACES.bonapriso,
          packageSize: 'S',
          scheduledFor: soon,
        })
        .expect(422);
      expect(early.body.error.code).toBe('SCHEDULE_INVALID');

      const promo = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(m.auth)
        .send({
          pickup: PLACES.akwa,
          dropoff: PLACES.bonapriso,
          packageSize: 'S',
          promoCode: 'INCONNU',
        })
        .expect(422);
      expect(promo.body.error.code).toBe('PROMO_INVALID');
    });
  });

  describe('création de commande (C1, C3, C5)', () => {
    it('crée une commande avec encaissement, la lance et prévient le destinataire', async () => {
      const m = await merchant();
      const key = randomUUID();
      const res = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .set('Idempotency-Key', key)
        .send(orderBody(m, { codAmount: 15_000 }))
        .expect(201);
      expect(res.body.pickupCode).toMatch(/^\d{4}$/);
      expect(res.body.order).toMatchObject({
        reference: expect.stringMatching(/^TR-[0-9A-Z]{6}$/),
        status: 'SEARCHING_RIDER',
        recipient: { name: 'Client Bonamoussadi', phone: '+237655443322' },
        pricing: { codAmount: 15_000, feePaymentMethod: 'CASH', currency: 'XAF' },
      });
      expect(res.body.order.timeline.map((e: { status: string }) => e.status)).toEqual([
        'CREATED',
        'SEARCHING_RIDER',
      ]);

      const sms = ctx.sms.lastTo('+237655443322')?.text ?? '';
      expect(sms).toContain(res.body.order.reference);
      expect(sms).toContain(res.body.order.trackingUrl);

      // Ni le prix ni les codes ne viennent du client ; aucun code n'est stocké en clair.
      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: res.body.order.id } });
      expect(stored.pickupCodeHash).not.toContain(res.body.pickupCode);
      expect(stored.riderEarning + stored.platformFee).toBe(stored.totalPrice);

      const replay = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .set('Idempotency-Key', key)
        .send(orderBody(m))
        .expect(201);
      expect(replay.body).toMatchObject({
        replayed: true,
        pickupCode: null,
        order: { id: res.body.order.id },
      });

      const other = await merchant();
      const conflict = await request(ctx.http)
        .post('/v1/orders')
        .set(other.auth)
        .set('Idempotency-Key', key)
        .send(orderBody(other))
        .expect(409);
      expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    });

    it('réserve l’encaissement aux marchands et protège les adresses des autres', async () => {
      const customer = await signIn(ctx);
      const pickup = await createAddress(ctx, customer, PLACES.akwa);
      const dropoff = await createAddress(ctx, customer, PLACES.bonapriso);
      const cod = await request(ctx.http)
        .post('/v1/orders')
        .set(customer.auth)
        .send(orderBody({ pickupId: pickup.id, dropoffId: dropoff.id }, { codAmount: 5000 }))
        .expect(422);
      expect(cod.body.error.code).toBe('MERCHANT_REQUIRED_FOR_COD');

      const m = await merchant();
      const stolen = await request(ctx.http)
        .post('/v1/orders')
        .set(customer.auth)
        .send(orderBody({ pickupId: pickup.id, dropoffId: m.dropoffId }))
        .expect(422);
      expect(stolen.body.error.code).toBe('ADDRESS_NOT_FOUND');

      const tooMuch = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { codAmount: 600_000 }))
        .expect(422);
      expect(tooMuch.body.error.code).toBe('COD_AMOUNT_TOO_HIGH');
    });

    it('garde en attente une commande prépayée ou programmée (C3)', async () => {
      const m = await merchant();
      const prepaid = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { feePaymentMethod: 'MOMO_MTN' }))
        .expect(201);
      expect(prepaid.body.order.status).toBe('CREATED');
      const scheduledFor = tomorrowDaytime();
      const scheduled = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { scheduledFor }))
        .expect(201);
      expect(scheduled.body.order).toMatchObject({ status: 'CREATED', scheduledFor });
    });

    it('applique un code promo dans sa limite et le rend à l’annulation (C6)', async () => {
      const code = `BIENVENUE-${randomUUID().slice(0, 6).toUpperCase()}`;
      await request(ctx.http)
        .post('/v1/admin/promo-codes')
        .set(admin.auth)
        .send({ code, kind: 'FIXED_PRICE', value: 500, perUserLimit: 1 })
        .expect(201);
      const m = await merchant();
      const scheduledFor = tomorrowDaytime();
      const first = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { promoCode: code.toLowerCase(), scheduledFor }))
        .expect(201);
      expect(first.body.order.pricing).toMatchObject({ discountTotal: 1000, totalPrice: 500 });

      const second = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { promoCode: code }))
        .expect(422);
      expect(second.body.error.code).toBe('PROMO_EXHAUSTED');

      await request(ctx.http)
        .post(`/v1/orders/${first.body.order.id}/cancel`)
        .set(m.auth)
        .send({ reason: 'Client injoignable' })
        .expect(200);
      await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { promoCode: code }))
        .expect(201);
    });

    it('crée un lot de livraisons avec un seul code d’enlèvement (C4)', async () => {
      const m = await merchant();
      const second = await createAddress(ctx, m, PLACES.bonapriso);
      const item = (dropoffAddressId: string, name: string) => ({
        dropoffAddressId,
        recipientName: name,
        recipientPhone: '699 00 11 22',
        packageSize: 'S',
        codAmount: 7_500,
      });
      const res = await request(ctx.http)
        .post('/v1/orders/batch')
        .set(m.auth)
        .set('Idempotency-Key', randomUUID())
        .send({
          pickupAddressId: m.pickupId,
          feePaymentMethod: 'CASH',
          items: [item(m.dropoffId, 'Awa'), item(second.id, 'Brice'), item(m.dropoffId, 'Carine')],
        })
        .expect(201);
      expect(res.body.orders).toHaveLength(3);
      expect(res.body.pickupCode).toMatch(/^\d{4}$/);
      expect(new Set(res.body.orders.map((o: { batchId: string }) => o.batchId))).toEqual(
        new Set([res.body.batchId]),
      );

      const regenerated = await request(ctx.http)
        .post(`/v1/orders/${res.body.orders[0].id}/pickup-code`)
        .set(m.auth)
        .expect(200);
      expect(regenerated.body.pickupCode).toMatch(/^\d{4}$/);

      const tooMany = await request(ctx.http)
        .post('/v1/orders/batch')
        .set(m.auth)
        .send({
          pickupAddressId: m.pickupId,
          feePaymentMethod: 'CASH',
          items: Array.from({ length: 11 }, () => item(m.dropoffId, 'X')),
        })
        .expect(400);
      expect(tooMany.body.error.code).toBe('VALIDATION_FAILED');
    });
  });

  describe('suivi, annulation et cycle de vie', () => {
    it('laisse le destinataire répondre une seule fois depuis la page de suivi (C5)', async () => {
      const m = await merchant();
      const order = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m))
        .expect(201);
      const token = (order.body.order.trackingUrl as string).split('/t/')[1];
      const view = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
      expect(view.body).toMatchObject({ canRespond: true, recipientName: 'Client Bonamoussadi' });
      expect(JSON.stringify(view.body)).not.toContain('+237');

      const answer = await request(ctx.http)
        .post(`/v1/public/tracking/${token}/response`)
        .send({ available: false, note: 'Disponible après 17 h' })
        .expect(200);
      expect(answer.body).toMatchObject({ canRespond: false, recipientAvailable: false });
      const again = await request(ctx.http)
        .post(`/v1/public/tracking/${token}/response`)
        .send({ available: true })
        .expect(409);
      expect(again.body.error.code).toBe('RECIPIENT_ALREADY_RESPONDED');

      const seen = await request(ctx.http)
        .get(`/v1/orders/${order.body.order.id}`)
        .set(m.auth)
        .expect(200);
      expect(seen.body.recipient).toMatchObject({
        available: false,
        note: 'Disponible après 17 h',
      });
    });

    it('cache la commande aux autres utilisateurs et la montre aux opérations', async () => {
      const m = await merchant();
      const order = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m))
        .expect(201);
      const stranger = await signIn(ctx);
      await request(ctx.http)
        .get(`/v1/orders/${order.body.order.id}`)
        .set(stranger.auth)
        .expect(404);
      await request(ctx.http).get(`/v1/orders/${order.body.order.id}`).set(ops.auth).expect(200);
      const list = await request(ctx.http).get('/v1/orders?limit=5').set(m.auth).expect(200);
      expect(list.body.items[0]).toMatchObject({
        id: order.body.order.id,
        dropoffLandmark: expect.any(String),
      });
    });

    it('n’accepte qu’une annulation parmi deux simultanées', async () => {
      const m = await merchant();
      const order = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m))
        .expect(201);
      const cancel = () =>
        request(ctx.http)
          .post(`/v1/orders/${order.body.order.id}/cancel`)
          .set(m.auth)
          .send({ reason: 'Doublon' });
      const results = await Promise.all([cancel(), cancel()]);
      expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([200, 409]);
      const events = await ctx.prisma.orderEvent.count({
        where: { orderId: order.body.order.id, toStatus: 'CANCELLED' },
      });
      expect(events).toBe(1);
    });

    it('déroule une livraison complète et mémorise le point du destinataire (B4)', async () => {
      const m = await merchant();
      const order = await request(ctx.http)
        .post('/v1/orders')
        .set(m.auth)
        .send(orderBody(m, { codAmount: 10_000 }))
        .expect(201);
      const id = order.body.order.id as string;

      const riderUser = await signIn(ctx);
      const rider = await ctx.prisma.riderProfile.create({
        data: {
          userId: riderUser.userId,
          status: 'ACTIVE',
          guarantorName: 'G',
          guarantorPhone: '+237699000000',
        },
      });
      await ctx.prisma.user.update({
        where: { id: riderUser.userId },
        data: { roles: ['CUSTOMER', 'RIDER'] },
      });
      // Solde prépayé qui couvre l'argent à encaisser (G5, décision 36).
      const ledger = ctx.app.get(LedgerService);
      await ctx.prisma.$transaction((tx) =>
        ledger.post(tx, {
          kind: 'PAYMENT_RECEIVED',
          description: 'Recharge de départ (test)',
          idempotencyKey: `test-start-balance:${rider.id}`,
          postings: [
            { account: PLATFORM_ACCOUNTS.officeCash, amount: 50_000 },
            { account: riderPayable(rider.id), amount: -50_000 },
          ],
        }),
      );

      const go = (to: string, extra: Record<string, unknown> = {}) =>
        request(ctx.http)
          .post(`/v1/admin/orders/${id}/transition`)
          .set(ops.auth)
          .send({ to, ...extra });

      await go('ASSIGNED').expect(400);
      await go('ASSIGNED', { riderId: rider.id }).expect(200);
      await request(ctx.http).get(`/v1/orders/${id}`).set(riderUser.auth).expect(200);

      await go('PICKED_UP').expect(200);
      expect(ctx.sms.lastTo('+237655443322')?.text).toMatch(/Code a donner au livreur : \d{4}/);
      await go('IN_DELIVERY').expect(200);
      await go('DELIVERY_FAILED').expect(400);
      const failed = await go('DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' }).expect(200);
      expect(failed.body.attemptCount).toBe(1);
      await go('IN_DELIVERY').expect(200);
      // Pas de livraison sans encaissement du contre-remboursement (E5), même forcée.
      const unpaid = await go('DELIVERED').expect(409);
      expect(unpaid.body.error.code).toBe('COLLECTION_REQUIRED');
      await request(ctx.http)
        .post(`/v1/rider/orders/${id}/collect`)
        .set(riderUser.auth)
        .send({ method: 'CASH' })
        .expect(200);
      const delivered = await go('DELIVERED').expect(200);
      expect(delivered.body.timeline.map((e: { status: string }) => e.status)).toEqual([
        'CREATED',
        'SEARCHING_RIDER',
        'ASSIGNED',
        'PICKED_UP',
        'IN_DELIVERY',
        'DELIVERY_FAILED',
        'IN_DELIVERY',
        'DELIVERED',
      ]);

      const notCancellable = await request(ctx.http)
        .post(`/v1/orders/${id}/cancel`)
        .set(m.auth)
        .send({ reason: 'Trop tard' })
        .expect(409);
      expect(notCancellable.body.error.code).toBe('ORDER_NOT_CANCELLABLE');
      const invalid = await go('IN_DELIVERY').expect(409);
      expect(invalid.body.error).toMatchObject({ code: 'ORDER_TRANSITION_INVALID' });

      const recipients = await request(ctx.http)
        .get('/v1/recipients?q=Bonamoussadi')
        .set(m.auth)
        .expect(200);
      expect(recipients.body[0]).toMatchObject({
        phone: '+237655443322',
        lastAddress: { id: m.dropoffId, verifiedAt: expect.any(String) },
      });
      // Seules les 6 transitions réussies sont auditées, pas les tentatives refusées.
      const audits = await ctx.prisma.auditLog.count({
        where: { entityId: id, action: 'order.transition' },
      });
      expect(audits).toBe(6);
    });
  });
});
