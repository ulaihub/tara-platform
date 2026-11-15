import request from 'supertest';
import { RetentionService } from '../src/privacy/retention.service.js';
import { MediaService } from '../src/storage/media.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../src/storage/object-storage.js';
import {
  createTestApp,
  otpFrom,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { createAddress, ensureDoualaServiceArea, PLACES } from './helpers/geo.js';
import { activeRider } from './helpers/riders.js';

describe('Données personnelles (loi n° 2024/017)', () => {
  let ctx: TestContext;
  let admin: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
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

  it('ferme le compte d’un livreur à sa demande, une fois son argent versé (administrateur)', async () => {
    const rider = await activeRider(ctx);
    const dispatcher = await staffUser(ctx, ['DISPATCHER']);
    const close = (who: SignedIn) =>
      request(ctx.http).post(`/v1/admin/riders/${rider.riderId}/close-account`).set(who.auth);
    await close(dispatcher).expect(403);

    // Il lui reste de l'argent : il le retire d'abord.
    const refused = await close(admin).expect(422);
    expect(refused.body.error.code).toBe('ACCOUNT_HAS_BALANCE');
    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    await request(ctx.http)
      .post('/v1/rider/withdrawals')
      .set(rider.auth)
      .set('Idempotency-Key', crypto.randomUUID())
      .send({ amount: wallet.body.available, phone: rider.phone, operator: 'MTN' })
      .expect(201);

    await close(admin).expect(204);
    const user = await ctx.prisma.user.findUniqueOrThrow({ where: { id: rider.userId } });
    expect(user).toMatchObject({ status: 'DELETED', fullName: null });
    expect(user.phone.startsWith('deleted:')).toBe(true);
    expect(await ctx.prisma.kycDocument.count({ where: { riderId: rider.riderId } })).toBe(0);
    const profile = await ctx.prisma.riderProfile.findUniqueOrThrow({
      where: { id: rider.riderId },
    });
    expect(profile).toMatchObject({ status: 'SUSPENDED', guarantorName: null, plateNumber: null });
    expect(
      await ctx.prisma.auditLog.count({
        where: { entityId: rider.riderId, action: 'rider.account_closed' },
      }),
    ).toBe(1);
    // Plus de session : l'app livreur repart à la connexion.
    await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(401);
    await close(admin).expect(404);
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

  it('efface après 90 jours photos, demandes closes et pièces des livreurs refusés, sauf litige ouvert', async () => {
    const media = ctx.app.get(MediaService);
    const storage = ctx.app.get<ObjectStorage>(OBJECT_STORAGE);
    const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
    const photo = (ownerId: string, kind: 'PROOF_PHOTO' | 'PARCEL_PHOTO') =>
      media.store(ownerId, kind, { buffer: jpeg, mimetype: 'image/jpeg', size: jpeg.length });
    const exists = (key: string) =>
      storage.get(key).then(
        () => true,
        () => false,
      );

    // Commande sans litige : preuve et photo du colis anciennes.
    const quiet = await customerWithOrder();
    const proofPhoto = await photo(quiet.userId, 'PROOF_PHOTO');
    const parcelPhoto = await photo(quiet.userId, 'PARCEL_PHOTO');
    await ctx.prisma.$executeRaw`
      UPDATE orders SET parcel_photo_key = ${parcelPhoto.key} WHERE id = ${quiet.orderId}::uuid`;
    const proof = await ctx.prisma.deliveryProof.create({
      data: {
        orderId: quiet.orderId,
        kind: 'PICKUP',
        photoKey: proofPhoto.key,
        latitude: PLACES.akwa.latitude,
        longitude: PLACES.akwa.longitude,
        occurredAt: new Date(),
      },
    });
    // Commande avec une demande au support encore ouverte : sa preuve est gardée.
    const disputed = await customerWithOrder();
    const keptPhoto = await photo(disputed.userId, 'PROOF_PHOTO');
    await ctx.prisma.deliveryProof.create({
      data: {
        orderId: disputed.orderId,
        kind: 'DELIVERY',
        photoKey: keptPhoto.key,
        latitude: PLACES.bonapriso.latitude,
        longitude: PLACES.bonapriso.longitude,
        occurredAt: new Date(),
      },
    });
    const ticket = (
      status: 'OPEN' | 'RESOLVED',
      resolvedDaysAgo: number | null,
      orderId?: string,
    ) =>
      ctx.prisma.ticket.create({
        data: {
          orderId: orderId ?? null,
          openedById: disputed.userId,
          contactPhone: disputed.phone,
          category: 'LOST_PARCEL',
          status,
          subject: 'Colis introuvable',
          resolvedAt:
            resolvedDaysAgo === null ? null : new Date(Date.now() - resolvedDaysAgo * 86_400_000),
          messages: { create: { authorId: disputed.userId, body: 'Je n’ai rien reçu.' } },
        },
      });
    await ticket('OPEN', null, disputed.orderId);
    const oldTicket = await ticket('RESOLVED', 91);
    const recentTicket = await ticket('RESOLVED', 10);
    await ctx.prisma.$executeRaw`
      UPDATE media_files SET created_at = now() - interval '91 days'
       WHERE storage_key IN (${proofPhoto.key}, ${parcelPhoto.key}, ${keptPhoto.key})`;

    // Livreur refusé il y a plus de 90 jours, et un autre refusé récemment.
    const rejectedRider = async (daysAgo: number) => {
      const user = await signIn(ctx);
      const document = await media.store(user.userId, 'KYC_DOCUMENT', {
        buffer: Buffer.from('%PDF-1.4 pièce fictive'),
        mimetype: 'application/pdf',
        size: 22,
      });
      const rider = await ctx.prisma.riderProfile.create({
        data: {
          userId: user.userId,
          status: 'REJECTED',
          documents: { create: { type: 'NATIONAL_ID_FRONT', storageKey: document.key } },
        },
      });
      await ctx.prisma.$executeRaw`
        UPDATE rider_profiles SET updated_at = now() - make_interval(days => ${daysAgo})
         WHERE id = ${rider.id}::uuid`;
      return document.key;
    };
    const oldDocument = await rejectedRider(91);
    const recentDocument = await rejectedRider(10);

    const report = await ctx.app.get(RetentionService).run(new Date());
    expect(report.photosDeleted).toBeGreaterThanOrEqual(2);
    expect(report.ticketsDeleted).toBeGreaterThanOrEqual(1);
    expect(report.kycDocumentsDeleted).toBeGreaterThanOrEqual(1);

    expect(await exists(proofPhoto.key)).toBe(false);
    expect(await exists(parcelPhoto.key)).toBe(false);
    expect(
      (await ctx.prisma.deliveryProof.findUniqueOrThrow({ where: { id: proof.id } })).photoKey,
    ).toBeNull();
    expect(
      (await ctx.prisma.order.findUniqueOrThrow({ where: { id: quiet.orderId } })).parcelPhotoKey,
    ).toBeNull();
    expect(await exists(keptPhoto.key)).toBe(true);

    expect(await ctx.prisma.ticket.findUnique({ where: { id: oldTicket.id } })).toBeNull();
    expect(await ctx.prisma.ticket.findUnique({ where: { id: recentTicket.id } })).not.toBeNull();

    expect(await exists(oldDocument)).toBe(false);
    expect(await ctx.prisma.kycDocument.count({ where: { storageKey: oldDocument } })).toBe(0);
    expect(await exists(recentDocument)).toBe(true);
  });
});
