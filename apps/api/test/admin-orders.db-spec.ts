import request from 'supertest';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, proofPhoto, resetPresence } from './helpers/riders.js';

interface Row {
  id: string;
  reference: string;
  status: string;
}

describe('Commandes au back-office (H2)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let dispatcher: SignedIn;
  let support: SignedIn;
  let shop: TestMerchant;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    dispatcher = await staffUser(ctx, ['DISPATCHER']);
    support = await staffUser(ctx, ['SUPPORT']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    await resetPresence();
  });
  afterAll(async () => {
    await resetPresence();
    await ctx.app.close();
  });

  const list = (who: SignedIn, query: Record<string, string>) =>
    request(ctx.http).get('/v1/admin/orders').query(query).set(who.auth);

  it('retrouve une commande par sa référence ou le numéro du destinataire', async () => {
    const order = await placeOrder(ctx, shop);
    const byReference = await list(support, { q: order.reference.toLowerCase() }).expect(200);
    expect((byReference.body.items as Row[]).map((row) => row.id)).toEqual([order.id]);
    expect(byReference.body.total).toBe(1);
    const digits = order.recipientPhone.slice(-8);
    const byPhone = await list(dispatcher, { q: digits }).expect(200);
    expect((byPhone.body.items as Row[]).map((row) => row.id)).toContain(order.id);
    expect(byPhone.body.items[0]).toMatchObject({
      reference: order.reference,
      senderName: expect.any(String),
      recipientName: 'Client Bonamoussadi',
    });
  });

  it('filtre par vue et pagine du plus récent au plus ancien', async () => {
    const first = await placeOrder(ctx, shop);
    const second = await placeOrder(ctx, shop);
    await request(ctx.http)
      .post(`/v1/admin/orders/${first.id}/cancel`)
      .set(dispatcher.auth)
      .send({ reason: 'Client injoignable avant l’enlèvement' })
      .expect(200);
    const cancelled = await list(admin, { view: 'cancelled' }).expect(200);
    const ids = (cancelled.body.items as Row[]).map((row) => row.id);
    expect(ids).toContain(first.id);
    expect(ids).not.toContain(second.id);
    const active = await list(admin, { view: 'active', limit: '1' }).expect(200);
    expect(active.body.items).toHaveLength(1);
    expect(active.body.items[0].id).toBe(second.id);
    const next = await list(admin, {
      view: 'active',
      limit: '1',
      cursor: active.body.nextCursor,
    }).expect(200);
    expect(next.body.items[0].id).not.toBe(second.id);
  });

  it('range une commande sans livreur signalée dans « à traiter »', async () => {
    const order = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: order.id },
      data: { dispatchAlertedAt: new Date() },
    });
    const problems = await list(dispatcher, { view: 'problems' }).expect(200);
    expect((problems.body.items as Row[]).map((row) => row.id)).toContain(order.id);
  });

  it('montre la fiche avec l’historique, le prix et les notes internes', async () => {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.001));
    const order = await placeOrder(ctx, shop);
    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: order.id, riderId: rider.riderId },
    });
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/notes`)
      .set(support.auth)
      .send({ body: 'Le client préfère être appelé après 14 h.' })
      .expect(201);

    const res = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}`)
      .set(support.auth)
      .expect(200);
    expect(res.body).toMatchObject({
      reference: order.reference,
      status: 'ASSIGNED',
      rider: { id: rider.riderId },
      price: { totalPrice: expect.any(Number), riderEarning: expect.any(Number) },
      can: { cancel: true, reassign: true },
      notes: [{ body: 'Le client préfère être appelé après 14 h.' }],
    });
    expect((res.body.timeline as { to: string }[]).map((event) => event.to)).toEqual([
      'CREATED',
      'SEARCHING_RIDER',
      'ASSIGNED',
    ]);

    // Colis récupéré : plus d'annulation ni de réattribution.
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...nearAkwa(0.001) })
      .expect(200);
    const after = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}`)
      .set(admin.auth)
      .expect(200);
    expect(after.body.can).toEqual({ cancel: false, reassign: false });
    expect(after.body.proofs).toEqual([
      expect.objectContaining({ kind: 'PICKUP', hasPhoto: true }),
    ]);
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/cancel`)
      .set(admin.auth)
      .send({ reason: 'Essai après enlèvement' })
      .expect(409);
  });

  it('réserve l’annulation au dispatch et exige une raison', async () => {
    const order = await placeOrder(ctx, shop);
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/cancel`)
      .set(support.auth)
      .send({ reason: 'Le support ne peut pas annuler' })
      .expect(403);
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/cancel`)
      .set(dispatcher.auth)
      .send({})
      .expect(400);
    const res = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/cancel`)
      .set(dispatcher.auth)
      .send({ reason: 'Doublon de commande' })
      .expect(200);
    expect(res.body).toMatchObject({ status: 'CANCELLED', cancelReason: 'Doublon de commande' });
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: order.id, action: 'order.transition' },
    });
    expect(audit).not.toBeNull();
  });

  it('reste fermé hors de l’équipe des opérations', async () => {
    const finance = await staffUser(ctx, ['FINANCE']);
    await list(finance, {}).expect(403);
    await request(ctx.http).get('/v1/admin/orders').set(shop.auth).expect(403);
    await request(ctx.http)
      .get('/v1/admin/orders/00000000-0000-4000-8000-000000000000')
      .set(admin.auth)
      .expect(404);
  });
});
