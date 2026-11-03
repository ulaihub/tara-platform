import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createTestApp, otpFrom, randomPhone, signIn, type TestContext } from './helpers/app.js';

describe('Authentification par code SMS (A1)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('normalise le numéro et envoie un code à 6 chiffres', async () => {
    const local = randomPhone().slice(4); // 6XXXXXXXX
    const spaced = `${local.slice(0, 3)} ${local.slice(3, 5)} ${local.slice(5, 7)} ${local.slice(7)}`;
    const res = await request(ctx.http).post('/v1/auth/otp').send({ phone: spaced }).expect(201);
    expect(res.body).toMatchObject({ challengeId: expect.any(String), resendAfterSeconds: 60 });
    expect(ctx.sms.lastTo(`+237${local}`)?.text).toMatch(/code de connexion est \d{6}/);
  });

  it('refuse un numéro qui n’est pas un mobile camerounais, avec un message en anglais si demandé', async () => {
    const res = await request(ctx.http)
      .post('/v1/auth/otp')
      .set('Accept-Language', 'en-US,en;q=0.9')
      .send({ phone: '+33612345678' })
      .expect(400);
    expect(res.body.error).toMatchObject({
      code: 'VALIDATION_FAILED',
      message: 'Some data is invalid.',
    });
    expect(res.body.error.details).toEqual([{ path: 'phone', message: 'INVALID_PHONE' }]);
  });

  it('impose un délai entre deux demandes de code', async () => {
    const phone = randomPhone();
    await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
    const res = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(429);
    expect(res.body.error.code).toBe('OTP_REQUEST_TOO_SOON');
  });

  it('exige l’acceptation des conditions sans consommer le code', async () => {
    const phone = randomPhone();
    const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
    const body = {
      challengeId: challenge.body.challengeId,
      code: otpFrom(ctx.sms, phone),
      device: { installationId: randomUUID(), platform: 'ANDROID' },
    };
    const refused = await request(ctx.http).post('/v1/auth/otp/verify').send(body).expect(422);
    expect(refused.body.error.code).toBe('TERMS_REQUIRED');

    const accepted = await request(ctx.http)
      .post('/v1/auth/otp/verify')
      .send({ ...body, termsVersion: '2026-11' })
      .expect(200);
    expect(accepted.body).toMatchObject({ isNewUser: true, user: { phone, roles: ['CUSTOMER'] } });

    const consents = await ctx.prisma.consent.findMany({
      where: { userId: accepted.body.user.id },
    });
    expect(consents.map((c) => c.kind).sort()).toEqual(['PRIVACY', 'TERMS']);
  });

  it('bloque après 5 codes faux', async () => {
    const phone = randomPhone();
    const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
    const good = otpFrom(ctx.sms, phone);
    const wrong = good === '000000' ? '111111' : '000000';
    const attempt = (code: string) =>
      request(ctx.http)
        .post('/v1/auth/otp/verify')
        .send({
          challengeId: challenge.body.challengeId,
          code,
          device: { installationId: randomUUID(), platform: 'ANDROID' },
          termsVersion: '2026-11',
        });
    for (let i = 0; i < 4; i += 1) {
      expect((await attempt(wrong)).body.error.code).toBe('OTP_INVALID');
    }
    expect((await attempt(wrong)).status).toBe(429);
    expect((await attempt(good)).body.error.code).toBe('OTP_TOO_MANY_ATTEMPTS');
  });

  it('laisse la route de santé publique, hors préfixe /v1', async () => {
    const res = await request(ctx.http).get('/health').expect(200);
    expect(res.body).toEqual({ status: 'ok', checks: { database: 'up' } });
  });

  it('protège les routes et accepte le jeton d’accès', async () => {
    await request(ctx.http).get('/v1/me').expect(401);
    const session = await signIn(ctx);
    expect(session.accessToken.split('.')).toHaveLength(3);
  });

  it('fait tourner le jeton de rafraîchissement et détecte sa réutilisation', async () => {
    const session = await signIn(ctx);
    const first = await request(ctx.http)
      .post('/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(200);
    expect(first.body.refreshToken).not.toBe(session.refreshToken);

    // Réutiliser l'ancien jeton révoque toutes les sessions, y compris la nouvelle.
    await request(ctx.http)
      .post('/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(401);
    await request(ctx.http)
      .post('/v1/auth/refresh')
      .send({ refreshToken: first.body.refreshToken })
      .expect(401);
  });

  it('refuse un compte suspendu, même avec un jeton encore valide', async () => {
    const session = await signIn(ctx);
    await ctx.prisma.user.update({ where: { id: session.userId }, data: { status: 'SUSPENDED' } });
    const res = await request(ctx.http).get('/v1/me').set(session.auth).expect(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });
});
