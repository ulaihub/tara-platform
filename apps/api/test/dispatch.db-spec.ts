import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { DispatchService } from '../src/dispatch/dispatch.service.js';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, resetPresence, type TestRider } from './helpers/riders.js';

const OPS_PHONE = '+237690000001';

describe('Attribution des courses (D1 à D4)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;
  let shop: TestMerchant;
  let dispatch: DispatchService;
  let push: FakePushProvider;

  beforeAll(async () => {
    ctx = await createTestApp({ OPS_ALERT_PHONES: OPS_PHONE });
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    dispatch = ctx.app.get(DispatchService);
    push = ctx.app.get<FakePushProvider>(PUSH_PROVIDER);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function onlineRider(offset: number, options = {}): Promise<TestRider> {
    const rider = await activeRider(ctx, options);
    await goOnline(ctx, rider, nearAkwa(offset));
    return rider;
  }

  async function pendingOffers(orderId: string) {
    return ctx.prisma.dispatchOffer.findMany({
      where: { orderId, outcome: 'PENDING' },
      orderBy: { approachMeters: 'asc' },
    });
  }

  it('refuse le passage en ligne d’un livreur aux pièces expirées (D4)', async () => {
    const rider = await activeRider(ctx, { expiredDocuments: true });
    const res = await request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: true, ...nearAkwa(0) })
      .expect(422);
    expect(res.body.error.code).toBe('RIDER_NOT_ELIGIBLE');
    const state = await request(ctx.http).get('/v1/rider/presence').set(rider.auth).expect(200);
    expect(state.body).toMatchObject({
      online: false,
      blockers: expect.arrayContaining(['DOCUMENT_NATIONAL_ID_FRONT']),
    });
  });

  it('propose la course au mieux placé, qui l’accepte (D1, D2)', async () => {
    const far = await onlineRider(0.02);
    const near = await onlineRider(0.002);
    const order = await placeOrder(ctx, shop);
    expect(order.status).toBe('SEARCHING_RIDER');

    const [offer, ...others] = await pendingOffers(order.id);
    expect(others).toHaveLength(0);
    expect(offer).toMatchObject({ riderId: near.riderId, round: 1 });
    // Notification sonore, même écran verrouillé (E1).
    expect(push.lastTo(near.pushToken)).toMatchObject({
      urgent: true,
      data: { type: 'offer.new', offerId: offer?.id },
    });
    expect(push.lastTo(far.pushToken)).toBeUndefined();

    const listed = await request(ctx.http).get('/v1/rider/offers').set(near.auth).expect(200);
    expect(listed.body).toHaveLength(1);
    expect(listed.body[0]).toMatchObject({ orderId: order.id, riderEarning: expect.any(Number) });
    expect(JSON.stringify(listed.body)).not.toContain(order.recipientPhone);
    // Zone de livraison seulement : ni repère ni coordonnées exactes du destinataire.
    expect(listed.body[0].dropoff).not.toHaveProperty('landmark');
    expect(listed.body[0].dropoff.latitude).toBe(Math.round(4.095 * 100) / 100);

    const accepted = await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(near.auth)
      .expect(200);
    expect(accepted.body).toMatchObject({
      status: 'ASSIGNED',
      recipient: { phone: order.recipientPhone },
      navigation: { googleMaps: expect.stringContaining('google.com/maps') },
    });
    const again = await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(near.auth)
      .expect(409);
    expect(again.body.error.code).toBe('OFFER_NO_LONGER_AVAILABLE');
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(stored).toMatchObject({
      status: 'ASSIGNED',
      riderId: near.riderId,
      searchingSince: null,
    });
  });

  it('passe au suivant après un refus ou un silence, puis diffuse après trois refus (D2)', async () => {
    const riders: TestRider[] = [];
    for (const offset of [0.001, 0.002, 0.003, 0.004, 0.005, 0.006])
      riders.push(await onlineRider(offset));
    const [r1, r2, r3, r4, r5, r6] = riders as [
      TestRider,
      TestRider,
      TestRider,
      TestRider,
      TestRider,
      TestRider,
    ];
    const order = await placeOrder(ctx, shop);

    // Tour 1 : refus immédiat, la course part aussitôt au suivant.
    const [first] = await pendingOffers(order.id);
    expect(first?.riderId).toBe(r1.riderId);
    await request(ctx.http).post(`/v1/rider/offers/${first?.id}/decline`).set(r1.auth).expect(204);

    // Tour 2 : pas de réponse dans le délai.
    const [second] = await pendingOffers(order.id);
    expect(second?.riderId).toBe(r2.riderId);
    await dispatch.runRound(order.id, new Date((second?.expiresAt.getTime() ?? 0) + 1));
    expect(
      await ctx.prisma.dispatchOffer.findUniqueOrThrow({ where: { id: second?.id ?? '' } }),
    ).toMatchObject({
      outcome: 'EXPIRED',
    });

    // Tour 3 : refus.
    const [third] = await pendingOffers(order.id);
    expect(third?.riderId).toBe(r3.riderId);
    await request(ctx.http).post(`/v1/rider/offers/${third?.id}/decline`).set(r3.auth).expect(204);

    // Tour 4 : diffusion simultanée aux livreurs qui n'ont ni refusé ni laissé passer.
    const broadcast = await pendingOffers(order.id);
    expect(broadcast.map((offer) => offer.riderId).sort()).toEqual(
      [r4.riderId, r5.riderId, r6.riderId].sort(),
    );
    expect(new Set(broadcast.map((offer) => offer.round)).size).toBe(1);

    const winner = broadcast.find((offer) => offer.riderId === r5.riderId);
    await request(ctx.http).post(`/v1/rider/offers/${winner?.id}/accept`).set(r5.auth).expect(200);
    const outcomes = await ctx.prisma.dispatchOffer.findMany({
      where: { orderId: order.id, round: winner?.round ?? 0 },
    });
    expect(outcomes.map((offer) => offer.outcome).sort()).toEqual([
      'ACCEPTED',
      'WITHDRAWN',
      'WITHDRAWN',
    ]);
    const late = broadcast.find((offer) => offer.riderId === r4.riderId);
    const res = await request(ctx.http)
      .post(`/v1/rider/offers/${late?.id}/accept`)
      .set(r4.auth)
      .expect(409);
    expect(res.body.error.code).toBe('OFFER_NO_LONGER_AVAILABLE');
  });

  it('écarte les pièces expirées et le solde prépayé insuffisant, et l’explique au dispatch (D4, G5)', async () => {
    const expired = await onlineRider(0.001);
    const broke = await onlineRider(0.002, { balance: 3_000 });
    const ok = await onlineRider(0.01);
    // Pièce expirée depuis le passage en ligne.
    await ctx.prisma.kycDocument.updateMany({
      where: { riderId: expired.riderId, type: 'DRIVING_LICENSE' },
      data: { expiresOn: new Date(Date.now() - 2 * 86_400_000) },
    });
    // 5 000 FCFA à encaisser + frais en espèces : au-delà de son solde de 3 000 FCFA.
    const order = await placeOrder(ctx, shop, { codAmount: 5_000 });

    const offers = await pendingOffers(order.id);
    expect(offers.map((offer) => offer.riderId)).toEqual([ok.riderId]);

    const candidates = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}/candidates`)
      .set(ops.auth)
      .expect(200);
    const byId = new Map(
      (candidates.body as { riderId: string; ineligibleBecause: string[] }[]).map((c) => [
        c.riderId,
        c,
      ]),
    );
    expect(byId.get(expired.riderId)?.ineligibleBecause).toEqual(['DOCUMENTS']);
    expect(byId.get(broke.riderId)?.ineligibleBecause).toEqual(['BALANCE_TOO_LOW']);
    expect(byId.get(ok.riderId)?.ineligibleBecause).toEqual(['PENDING_OFFER']);
  });

  it('un colis de valeur ne part pas avec un livreur sans expérience, et le dispatch voit pourquoi', async () => {
    const newcomer = await onlineRider(0.001);
    // 80 000 FCFA déclarés : au-delà de 25 000 FCFA, il faut 20 livraisons faites.
    const precious = await placeOrder(ctx, shop, { declaredValue: 80_000 });
    expect(await pendingOffers(precious.id)).toEqual([]);
    const candidates = await request(ctx.http)
      .get(`/v1/admin/orders/${precious.id}/candidates`)
      .set(ops.auth)
      .expect(200);
    const mine = (candidates.body as { riderId: string; ineligibleBecause: string[] }[]).find(
      (c) => c.riderId === newcomer.riderId,
    );
    expect(mine?.ineligibleBecause).toEqual(['PARCEL_VALUE']);

    // Un colis modeste lui est proposé.
    const modest = await placeOrder(ctx, shop, { declaredValue: 15_000 });
    expect((await pendingOffers(modest.id)).map((offer) => offer.riderId)).toEqual([
      newcomer.riderId,
    ]);
  });

  it('alerte le dispatch une seule fois après 5 minutes sans livreur (D2)', async () => {
    const order = await placeOrder(ctx, shop);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(stored.searchingSince).not.toBeNull();
    const later = new Date((stored.searchingSince?.getTime() ?? 0) + 301_000);
    expect(await dispatch.runRound(order.id, later)).toBe('none');
    await dispatch.runRound(order.id, new Date(later.getTime() + 60_000));

    const alerts = ctx.sms.outbox.filter(
      (sms) => sms.to === OPS_PHONE && sms.text.includes(order.reference),
    );
    expect(alerts).toHaveLength(1);
    expect(alerts[0]?.text).toContain('5 min');
    const state = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}/dispatch`)
      .set(ops.auth)
      .expect(200);
    expect(state.body).toMatchObject({ status: 'SEARCHING_RIDER', alerted: true, offers: [] });
  });

  it('attribue et réattribue à la main, avec trace et prévenance du livreur retiré (D3)', async () => {
    const first = await onlineRider(0.001);
    const second = await activeRider(ctx);
    const order = await placeOrder(ctx, shop);
    const [offer] = await pendingOffers(order.id);
    await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(first.auth)
      .expect(200);

    const res = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(ops.auth)
      .send({ riderId: second.riderId, note: 'Livreur en panne' })
      .expect(200);
    expect(res.body).toMatchObject({ status: 'ASSIGNED', riderId: second.riderId });
    const statuses = (res.body.timeline as { status: string }[]).map((event) => event.status);
    expect(statuses.slice(-3)).toEqual(['ASSIGNED', 'SEARCHING_RIDER', 'ASSIGNED']);
    expect(push.lastTo(first.pushToken)).toMatchObject({ data: { type: 'order.reassigned' } });
    await request(ctx.http).get(`/v1/rider/orders/${order.id}`).set(first.auth).expect(404);
    await request(ctx.http).get(`/v1/rider/orders/${order.id}`).set(second.auth).expect(200);
    expect(
      await ctx.prisma.auditLog.count({ where: { entityId: order.id, action: 'order.assign' } }),
    ).toBe(1);

    // Jamais un livreur aux pièces expirées, même à la main.
    const expired = await activeRider(ctx, { expiredDocuments: true });
    const refused = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(ops.auth)
      .send({ riderId: expired.riderId })
      .expect(422);
    expect(refused.body.error.code).toBe('RIDER_NOT_ELIGIBLE');

    // Le livreur n'est pas du back-office.
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(first.auth)
      .send({ riderId: first.riderId })
      .expect(403);
  });

  it('commande « créée » : programmée, le dispatch avance son départ ; non payée, il attend le paiement', async () => {
    const rider = await activeRider(ctx);
    const slot = new Date(Date.now() + 86_400_000);
    slot.setUTCHours(9, 0, 0, 0);
    const scheduled = await placeOrder(ctx, shop, { scheduledFor: slot.toISOString() });
    expect(scheduled.status).toBe('CREATED');
    const before = await request(ctx.http)
      .get(`/v1/admin/orders/${scheduled.id}`)
      .set(ops.auth)
      .expect(200);
    expect(before.body).toMatchObject({ waitingFor: 'SCHEDULE', can: { reassign: true } });
    const assigned = await request(ctx.http)
      .post(`/v1/admin/orders/${scheduled.id}/assign`)
      .set(ops.auth)
      .send({ riderId: rider.riderId })
      .expect(200);
    expect(assigned.body).toMatchObject({ status: 'ASSIGNED', riderId: rider.riderId });
    const statuses = (assigned.body.timeline as { status: string }[]).map((event) => event.status);
    expect(statuses).toEqual(['CREATED', 'SEARCHING_RIDER', 'ASSIGNED']);

    // Frais Mobile Money pas encore payés : ni livreur ni bouton « Confier ».
    const unpaid = await placeOrder(ctx, shop, { feePaymentMethod: 'MOMO_MTN' });
    expect(unpaid.status).toBe('CREATED');
    const waiting = await request(ctx.http)
      .get(`/v1/admin/orders/${unpaid.id}`)
      .set(ops.auth)
      .expect(200);
    expect(waiting.body).toMatchObject({
      waitingFor: 'PAYMENT',
      lastFeePayment: null,
      can: { reassign: false },
    });
    const refused = await request(ctx.http)
      .post(`/v1/admin/orders/${unpaid.id}/assign`)
      .set(ops.auth)
      .send({ riderId: rider.riderId })
      .expect(409);
    expect(refused.body.error.code).toBe('ORDER_AWAITING_PAYMENT');

    // La demande de paiement apparaît dans la fiche ; l'expéditeur voit les frais impayés.
    await request(ctx.http)
      .post(`/v1/orders/${unpaid.id}/pay`)
      .set(shop.auth)
      .send({ phone: shop.phone, operator: 'MTN' })
      .expect(201);
    const pending = await request(ctx.http)
      .get(`/v1/admin/orders/${unpaid.id}`)
      .set(ops.auth)
      .expect(200);
    expect(pending.body.lastFeePayment).toMatchObject({ status: expect.any(String) });
    const mine = await request(ctx.http).get(`/v1/orders/${unpaid.id}`).set(shop.auth).expect(200);
    expect(mine.body.pricing.feePaid).toBe(pending.body.price.feePaidAt !== null);
  });

  it('envoi de plusieurs colis : le livreur voit le numéro du sien, l’expéditeur sait lequel donner', async () => {
    const rider = await activeRider(ctx);
    // Le téléphone de la boutique reçoit les notifications.
    await request(ctx.http)
      .put(`/v1/me/devices/${shop.installationId}/push-token`)
      .set(shop.auth)
      .send({ pushToken: `push-${randomUUID()}-${randomUUID()}` })
      .expect(204);
    const item = (name: string, description: string) => ({
      dropoffAddressId: shop.dropoffId,
      recipientName: name,
      recipientPhone: '699 00 11 22',
      packageSize: 'S',
      packageContents: 'CLOTHING',
      packageDescription: description,
    });
    const batch = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .set('Idempotency-Key', randomUUID())
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'CASH',
        items: [item('Marie Ngo', 'Robe rouge'), item('Jean Mbarga', '2 paires de chaussures')],
      })
      .expect(201);
    const second = batch.body.orders[1] as { id: string; reference: string };
    await request(ctx.http)
      .post(`/v1/admin/orders/${second.id}/assign`)
      .set(ops.auth)
      .send({ riderId: rider.riderId })
      .expect(200);

    const active = await request(ctx.http).get('/v1/rider/orders').set(rider.auth).expect(200);
    const mine = (active.body.items as { id: string }[]).find((order) => order.id === second.id);
    expect(mine).toMatchObject({
      batchNumber: 2,
      packageDescription: '2 paires de chaussures',
      recipient: { name: 'Jean Mbarga' },
    });
    const admin = await request(ctx.http)
      .get(`/v1/admin/orders/${second.id}`)
      .set(ops.auth)
      .expect(200);
    expect(admin.body.parcel).toMatchObject({ batchNumber: 2, batchSize: 2 });

    const push = await ctx.prisma.notification.findFirstOrThrow({
      where: {
        userId: shop.userId,
        orderId: second.id,
        template: { startsWith: 'ORDER_ASSIGNED' },
      },
    });
    expect(push).toMatchObject({
      template: 'ORDER_ASSIGNED_BATCH',
      payload: { params: expect.objectContaining({ number: 2, recipient: 'Jean' }) },
    });
  });

  it('ne repropose pas une course au livreur qui l’a rendue', async () => {
    const first = await onlineRider(0.001);
    const second = await onlineRider(0.008);
    const order = await placeOrder(ctx, shop);
    const [offer] = await pendingOffers(order.id);
    expect(offer?.riderId).toBe(first.riderId);
    await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(first.auth)
      .expect(200);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/release`)
      .set(first.auth)
      .send({ reason: 'Crevaison' })
      .expect(204);
    const offers = await pendingOffers(order.id);
    expect(offers.map((o) => o.riderId)).toEqual([second.riderId]);
  });

  it('un livreur hors ligne ne reçoit plus de proposition et rend celle en cours', async () => {
    const rider = await onlineRider(0.001);
    const order = await placeOrder(ctx, shop);
    expect(await pendingOffers(order.id)).toHaveLength(1);
    await request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: false, ...nearAkwa(0.001) })
      .expect(200);
    expect(await pendingOffers(order.id)).toHaveLength(0);
    const declined = await ctx.prisma.dispatchOffer.count({
      where: { orderId: order.id, outcome: 'DECLINED' },
    });
    expect(declined).toBe(1);
  });

  it('lance la recherche d’une commande programmée avant son créneau', async () => {
    const slot = new Date(Date.now() + 86_400_000);
    slot.setUTCHours(9, 0, 0, 0);
    const order = await placeOrder(ctx, shop, { scheduledFor: slot.toISOString() });
    expect(order.status).toBe('CREATED');
    await dispatch.sweep(new Date(slot.getTime() - 30 * 60_000));
    expect((await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } })).status).toBe(
      'CREATED',
    );
    await dispatch.sweep(new Date(slot.getTime() - 15 * 60_000));
    expect((await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } })).status).toBe(
      'SEARCHING_RIDER',
    );
  });
});
