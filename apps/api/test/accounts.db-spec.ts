import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import request from 'supertest';
import { KycExpiryService } from '../src/riders/kyc-expiry.service.js';
import { REQUIRED_DOCUMENTS } from '../src/riders/riders.schemas.js';
import {
  CLIENT_TERMS,
  createTestApp,
  randomPhone,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { activeRider } from './helpers/riders.js';

/** Plus petit PNG valide (1 × 1 pixel). */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

describe('Mon compte (A2, A4) et parrainage (C6)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('donne les réglages de l’app expéditeur sans connexion', async () => {
    const res = await request(ctx.http).get('/v1/public/config').expect(200);
    expect(res.body).toMatchObject({
      country: { code: 'CM', dialCode: '+237', currency: 'XAF' },
      mobileMoneyOperators: [
        { code: 'MTN', name: 'MTN MoMo' },
        { code: 'ORANGE', name: 'Orange Money' },
      ],
    });
    expect(res.body).toHaveProperty('supportPhone');
  });

  it('renvoie le profil avec un code de parrainage', async () => {
    const session = await signIn(ctx);
    const res = await request(ctx.http).get('/v1/me').set(session.auth).expect(200);
    expect(res.body).toMatchObject({
      phone: session.phone,
      roles: ['CUSTOMER'],
      locale: 'FR',
      merchant: null,
      rider: null,
      referralCode: expect.stringMatching(/^TARA-[0-9A-Z]{6}$/),
    });
  });

  it('met à jour le nom et la langue, puis répond en anglais', async () => {
    const session = await signIn(ctx);
    await request(ctx.http)
      .patch('/v1/me')
      .set(session.auth)
      .send({ fullName: 'Awa Ngono', locale: 'EN' })
      .expect(200);
    const res = await request(ctx.http).get('/v1/riders/me').set(session.auth).expect(403);
    expect(res.body.error.message).toBe('Action not allowed.');
  });

  it('passe le compte en mode marchand et trace l’opération (A2)', async () => {
    const session = await signIn(ctx);
    const res = await request(ctx.http)
      .put('/v1/me/merchant')
      .set(session.auth)
      .send({ shopName: 'Bijoux de Bonapriso', payoutPhone: '677 00 00 01', payoutOperator: 'MTN' })
      .expect(200);
    expect(res.body).toMatchObject({
      shopName: 'Bijoux de Bonapriso',
      payoutPhone: '+237677000001',
      plan: 'FREE',
    });

    const me = await request(ctx.http).get('/v1/me').set(session.auth).expect(200);
    expect(me.body.roles).toEqual(['CUSTOMER', 'MERCHANT']);
    const audit = await ctx.prisma.auditLog.findFirst({ where: { entityId: res.body.id } });
    expect(audit?.action).toBe('merchant.created');
  });

  it('garde le dernier choix de consentement', async () => {
    const session = await signIn(ctx);
    await request(ctx.http)
      .post('/v1/me/consents')
      .set(session.auth)
      .send({ kind: 'MARKETING', version: '2026-11', granted: true })
      .expect(201);
    await request(ctx.http)
      .post('/v1/me/consents')
      .set(session.auth)
      .send({ kind: 'MARKETING', version: '2026-11', granted: false })
      .expect(201);
    const res = await request(ctx.http).get('/v1/me/consents').set(session.auth).expect(200);
    expect(res.body.find((c: { kind: string }) => c.kind === 'MARKETING')).toMatchObject({
      granted: false,
    });
  });

  it('enregistre le parrainage à l’inscription', async () => {
    const referrer = await signIn(ctx);
    const me = await request(ctx.http).get('/v1/me').set(referrer.auth).expect(200);
    const phone = randomPhone();
    const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
    const code = /(\d{6})/.exec(ctx.sms.lastTo(phone)?.text ?? '')?.[1];
    const res = await request(ctx.http)
      .post('/v1/auth/otp/verify')
      .send({
        challengeId: challenge.body.challengeId,
        code,
        device: { installationId: 'installation-parrainage', platform: 'ANDROID' },
        terms: CLIENT_TERMS,
        referralCode: me.body.referralCode.toLowerCase(),
      })
      .expect(200);
    expect(res.body.referralApplied).toBe(true);
    const referral = await ctx.prisma.referral.findUnique({
      where: { refereeId: res.body.user.id },
    });
    expect(referral?.referrerId).toBe(referrer.userId);
  });
});

