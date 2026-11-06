import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { LEGAL_TEXTS } from '../src/legal/legal-texts.generated.js';
import {
  CLIENT_TERMS,
  createTestApp,
  otpFrom,
  randomPhone,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { merchant, nearAkwa, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider, resetPresence } from './helpers/riders.js';

const VERSION = LEGAL_TEXTS.expediteurs.version;
const RIDER_TERMS = {
  livreurs: LEGAL_TEXTS.livreurs.version,
  confidentialite: LEGAL_TEXTS.confidentialite.version,
};

describe('Conditions d’utilisation : textes, acceptation signée, nouvelle version', () => {
  let ctx: TestContext;
  let admin: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  /** Simule la parution d'une nouvelle version : l'acceptation enregistrée devient ancienne. */
  async function outdate(userId: string, document: keyof typeof LEGAL_TEXTS): Promise<void> {
    await ctx.prisma.consent.updateMany({
      where: { userId, version: `${document}:${LEGAL_TEXTS[document].version}` },
      data: { version: `${document}:2000-01` },
    });
  }

  /** Code SMS de signature : l'app le demande une fois les textes lus et la case cochée. */
  async function signatureCode(user: SignedIn): Promise<string> {
    // Le code de connexion vient d'être envoyé : on passe le délai avant un nouveau SMS.
    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: user.phone } });
    const challenge = await request(ctx.http).post('/v1/me/terms/code').set(user.auth).expect(201);
    return challenge.body.challengeId as string;
  }

  /** Renvoie le code reçu avec les versions affichées par l'app. */
  function sign(
    user: SignedIn,
    app: 'client' | 'rider',
    challengeId: string,
    versions: Record<string, string>,
    code = otpFrom(ctx.sms, user.phone),
  ) {
    return request(ctx.http)
      .post(`/v1/me/terms?app=${app}`)
      .set(user.auth)
      .set('user-agent', 'TaraLivreur/1.0 (Android)')
      .send({ challengeId, code, versions, installationId: 'installation-signature' });
  }

  it('publie le texte complet de chaque document, sans compte', async () => {
    const res = await request(ctx.http).get('/v1/legal/expediteurs').expect(200);
    expect(res.body).toMatchObject({ document: 'expediteurs', version: VERSION });
    expect(res.body.title).toContain('expéditeurs');
    expect(res.body.markdown).toContain('pas de paiement, pas de colis');
    await request(ctx.http).get('/v1/legal/livreurs').expect(200);
    await request(ctx.http).get('/v1/legal/inconnu').expect(404);
  });

  it('signe l’inscription : textes en vigueur, code SMS, preuve gardée', async () => {
    const phone = randomPhone();
    const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
    const body = {
      challengeId: challenge.body.challengeId,
      code: otpFrom(ctx.sms, phone),
      device: { installationId: 'installation-inscription', platform: 'ANDROID' },
    };
    const verify = (terms: Record<string, string>) =>
      request(ctx.http)
        .post('/v1/auth/otp/verify')
        .set('user-agent', 'TaraClient/1.0 (Android)')
        .send({ ...body, terms });

    // Texte périmé, confidentialité oubliée, deux apps à la fois : refusés, code intact.
    expect((await verify({ ...CLIENT_TERMS, expediteurs: '2000-01' })).status).toBe(409);
    expect((await verify({ expediteurs: VERSION })).body.error.code).toBe('TERMS_OUTDATED');
    expect((await verify({ ...CLIENT_TERMS, ...RIDER_TERMS })).status).toBe(409);

    const accepted = await verify(CLIENT_TERMS).expect(200);
    const consents = await ctx.prisma.consent.findMany({
      where: { userId: accepted.body.user.id },
      orderBy: { kind: 'asc' },
    });
    expect(consents).toEqual([
      expect.objectContaining({
        kind: 'TERMS',
        version: `expediteurs:${VERSION}`,
        installationId: 'installation-inscription',
        userAgent: 'TaraClient/1.0 (Android)',
        ip: expect.any(String),
      }),
      expect.objectContaining({
        kind: 'PRIVACY',
        version: `confidentialite:${LEGAL_TEXTS.confidentialite.version}`,
      }),
    ]);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'terms.accepted', entityId: accepted.body.user.id },
    });
    expect(audit?.after).toMatchObject({ signup: true });
  });

  it('demande les conditions des livreurs à un expéditeur qui ouvre l’app livreur', async () => {
    const user = await signIn(ctx);
    const client = await request(ctx.http)
      .get('/v1/me/terms?app=client')
      .set(user.auth)
      .expect(200);
    expect(client.body.required).toEqual([]);
    expect(client.body.accepted).toEqual(
      expect.arrayContaining([
        { document: 'expediteurs', version: VERSION, acceptedAt: expect.any(String) },
      ]),
    );

    const rider = await request(ctx.http).get('/v1/me/terms?app=rider').set(user.auth).expect(200);
    expect(rider.body.required).toEqual([
      { document: 'livreurs', version: LEGAL_TEXTS.livreurs.version },
    ]);

    // Mauvais code, puis version qui n'est pas celle en vigueur : rien n'est enregistré.
    const challengeId = await signatureCode(user);
    const good = otpFrom(ctx.sms, user.phone);
    const wrong = await sign(
      user,
      'rider',
      challengeId,
      RIDER_TERMS,
      good === '000000' ? '111111' : '000000',
    );
    expect(wrong.body.error.code).toBe('OTP_INVALID');
    const outdated = await sign(user, 'rider', challengeId, { livreurs: '2000-01' });
    expect(outdated.status).toBe(409);
    expect(outdated.body.error.code).toBe('TERMS_OUTDATED');
    expect(await ctx.prisma.consent.count({ where: { userId: user.userId } })).toBe(2);

    await sign(user, 'rider', challengeId, RIDER_TERMS).expect(204);
    // Le code ne signe qu'une fois.
    await sign(user, 'rider', challengeId, RIDER_TERMS).expect(400);
    const after = await request(ctx.http).get('/v1/me/terms?app=rider').set(user.auth).expect(200);
    expect(after.body.required).toEqual([]);
    const signed = await ctx.prisma.consent.findFirst({
      where: { userId: user.userId, version: `livreurs:${LEGAL_TEXTS.livreurs.version}` },
    });
    expect(signed).toMatchObject({
      kind: 'TERMS',
      installationId: 'installation-signature',
      userAgent: 'TaraLivreur/1.0 (Android)',
    });
  });

  it('bloque les nouvelles commandes jusqu’à l’acceptation d’une nouvelle version', async () => {
    const shop = await merchant(ctx);
    await outdate(shop.userId, 'expediteurs');
    const refused = await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        dropoffAddressId: shop.dropoffId,
        recipientName: 'Client',
        recipientPhone: randomPhone(),
        packageSize: 'M',
        feePaymentMethod: 'CASH',
      })
      .expect(403);
    expect(refused.body.error.code).toBe('TERMS_ACCEPTANCE_REQUIRED');

    await sign(shop, 'client', await signatureCode(shop), { expediteurs: VERSION }).expect(204);
    await placeOrder(ctx, shop);
  });

  it('refuse les conditions par la route des consentements (sans code SMS)', async () => {
    const user = await signIn(ctx);
    await request(ctx.http)
      .post('/v1/me/consents')
      .set(user.auth)
      .send({ kind: 'TERMS', version: `livreurs:${LEGAL_TEXTS.livreurs.version}`, granted: true })
      .expect(400);
  });

  it('garde hors ligne le livreur qui n’a pas signé la nouvelle version', async () => {
    const rider = await activeRider(ctx);
    await outdate(rider.userId, 'livreurs');
    const res = await request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: true, ...nearAkwa(0) })
      .expect(422);
    expect(res.body.error.code).toBe('RIDER_NOT_ELIGIBLE');
    const state = await request(ctx.http).get('/v1/rider/presence').set(rider.auth).expect(200);
    expect(state.body.blockers).toEqual(['TERMS']);

    const challengeId = await signatureCode(rider);
    await sign(rider, 'rider', challengeId, { livreurs: LEGAL_TEXTS.livreurs.version }).expect(204);
    await request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: true, ...nearAkwa(0) })
      .expect(200);
  });

  it('n’envoie pas d’offre au livreur en ligne quand une nouvelle version paraît', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    await request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: true, ...nearAkwa(0.001) })
      .expect(200);
    await outdate(rider.userId, 'livreurs');
    const order = await placeOrder(ctx, shop);
    const offers = await ctx.prisma.dispatchOffer.findMany({
      where: { orderId: order.id, riderId: rider.riderId },
    });
    expect(offers).toEqual([]);
    const id = randomUUID();
    await request(ctx.http).post(`/v1/rider/offers/${id}/accept`).set(rider.auth).expect(403);
  });
});
