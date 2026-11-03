import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  type PlacedOrder,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import {
  activeRider,
  goOnline,
  proofPhoto,
  resetPresence,
  type TestRider,
} from './helpers/riders.js';

const OPS_PHONE = '+237690000002';
const HERE = nearAkwa(0.001);

describe('Actions du livreur (E2 à E9)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let support: SignedIn;
  let shop: TestMerchant;
  let push: FakePushProvider;

  beforeAll(async () => {
    ctx = await createTestApp({ OPS_ALERT_PHONES: OPS_PHONE, SUPPORT_VALIDATION_LIMIT: '3000' });
    admin = await staffUser(ctx, ['ADMIN']);
    support = await staffUser(ctx, ['SUPPORT']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    push = ctx.app.get<FakePushProvider>(PUSH_PROVIDER);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  /** Commande attribuée à un livreur qui vient de l'accepter. */
  async function assigned(
    extra: Record<string, unknown> = {},
  ): Promise<{ rider: TestRider; order: PlacedOrder }> {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, HERE);
    const order = await placeOrder(ctx, shop, extra);
    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: order.id, riderId: rider.riderId },
    });
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    return { rider, order };
  }

  function deliveryCodeFor(order: PlacedOrder): string {
    const text = ctx.sms.lastTo(order.recipientPhone)?.text ?? '';
    const code = /donner au livreur : (\d{4})/.exec(text)?.[1];
    if (!code) throw new Error(`Pas de code de livraison pour ${order.reference}`);
    return code;
  }

  async function pickUp(rider: TestRider, order: PlacedOrder): Promise<void> {
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...HERE })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/depart`)
      .set(rider.auth)
      .send(HERE)
      .expect(200);
  }

  it('bloque le code d’enlèvement après 5 erreurs, jusqu’à un nouveau code de l’expéditeur (E3)', async () => {
    const { rider, order } = await assigned();
    const photoKey = await proofPhoto(ctx, rider);
    const wrong = order.pickupCode === '0000' ? '1111' : '0000';
    for (let remaining = 4; remaining >= 1; remaining -= 1) {
      const res = await request(ctx.http)
        .post(`/v1/rider/orders/${order.id}/pickup`)
        .set(rider.auth)
        .send({ pickupCode: wrong, photoKey, ...HERE })
        .expect(422);
      expect(res.body.error).toMatchObject({
        code: 'PICKUP_CODE_INVALID',
        message: expect.stringContaining(String(remaining)),
      });
    }
    const fifth = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: wrong, photoKey, ...HERE })
      .expect(422);
    expect(fifth.body.error.code).toBe('PICKUP_CODE_LOCKED');
    // Même le bon code est refusé une fois le code bloqué.
    const locked = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...HERE })
      .expect(422);
    expect(locked.body.error.code).toBe('PICKUP_CODE_LOCKED');

    const fresh = await request(ctx.http)
      .post(`/v1/orders/${order.id}/pickup-code`)
      .set(shop.auth)
      .expect(200);
    const clientEventId = randomUUID();
    const picked = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: fresh.body.pickupCode, photoKey, clientEventId, ...HERE })
      .expect(200);
    expect(picked.body.status).toBe('PICKED_UP');
    expect(deliveryCodeFor(order)).toMatch(/^\d{4}$/);

    // Synchronisation rejouée (E7) : rien de plus n'est enregistré.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: fresh.body.pickupCode, photoKey, clientEventId, ...HERE })
      .expect(200);
    expect(
      await ctx.prisma.deliveryProof.count({ where: { orderId: order.id, kind: 'PICKUP' } }),
    ).toBe(1);
    expect(
      await ctx.prisma.orderEvent.count({ where: { orderId: order.id, toStatus: 'PICKED_UP' } }),
    ).toBe(1);
  });

  it('livre avec le code du destinataire et une photo, puis compte les gains (E4, E9)', async () => {
    const { rider, order } = await assigned();
    await pickUp(rider, order);
    const code = deliveryCodeFor(order);
    const photoKey = await proofPhoto(ctx, rider);
    const wrong = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ deliveryCode: code === '0000' ? '1111' : '0000', photoKey, ...HERE })
      .expect(422);
    expect(wrong.body.error.code).toBe('DELIVERY_CODE_INVALID');

    const delivered = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ deliveryCode: code, photoKey, ...HERE })
      .expect(200);
    // Course terminée : les contacts ne sont plus visibles.
    expect(delivered.body).toMatchObject({
      status: 'DELIVERED',
      recipient: { phone: null },
      navigation: null,
    });
    expect(ctx.sms.lastTo(order.recipientPhone)?.text).toContain('a ete livre');

    const earnings = await request(ctx.http)
      .get('/v1/rider/earnings?period=day')
      .set(rider.auth)
      .expect(200);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(earnings.body).toMatchObject({
      delivered: 1,
      earnings: stored.riderEarning,
      bucket: 'two_hours',
    });
    // L'histogramme répartit exactement le total de la période.
    expect(earnings.body.series).toHaveLength(8);
    const series = earnings.body.series as { earnings: number; delivered: number }[];
    expect(series.reduce((sum, bucket) => sum + bucket.earnings, 0)).toBe(stored.riderEarning);
    expect(series.reduce((sum, bucket) => sum + bucket.delivered, 0)).toBe(1);
    // En ligne depuis le début du test : du temps compté, et pas plus que la durée écoulée.
    expect(earnings.body.onlineSeconds).toBeGreaterThanOrEqual(0);
    expect(earnings.body.onlineSeconds).toBeLessThan(600);
    const week = await request(ctx.http)
      .get('/v1/rider/earnings?period=week')
      .set(rider.auth)
      .expect(200);
    expect(week.body).toMatchObject({ bucket: 'day', earnings: stored.riderEarning });
    expect(week.body.series).toHaveLength(7);
    const history = await request(ctx.http)
      .get('/v1/rider/orders?scope=history')
      .set(rider.auth)
      .expect(200);
    expect(history.body.items.map((item: { id: string }) => item.id)).toEqual([order.id]);
  });

  it('sans code, le support valide après appel ; au-delà du plafond, un administrateur (E4)', async () => {
    const { rider, order } = await assigned({ codAmount: 5_000 });
    await pickUp(rider, order);
    const photoKey = await proofPhoto(ctx, rider);
    const unpaid = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ photoKey, ...HERE })
      .expect(409);
    expect(unpaid.body.error.code).toBe('COLLECTION_REQUIRED');
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(200);
    const pending = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ photoKey, ...HERE })
      .expect(200);
    expect(pending.body).toMatchObject({ status: 'IN_DELIVERY', awaitingSupportValidation: true });

    const refused = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/validate-delivery`)
      .set(support.auth)
      .send({ note: 'Destinataire joint, colis bien reçu' })
      .expect(403);
    expect(refused.body.error.code).toBe('DELIVERY_VALIDATION_ADMIN_REQUIRED');
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/validate-delivery`)
      .set(admin.auth)
      .send({ note: 'Destinataire joint, colis bien reçu' })
      .expect(204);
    const proof = await ctx.prisma.deliveryProof.findFirstOrThrow({
      where: { orderId: order.id, kind: 'DELIVERY' },
    });
    expect(proof).toMatchObject({ codeVerified: false, supportValidatorId: admin.userId });
    expect((await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } })).status).toBe(
      'DELIVERED',
    );
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/validate-delivery`)
      .set(admin.auth)
      .send({ note: 'Deuxième fois' })
      .expect(409);
  });

  it('échec avec motif et appels, choix de l’expéditeur, retour avec son code (E6)', async () => {
    const { rider, order } = await assigned();
    await pickUp(rider, order);
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'RECIPIENT_ABSENT', photoKey, callLog: [], ...HERE })
      .expect(400);
    const failed = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({
        reason: 'PAYMENT_REFUSED',
        photoKey,
        callLog: [{ to: 'RECIPIENT', at: new Date().toISOString(), durationSeconds: 0 }],
        ...HERE,
      })
      .expect(200);
    expect(failed.body.status).toBe('DELIVERY_FAILED');
    const failure = await ctx.prisma.orderEvent.findFirstOrThrow({
      where: { orderId: order.id, toStatus: 'DELIVERY_FAILED' },
    });
    expect(failure.failureReason).toBe('PAYMENT_REFUSED');

    await request(ctx.http)
      .post(`/v1/orders/${order.id}/failure-decision`)
      .set(shop.auth)
      .send({ decision: 'RETURN' })
      .expect(204);
    expect(push.lastTo(rider.pushToken)).toMatchObject({
      data: { type: 'order.failure-decision', decision: 'RETURN' },
    });
    const seen = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}`)
      .set(rider.auth)
      .expect(200);
    expect(seen.body).toMatchObject({ failureDecision: 'RETURN' });
    expect(seen.body.navigation.waze).toContain(`${seen.body.pickup.latitude}`);

    // Le code d'enlèvement, connu du livreur, ne vaut pas pour le retour : un code neuf
    // est envoyé à l'expéditeur seul.
    const reused = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/return`)
      .set(rider.auth)
      .send({ senderCode: order.pickupCode, ...HERE });
    const returnCode = /colis : (\d{4})/.exec(ctx.sms.lastTo(shop.phone)?.text ?? '')?.[1];
    expect(returnCode).toMatch(/^\d{4}$/);
    if (returnCode !== order.pickupCode) {
      expect(reused.status).toBe(422);
      expect(reused.body.error.code).toBe('PICKUP_CODE_INVALID');
    }
    const stored = await ctx.prisma.notification.findFirstOrThrow({
      where: { orderId: order.id, template: 'RETURN_CODE' },
    });
    expect(JSON.stringify(stored.payload)).not.toContain(returnCode);
    const returned = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/return`)
      .set(rider.auth)
      .send({ senderCode: returnCode, ...HERE })
      .expect(200);
    expect(returned.body.status).toBe('RETURNED');
  });

  it('garde l’heure d’une action faite hors ligne et refuse une heure dans le futur (E7)', async () => {
    const { rider, order } = await assigned();
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...HERE })
      .expect(200);
    const future = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/depart`)
      .set(rider.auth)
      .send({ ...HERE, occurredAt: new Date(Date.now() + 3_600_000).toISOString() })
      .expect(400);
    expect(future.body.error.code).toBe('ACTION_TIME_INVALID');
    const offlineAt = new Date(Date.now() - 10 * 60_000);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/depart`)
      .set(rider.auth)
      .send({ ...HERE, occurredAt: offlineAt.toISOString(), clientEventId: randomUUID() })
      .expect(200);
    const event = await ctx.prisma.orderEvent.findFirstOrThrow({
      where: { orderId: order.id, toStatus: 'IN_DELIVERY' },
    });
    expect(event.occurredAt.toISOString()).toBe(offlineAt.toISOString());
  });

  it('cache les courses des autres livreurs et réserve les photos de preuve aux livreurs', async () => {
    const { order } = await assigned();
    const other = await activeRider(ctx);
    await request(ctx.http).get(`/v1/rider/orders/${order.id}`).set(other.auth).expect(404);
    const photoKey = await proofPhoto(ctx, other);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(other.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...HERE })
      .expect(404);
    const customer = await signIn(ctx);
    await request(ctx.http).get('/v1/rider/offers').set(customer.auth).expect(403);
    await request(ctx.http)
      .post('/v1/media')
      .set(customer.auth)
      .field('kind', 'PROOF_PHOTO')
      .attach('file', Buffer.from('ffd8ffe000104a464946', 'hex'), {
        filename: 'x.jpg',
        contentType: 'image/jpeg',
      })
      .expect(403);
  });

  it('donne à l’app ses réglages : ligne de secours, opérateurs, délai des propositions', async () => {
    const rider = await activeRider(ctx);
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/rider/config')
      .set(rider.auth)
      .expect(200);
    expect(res.body).toEqual({
      country: { code: 'CM', dialCode: '+237', currency: 'XAF' },
      safetyHotline: '+237640114064',
      supportPhone: null,
      mobileMoneyOperators: [
        { code: 'MTN', name: 'MTN Mobile Money' },
        { code: 'ORANGE', name: 'Orange Money' },
      ],
      offerTimeoutSeconds: 30,
    });
    await request(ctx.app.getHttpServer()).get('/v1/rider/config').expect(401);
  });

  it('envoie l’alerte de sécurité au dispatch et aux numéros d’astreinte (E8)', async () => {
    const { rider, order } = await assigned();
    const res = await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(rider.auth)
      .send({ ...HERE, orderId: order.id, note: 'Agression' })
      .expect(201);
    expect(res.body).toMatchObject({ riderId: rider.riderId, orderId: order.id, resolvedAt: null });
    expect(ctx.sms.lastTo(OPS_PHONE)?.text).toContain('maps.google.com');

    const open = await request(ctx.http)
      .get('/v1/admin/safety-alerts')
      .set(support.auth)
      .expect(200);
    expect(open.body.map((alert: { id: string }) => alert.id)).toContain(res.body.id);
    await request(ctx.http)
      .post(`/v1/admin/safety-alerts/${res.body.id}/resolve`)
      .set(support.auth)
      .send({ resolution: 'Livreur rappelé, en sécurité' })
      .expect(200);
    const after = await request(ctx.http)
      .get('/v1/admin/safety-alerts')
      .set(support.auth)
      .expect(200);
    expect(after.body.map((alert: { id: string }) => alert.id)).not.toContain(res.body.id);
  });

  it('prévient le contact d’urgence ; une alerte annulée reste ouverte au dispatch (E8)', async () => {
    const rider = await activeRider(ctx);
    const contact = `+2376${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
    await request(ctx.http)
      .put('/v1/riders/me/emergency-contact')
      .set(rider.auth)
      .send({ name: 'Mama', phone: rider.phone })
      .expect(422);
    const profile = await request(ctx.http)
      .put('/v1/riders/me/emergency-contact')
      .set(rider.auth)
      .send({ name: 'Mama Ngo', phone: contact })
      .expect(200);
    expect(profile.body.emergencyContact).toEqual({ name: 'Mama Ngo', phone: contact });

    const alert = await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(rider.auth)
      .send(HERE)
      .expect(201);
    expect(ctx.sms.lastTo(contact)?.text).toContain('maps.google.com');

    // Un autre livreur ne peut pas annuler l'alerte.
    const other = await activeRider(ctx);
    await request(ctx.http)
      .post(`/v1/rider/alerts/${alert.body.id}/cancel`)
      .set(other.auth)
      .expect(404);
    const cancelled = await request(ctx.http)
      .post(`/v1/rider/alerts/${alert.body.id}/cancel`)
      .set(rider.auth)
      .expect(200);
    expect(cancelled.body.cancelledAt).not.toBeNull();
    expect(ctx.sms.lastTo(OPS_PHONE)?.text).toContain('annule son alerte');
    expect(ctx.sms.lastTo(contact)?.text).toContain('annule son alerte');
    await request(ctx.http)
      .post(`/v1/rider/alerts/${alert.body.id}/cancel`)
      .set(rider.auth)
      .expect(409);
    // Toujours visible du dispatch, qui rappelle le livreur avant de clore.
    const open = await request(ctx.http)
      .get('/v1/admin/safety-alerts')
      .set(support.auth)
      .expect(200);
    expect(open.body.find((item: { id: string }) => item.id === alert.body.id)).toMatchObject({
      cancelledAt: cancelled.body.cancelledAt,
      resolvedAt: null,
    });

    const removed = await request(ctx.http)
      .delete('/v1/riders/me/emergency-contact')
      .set(rider.auth)
      .expect(200);
    expect(removed.body.emergencyContact).toBeNull();
  });

  it('liste les pièces exigées, avec les alternatives et la date d’expiration demandée', async () => {
    const rider = await activeRider(ctx);
    const res = await request(ctx.http).get('/v1/riders/requirements').set(rider.auth).expect(200);
    const vehicle = res.body.find((group: { types: { type: string }[] }) =>
      group.types.some((item) => item.type === 'VEHICLE_REGISTRATION'),
    );
    expect(vehicle.types.map((item: { type: string }) => item.type)).toEqual([
      'VEHICLE_REGISTRATION',
      'VEHICLE_RENTAL_CONTRACT',
    ]);
    const licence = res.body.find(
      (group: { types: { type: string }[] }) => group.types[0]?.type === 'DRIVING_LICENSE',
    );
    expect(licence.types[0]).toMatchObject({
      asksExpiry: true,
      label: { fr: 'Permis de conduire', en: 'Driving licence' },
    });
  });
});
