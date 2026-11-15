import request from 'supertest';
import {
  createTestApp,
  randomPhone,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { merchant, placeOrder, setupDouala, type TestMerchant } from './helpers/orders.js';
import { activeRider, proofPhoto } from './helpers/riders.js';

/**
 * Service client (H6) : demandes ouvertes depuis les apps ou après un appel, réponses et
 * notes internes, prise en charge, et preuves d'une commande pour trancher un litige.
 */
describe('Service client (H6)', () => {
  let ctx: TestContext;
  let agent: SignedIn;
  let shop: TestMerchant;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    agent = await staffUser(ctx, ['SUPPORT']);
    await ctx.prisma.user.update({
      where: { id: agent.userId },
      data: { fullName: 'Nadège Support' },
    });
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const open = (session: SignedIn, body: Record<string, unknown>) =>
    request(ctx.http).post('/v1/support/tickets').set(session.auth).send(body);

  it('l’expéditeur ouvre une demande sur sa commande ; l’équipe la voit en tête de file', async () => {
    const placed = await placeOrder(ctx, shop);
    const created = await open(shop, {
      category: 'LOST_PARCEL',
      subject: 'Colis non reçu',
      message: 'Ma cliente dit ne rien avoir reçu.',
      orderId: placed.id,
    }).expect(201);
    expect(created.body).toMatchObject({
      reference: expect.stringMatching(/^SUP-\d+$/),
      status: 'OPEN',
      order: { id: placed.id, reference: placed.reference },
      messages: [{ fromTara: false, body: 'Ma cliente dit ne rien avoir reçu.' }],
    });

    // La commande de quelqu'un d'autre n'est pas accessible.
    const stranger = await signIn(ctx);
    await open(stranger, {
      category: 'OTHER',
      subject: 'Curiosité',
      message: 'Je veux voir cette commande.',
      orderId: placed.id,
    }).expect(404);

    const queue = await request(ctx.http)
      .get('/v1/admin/support/tickets')
      .set(agent.auth)
      .expect(200);
    const row = queue.body.items.find((t: { id: string }) => t.id === created.body.id);
    expect(row).toMatchObject({
      priority: 'HIGH',
      status: 'OPEN',
      fromApp: true,
      awaitingReply: true,
      assignee: null,
      requester: { kind: 'MERCHANT', phone: shop.phone },
    });
    expect(queue.body.counts.TO_HANDLE).toBeGreaterThanOrEqual(1);

    for (const q of [created.body.reference, placed.reference, shop.phone.slice(-6)]) {
      const found = await request(ctx.http)
        .get('/v1/admin/support/tickets')
        .query({ view: 'ALL', q })
        .set(agent.auth)
        .expect(200);
      expect(found.body.items.map((t: { id: string }) => t.id)).toContain(created.body.id);
    }

    // Le dispatch ne voit pas la file du support ; un client non plus.
    const dispatch = await staffUser(ctx, ['DISPATCHER']);
    await request(ctx.http).get('/v1/admin/support/tickets').set(dispatch.auth).expect(403);
    await request(ctx.http).get('/v1/admin/support/tickets').set(shop.auth).expect(403);
  });

  it('réponse visible et prévenue, note interne cachée ; résolue puis rouverte par le client', async () => {
    const customer = await signIn(ctx);
    const created = await open(customer, {
      category: 'PAYMENT',
      subject: 'Paiement prélevé deux fois',
      message: 'J’ai été débité deux fois pour la même course.',
    }).expect(201);
    const id = created.body.id as string;

    await request(ctx.http)
      .post(`/v1/admin/support/tickets/${id}/messages`)
      .set(agent.auth)
      .send({ body: 'Vérifier le relevé Sebpay du 12/11.', internal: true })
      .expect(200);
    const answered = await request(ctx.http)
      .post(`/v1/admin/support/tickets/${id}/messages`)
      .set(agent.auth)
      .send({ body: 'Bonjour, le second paiement vous est remboursé sur votre solde Tara.' })
      .expect(200);
    expect(answered.body).toMatchObject({
      requesterHasApp: false,
      status: 'IN_PROGRESS',
      assignee: { id: agent.userId, name: 'Nadège Support' },
      awaitingReply: false,
    });
    expect(answered.body.messages.map((m: { internal: boolean }) => m.internal)).toEqual([
      false,
      true,
      false,
    ]);

    // Sans téléphone enregistré pour les notifications : la réponse part par SMS.
    const sms = await ctx.prisma.notification.findFirstOrThrow({
      where: { recipientPhone: customer.phone, template: 'SUPPORT_REPLY', channel: 'SMS' },
    });
    expect(sms.payload).toMatchObject({ params: { reference: created.body.reference } });

    const seen = await request(ctx.http)
      .get(`/v1/support/tickets/${id}`)
      .set(customer.auth)
      .expect(200);
    expect(seen.body.messages).toEqual([
      expect.objectContaining({ fromTara: false }),
      expect.objectContaining({
        fromTara: true,
        body: 'Bonjour, le second paiement vous est remboursé sur votre solde Tara.',
      }),
    ]);

    const resolved = await request(ctx.http)
      .patch(`/v1/admin/support/tickets/${id}`)
      .set(agent.auth)
      .send({ status: 'RESOLVED' })
      .expect(200);
    expect(resolved.body.resolvedAt).toEqual(expect.any(String));

    // Le client répond : la demande est rouverte et attend Tara.
    const reopened = await request(ctx.http)
      .post(`/v1/support/tickets/${id}/messages`)
      .set(customer.auth)
      .send({ body: 'Je ne vois pas encore le remboursement.' })
      .expect(200);
    expect(reopened.body.status).toBe('OPEN');
    const row = await request(ctx.http)
      .get(`/v1/admin/support/tickets/${id}`)
      .set(agent.auth)
      .expect(200);
    expect(row.body).toMatchObject({ awaitingReply: true, resolvedAt: null });

    await request(ctx.http)
      .patch(`/v1/admin/support/tickets/${id}`)
      .set(agent.auth)
      .send({ status: 'CLOSED' })
      .expect(200);
    const closed = await request(ctx.http)
      .post(`/v1/support/tickets/${id}/messages`)
      .set(customer.auth)
      .send({ body: 'Encore moi.' })
      .expect(409);
    expect(closed.body.error.code).toBe('TICKET_CLOSED');

    // Seule une personne de l'équipe peut suivre une demande.
    await request(ctx.http)
      .patch(`/v1/admin/support/tickets/${id}`)
      .set(agent.auth)
      .send({ assigneeId: customer.userId })
      .expect(400);

    // L'export de ses données contient la demande, sans la note interne.
    const exported = await request(ctx.http).get('/v1/me/export').set(customer.auth).expect(200);
    const support = exported.body.supportRequests[0];
    expect(support).toMatchObject({ reference: created.body.reference, status: 'CLOSED' });
    expect(JSON.stringify(support)).not.toContain('Sebpay');
  });

  it('demande ouverte après un appel : par numéro (même sans compte) ou par commande', async () => {
    const caller = randomPhone();
    const byPhone = await request(ctx.http)
      .post('/v1/admin/support/tickets')
      .set(agent.auth)
      .send({
        phone: caller,
        category: 'RIDER_BEHAVIOR',
        priority: 'URGENT',
        subject: 'Livreur impoli à la porte',
        message: 'La destinataire appelle : le livreur a haussé le ton.',
      })
      .expect(201);
    expect(byPhone.body).toMatchObject({
      requester: { id: null, kind: 'NO_ACCOUNT', phone: caller },
      assignee: { id: agent.userId },
      fromApp: false,
      priority: 'URGENT',
    });

    const placed = await placeOrder(ctx, shop);
    const byOrder = await request(ctx.http)
      .post('/v1/admin/support/tickets')
      .set(agent.auth)
      .send({
        orderReference: placed.reference.replace('TR-', ''),
        category: 'LATE_DELIVERY',
        subject: 'Retard signalé par téléphone',
        message: 'La boutique appelle pour un retard.',
      })
      .expect(201);
    expect(byOrder.body).toMatchObject({
      requester: { id: shop.userId, kind: 'MERCHANT' },
      order: { reference: placed.reference },
    });
    // La boutique retrouve la demande dans son app.
    const mine = await request(ctx.http).get('/v1/support/tickets').set(shop.auth).expect(200);
    expect(mine.body.map((t: { id: string }) => t.id)).toContain(byOrder.body.id);

    const urgent = await request(ctx.http)
      .get('/v1/admin/support/tickets?view=URGENT')
      .set(agent.auth)
      .expect(200);
    expect(urgent.body.items[0].priority).toBe('URGENT');
    const mineQueue = await request(ctx.http)
      .get('/v1/admin/support/tickets?view=MINE')
      .set(agent.auth)
      .expect(200);
    expect(mineQueue.body.items.map((t: { id: string }) => t.id)).toEqual(
      expect.arrayContaining([byPhone.body.id, byOrder.body.id]),
    );

    await request(ctx.http)
      .post('/v1/admin/support/tickets')
      .set(agent.auth)
      .send({ category: 'OTHER', subject: 'Sans contact', message: 'Personne à rappeler ?' })
      .expect(400);
    await request(ctx.http)
      .post('/v1/admin/support/tickets')
      .set(agent.auth)
      .send({
        orderReference: 'TR-ZZZZZZ',
        category: 'OTHER',
        subject: 'Inconnue',
        message: 'Commande ?',
      })
      .expect(404);
  });

  it('colis abîmé : à signaler dans les 7 jours suivant la livraison, dimanches et jours fériés non compris', async () => {
    const recent = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: recent.id },
      data: { deliveredAt: new Date(Date.now() - 2 * 86_400_000) },
    });
    await open(shop, {
      category: 'DAMAGED_PARCEL',
      subject: 'Article cassé',
      message: 'Le vase est arrivé fêlé à l’intérieur du carton.',
      orderId: recent.id,
    }).expect(201);

    const old = await placeOrder(ctx, shop);
    await ctx.prisma.order.update({
      where: { id: old.id },
      data: { deliveredAt: new Date(Date.now() - 15 * 86_400_000) },
    });
    const late = await open(shop, {
      category: 'DAMAGED_PARCEL',
      subject: 'Article cassé',
      message: 'Je découvre que le vase est fêlé.',
      orderId: old.id,
    }).expect(422);
    expect(late.body.error.code).toBe('DAMAGE_CLAIM_TOO_LATE');
  });

  it('limite à 5 demandes en cours par personne', async () => {
    const busy = await signIn(ctx);
    for (let i = 0; i < 5; i += 1) {
      await open(busy, {
        category: 'OTHER',
        subject: `Question ${i}`,
        message: 'Une question.',
      }).expect(201);
    }
    const sixth = await open(busy, {
      category: 'OTHER',
      subject: 'Encore',
      message: 'Une autre.',
    }).expect(429);
    expect(sixth.body.error.code).toBe('TICKET_LIMIT_REACHED');
  });

  it('donne les preuves d’une commande : photo, position, appels, notes ; photo consultée tracée', async () => {
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop);
    const photoKey = await proofPhoto(ctx, rider);
    const proof = await ctx.prisma.deliveryProof.create({
      data: {
        orderId: placed.id,
        kind: 'FAILED_ATTEMPT',
        photoKey,
        latitude: 4.0511,
        longitude: 9.7679,
        occurredAt: new Date(),
        callLog: [
          { to: 'RECIPIENT', at: '2026-11-12T09:00:00.000Z', durationSeconds: 0 },
          { to: 'RECIPIENT', at: '2026-11-12T09:06:00.000Z', durationSeconds: 12 },
        ],
      },
    });
    await ctx.prisma.rating.create({
      data: {
        orderId: placed.id,
        raterId: shop.userId,
        rateeId: rider.userId,
        score: 2,
        comment: 'Colis abîmé',
      },
    });

    const evidence = await request(ctx.http)
      .get(`/v1/admin/support/orders/${placed.id}/evidence`)
      .set(agent.auth)
      .expect(200);
    expect(evidence.body).toMatchObject({
      hasParcelPhoto: false,
      trackPoints: 0,
      proofs: [
        {
          id: proof.id,
          kind: 'FAILED_ATTEMPT',
          hasPhoto: true,
          latitude: 4.0511,
          calls: [
            { to: 'RECIPIENT', durationSeconds: 0 },
            { to: 'RECIPIENT', durationSeconds: 12 },
          ],
        },
      ],
      ratings: [{ by: 'SENDER', score: 2, comment: 'Colis abîmé' }],
    });

    const photo = await request(ctx.http)
      .get(`/v1/admin/support/proofs/${proof.id}/photo`)
      .set(agent.auth)
      .expect(200);
    expect(photo.headers['content-type']).toContain('image/jpeg');
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: proof.id, action: 'delivery_proof.photo_viewed' },
    });
    expect(audit?.actorId).toBe(agent.userId);

    await request(ctx.http)
      .get(`/v1/admin/support/orders/${placed.id}/parcel-photo`)
      .set(agent.auth)
      .expect(404);
    await request(ctx.http)
      .get(`/v1/admin/support/orders/${placed.id}/evidence`)
      .set(rider.auth)
      .expect(403);
  });
});
