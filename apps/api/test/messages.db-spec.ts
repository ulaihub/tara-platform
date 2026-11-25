import request from 'supertest';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import { createTestApp, type SignedIn, signIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, nearAkwa, placeOrder, setupDouala, type TestMerchant } from './helpers/orders.js';
import { activeRider, goOnline, resetPresence, type TestRider } from './helpers/riders.js';

describe('Livreur trouvé : qui il est, et messages avec l’expéditeur', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let shop: TestMerchant;
  let push: FakePushProvider;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
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

  async function assigned(): Promise<{ orderId: string; rider: TestRider }> {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.001));
    const order = await placeOrder(ctx, shop);
    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: order.id, riderId: rider.riderId, outcome: 'PENDING' },
    });
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    return { orderId: order.id, rider };
  }

  it('montre à l’expéditeur la marque, la couleur et la photo du livreur', async () => {
    const { orderId, rider } = await assigned();
    const vehicle = await request(ctx.http)
      .put('/v1/riders/me/vehicle')
      .set(rider.auth)
      .send({ brand: 'NANFANG', color: 'RED', plateNumber: 'lt 456 cc' })
      .expect(200);
    expect(vehicle.body).toMatchObject({
      vehicleBrand: 'NANFANG',
      vehicleColor: 'RED',
      plateNumber: 'LT 456 CC',
    });
    await request(ctx.http)
      .put('/v1/riders/me/vehicle')
      .set(rider.auth)
      .send({ brand: 'PEUGEOT-INCONNUE', color: 'RED' })
      .expect(400);

    const seen = await request(ctx.http).get(`/v1/orders/${orderId}`).set(shop.auth).expect(200);
    expect(seen.body.rider).toMatchObject({
      phone: expect.any(String),
      vehicleBrand: 'NANFANG',
      vehicleColor: 'RED',
      plateNumber: 'LT 456 CC',
      hasPhoto: true,
    });
    // La photo n'est donnée qu'à l'expéditeur et à l'équipe.
    const stranger = await signIn(ctx);
    await request(ctx.http).get(`/v1/orders/${orderId}/rider-photo`).set(stranger.auth).expect(404);
    await request(ctx.http).get(`/v1/orders/${orderId}/rider-photo`).set(rider.auth).expect(404);
  });

  it('l’expéditeur et le livreur s’écrivent ; lu à l’ouverture ; fermé après la course', async () => {
    const { orderId, rider } = await assigned();
    const sent = await request(ctx.http)
      .post(`/v1/orders/${orderId}/messages`)
      .set(shop.auth)
      .send({ body: '  Le colis est au comptoir, demandez Awa.  ' })
      .expect(201);
    expect(sent.body).toMatchObject({
      mine: true,
      authorRole: 'SENDER',
      body: 'Le colis est au comptoir, demandez Awa.',
      readAt: null,
    });
    expect(push.lastTo(rider.pushToken)).toMatchObject({
      data: { type: 'order.message', orderId },
    });

    const riderView = await request(ctx.http)
      .get(`/v1/orders/${orderId}/messages`)
      .set(rider.auth)
      .expect(200);
    expect(riderView.body.open).toBe(true);
    expect(riderView.body.messages).toEqual([
      expect.objectContaining({ mine: false, authorRole: 'SENDER' }),
    ]);
    await request(ctx.http)
      .post(`/v1/orders/${orderId}/messages`)
      .set(rider.auth)
      .send({ body: 'J’arrive dans 5 min' })
      .expect(201);

    const senderView = await request(ctx.http)
      .get(`/v1/orders/${orderId}/messages`)
      .set(shop.auth)
      .expect(200);
    expect(senderView.body.messages.map((m: { body: string }) => m.body)).toEqual([
      'Le colis est au comptoir, demandez Awa.',
      'J’arrive dans 5 min',
    ]);
    // Le livreur a ouvert la conversation : le message de l'expéditeur est lu.
    expect(senderView.body.messages[0].readAt).not.toBeNull();

    // Personne d'autre ne lit ni n'écrit ; l'équipe lit sans écrire.
    const stranger = await signIn(ctx);
    await request(ctx.http).get(`/v1/orders/${orderId}/messages`).set(stranger.auth).expect(404);
    await request(ctx.http).get(`/v1/orders/${orderId}/messages`).set(admin.auth).expect(200);
    await request(ctx.http)
      .post(`/v1/orders/${orderId}/messages`)
      .set(admin.auth)
      .send({ body: 'Bonjour' })
      .expect(403);
    await request(ctx.http)
      .post(`/v1/orders/${orderId}/messages`)
      .set(shop.auth)
      .send({ body: '   ' })
      .expect(400);

    // Course rendue : plus de nouveaux messages.
    await request(ctx.http)
      .post(`/v1/rider/orders/${orderId}/release`)
      .set(rider.auth)
      .send({ reason: 'Crevaison' })
      .expect(204);
    const closed = await request(ctx.http)
      .post(`/v1/orders/${orderId}/messages`)
      .set(shop.auth)
      .send({ body: 'Vous êtes où ?' })
      .expect(409);
    expect(closed.body.error.code).toBe('CONVERSATION_CLOSED');
  });
});
