import request from 'supertest';
import { NotificationService } from '../src/notifications/notification.service.js';
import {
  type FakeWhatsAppProvider,
  WHATSAPP_PROVIDER,
} from '../src/notifications/whatsapp.provider.js';
import {
  CLIENT_TERMS,
  createTestApp,
  otpFrom,
  randomPhone,
  type TestContext,
} from './helpers/app.js';

/** Empreinte de l'app Android connue du serveur (réglée par `tara apk`). */
const APP_HASH = 'FA+9qCX9VSu';

describe('Codes de connexion : empreinte Android dans le SMS, WhatsApp avec SMS en secours', () => {
  describe('SMS', () => {
    let ctx: TestContext;
    beforeAll(async () => {
      ctx = await createTestApp({ SMS_APP_HASHES: `${APP_HASH},AAAAAAAAAAA` });
    });
    afterAll(async () => {
      await ctx.app.close();
    });

    it('ajoute l’empreinte connue à la fin du SMS : Android remet le code à l’app', async () => {
      const phone = randomPhone();
      const res = await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone, appHash: APP_HASH })
        .expect(201);
      expect(res.body).toMatchObject({ channel: 'SMS', autoRead: true });
      const text = ctx.sms.lastTo(phone)?.text ?? '';
      expect(text.endsWith(`\n\n${APP_HASH}`)).toBe(true);
      // Limite du SMS Retriever : 140 octets.
      expect(Buffer.byteLength(text)).toBeLessThanOrEqual(140);
      const english = randomPhone();
      await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone: english, appHash: APP_HASH, locale: 'en' })
        .expect(201);
      expect(Buffer.byteLength(ctx.sms.lastTo(english)?.text ?? '')).toBeLessThanOrEqual(140);

      // Le code se vérifie comme avant.
      await request(ctx.http)
        .post('/v1/auth/otp/verify')
        .send({
          challengeId: res.body.challengeId,
          code: otpFrom(ctx.sms, phone),
          device: { installationId: 'installation-retriever', platform: 'ANDROID' },
          terms: CLIENT_TERMS,
        })
        .expect(200);
    });

    it('n’ajoute pas une empreinte inconnue (celle d’une autre app)', async () => {
      const phone = randomPhone();
      const res = await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone, appHash: 'Zz0Zz0Zz0Zz' })
        .expect(201);
      expect(res.body).toMatchObject({ channel: 'SMS', autoRead: false });
      expect(ctx.sms.lastTo(phone)?.text).not.toContain('Zz0Zz0Zz0Zz');
      await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone: randomPhone(), appHash: 'trop-court' })
        .expect(400);
    });
  });

  describe('WhatsApp', () => {
    let ctx: TestContext;
    let whatsapp: FakeWhatsAppProvider;
    let notifications: NotificationService;
    beforeAll(async () => {
      ctx = await createTestApp({
        WHATSAPP_PROVIDER: 'fake',
        WHATSAPP_OTP: 'true',
        SMS_APP_HASHES: APP_HASH,
      });
      whatsapp = ctx.app.get<FakeWhatsAppProvider>(WHATSAPP_PROVIDER);
      notifications = ctx.app.get(NotificationService);
    });
    afterAll(async () => {
      await ctx.app.close();
    });

    function lastReference(phone: string): string {
      const entry = whatsapp.outbox.filter((sent) => sent.to === phone).at(-1);
      if (!entry) throw new Error('Aucun message WhatsApp');
      return entry.reference;
    }

    it('envoie le code par WhatsApp (bouton « Copier le code »), sans SMS', async () => {
      const phone = randomPhone();
      const res = await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone, appHash: APP_HASH })
        .expect(201);
      expect(res.body).toMatchObject({ channel: 'WHATSAPP', autoRead: true });
      const message = whatsapp.lastTo(phone);
      expect(message).toMatchObject({ template: 'tara_otp', locale: 'fr' });
      const code = message?.parameters[0] ?? '';
      expect(code).toMatch(/^\d{6}$/);
      expect(message?.copyCode).toBe(code);
      expect(ctx.sms.lastTo(phone)).toBeUndefined();
      // Le code n'est pas gardé en clair dans le suivi des envois.
      const row = await ctx.prisma.notification.findFirst({
        where: { recipientPhone: phone, channel: 'WHATSAPP' },
      });
      expect(JSON.stringify(row?.payload)).not.toContain(code);

      await request(ctx.http)
        .post('/v1/auth/otp/verify')
        .send({
          challengeId: res.body.challengeId,
          code,
          device: { installationId: 'installation-whatsapp', platform: 'ANDROID' },
          terms: CLIENT_TERMS,
        })
        .expect(200);
    });

    it('passe au SMS si WhatsApp refuse, ou si l’utilisateur le demande', async () => {
      const refused = randomPhone();
      whatsapp.failingNumbers.add(refused);
      const res = await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone: refused, appHash: APP_HASH })
        .expect(201);
      expect(res.body).toMatchObject({ channel: 'SMS', autoRead: true });
      expect(ctx.sms.lastTo(refused)?.text).toContain(APP_HASH);

      const chosen = randomPhone();
      const sms = await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone: chosen, channel: 'SMS' })
        .expect(201);
      expect(sms.body).toMatchObject({ channel: 'SMS', autoRead: false });
      expect(whatsapp.lastTo(chosen)).toBeUndefined();
      otpFrom(ctx.sms, chosen);
    });

    it('envoie le SMS de secours quand Meta signale un échec, tant que le code est valable', async () => {
      const phone = randomPhone();
      await request(ctx.http).post('/v1/auth/otp').send({ phone, appHash: APP_HASH }).expect(201);
      const code = whatsapp.lastTo(phone)?.parameters[0];
      await notifications.whatsappStatus(lastReference(phone), 'failed', 'Numéro sans WhatsApp');
      const text = ctx.sms.lastTo(phone)?.text ?? '';
      expect(text).toContain(`${code}`);
      expect(text.endsWith(`\n\n${APP_HASH}`)).toBe(true);

      // Échec signalé après l'expiration du code : pas de SMS inutile.
      const late = randomPhone();
      await request(ctx.http).post('/v1/auth/otp').send({ phone: late }).expect(201);
      await ctx.prisma.notification.updateMany({
        where: { recipientPhone: late, channel: 'WHATSAPP' },
        data: { createdAt: new Date(Date.now() - 10 * 60_000) },
      });
      await notifications.whatsappStatus(lastReference(late), 'failed');
      expect(ctx.sms.lastTo(late)).toBeUndefined();
    });

    it('renvoie le code par SMS sans accusé « remis » de WhatsApp après 45 secondes', async () => {
      const silent = randomPhone();
      const delivered = randomPhone();
      await request(ctx.http)
        .post('/v1/auth/otp')
        .send({ phone: silent, appHash: APP_HASH })
        .expect(201);
      await request(ctx.http).post('/v1/auth/otp').send({ phone: delivered }).expect(201);
      const code = whatsapp.lastTo(silent)?.parameters[0];
      await notifications.whatsappStatus(lastReference(delivered), 'delivered');

      // Avant 45 s : on attend l'accusé.
      await notifications.watchWhatsAppCodes(new Date(Date.now() + 30_000));
      expect(ctx.sms.lastTo(silent)).toBeUndefined();

      await notifications.watchWhatsAppCodes(new Date(Date.now() + 50_000));
      const text = ctx.sms.lastTo(silent)?.text ?? '';
      expect(text).toContain(`${code}`);
      expect(text.endsWith(`\n\n${APP_HASH}`)).toBe(true);
      expect(ctx.sms.lastTo(delivered)).toBeUndefined();
      // Une seule fois, même si la surveillance repasse ou si Meta signale l'échec ensuite.
      await notifications.watchWhatsAppCodes(new Date(Date.now() + 65_000));
      await notifications.whatsappStatus(lastReference(silent), 'failed');
      expect(ctx.sms.outbox.filter((sms) => sms.to === silent)).toHaveLength(1);
      // L'accusé « remis » arrivé en retard est enregistré.
      await notifications.whatsappStatus(lastReference(silent), 'delivered');
      const row = await ctx.prisma.notification.findFirstOrThrow({
        where: { recipientPhone: silent, channel: 'WHATSAPP' },
      });
      expect(row.status).toBe('DELIVERED');
    });
  });
});
