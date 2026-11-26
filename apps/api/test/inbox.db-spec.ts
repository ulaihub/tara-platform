import request from 'supertest';
import { NotificationService } from '../src/notifications/notification.service.js';
import { RetentionService } from '../src/privacy/retention.service.js';
import { createTestApp, signIn, type TestContext } from './helpers/app.js';

describe('Cloche de l’app : boîte de réception des notifications', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('garde les notifications même sans téléphone joignable, les lit et les marque lues', async () => {
    const user = await signIn(ctx);
    const other = await signIn(ctx);
    const notifications = ctx.app.get(NotificationService);
    const empty = await request(ctx.http).get('/v1/me/notifications').set(user.auth).expect(200);
    expect(empty.body).toEqual({ items: [], unread: 0 });

    // Aucun appareil enregistré : pas de push, mais la cloche la garde.
    const pushed = await notifications.toUser(user.userId, {
      template: 'ORDER_DELIVERED',
      params: { reference: 'TR-40001' },
      data: {},
    });
    expect(pushed).toBe(false);
    await notifications.toUser(user.userId, {
      template: 'PAYOUT_SENT',
      params: { amount: '128 500' },
      data: {},
    });
    // Une proposition de course ne vaut que 30 s : jamais dans la cloche.
    await notifications.toUser(user.userId, {
      template: 'OFFER_NEW',
      params: { pickup: 'Akwa', dropoff: 'Bonapriso', earning: '840' },
      data: {},
      urgent: true,
    });

    const inbox = await request(ctx.http).get('/v1/me/notifications').set(user.auth).expect(200);
    expect(inbox.body.unread).toBe(2);
    expect(inbox.body.items).toMatchObject([
      {
        kind: 'PAYOUT_SENT',
        title: 'Argent envoyé',
        body: '128 500 FCFA envoyés sur votre Mobile Money.',
        read: false,
      },
      { kind: 'ORDER_DELIVERED', title: 'Colis livré', body: 'Votre colis TR-40001 a été livré.' },
    ]);
    // Chacun ne voit que les siennes.
    const theirs = await request(ctx.http).get('/v1/me/notifications').set(other.auth).expect(200);
    expect(theirs.body.items).toEqual([]);

    // Une notification ouverte : seulement elle.
    await request(ctx.http)
      .post('/v1/me/notifications/read')
      .set(user.auth)
      .send({ ids: [inbox.body.items[1].id] })
      .expect(204);
    const one = await request(ctx.http).get('/v1/me/notifications').set(user.auth).expect(200);
    expect(one.body.unread).toBe(1);
    // Les notifications d'un autre compte ne bougent pas.
    await request(ctx.http)
      .post('/v1/me/notifications/read')
      .set(other.auth)
      .send({ ids: [inbox.body.items[0].id] })
      .expect(204);
    expect(
      (await request(ctx.http).get('/v1/me/notifications').set(user.auth).expect(200)).body.unread,
    ).toBe(1);
    await request(ctx.http).post('/v1/me/notifications/read').set(user.auth).send({}).expect(204);
    const read = await request(ctx.http).get('/v1/me/notifications').set(user.auth).expect(200);
    expect(read.body.unread).toBe(0);
    expect(read.body.items.every((item: { read: boolean }) => item.read)).toBe(true);

    // Effacées après 90 jours.
    await ctx.prisma.inboxItem.updateMany({
      where: { userId: user.userId },
      data: { createdAt: new Date(Date.now() - 91 * 86_400_000) },
    });
    const report = await ctx.app.get(RetentionService).run(new Date());
    expect(report.inboxItemsDeleted).toBeGreaterThanOrEqual(2);
    expect(await ctx.prisma.inboxItem.count({ where: { userId: user.userId } })).toBe(0);
  });
});
