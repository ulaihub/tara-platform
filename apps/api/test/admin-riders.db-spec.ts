import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { REQUIRED_DOCUMENTS } from '../src/riders/riders.schemas.js';
import {
  createTestApp,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { merchant, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

/** Plus petit PNG valide (1 × 1 pixel). */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

const MINUTE = 60_000;
const DAY = 86_400_000;

/**
 * Écran Livreurs du back-office (H3) : vues et recherche, validation sur pièces, fiabilité
 * sur 30 jours et depuis l'inscription, historique des décisions.
 */
describe('Back-office · livreurs (H3)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await ctx.prisma.user.update({ where: { id: ops.userId }, data: { fullName: 'Awa Dispatch' } });
    await setupDouala(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  /** Candidat avec un nom et une plaque uniques, toutes ses pièces envoyées. */
  async function candidate(name: string, plate: string): Promise<SignedIn & { riderId: string }> {
    const session = await signIn(ctx);
    await ctx.prisma.user.update({ where: { id: session.userId }, data: { fullName: name } });
    const res = await request(ctx.http)
      .post('/v1/riders/apply')
      .set(session.auth)
      .send({ plateNumber: plate })
      .expect(201);
    for (const group of REQUIRED_DOCUMENTS) {
      await request(ctx.http)
        .post('/v1/riders/me/documents')
        .set(session.auth)
        .field('type', group[0] as string)
        .field('expiresOn', '2030-12-31')
        .attach('file', PNG, { filename: 'piece.png', contentType: 'image/png' })
        .expect(201);
    }
    return { ...session, riderId: res.body.id };
  }

  async function approveAllDocuments(riderId: string): Promise<void> {
    const docs = await ctx.prisma.kycDocument.findMany({ where: { riderId, status: 'PENDING' } });
    for (const doc of docs) {
      await request(ctx.http)
        .post(`/v1/admin/kyc-documents/${doc.id}/review`)
        .set(ops.auth)
        .send({ decision: 'APPROVED' })
        .expect(200);
    }
  }

  it('liste « à examiner » avec le nombre par vue ; recherche par nom, numéro ou plaque', async () => {
    const tag = randomUUID().slice(0, 6).toUpperCase();
    const pending = await candidate(`Ibrahim Nfor ${tag}`, `LT ${tag} A`);
    const active = await activeRider(ctx);
    // Un livreur actif qui renvoie son assurance : à examiner aussi.
    await request(ctx.http)
      .post('/v1/riders/me/documents')
      .set(active.auth)
      .field('type', 'INSURANCE')
      .field('expiresOn', '2031-06-30')
      .attach('file', PNG, { filename: 'assurance.png', contentType: 'image/png' })
      .expect(201);

    const toReview = await request(ctx.http)
      .get('/v1/admin/riders?view=TO_REVIEW&limit=100')
      .set(ops.auth)
      .expect(200);
    const ids = toReview.body.items.map((r: { id: string }) => r.id);
    expect(ids).toEqual(expect.arrayContaining([pending.riderId, active.riderId]));
    const row = toReview.body.items.find((r: { id: string }) => r.id === pending.riderId);
    expect(row).toMatchObject({
      status: 'PENDING',
      pendingDocuments: REQUIRED_DOCUMENTS.length,
      rating: { average: null, count: 0 },
      deliveredLast30Days: 0,
    });
    expect(toReview.body.counts.TO_REVIEW).toBeGreaterThanOrEqual(2);
    expect(toReview.body.counts.ALL).toBeGreaterThanOrEqual(toReview.body.counts.ACTIVE + 1);

    for (const q of [`nfor ${tag.toLowerCase()}`, pending.phone.slice(-6), `lt${tag}`]) {
      const found = await request(ctx.http)
        .get('/v1/admin/riders')
        .query({ q })
        .set(ops.auth)
        .expect(200);
      expect(found.body.items.map((r: { id: string }) => r.id)).toEqual([pending.riderId]);
    }
    await request(ctx.http).get('/v1/admin/riders?view=WRONG').set(ops.auth).expect(400);
  });

  it('calcule la fiabilité sur 30 jours et depuis l’inscription', async () => {
    const rider = await activeRider(ctx);
    const shop = await merchant(ctx);
    const now = Date.now();
    await ctx.prisma.riderProfile.update({
      where: { id: rider.riderId },
      data: { createdAt: new Date(now - 90 * DAY) },
    });

    // Livrée à l'heure il y a 2 jours, livrée en retard il y a 3 jours, livrée il y a 60 jours.
    const deliveries = [
      { daysAgo: 2, minutes: 20 },
      { daysAgo: 3, minutes: 240 },
      { daysAgo: 60, minutes: 15 },
    ];
    const orderIds: string[] = [];
    for (const delivery of deliveries) {
      const placed = await placeOrder(ctx, shop);
      const pickedUpAt = new Date(now - delivery.daysAgo * DAY);
      await ctx.prisma.order.update({
        where: { id: placed.id },
        data: {
          status: 'DELIVERED',
          riderId: rider.riderId,
          assignedAt: new Date(pickedUpAt.getTime() - 10 * MINUTE),
          pickedUpAt,
          deliveredAt: new Date(pickedUpAt.getTime() + delivery.minutes * MINUTE),
        },
      });
      orderIds.push(placed.id);
    }
    const [recent, , old] = orderIds as [string, string, string];

    // Propositions : 3 acceptées, 1 refusée, 1 sans réponse ces 30 jours ; 1 refusée avant.
    const offers: ['ACCEPTED' | 'DECLINED' | 'EXPIRED', number][] = [
      ['ACCEPTED', 2],
      ['ACCEPTED', 3],
      ['ACCEPTED', 4],
      ['DECLINED', 5],
      ['EXPIRED', 6],
      ['DECLINED', 50],
    ];
    for (const [outcome, days] of offers) {
      const offeredAt = new Date(now - days * DAY);
      await ctx.prisma.dispatchOffer.create({
        data: {
          orderId: recent,
          riderId: rider.riderId,
          round: 1,
          offeredAt,
          expiresAt: new Date(offeredAt.getTime() + 30_000),
          respondedAt: offeredAt,
          outcome,
        },
      });
    }

    // Un échec de livraison et un colis refusé ces 30 jours, un échec il y a 45 jours.
    for (const [toStatus, days] of [
      ['DELIVERY_FAILED', 4],
      ['CANCELLED', 1],
      ['DELIVERY_FAILED', 45],
    ] as const) {
      await ctx.prisma.orderEvent.create({
        data: {
          orderId: old,
          toStatus,
          actorId: rider.userId,
          actorRole: 'RIDER',
          occurredAt: new Date(now - days * DAY),
        },
      });
    }

    // Notes : 5 et 4 ces 30 jours, 2 il y a 60 jours ; une note reçue comme expéditeur ignorée.
    const raters = [await signIn(ctx), await signIn(ctx), await signIn(ctx), await signIn(ctx)];
    const notes: [string, number, number][] = [
      [recent, 5, 2],
      [orderIds[1] as string, 4, 3],
      [old, 2, 60],
    ];
    for (const [index, [orderId, score, days]] of notes.entries()) {
      await ctx.prisma.rating.create({
        data: {
          orderId,
          raterId: (raters[index] as SignedIn).userId,
          rateeId: rider.userId,
          score,
          createdAt: new Date(now - days * DAY),
        },
      });
    }
    const asSender = await placeOrder(ctx, shop);
    await ctx.prisma.rating.create({
      data: {
        orderId: asSender.id,
        raterId: (raters[3] as SignedIn).userId,
        rateeId: rider.userId,
        score: 1,
      },
    });

    // 2 h en ligne il y a 5 jours ; une alerte de course, un SOS, un SOS annulé.
    await ctx.prisma.riderOnlineSession.create({
      data: {
        riderId: rider.riderId,
        startedAt: new Date(now - 5 * DAY),
        lastSeenAt: new Date(now - 5 * DAY + 120 * MINUTE),
        endedAt: new Date(now - 5 * DAY + 120 * MINUTE),
      },
    });
    await ctx.prisma.courseAlert.create({
      data: {
        orderId: recent,
        riderId: rider.riderId,
        kind: 'LONG_STOP',
        dedupeKey: 'LONG_STOP:1',
        details: {},
      },
    });
    for (const cancelledAt of [null, new Date()]) {
      await ctx.prisma.safetyAlert.create({
        data: { riderId: rider.riderId, latitude: 4.05, longitude: 9.7, cancelledAt },
      });
    }

    const res = await request(ctx.http)
      .get(`/v1/admin/riders/${rider.riderId}/reliability`)
      .set(ops.auth)
      .expect(200);
    expect(res.body.last30Days).toEqual({
      offers: { accepted: 3, declined: 1, expired: 1 },
      deliveries: { delivered: 2, onTime: 1, failed: 1, parcelsRefused: 1 },
      rating: { average: 4.5, count: 2 },
      onlineMinutes: 120,
      courseAlerts: 1,
      sosAlerts: 1,
    });
    expect(res.body.allTime).toMatchObject({
      offers: { accepted: 3, declined: 2, expired: 1 },
      deliveries: { delivered: 3, onTime: 2, failed: 2, parcelsRefused: 1 },
      rating: { average: 3.7, count: 3 },
    });

    const row = await request(ctx.http)
      .get(`/v1/admin/riders/${rider.riderId}`)
      .set(ops.auth)
      .expect(200);
    expect(row.body.deliveredLast30Days).toBe(2);
  });

  it('retrace les décisions : pièces, validation, suspension avec motif', async () => {
    const rider = await candidate('Sandrine Mvogo', 'LT 777 SM');
    await approveAllDocuments(rider.riderId);
    const selfie = await request(ctx.http)
      .post('/v1/riders/me/documents')
      .set(rider.auth)
      .field('type', 'SELFIE')
      .attach('file', PNG, { filename: 'selfie.png', contentType: 'image/png' })
      .expect(201);
    await request(ctx.http)
      .post(`/v1/admin/kyc-documents/${selfie.body.id}/review`)
      .set(ops.auth)
      .send({ decision: 'REJECTED', rejectionReason: 'Photo floue.' })
      .expect(200);
    // Renvoyée nette depuis son profil, puis validée.
    await request(ctx.http)
      .post('/v1/riders/me/documents')
      .set(rider.auth)
      .field('type', 'SELFIE')
      .attach('file', PNG, { filename: 'selfie.png', contentType: 'image/png' })
      .expect(201);
    await approveAllDocuments(rider.riderId);
    await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(ops.auth)
      .send({ decision: 'APPROVE' })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(ops.auth)
      .send({ decision: 'SUSPEND', reason: 'Plainte d’une boutique à instruire' })
      .expect(200);
    // Une consultation de pièce n'apparaît pas dans l'historique.
    await request(ctx.http)
      .get(`/v1/admin/kyc-documents/${selfie.body.id}/file`)
      .set(ops.auth)
      .expect(200);

    const res = await request(ctx.http)
      .get(`/v1/admin/riders/${rider.riderId}/reliability`)
      .set(ops.auth)
      .expect(200);
    const history = res.body.history as {
      action: string;
      by: string | null;
      note: string | null;
      documentType: string | null;
    }[];
    expect(history.slice(0, 4)).toEqual([
      {
        at: expect.any(String),
        action: 'SUSPENDED',
        by: 'Awa Dispatch',
        note: 'Plainte d’une boutique à instruire',
        documentType: null,
      },
      {
        at: expect.any(String),
        action: 'APPROVED',
        by: 'Awa Dispatch',
        note: null,
        documentType: null,
      },
      {
        at: expect.any(String),
        action: 'DOCUMENT_APPROVED',
        by: 'Awa Dispatch',
        note: null,
        documentType: 'SELFIE',
      },
      {
        at: expect.any(String),
        action: 'DOCUMENT_REJECTED',
        by: 'Awa Dispatch',
        note: 'Photo floue.',
        documentType: 'SELFIE',
      },
    ]);
    expect(history.filter((item) => item.action === 'DOCUMENT_APPROVED')).toHaveLength(
      REQUIRED_DOCUMENTS.length + 1,
    );
    expect(history.at(-1)).toMatchObject({ action: 'APPLIED', by: null });

    const support = await staffUser(ctx, ['SUPPORT']);
    await request(ctx.http)
      .get(`/v1/admin/riders/${rider.riderId}/reliability`)
      .set(support.auth)
      .expect(403);
  });
});
