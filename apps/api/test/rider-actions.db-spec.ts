import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import { RealtimeService } from '../src/realtime/realtime.service.js';
import { OrderSupportService } from '../src/rider-app/order-support.service.js';
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
import { square } from './helpers/geo.js';
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
    const code = /le code au livreur : (\d{4})/.exec(text)?.[1];
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

  it('photo de façade et note vocale de l’adresse : pour le livreur de la course, pendant la course (B2)', async () => {
    const png = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      'base64',
    );
    const voice = Buffer.from('fausse note vocale AAC');
    const upload = async (kind: string, file: Buffer, filename: string, contentType: string) =>
      (
        await request(ctx.http)
          .post('/v1/media')
          .set(shop.auth)
          .field('kind', kind)
          .attach('file', file, { filename, contentType })
          .expect(201)
      ).body.key as string;
    const photoKey = await upload('ADDRESS_PHOTO', png, 'facade.png', 'image/png');
    const voiceNoteKey = await upload('VOICE_NOTE', voice, 'note.m4a', 'audio/mp4');
    const dropoff = await request(ctx.http)
      .post('/v1/addresses')
      .set(shop.auth)
      .send({ ...nearAkwa(0.004), landmark: 'Portail bleu', photoKey, voiceNoteKey })
      .expect(201);

    const { rider, order } = await assigned({ dropoffAddressId: dropoff.body.id });
    const base = `/v1/rider/orders/${order.id}/address-media`;
    const photo = await request(ctx.http)
      .get(`${base}/dropoff/photo`)
      .set(rider.auth)
      .buffer(true)
      .expect(200);
    expect(photo.headers['content-type']).toBe('image/png');
    expect(Buffer.compare(photo.body as Buffer, png)).toBe(0);
    const note = await request(ctx.http).get(`${base}/dropoff/voice`).set(rider.auth).expect(200);
    expect(note.headers['content-type']).toBe('audio/mp4');
    // Rien à l'enlèvement, mauvais type, autre livreur : introuvable.
    await request(ctx.http).get(`${base}/pickup/photo`).set(rider.auth).expect(404);
    await request(ctx.http).get(`${base}/dropoff/video`).set(rider.auth).expect(404);
    const other = await activeRider(ctx);
    await request(ctx.http).get(`${base}/dropoff/photo`).set(other.auth).expect(404);
  });

  it('livre avec le code du destinataire et une photo, puis compte les gains (E4, E9)', async () => {
    const { rider, order } = await assigned();
    // Suivi de l'expéditeur (F1) : prénom et initiale du livreur, son numéro pendant la course.
    const riderUser = await ctx.prisma.user.findUniqueOrThrow({ where: { id: rider.userId } });
    const tracked = await request(ctx.http)
      .get(`/v1/orders/${order.id}`)
      .set(shop.auth)
      .expect(200);
    expect(tracked.body.rider).toMatchObject({
      name: expect.stringMatching(/^\S+( \p{Lu}\.)?$/u),
      phone: riderUser.phone,
      vehicleType: 'MOTORBIKE',
    });
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
    // Livrée : l'expéditeur garde le nom pour le récapitulatif, plus le numéro.
    const done = await request(ctx.http).get(`/v1/orders/${order.id}`).set(shop.auth).expect(200);
    expect(done.body.rider).toMatchObject({ phone: null });

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
    expect(history.body.items[0].completedAt).toBe(history.body.items[0].deliveredAt);
  });

  it('notation réciproque après la livraison : une fois chacun, dans les 7 jours (F4)', async () => {
    const { rider, order } = await assigned();
    // Pas avant la fin de la course.
    const early = await request(ctx.http)
      .post(`/v1/orders/${order.id}/rating`)
      .set(shop.auth)
      .send({ score: 5 })
      .expect(422);
    expect(early.body.error.code).toBe('RATING_NOT_OPEN');
    await pickUp(rider, order);
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ deliveryCode: deliveryCodeFor(order), photoKey, ...HERE })
      .expect(200);

    // L'expéditeur note le livreur : la note entre dans son score d'attribution.
    await request(ctx.http)
      .post(`/v1/orders/${order.id}/rating`)
      .set(shop.auth)
      .send({ score: 6 })
      .expect(400);
    const given = await request(ctx.http)
      .post(`/v1/orders/${order.id}/rating`)
      .set(shop.auth)
      .send({ score: 4, comment: '  Rapide, mais sans prévenir de son arrivée.  ' })
      .expect(200);
    expect(given.body).toMatchObject({
      score: 4,
      comment: 'Rapide, mais sans prévenir de son arrivée.',
    });
    const profile = await ctx.prisma.riderProfile.findUniqueOrThrow({
      where: { id: rider.riderId },
    });
    expect(profile).toMatchObject({ ratingSum: 4, ratingCount: 1 });
    const again = await request(ctx.http)
      .post(`/v1/orders/${order.id}/rating`)
      .set(shop.auth)
      .send({ score: 1 })
      .expect(409);
    expect(again.body.error.code).toBe('RATING_ALREADY_GIVEN');
    const seen = await request(ctx.http).get(`/v1/orders/${order.id}`).set(shop.auth).expect(200);
    expect(seen.body.rating).toMatchObject({ score: 4 });

    // Le livreur note l'expéditeur ; personne d'autre ne peut noter cette course.
    const other = await activeRider(ctx);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/rating`)
      .set(other.auth)
      .send({ score: 5 })
      .expect(404);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/rating`)
      .set(rider.auth)
      .send({ score: 5 })
      .expect(200);
    const mine = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}`)
      .set(rider.auth)
      .expect(200);
    expect(mine.body.rating).toMatchObject({ score: 5, comment: null });
    expect(
      await ctx.prisma.rating.findFirst({ where: { orderId: order.id, rateeId: shop.userId } }),
    ).toMatchObject({ raterId: rider.userId, score: 5 });
    // L'expéditeur ne voit que sa propre note.
    const still = await request(ctx.http).get(`/v1/orders/${order.id}`).set(shop.auth).expect(200);
    expect(still.body.rating).toMatchObject({ score: 4 });

    // Au-delà de 7 jours, la course ne se note plus.
    await resetPresence();
    const late = await assigned();
    await pickUp(late.rider, late.order);
    const latePhoto = await proofPhoto(ctx, late.rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${late.order.id}/deliver`)
      .set(late.rider.auth)
      .send({ deliveryCode: deliveryCodeFor(late.order), photoKey: latePhoto, ...HERE })
      .expect(200);
    await ctx.prisma.order.update({
      where: { id: late.order.id },
      data: { deliveredAt: new Date(Date.now() - 8 * 86_400_000) },
    });
    await request(ctx.http)
      .post(`/v1/orders/${late.order.id}/rating`)
      .set(shop.auth)
      .send({ score: 5 })
      .expect(422);
  });

  it('page de suivi du destinataire : livreur à appeler, heure estimée, somme à payer (F2)', async () => {
    const { rider, order } = await assigned({ codAmount: 12_500, feePayer: 'RECIPIENT' });
    const placed = await request(ctx.http).get(`/v1/orders/${order.id}`).set(shop.auth).expect(200);
    const token = (placed.body.trackingUrl as string).split('/t/')[1];
    const total = placed.body.pricing.totalPrice as number;

    // Livreur trouvé, colis pas encore pris : son nom, pas encore son numéro.
    const before = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(before.body).toMatchObject({
      status: 'ASSIGNED',
      rider: { name: expect.any(String), vehicleType: 'MOTORBIKE', phone: null },
      eta: null,
      due: { fee: total, cod: 12_500, total: total + 12_500 },
      paymentPending: null,
    });

    // Colis à bord : numéro du livreur et heure estimée d'après sa dernière position.
    await pickUp(rider, order);
    const riderUser = await ctx.prisma.user.findUniqueOrThrow({ where: { id: rider.userId } });
    const coming = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(coming.body).toMatchObject({
      status: 'IN_DELIVERY',
      rider: { phone: riderUser.phone },
      eta: { minutes: expect.any(Number), distanceMeters: expect.any(Number) },
    });
    expect(coming.body.eta.minutes).toBeGreaterThanOrEqual(1);
    expect(coming.body.eta.progress).toBeGreaterThanOrEqual(0);
    expect(coming.body.eta.progress).toBeLessThanOrEqual(1);

    // Le livreur envoie la demande Mobile Money : la page invite à la valider.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/collect`)
      .set(rider.auth)
      .send({ method: 'MOBILE_MONEY', phone: '677001122', operator: 'MTN' })
      .expect(200);
    const asked = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(asked.body.paymentPending).toEqual({ amount: total + 12_500 });
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
      .send({ photoKey, receivedBy: 'Sa sœur, Brigitte', ...HERE })
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
    expect(proof).toMatchObject({
      codeVerified: false,
      supportValidatorId: admin.userId,
      receivedBy: 'Sa sœur, Brigitte',
    });
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
    // Colis enlevé il y a 10 min : les appels comptent à partir de là.
    await ctx.prisma.order.update({
      where: { id: order.id },
      data: { pickedUpAt: new Date(Date.now() - 10 * 60_000) },
    });
    // Client absent : deux appels au destinataire, à 5 min d'écart au moins.
    const call = (minutesAgo: number) => ({
      to: 'RECIPIENT',
      at: new Date(Date.now() - minutesAgo * 60_000).toISOString(),
      durationSeconds: 30,
    });
    const none = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'RECIPIENT_ABSENT', photoKey, callLog: [], ...HERE })
      .expect(422);
    expect(none.body.error.code).toBe('FAILURE_CALLS_REQUIRED');
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'RECIPIENT_UNREACHABLE', photoKey, callLog: [call(3), call(0)], ...HERE })
      .expect(422);
    // Journal du téléphone : un appel d'avant l'enlèvement ou dans le futur ne compte pas.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'RECIPIENT_ABSENT', photoKey, callLog: [call(30), call(0)], ...HERE })
      .expect(422);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'RECIPIENT_ABSENT', photoKey, callLog: [call(1), call(-10)], ...HERE })
      .expect(422);
    // Autre motif : un appel et une explication.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'OTHER', photoKey, callLog: [call(0)], ...HERE })
      .expect(400);
    // Refus sur place : pas d'appel exigé.
    const failed = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({
        reason: 'PAYMENT_REFUSED',
        photoKey,
        ...HERE,
      })
      .expect(200);
    expect(failed.body).toMatchObject({
      status: 'DELIVERY_FAILED',
      failureReason: 'PAYMENT_REFUSED',
    });
    expect(Date.parse(failed.body.failureDecisionDueAt) - Date.parse(failed.body.failedAt)).toBe(
      15 * 60_000,
    );
    const failure = await ctx.prisma.orderEvent.findFirstOrThrow({
      where: { orderId: order.id, toStatus: 'DELIVERY_FAILED' },
    });
    expect(failure.failureReason).toBe('PAYMENT_REFUSED');
    // Déclaré loin de l'adresse du destinataire : alerte au support.
    const far = await ctx.prisma.courseAlert.findFirst({
      where: { orderId: order.id, dedupeKey: 'ACTION_FAR:FAILURE' },
    });
    expect(far).not.toBeNull();

    // L'expéditeur voit le motif et l'heure limite de son choix.
    const asSender = await request(ctx.http)
      .get(`/v1/orders/${order.id}`)
      .set(shop.auth)
      .expect(200);
    expect(asSender.body.failure).toMatchObject({
      reason: 'PAYMENT_REFUSED',
      decision: null,
      decisionDueAt: failed.body.failureDecisionDueAt,
    });

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
    const decided = await request(ctx.http)
      .get(`/v1/orders/${order.id}`)
      .set(shop.auth)
      .expect(200);
    expect(decided.body.failure).toMatchObject({ decision: 'RETURN', decisionDueAt: null });
    const listed = await request(ctx.http)
      .get('/v1/orders?scope=active')
      .set(shop.auth)
      .expect(200);
    expect(listed.body.items.find((item: { id: string }) => item.id === order.id)).toMatchObject({
      status: 'DELIVERY_FAILED',
      failureDecision: 'RETURN',
    });
    // Un second choix n'est plus possible.
    await request(ctx.http)
      .post(`/v1/orders/${order.id}/failure-decision`)
      .set(shop.auth)
      .send({ decision: 'RETRY' })
      .expect(409);
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
    expect(returned.body.completedAt).not.toBeNull();
  });

  it('colis refusé car abîmé : photo, aucun appel exigé, réclamation ouverte pour l’expéditeur', async () => {
    const { rider, order } = await assigned();
    await pickUp(rider, order);
    const photoKey = await proofPhoto(ctx, rider);
    const failed = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/fail`)
      .set(rider.auth)
      .send({ reason: 'DAMAGED', note: 'Carton écrasé, liquide qui coule', photoKey, ...HERE })
      .expect(200);
    expect(failed.body).toMatchObject({ status: 'DELIVERY_FAILED', failureReason: 'DAMAGED' });
    const claims = await ctx.prisma.ticket.findMany({
      where: { orderId: order.id, category: 'DAMAGED_PARCEL' },
      include: { messages: true },
    });
    expect(claims).toHaveLength(1);
    const placed = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(claims[0]).toMatchObject({ priority: 'HIGH', requesterId: placed.senderId });
    expect(claims[0]?.messages[0]?.body).toContain('Carton écrasé');
  });

  it('échec sans réponse de l’expéditeur : retour automatique ; le support peut choisir à sa place (E6)', async () => {
    const call = (minutesAgo: number) => ({
      to: 'RECIPIENT',
      at: new Date(Date.now() - minutesAgo * 60_000).toISOString(),
      durationSeconds: 25,
    });
    const fail = async () => {
      const { rider, order } = await assigned();
      await pickUp(rider, order);
      await ctx.prisma.order.update({
        where: { id: order.id },
        data: { pickedUpAt: new Date(Date.now() - 10 * 60_000) },
      });
      const photoKey = await proofPhoto(ctx, rider);
      await request(ctx.http)
        .post(`/v1/rider/orders/${order.id}/fail`)
        .set(rider.auth)
        .send({ reason: 'RECIPIENT_ABSENT', photoKey, callLog: [call(6), call(0)], ...HERE })
        .expect(200);
      return { rider, order };
    };
    const support$ = ctx.app.get(OrderSupportService);

    const first = await fail();
    // Avant le délai : rien ne change.
    await support$.sweepFailures(new Date(Date.now() + 14 * 60_000));
    const waiting = await ctx.prisma.order.findUniqueOrThrow({ where: { id: first.order.id } });
    expect(waiting.failureDecision).toBeNull();
    const live = vi.spyOn(ctx.app.get(RealtimeService), 'toUser');
    await support$.sweepFailures(new Date(Date.now() + 16 * 60_000));
    // L'accueil de l'expéditeur l'apprend en direct.
    expect(live).toHaveBeenCalledWith(
      shop.userId,
      'order.status',
      expect.objectContaining({ orderId: first.order.id, failureDecision: 'RETURN' }),
    );
    live.mockRestore();
    const back = await request(ctx.http)
      .get(`/v1/rider/orders/${first.order.id}`)
      .set(first.rider.auth)
      .expect(200);
    expect(back.body).toMatchObject({ failureDecision: 'RETURN', failureDecisionDueAt: null });
    expect(push.lastTo(first.rider.pushToken)).toMatchObject({
      data: { type: 'order.failure-decision', decision: 'RETURN' },
    });

    // Le support choisit à la place de l'expéditeur ; le retour automatique ne le remplace pas.
    const second = await fail();
    await request(ctx.http)
      .post(`/v1/admin/orders/${second.order.id}/failure-decision`)
      .set(first.rider.auth)
      .send({ decision: 'RETRY' })
      .expect(403);
    await request(ctx.http)
      .post(`/v1/admin/orders/${second.order.id}/failure-decision`)
      .set(support.auth)
      .send({ decision: 'RETRY' })
      .expect(204);
    await support$.sweepFailures(new Date(Date.now() + 16 * 60_000));
    const kept = await ctx.prisma.order.findUniqueOrThrow({ where: { id: second.order.id } });
    expect(kept.failureDecision).toBe('RETRY');
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: second.order.id, action: 'order.failure-decision' },
    });
    expect(audit).not.toBeNull();
    await request(ctx.http)
      .post(`/v1/rider/orders/${second.order.id}/retry`)
      .set(second.rider.auth)
      .send(HERE)
      .expect(200);
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

  it('trace l’itinéraire vers la prochaine étape, sans révéler la course aux autres (E2)', async () => {
    const { rider, order } = await assigned();
    const position = { latitude: HERE.latitude, longitude: HERE.longitude };
    const toPickup = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}/route`)
      .query(position)
      .set(rider.auth)
      .expect(200);
    const detail = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}`)
      .set(rider.auth)
      .expect(200);
    const pickup = detail.body.pickup as { latitude: number; longitude: number };
    // Sans OSRM en test : ligne droite de la position du livreur au vendeur.
    expect(toPickup.body).toMatchObject({ stop: 'PICKUP', source: 'estimate' });
    expect(toPickup.body.path).toEqual([
      [position.longitude, position.latitude],
      [pickup.longitude, pickup.latitude],
    ]);
    expect(toPickup.body.meters).toBeGreaterThan(0);

    await pickUp(rider, order);
    const toDropoff = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}/route`)
      .query(position)
      .set(rider.auth)
      .expect(200);
    expect(toDropoff.body.stop).toBe('DROPOFF');

    const other = await activeRider(ctx);
    await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}/route`)
      .query(position)
      .set(other.auth)
      .expect(404);
    await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}/route`)
      .query({ latitude: 'abc', longitude: 9.7 })
      .set(rider.auth)
      .expect(400);
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
      failurePolicy: { minCalls: 2, callSpacingMinutes: 5, decisionTimeoutMinutes: 15 },
      emergencyNumbers: { police: '117', fire: '118', medical: '119' },
      mobileMoneyOperators: [
        { code: 'MTN', name: 'MTN MoMo' },
        { code: 'ORANGE', name: 'Orange Money' },
      ],
      offerTimeoutSeconds: 30,
      mobileMoneyFeeBps: 0,
      waiting: { freeMinutes: 10, stepMinutes: 5, feePerStep: 100, riderPercent: 70 },
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

  it('alerte : plaque et quartier pour l’équipe, renvoi sans doublon, police appelée par l’agent (E8)', async () => {
    const rider = await activeRider(ctx);
    await ctx.prisma.riderProfile.update({
      where: { id: rider.riderId },
      data: { plateNumber: 'LT 482 AB' },
    });
    const suffix = randomUUID().slice(0, 8);
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: `Akwa SOS ${suffix}`,
        city: 'Douala',
        kind: 'NEIGHBORHOOD',
        geometry: square(HERE, 0.0002),
      })
      .expect(201);
    const body = { ...HERE, accuracy: 8, clientEventId: `sos-${suffix}` };

    const first = await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(rider.auth)
      .send(body)
      .expect(201);
    expect(first.body).toMatchObject({
      riderPlate: 'LT 482 AB',
      accuracy: 8,
      policeCalledAt: null,
    });
    expect(first.body.neighborhood).toMatch(/^Akwa SOS /);
    const sms = ctx.sms.lastTo(OPS_PHONE)?.text ?? '';
    expect(sms).toContain('moto LT 482 AB');
    expect(sms).toContain('Quartier : Akwa SOS');

    // Renvoyée au retour du réseau : la même alerte, sans nouveau SMS à l'équipe.
    const smsCount = ctx.sms.outbox.length;
    const again = await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(rider.auth)
      .send(body)
      .expect(201);
    expect(again.body.id).toBe(first.body.id);
    expect(ctx.sms.outbox.length).toBe(smsCount);
    // Nouvel appui pendant que l'alerte est ouverte : la même, sans nouvelle salve de SMS.
    const pressed = await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(rider.auth)
      .send({ ...body, clientEventId: `sos-bis-${suffix}` })
      .expect(201);
    expect(pressed.body.id).toBe(first.body.id);
    expect(ctx.sms.outbox.length).toBe(smsCount);

    // Livreur injoignable : l'agent appelle la police ; heure, agent et note gardés, action tracée.
    await request(ctx.http)
      .post(`/v1/admin/safety-alerts/${first.body.id}/police-called`)
      .set(rider.auth)
      .send({ note: 'Appel au 117' })
      .expect(403);
    const called = await request(ctx.http)
      .post(`/v1/admin/safety-alerts/${first.body.id}/police-called`)
      .set(support.auth)
      .send({ note: 'Livreur injoignable, 117 prévenu avec position et plaque' })
      .expect(200);
    expect(called.body.policeCalledAt).not.toBeNull();
    expect(called.body.acknowledgedAt).not.toBeNull();
    const stored = await ctx.prisma.safetyAlert.findUniqueOrThrow({ where: { id: first.body.id } });
    expect(stored.policeCalledById).toBe(support.userId);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: first.body.id, action: 'safety-alert.police-called' },
    });
    expect(audit).not.toBeNull();

    await request(ctx.http)
      .post(`/v1/admin/safety-alerts/${first.body.id}/resolve`)
      .set(support.auth)
      .send({ resolution: 'Police sur place, livreur en sécurité' })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/admin/safety-alerts/${first.body.id}/police-called`)
      .set(support.auth)
      .send({ note: 'Encore' })
      .expect(409);
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
