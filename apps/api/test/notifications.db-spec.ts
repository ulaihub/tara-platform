import { createHmac } from 'node:crypto';
import request from 'supertest';
import { NotificationService } from '../src/notifications/notification.service.js';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import {
  type FakeWhatsAppProvider,
  WHATSAPP_PROVIDER,
} from '../src/notifications/whatsapp.provider.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, placeOrder, setupDouala, type TestMerchant } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

describe('Notifications push, WhatsApp et SMS (F3)', () => {
  describe('WhatsApp d’abord, SMS en repli', () => {
    let ctx: TestContext;
    let admin: SignedIn;
    let shop: TestMerchant;
    let whatsapp: FakeWhatsAppProvider;

    beforeAll(async () => {
      ctx = await createTestApp({ WHATSAPP_PROVIDER: 'fake' });
      admin = await staffUser(ctx, ['ADMIN']);
      await setupDouala(ctx, admin);
      shop = await merchant(ctx);
      whatsapp = ctx.app.get<FakeWhatsAppProvider>(WHATSAPP_PROVIDER);
    });
    afterAll(async () => {
      await ctx.app.close();
    });

    it('envoie la confirmation au destinataire par WhatsApp, avec le modèle approuvé', async () => {
      const order = await placeOrder(ctx, shop);
      expect(whatsapp.lastTo(order.recipientPhone)).toMatchObject({
        template: 'tara_recipient_confirmation',
        locale: 'fr',
        parameters: [
          expect.stringContaining('Boutique'),
          order.reference,
          expect.stringContaining('/t/'),
        ],
      });
      expect(ctx.sms.lastTo(order.recipientPhone)).toBeUndefined();
      const sent = await ctx.prisma.notification.findFirstOrThrow({ where: { orderId: order.id } });
      expect(sent).toMatchObject({
        channel: 'WHATSAPP',
        status: 'SENT',
        provider: 'fake-whatsapp',
      });
    });

    it('bascule sur SMS quand le numéro n’a pas WhatsApp', async () => {
      const phone = '+237655000111';
      whatsapp.failingNumbers.add(phone);
      const order = await placeOrder(ctx, shop, { recipientPhone: phone });
      expect(ctx.sms.lastTo(phone)?.text).toContain(order.reference);
      const rows = await ctx.prisma.notification.findMany({
        where: { orderId: order.id },
        orderBy: { createdAt: 'asc' },
      });
      expect(rows.map((row) => [row.channel, row.status])).toEqual([
        ['WHATSAPP', 'FAILED'],
        ['SMS', 'SENT'],
      ]);
      expect(rows[1]?.fallbackForId).toBe(rows[0]?.id);
    });

    it('n’enregistre jamais le code de livraison en clair', async () => {
      const notifications = ctx.app.get(NotificationService);
      await notifications.toPhone({
        phone: '+237655000222',
        template: 'DELIVERY_CODE',
        locale: 'fr',
        params: { reference: 'TR-TEST01', url: 'https://tara.test/t/x' },
        secretParams: { code: '4821' },
      });
      expect(whatsapp.lastTo('+237655000222')?.parameters).toEqual([
        'TR-TEST01',
        '4821',
        'https://tara.test/t/x',
      ]);
      const row = await ctx.prisma.notification.findFirstOrThrow({
        where: { recipientPhone: '+237655000222' },
      });
      expect(JSON.stringify(row.payload)).not.toContain('4821');
    });
  });

  describe('accusés de remise WhatsApp (webhook)', () => {
    const secret = 'secret-app-meta-de-test-0123456789';
    const verifyToken = 'jeton-de-verification-0123456789';
    let ctx: TestContext;

    beforeAll(async () => {
      ctx = await createTestApp({
        WHATSAPP_PROVIDER: 'meta',
        WHATSAPP_PHONE_NUMBER_ID: '123456789',
        WHATSAPP_ACCESS_TOKEN: 'jeton-non-utilise',
        WHATSAPP_API_VERSION: 'v23.0',
        WHATSAPP_APP_SECRET: secret,
        WHATSAPP_VERIFY_TOKEN: verifyToken,
      });
    });
    afterAll(async () => {
      await ctx.app.close();
    });

    function signed(body: object): { raw: string; signature: string } {
      const raw = JSON.stringify(body);
      return { raw, signature: `sha256=${createHmac('sha256', secret).update(raw).digest('hex')}` };
    }

    it('répond à la vérification de Meta avec le bon jeton seulement', async () => {
      const ok = await request(ctx.http)
        .get('/v1/webhooks/whatsapp')
        .query({
          'hub.mode': 'subscribe',
          'hub.verify_token': verifyToken,
          'hub.challenge': '1158201444',
        })
        .expect(200);
      expect(ok.text).toBe('1158201444');
      await request(ctx.http)
        .get('/v1/webhooks/whatsapp')
        .query({
          'hub.mode': 'subscribe',
          'hub.verify_token': 'mauvais-jeton-0000000',
          'hub.challenge': '1',
        })
        .expect(403);
    });

    it('refuse un accusé non signé et bascule sur SMS à l’accusé « failed »', async () => {
      const phone = '+237655000333';
      const original = await ctx.prisma.notification.create({
        data: {
          recipientPhone: phone,
          channel: 'WHATSAPP',
          template: 'DELIVERY_RECEIPT',
          payload: { params: { reference: 'TR-WEBHK1' } },
          status: 'SENT',
          provider: 'whatsapp-meta',
          providerReference: 'wamid.TEST-FAILED-1',
        },
      });
      const body = {
        entry: [
          {
            changes: [
              {
                value: {
                  statuses: [
                    {
                      id: 'wamid.TEST-FAILED-1',
                      status: 'failed',
                      errors: [{ code: 131026, title: 'Message undeliverable' }],
                    },
                  ],
                },
              },
            ],
          },
        ],
      };
      const { raw, signature } = signed(body);
      await request(ctx.http)
        .post('/v1/webhooks/whatsapp')
        .set('Content-Type', 'application/json')
        .set('X-Hub-Signature-256', 'sha256=00')
        .send(raw)
        .expect(401);
      await request(ctx.http)
        .post('/v1/webhooks/whatsapp')
        .set('Content-Type', 'application/json')
        .set('X-Hub-Signature-256', signature)
        .send(raw)
        .expect(200);
      // Accusé reçu deux fois : un seul SMS.
      await request(ctx.http)
        .post('/v1/webhooks/whatsapp')
        .set('Content-Type', 'application/json')
        .set('X-Hub-Signature-256', signature)
        .send(raw)
        .expect(200);

      const updated = await ctx.prisma.notification.findUniqueOrThrow({
        where: { id: original.id },
      });
      expect(updated).toMatchObject({
        status: 'FAILED',
        lastError: '131026 Message undeliverable',
      });
      const fallback = await ctx.prisma.notification.findFirstOrThrow({
        where: { fallbackForId: original.id },
      });
      expect(fallback).toMatchObject({ channel: 'SMS', status: 'SENT' });
      expect(ctx.sms.outbox.filter((sms) => sms.to === phone)).toHaveLength(1);
      expect(ctx.sms.lastTo(phone)?.text).toContain('TR-WEBHK1');
    });
  });

  describe('push', () => {
    let ctx: TestContext;

    beforeAll(async () => {
      ctx = await createTestApp();
    });
    afterAll(async () => {
      await ctx.app.close();
    });

    it('efface le jeton d’un appareil refusé par le service de notifications', async () => {
      const rider = await activeRider(ctx);
      const push = ctx.app.get<FakePushProvider>(PUSH_PROVIDER);
      push.invalidTokens.add(rider.pushToken);
      const notifications = ctx.app.get(NotificationService);
      const sent = await notifications.toUser(rider.userId, {
        template: 'ORDER_DELIVERED',
        params: { reference: 'TR-PUSH01' },
        data: { type: 'order.status' },
      });
      expect(sent).toBe(true);
      const device = await ctx.prisma.device.findFirstOrThrow({ where: { userId: rider.userId } });
      expect(device.pushToken).toBeNull();
      const row = await ctx.prisma.notification.findFirstOrThrow({
        where: { userId: rider.userId, channel: 'PUSH' },
      });
      expect(row.status).toBe('FAILED');
      // Plus d'appareil joignable : rien n'est créé.
      expect(
        await notifications.toUser(rider.userId, {
          template: 'ORDER_DELIVERED',
          params: { reference: 'TR-PUSH02' },
          data: {},
        }),
      ).toBe(false);
    });

    it('un jeton passe au dernier compte qui l’enregistre', async () => {
      const first = await activeRider(ctx);
      const second = await activeRider(ctx);
      await request(ctx.http)
        .put(`/v1/me/devices/${second.installationId}/push-token`)
        .set(second.auth)
        .send({ pushToken: first.pushToken })
        .expect(204);
      const devices = await ctx.prisma.device.findMany({ where: { pushToken: first.pushToken } });
      expect(devices.map((device) => device.userId)).toEqual([second.userId]);
      await request(ctx.http)
        .put('/v1/me/devices/inconnu-0000/push-token')
        .set(second.auth)
        .send({ pushToken: first.pushToken })
        .expect(404);
    });
  });
});