describe('Livreurs et pièces (A3, A5, H3)', () => {
  let ctx: TestContext;
  let ops: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    ops = await staffUser(ctx, ['DISPATCHER']);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function applyAsRider(): Promise<SignedIn & { riderId: string }> {
    const session = await signIn(ctx);
    const res = await request(ctx.http)
      .post('/v1/riders/apply')
      .set(session.auth)
      .send({ plateNumber: 'LT 123 AB', guarantorName: 'Paul Mbarga', guarantorPhone: '699112233' })
      .expect(201);
    // Le jeton reste valable : les rôles sont relus en base à chaque requête.
    return { ...session, riderId: res.body.id };
  }

  function upload(session: SignedIn, type: string, expiresOn?: string) {
    const req = request(ctx.http)
      .post('/v1/riders/me/documents')
      .set(session.auth)
      .field('type', type)
      .attach('file', PNG, { filename: 'piece.png', contentType: 'image/png' });
    return expiresOn ? req.field('expiresOn', expiresOn) : req;
  }

  it('crée une candidature en attente avec la liste des pièces à fournir', async () => {
    const rider = await applyAsRider();
    const res = await request(ctx.http).get('/v1/riders/me').set(rider.auth).expect(200);
    expect(res.body).toMatchObject({
      status: 'PENDING',
      // Plafond des espèces de l'ancien fonctionnement (avant le solde prépayé).
      cashLimit: 25_000,
      guarantorPhone: '+237699112233',
    });
    expect(res.body.missingDocuments).toHaveLength(REQUIRED_DOCUMENTS.length);
    await request(ctx.http)
      .post('/v1/riders/apply')
      .set(rider.auth)
      .send({
        guarantorName: 'X Y',
        guarantorPhone: '699112233',
      })
      .expect(409);
  });

  it('chiffre les pièces au stockage et les restitue au back-office avec audit', async () => {
    const rider = await applyAsRider();
    const doc = await upload(rider, 'NATIONAL_ID_FRONT').expect(201);
    expect(doc.body).toMatchObject({ type: 'NATIONAL_ID_FRONT', status: 'PENDING' });

    const stored = await ctx.prisma.kycDocument.findUniqueOrThrow({ where: { id: doc.body.id } });
    const onDisk = await readFile(join(process.env['STORAGE_LOCAL_DIR'] ?? '', stored.storageKey));
    expect(onDisk.includes(PNG)).toBe(false);

    const file = await request(ctx.http)
      .get(`/v1/admin/kyc-documents/${doc.body.id}/file`)
      .set(ops.auth)
      .expect(200);
    expect(Buffer.compare(file.body as Buffer, PNG)).toBe(0);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: doc.body.id, action: 'kyc_document.viewed' },
    });
    expect(audit?.actorId).toBe(ops.userId);

    await request(ctx.http)
      .get(`/v1/admin/kyc-documents/${doc.body.id}/file`)
      .set(rider.auth)
      .expect(403);
  });

  it('refuse un fichier dont le contenu ne correspond pas au type annoncé', async () => {
    const rider = await applyAsRider();
    const res = await request(ctx.http)
      .post('/v1/riders/me/documents')
      .set(rider.auth)
      .field('type', 'SELFIE')
      .attach('file', Buffer.from('<script>alert(1)</script>'), {
        filename: 'selfie.png',
        contentType: 'image/png',
      })
      .expect(400);
    expect(res.body.error.code).toBe('MEDIA_TYPE_NOT_ALLOWED');
  });

  it('prévient le livreur d’une pièce refusée, avec le motif', async () => {
    const rider = await activeRider(ctx);
    const doc = await upload(rider, 'SELFIE').expect(201);
    await request(ctx.http)
      .post(`/v1/admin/kyc-documents/${doc.body.id}/review`)
      .set(ops.auth)
      .send({ decision: 'REJECTED', rejectionReason: 'Visage caché par le casque.' })
      .expect(200);
    const push = await ctx.prisma.notification.findFirstOrThrow({
      where: { userId: rider.userId, channel: 'PUSH', template: 'RIDER_DOCUMENT_REJECTED' },
    });
    expect(push.payload).toMatchObject({
      params: {
        documentFr: 'Photo du visage',
        documentEn: 'Selfie',
        reason: 'Visage caché par le casque',
      },
      data: { type: 'kyc.document_rejected', documentType: 'SELFIE' },
    });
  });

  it('ne valide le livreur qu’une fois toutes les pièces approuvées', async () => {
    const rider = await applyAsRider();
    const types = REQUIRED_DOCUMENTS.map((group) => group[0] as string);
    const ids: string[] = [];
    for (const type of types)
      ids.push((await upload(rider, type, '2030-12-31').expect(201)).body.id);

    for (const id of ids.slice(1)) {
      await request(ctx.http)
        .post(`/v1/admin/kyc-documents/${id}/review`)
        .set(ops.auth)
        .send({ decision: 'APPROVED' })
        .expect(200);
    }
    const incomplete = await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(ops.auth)
      .send({ decision: 'APPROVE' })
      .expect(422);
    expect(incomplete.body.error).toMatchObject({
      code: 'RIDER_DOCUMENTS_INCOMPLETE',
      details: { missing: ['NATIONAL_ID_FRONT'] },
    });

    await request(ctx.http)
      .post(`/v1/admin/kyc-documents/${ids[0]}/review`)
      .set(ops.auth)
      .send({ decision: 'REJECTED' })
      .expect(400);
    await request(ctx.http)
      .post(`/v1/admin/kyc-documents/${ids[0]}/review`)
      .set(ops.auth)
      .send({ decision: 'APPROVED' })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/admin/kyc-documents/${ids[0]}/review`)
      .set(ops.auth)
      .send({ decision: 'APPROVED' })
      .expect(409);

    const approved = await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(ops.auth)
      .send({ decision: 'APPROVE' })
      .expect(200);
    expect(approved.body).toMatchObject({ status: 'ACTIVE', missingDocuments: [] });

    const suspended = await request(ctx.http)
      .post(`/v1/admin/riders/${rider.riderId}/decision`)
      .set(ops.auth)
      .send({ decision: 'SUSPEND', reason: 'Plainte client à instruire' })
      .expect(200);
    expect(suspended.body).toMatchObject({
      status: 'SUSPENDED',
      suspendedReason: 'Plainte client à instruire',
    });

    const listed = await request(ctx.http)
      .get('/v1/admin/riders?status=SUSPENDED&limit=100')
      .set(ops.auth)
      .expect(200);
    expect(listed.body.items.some((r: { id: string }) => r.id === rider.riderId)).toBe(true);
  });

  it('fait expirer les pièces échues et prévient avant l’échéance (A5)', async () => {
    const rider = await applyAsRider();
    const now = new Date('2026-11-02T08:00:00Z');
    const expired = (await upload(rider, 'INSURANCE', '2026-11-01').expect(201)).body.id;
    const soon = (await upload(rider, 'DRIVING_LICENSE', '2026-11-09').expect(201)).body.id;
    for (const id of [expired, soon]) {
      await request(ctx.http)
        .post(`/v1/admin/kyc-documents/${id}/review`)
        .set(ops.auth)
        .send({ decision: 'APPROVED' })
        .expect(200);
    }

    const result = await ctx.app.get(KycExpiryService).run(now);
    expect(result.expired).toBeGreaterThanOrEqual(1);
    const reloaded = await ctx.prisma.kycDocument.findUniqueOrThrow({ where: { id: expired } });
    expect(reloaded.status).toBe('EXPIRED');
    expect(ctx.sms.lastTo(rider.phone)?.text).toMatch(/Permis de conduire.*2026-11-09/);
  });
});
