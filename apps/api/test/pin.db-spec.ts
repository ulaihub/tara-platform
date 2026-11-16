import request from 'supertest';
import {
  createTestApp,
  otpFrom,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { merchant, setupDouala } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

describe('Code secret (comme Orange Money et MTN MoMo) et empreinte digitale', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await setupDouala(ctx, await staffUser(ctx, ['ADMIN']));
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const setPin = (user: SignedIn, body: Record<string, string>) =>
    request(ctx.http).put('/v1/me/pin').set(user.auth).send(body);
  const verify = (user: SignedIn, body: Record<string, string>) =>
    request(ctx.http).post('/v1/me/pin/verify').set(user.auth).send(body);

  it('choisit un code, refuse les codes trop simples, le change avec l’ancien', async () => {
    const user = await signIn(ctx);
    const before = await request(ctx.http).get('/v1/me/pin').set(user.auth).expect(200);
    expect(before.body).toEqual({ set: false, locked: false, remainingAttempts: 5 });
    await verify(user, { pin: '2580' }).expect(403);

    for (const pin of ['1111', '1234', '9876', '0123']) {
      const refused = await setPin(user, { pin }).expect(400);
      expect(refused.body.error.code).toBe('PIN_TOO_SIMPLE');
    }
    await setPin(user, { pin: '12345' }).expect(400);
    await setPin(user, { pin: '2580' }).expect(204);
    const after = await request(ctx.http).get('/v1/me/pin').set(user.auth).expect(200);
    expect(after.body).toMatchObject({ set: true, locked: false });

    // Déjà choisi : le changer demande l'ancien.
    expect((await setPin(user, { pin: '1357' }).expect(403)).body.error.code).toBe('PIN_REQUIRED');
    await setPin(user, { pin: '1357', currentPin: '2580' }).expect(204);
    await verify(user, { pin: '1357' }).expect(204);

    const row = await ctx.prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
    expect(row.pinHash).toMatch(/^s1\$/);
    expect(row.pinHash).not.toContain('1357');
    const actions = await ctx.prisma.auditLog.findMany({
      where: { entityId: user.userId, action: { startsWith: 'pin.' } },
      select: { action: true },
    });
    expect(actions.map((entry) => entry.action).sort()).toEqual(['pin.changed', 'pin.set']);
  });

  it('bloque le code après 5 erreurs ; un code reçu par SMS permet d’en choisir un nouveau', async () => {
    const user = await signIn(ctx);
    await setPin(user, { pin: '2580' }).expect(204);
    for (const remaining of [4, 3, 2, 1]) {
      const wrong = await verify(user, { pin: '0000' }).expect(403);
      expect(wrong.body.error).toMatchObject({ code: 'PIN_INVALID' });
      expect(wrong.body.error.message).toContain(`Encore ${remaining} essai`);
    }
    const locked = await verify(user, { pin: '0000' }).expect(403);
    expect(locked.body.error.code).toBe('PIN_LOCKED');
    // Même le bon code ne passe plus.
    expect((await verify(user, { pin: '2580' })).body.error.code).toBe('PIN_LOCKED');
    expect((await request(ctx.http).get('/v1/me/pin').set(user.auth)).body).toMatchObject({
      locked: true,
      remainingAttempts: 0,
    });

    // Le délai de 60 s entre deux codes : le code de connexion vient d'être envoyé.
    await ctx.prisma.otpChallenge.deleteMany({ where: { phone: user.phone } });
    const challenge = await request(ctx.http)
      .post('/v1/me/pin/code')
      .set(user.auth)
      .send({})
      .expect(201);
    expect(challenge.body.channel).toBe('SMS');
    expect(ctx.sms.lastTo(user.phone)?.text).toContain('CHANGER votre code secret');
    await setPin(user, {
      pin: '4826',
      challengeId: challenge.body.challengeId,
      code: otpFrom(ctx.sms, user.phone),
    }).expect(204);
    await verify(user, { pin: '4826' }).expect(204);
    expect((await request(ctx.http).get('/v1/me/pin').set(user.auth)).body).toEqual({
      set: true,
      locked: false,
      remainingAttempts: 5,
    });
  });

  it('empreinte : une clé par téléphone, effacée quand le code change', async () => {
    const user = await signIn(ctx);
    const other = await signIn(ctx);
    const installationId = user.installationId ?? 'installation-empreinte';
    // Pas de code secret : pas d'empreinte.
    await request(ctx.http)
      .post('/v1/me/pin/biometric')
      .set(user.auth)
      .send({ pin: '2580', installationId })
      .expect(403);
    await setPin(user, { pin: '2580' }).expect(204);
    await request(ctx.http)
      .post('/v1/me/pin/biometric')
      .set(user.auth)
      .send({ pin: '0000', installationId })
      .expect(403);
    const enabled = await request(ctx.http)
      .post('/v1/me/pin/biometric')
      .set(user.auth)
      .send({ pin: '2580', installationId })
      .expect(201);
    const key = enabled.body.key as string;
    await verify(user, { biometricKey: key }).expect(204);
    expect((await verify(other, { biometricKey: key })).status).toBe(403);
    const stored = await ctx.prisma.pinDeviceKey.findFirstOrThrow({
      where: { userId: user.userId },
    });
    expect(stored.keyHash).not.toBe(key);

    // Code changé : l'empreinte est à réactiver.
    await setPin(user, { pin: '1357', currentPin: '2580' }).expect(204);
    const stale = await verify(user, { biometricKey: key }).expect(403);
    expect(stale.body.error.code).toBe('BIOMETRIC_INVALID');

    const again = await request(ctx.http)
      .post('/v1/me/pin/biometric')
      .set(user.auth)
      .send({ pin: '1357', installationId })
      .expect(201);
    await request(ctx.http)
      .delete(`/v1/me/pin/biometric?installationId=${installationId}`)
      .set(user.auth)
      .expect(204);
    await verify(user, { biometricKey: again.body.key as string }).expect(403);
  });

  it('retraits : exigent le code (ou l’empreinte) une fois choisi', async () => {
    const rider = await activeRider(ctx, { balance: 5_000 });
    const withdraw = (body: Record<string, unknown>, key: string) =>
      request(ctx.http)
        .post('/v1/rider/withdrawals')
        .set(rider.auth)
        .set('idempotency-key', key)
        .send({ phone: rider.phone, operator: 'MTN', amount: 1_000, ...body });
    await setPin(rider, { pin: '2580' }).expect(204);
    expect((await withdraw({}, 'retrait-sans-code')).body.error.code).toBe('PIN_REQUIRED');
    expect((await withdraw({ pin: '0000' }, 'retrait-faux-code')).body.error.code).toBe(
      'PIN_INVALID',
    );
    await withdraw({ pin: '2580' }, 'retrait-bon-code').expect(201);
    // La bonne réponse remet le compteur d'erreurs à zéro.
    expect((await request(ctx.http).get('/v1/me/pin').set(rider.auth)).body.remainingAttempts).toBe(
      5,
    );

    const shop = await merchant(ctx);
    await setPin(shop, { pin: '2580' }).expect(204);
    const payout = await request(ctx.http)
      .post('/v1/me/merchant/payouts')
      .set(shop.auth)
      .set('idempotency-key', 'reversement-sans-code')
      .send({});
    expect(payout.body.error.code).toBe('PIN_REQUIRED');

    // Sans code secret choisi (ancienne version de l'app) : rien ne change.
    const customer = await signIn(ctx);
    const refund = await request(ctx.http)
      .post('/v1/me/wallet/refund')
      .set(customer.auth)
      .set('idempotency-key', 'remboursement-sans-code')
      .send({ phone: customer.phone, operator: 'MTN' });
    expect(String(refund.body.error?.code ?? '')).not.toMatch(/^PIN_/);
  });

  it('supprime le compte avec le code secret, sans SMS', async () => {
    const user = await signIn(ctx);
    const noPin = await request(ctx.http).post('/v1/me/deletion').set(user.auth).send({});
    expect(noPin.body.error.code).toBe('PIN_NOT_SET');
    await setPin(user, { pin: '2580' }).expect(204);
    const wrong = await request(ctx.http)
      .post('/v1/me/deletion')
      .set(user.auth)
      .send({ pin: '0000' })
      .expect(403);
    expect(wrong.body.error.code).toBe('PIN_INVALID');
    await request(ctx.http)
      .post('/v1/me/deletion')
      .set(user.auth)
      .send({ pin: '2580' })
      .expect(204);
    const row = await ctx.prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
    expect(row).toMatchObject({ status: 'DELETED', pinHash: null });
  });
});
