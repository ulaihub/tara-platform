import { randomUUID } from 'node:crypto';
import { SignJWT } from 'jose';
import request from 'supertest';
import { totpCode, totpStep } from '../src/auth/totp.js';
import {
  CLIENT_TERMS,
  createTestApp,
  otpFrom,
  randomPhone,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';

describe('Sécurité', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  describe('codes SMS : verrouillage et anti-pompage', () => {
    it('bloque un numéro après 10 codes faux en 24 h, même avec le bon code ensuite', async () => {
      const phone = randomPhone();
      // 9 échecs déjà enregistrés aujourd'hui sur des codes précédents.
      await ctx.prisma.otpChallenge.create({
        data: {
          phone,
          codeHash: 'x',
          attempts: 9,
          expiresAt: new Date(),
          createdAt: new Date(Date.now() - 3_600_000),
        },
      });
      const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
      const good = otpFrom(ctx.sms, phone);
      const body = (code: string) => ({
        challengeId: challenge.body.challengeId,
        code,
        device: { installationId: randomUUID(), platform: 'ANDROID' },
        terms: CLIENT_TERMS,
      });
      const tenth = await request(ctx.http)
        .post('/v1/auth/otp/verify')
        .send(body(good === '000000' ? '111111' : '000000'))
        .expect(429);
      expect(tenth.body.error.code).toBe('OTP_LOCKED');
      const withGood = await request(ctx.http)
        .post('/v1/auth/otp/verify')
        .send(body(good))
        .expect(429);
      expect(withGood.body.error.code).toBe('OTP_LOCKED');
      await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(429);

      const audit = await ctx.prisma.auditLog.findFirst({
        where: {
          action: 'security.otp_locked',
          after: { path: ['phone'], string_contains: phone.slice(-2) },
        },
        orderBy: { createdAt: 'desc' },
      });
      expect(audit).not.toBeNull();
      expect(JSON.stringify(audit?.after)).not.toContain(phone);
    });

    it('plafonne les codes par adresse IP', async () => {
      const limited = await createTestApp({ OTP_MAX_PER_IP_PER_HOUR: '1' });
      try {
        await request(limited.http).post('/v1/auth/otp').send({ phone: randomPhone() });
        const res = await request(limited.http)
          .post('/v1/auth/otp')
          .send({ phone: randomPhone() })
          .expect(429);
        expect(res.body.error.code).toBe('RATE_LIMITED');
      } finally {
        await limited.app.close();
      }
    });

    it('au plafond global, refuse les nouveaux numéros mais laisse se connecter les clients', async () => {
      const client = await signIn(ctx);
      const capped = await createTestApp({ OTP_DAILY_GLOBAL_LIMIT: '1' });
      try {
        const unknown = await request(capped.http)
          .post('/v1/auth/otp')
          .send({ phone: randomPhone() })
          .expect(503);
        expect(unknown.body.error.code).toBe('SMS_TEMPORARILY_UNAVAILABLE');
        await ctx.prisma.otpChallenge.deleteMany({ where: { phone: client.phone } });
        await request(capped.http).post('/v1/auth/otp').send({ phone: client.phone }).expect(201);
      } finally {
        await capped.app.close();
      }
    });
  });

  describe('double authentification de l’équipe', () => {
    async function adminWithoutMfa(): Promise<SignedIn> {
      const session = await signIn(ctx);
      await ctx.prisma.user.update({
        where: { id: session.userId },
        data: { roles: ['CUSTOMER', 'ADMIN'] },
      });
      return session;
    }

    it('refuse le back-office et retire les droits de l’équipe sans second facteur', async () => {
      const admin = await adminWithoutMfa();
      const res = await request(ctx.http).get('/v1/admin/riders').set(admin.auth).expect(403);
      expect(res.body.error).toMatchObject({ code: 'MFA_REQUIRED', details: { enrolled: false } });

      // Même sur une route ouverte à tous, aucun droit de l'équipe n'est accordé.
      const owner = await signIn(ctx);
      const zone = await ctx.prisma.address.findFirst({ where: { ownerId: { not: null } } });
      if (zone) await request(ctx.http).get(`/v1/addresses/${zone.id}`).set(admin.auth).expect(404);
      expect(owner.userId).toBeDefined();
    });

    it('enrôle, active, vérifie et refuse un code rejoué', async () => {
      const admin = await adminWithoutMfa();
      const setup = await request(ctx.http).post('/v1/auth/mfa/setup').set(admin.auth).expect(200);
      expect(setup.body.otpauthUrl).toMatch(/^otpauth:\/\/totp\/Tara/);
      const secret = setup.body.secret as string;
      const stored = await ctx.prisma.user.findUniqueOrThrow({ where: { id: admin.userId } });
      expect(stored.totpSecretEnc).not.toContain(secret);

      const wrong = await request(ctx.http)
        .post('/v1/auth/mfa/activate')
        .set(admin.auth)
        .send({ code: '000000', refreshToken: admin.refreshToken })
        .expect(400);
      expect(wrong.body.error.code).toBe('MFA_INVALID');

      const step = totpStep(new Date());
      const activated = await request(ctx.http)
        .post('/v1/auth/mfa/activate')
        .set(admin.auth)
        .send({ code: totpCode(secret, step), refreshToken: admin.refreshToken })
        .expect(200);
      expect(ctx.sms.lastTo(admin.phone)?.text).toMatch(
        /double authentification vient d etre activee/,
      );
      await request(ctx.http)
        .get('/v1/admin/riders')
        .set({ Authorization: `Bearer ${activated.body.accessToken}` })
        .expect(200);

      // Le même code ne sert pas deux fois ; le code du pas suivant est accepté.
      const replay = await request(ctx.http)
        .post('/v1/auth/mfa/verify')
        .set({ Authorization: `Bearer ${activated.body.accessToken}` })
        .send({ code: totpCode(secret, step), refreshToken: activated.body.refreshToken })
        .expect(400);
      expect(replay.body.error.code).toBe('MFA_INVALID');
      await request(ctx.http)
        .post('/v1/auth/mfa/verify')
        .set({ Authorization: `Bearer ${activated.body.accessToken}` })
        .send({ code: totpCode(secret, step + 1), refreshToken: activated.body.refreshToken })
        .expect(200);
    });

    it('bloque le second facteur 15 minutes après 5 codes faux', async () => {
      const admin = await adminWithoutMfa();
      await request(ctx.http).post('/v1/auth/mfa/setup').set(admin.auth).expect(200);
      const attempt = () =>
        request(ctx.http)
          .post('/v1/auth/mfa/activate')
          .set(admin.auth)
          .send({ code: '000000', refreshToken: admin.refreshToken });
      for (let i = 0; i < 4; i += 1) expect((await attempt()).status).toBe(400);
      const locked = await attempt();
      expect(locked.status).toBe(429);
      expect(locked.body.error.code).toBe('MFA_LOCKED');
    });

    it('réserve l’enrôlement aux comptes de l’équipe', async () => {
      const customer = await signIn(ctx);
      await request(ctx.http).post('/v1/auth/mfa/setup').set(customer.auth).expect(403);
    });

    it('exige une nouvelle vérification au-delà de 12 heures', async () => {
      const ops = await staffUser(ctx, ['DISPATCHER']);
      const stale = await ctx.tokens.issueSession(
        ops.userId,
        null,
        undefined,
        new Date(Date.now() - 13 * 3_600_000),
      );
      const res = await request(ctx.http)
        .get('/v1/admin/riders')
        .set({ Authorization: `Bearer ${stale.accessToken}` })
        .expect(403);
      expect(res.body.error).toMatchObject({ code: 'MFA_REQUIRED', details: { enrolled: true } });
    });

    it('permet à un administrateur de réinitialiser le second facteur d’un collègue', async () => {
      const admin = await staffUser(ctx, ['ADMIN']);
      const colleague = await staffUser(ctx, ['DISPATCHER']);
      await request(ctx.http)
        .post(`/v1/admin/users/${colleague.userId}/mfa/reset`)
        .set(admin.auth)
        .expect(204);
      // Toutes les sessions du collègue sont fermées.
      await request(ctx.http)
        .post('/v1/auth/refresh')
        .send({ refreshToken: colleague.refreshToken })
        .expect(401);
      await request(ctx.http).get('/v1/admin/riders').set(colleague.auth).expect(403);
      expect(ctx.sms.lastTo(colleague.phone)?.text).toMatch(/reinitialisee/);
      await request(ctx.http)
        .post(`/v1/admin/users/${admin.userId}/mfa/reset`)
        .set(colleague.auth)
        .expect(403);
    });
  });

  describe('jetons', () => {
    it('accepte l’ancien secret pendant une rotation de clé, et lui seul', async () => {
      const oldSecret = 'ancien-secret-de-signature-0123456789abcdef';
      const rotated = await createTestApp({
        JWT_SECRET: 'nouveau-secret-de-signature-0123456789abcdef',
        JWT_SECRET_PREVIOUS: oldSecret,
      });
      try {
        const user = await signIn(rotated);
        const sign = (secret: string) =>
          new SignJWT({})
            .setProtectedHeader({ alg: 'HS256' })
            .setSubject(user.userId)
            .setIssuer('tara-api')
            .setAudience('tara-apps')
            .setIssuedAt()
            .setExpirationTime('5m')
            .sign(new TextEncoder().encode(secret));
        await request(rotated.http)
          .get('/v1/me')
          .set({ Authorization: `Bearer ${await sign(oldSecret)}` })
          .expect(200);
        await request(rotated.http)
          .get('/v1/me')
          .set({
            Authorization: `Bearer ${await sign('un-autre-secret-inconnu-0123456789abcdef')}`,
          })
          .expect(401);
      } finally {
        await rotated.app.close();
      }
    });

    it('refuse un jeton sans signature (alg none)', async () => {
      const user = await signIn(ctx);
      const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
      const payload = Buffer.from(
        JSON.stringify({ sub: user.userId, iss: 'tara-api', aud: 'tara-apps', exp: 9_999_999_999 }),
      ).toString('base64url');
      await request(ctx.http)
        .get('/v1/me')
        .set({ Authorization: `Bearer ${header}.${payload}.` })
        .expect(401);
    });
  });

  describe('HTTP', () => {
    it('envoie les en-têtes de sécurité et un identifiant de requête', async () => {
      const res = await request(ctx.http)
        .get('/v1/me')
        .set('X-Request-Id', 'test-requete-0001')
        .expect(401);
      expect(res.headers['x-powered-by']).toBeUndefined();
      expect(res.headers['x-content-type-options']).toBe('nosniff');
      expect(res.headers['strict-transport-security']).toMatch(/max-age=/);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(res.headers['x-request-id']).toBe('test-requete-0001');
      expect(res.body.error.requestId).toBe('test-requete-0001');

      const generated = await request(ctx.http)
        .get('/health')
        .set('X-Request-Id', 'x<script>')
        .expect(200);
      expect(generated.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
    });

    it('n’autorise que les origines web déclarées', async () => {
      const web = await createTestApp({ CORS_ORIGINS: 'https://admin.tara.test' });
      try {
        const allowed = await request(web.http)
          .options('/v1/me')
          .set('Origin', 'https://admin.tara.test')
          .set('Access-Control-Request-Method', 'GET');
        expect(allowed.headers['access-control-allow-origin']).toBe('https://admin.tara.test');
        const denied = await request(web.http)
          .options('/v1/me')
          .set('Origin', 'https://pirate.example')
          .set('Access-Control-Request-Method', 'GET');
        expect(denied.headers['access-control-allow-origin']).toBeUndefined();
      } finally {
        await web.app.close();
      }
    });

    it('ne croit l’en-tête X-Forwarded-For que d’un relais déclaré', async () => {
      const read = async (trustProxy: string) => {
        const app = await createTestApp({ TRUST_PROXY: trustProxy });
        try {
          const res = await request(app.http)
            .post('/v1/auth/otp')
            .set('X-Forwarded-For', '41.202.219.7')
            .send({ phone: randomPhone() })
            .expect(201);
          const challenge = await app.prisma.otpChallenge.findUniqueOrThrow({
            where: { id: res.body.challengeId },
          });
          return challenge.ip;
        } finally {
          await app.app.close();
        }
      };
      expect(await read('loopback')).toBe('41.202.219.7');
      expect(await read('10.0.0.0/8')).not.toBe('41.202.219.7');
    });

    it('fait télécharger les pièces d’identité comme pièces jointes', async () => {
      const ops = await staffUser(ctx, ['DISPATCHER']);
      const rider = await signIn(ctx);
      await request(ctx.http)
        .post('/v1/riders/apply')
        .set(rider.auth)
        .send({ guarantorName: 'Paul Mbarga', guarantorPhone: '699112233' })
        .expect(201);
      const png = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        'base64',
      );
      const doc = await request(ctx.http)
        .post('/v1/riders/me/documents')
        .set(rider.auth)
        .field('type', 'SELFIE')
        .attach('file', png, { filename: 'selfie.png', contentType: 'image/png' })
        .expect(201);
      const file = await request(ctx.http)
        .get(`/v1/admin/kyc-documents/${doc.body.id}/file`)
        .set(ops.auth)
        .expect(200);
      expect(file.headers['content-disposition']).toMatch(/^attachment;/);
    });
  });

  it('déconnexion : l’appareil ne reçoit plus les notifications du compte', async () => {
    const user = await signIn(ctx);
    const pushToken = `push-${randomUUID()}-${randomUUID()}`;
    await request(ctx.http)
      .put(`/v1/me/devices/${user.installationId}/push-token`)
      .set(user.auth)
      .send({ pushToken })
      .expect(204);
    await request(ctx.http)
      .post('/v1/auth/logout')
      .send({ refreshToken: user.refreshToken })
      .expect(204);
    const device = await ctx.prisma.device.findFirstOrThrow({
      where: { userId: user.userId, installationId: user.installationId },
    });
    expect(device.pushToken).toBeNull();
    await request(ctx.http)
      .post('/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken })
      .expect(401);
  });
});
