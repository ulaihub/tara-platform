import request from 'supertest';
import { RetentionService } from '../src/privacy/retention.service.js';
import {
  createTestApp,
  otpFrom,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { createAddress, ensureDoualaServiceArea, PLACES } from './helpers/geo.js';

describe('Données personnelles (loi n° 2024/017)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    await ensureDoualaServiceArea(ctx, admin);
    await request(ctx.http)
      .post('/v1/admin/pricing-grids')
      .set(admin.auth)
      .send({
        name: 'Douala (tests données)',
        city: 'Douala',
        perKmBeyondLastTier: 150,
        tiers: [{ upToMeters: 15_000, price: 1500 }],
        activate: true,
      })
      .expect(201);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function customerWithOrder(): Promise<SignedIn & { orderId: string; dropoffId: string }> {
    const user = await signIn(ctx);
    const pickup = await createAddress(ctx, user, PLACES.akwa);
    const dropoff = await createAddress(ctx, user, PLACES.bonapriso, {
      contactName: 'Clarisse',
      contactPhone: '655001122',
    });
    const order = await request(ctx.http)
      .post('/v1/orders')
      .set(user.auth)
      .send({
        pickupAddressId: pickup.id,
        dropoffAddressId: dropoff.id,
        recipientName: 'Clarisse Ndongo',
        recipientPhone: '655 00 11 22',
        packageSize: 'S',
        feePaymentMethod: 'CASH',
        instructions: 'Appeler sa sœur au 677 88 99 00',
      })
      .expect(201);
    return { ...user, orderId: order.body.order.id, dropoffId: dropoff.id };
  }

  it('exporte toutes les données du compte (droit d’accès)', async () => {
    const user = await customerWithOrder();
    const other = await signIn(ctx);
    await ctx.prisma.rating.create({
      data: {
        orderId: user.orderId,
        raterId: user.userId,
        rateeId: other.userId,
        score: 5,
        comment: 'Très soigneux',
      },
    });
    const res = await request(ctx.http).get('/v1/me/export').set(user.auth).expect(200);
    expect(res.body.ratingsGiven).toEqual([
      expect.objectContaining({ score: 5, comment: 'Très soigneux' }),
    ]);
    expect(res.headers['content-disposition']).toMatch(/^attachment; filename="tara-donnees-/);
    expect(res.body.account.phone).toBe(user.phone);
    expect(res.body.orders[0]).toMatchObject({
      recipientName: 'Clarisse Ndongo',
      recipientPhone: '+237655001122',
    });
    expect(res.body.consents.map((c: { kind: string }) => c.kind).sort()).toEqual([
      'PRIVACY',
      'TERMS',
    ]);
    const audit = await ctx.prisma.auditLog.count({
      where: { entityId: user.userId, action: 'user.data_exported' },
    });
    expect(audit).toBe(1);
  });

  it('refuse la suppression d’un livreur ou d’un compte avec une commande en cours', async () => {
    const rider = await signIn(ctx);
    await request(ctx.http)
      .post('/v1/riders/apply')
      .set(rider.auth)
      .send({ guarantorName: 'Paul Mbarga', guarantorPhone: '699112233' })
      .expect(201);
    const riderRes = await request(ctx.http)
      .post('/v1/me/deletion/code')
      .set(rider.auth)
      .expect(422);
    expect(riderRes.body.error.code).toBe('ACCOUNT_DELETION_NOT_ALLOWED');

    const customer = await customerWithOrder();
    const busy = await request(ctx.http)
      .post('/v1/me/deletion/code')
      .set(customer.auth)
      .expect(422);
    expect(busy.body.error.code).toBe('ACCOUNT_HAS_ACTIVE_ORDERS');
  });

  it('supprime le compte après confirmation par SMS et libère le numéro (droit à l’effacement)', async () => {
    const user = await customerWithOrder();
    await request(ctx.http)
      .post(`/v1/orders/${user.orderId}/cancel`)
      .set(user.auth)
      .send({ reason: 'Plus besoin' })
      .expect(200);

    const rider = await signIn(ctx);
    await ctx.prisma.rating.create({
      data: {
        orderId: user.orderId,
        raterId: user.userId,
        rateeId: rider.userId,
        score: 2,
        comment: 'Il a appelé ma voisine Mme Ekambi',
      },
    });

    // Un code de connexion ne confirme pas une suppression.
    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: user.phone } });
    const login = await request(ctx.http)
      .post('/v1/auth/otp')
      .send({ phone: user.phone })
      .expect(201);
    const loginCode = otpFrom(ctx.sms, user.phone);
    const wrongPurpose = await request(ctx.http)
      .post('/v1/me/deletion')
      .set(user.auth)
      .send({ challengeId: login.body.challengeId, code: loginCode })
      .expect(400);
    expect(wrongPurpose.body.error.code).toBe('OTP_INVALID');

    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: user.phone } });
    const challenge = await request(ctx.http)
      .post('/v1/me/deletion/code')
      .set(user.auth)
      .expect(201);
    expect(ctx.sms.lastTo(user.phone)?.text).toMatch(/SUPPRESSION/);
    await request(ctx.http)
      .post('/v1/me/deletion')
      .set(user.auth)
      .send({ challengeId: challenge.body.challengeId, code: otpFrom(ctx.sms, user.phone) })
      .expect(204);

    await request(ctx.http).get('/v1/me').set(user.auth).expect(401);
    await request(ctx.http)
      .post('/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken })
      .expect(401);

    const deleted = await ctx.prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
    expect(deleted).toMatchObject({ status: 'DELETED', fullName: null, referralCode: null });
    expect(deleted.phone).toMatch(/^deleted:/);
    const order = await ctx.prisma.order.findUniqueOrThrow({ where: { id: user.orderId } });
    expect(order).toMatchObject({
      recipientPhone: '+2376•••••22',
      recipientName: 'C.',
      instructions: null,
    });
    const dropoff = await ctx.prisma.address.findUniqueOrThrow({ where: { id: user.dropoffId } });
    expect(dropoff).toMatchObject({ ownerId: null, contactName: null, contactPhone: null });
    // Les étoiles restent (score du livreur), le mot libre disparaît.
    expect(
      await ctx.prisma.rating.findFirstOrThrow({ where: { raterId: user.userId } }),
    ).toMatchObject({ score: 2, comment: null });

    // Le numéro est libre : la même personne peut se réinscrire.
    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: user.phone } });
    const again = await signIn(ctx, user.phone);
    expect(again.userId).not.toBe(user.userId);
  });

  it('masque les destinataires 30 jours après la fin de la commande', async () => {
    const user = await customerWithOrder();
    await request(ctx.http)
      .post(`/v1/orders/${user.orderId}/cancel`)
      .set(user.auth)
      .send({ reason: 'Annulée' })
      .expect(200);
    await ctx.prisma.$executeRaw`
      UPDATE orders SET updated_at = now() - interval '31 days' WHERE id = ${user.orderId}::uuid`;
    await ctx.prisma.$executeRaw`
      UPDATE notifications SET created_at = now() - interval '31 days' WHERE order_id = ${user.orderId}::uuid`;

    const report = await ctx.app.get(RetentionService).run(new Date());
    expect(report.ordersMasked).toBeGreaterThanOrEqual(1);

    const order = await ctx.prisma.order.findUniqueOrThrow({ where: { id: user.orderId } });
    expect(order).toMatchObject({
      recipientPhone: '+2376•••••22',
      recipientName: 'C.',
      piiMaskedAt: expect.any(Date),
    });
    const notification = await ctx.prisma.notification.findFirstOrThrow({
      where: { orderId: user.orderId },
    });
    expect(notification.recipientPhone).toBeNull();
    const recipients = await request(ctx.http).get('/v1/recipients').set(user.auth).expect(200);
    expect(recipients.body).toEqual([]);
  });
});
