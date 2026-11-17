import request from 'supertest';
import { hashCode } from '../src/common/crypto.js';
import { merchantPayable, PLATFORM_ACCOUNTS } from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import {
  createTestApp,
  randomPhone,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { createAddress, PLACES } from './helpers/geo.js';
import { merchant, setupDouala, type TestMerchant } from './helpers/orders.js';

const CODE_SECRET = 'test-code-secret-0123456789abcdef012345678';

interface PendingBody {
  id: string;
  batchNumber: number;
  status: string;
  blockedReason: string | null;
  linkUrl: string;
  orderId: string | null;
}

describe('Envoi en masse (C4) : 100 colis, clients qui placent eux-mêmes leur point', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  const parcel = (n: number, extra: Record<string, unknown> = {}) => ({
    recipientName: `Client ${n}`,
    recipientPhone: randomPhone(),
    packageSize: 'S',
    ...extra,
  });

  /** Ventes déjà encaissées par la boutique : de quoi payer ses courses par le solde. */
  async function fund(shop: TestMerchant, amount: number): Promise<void> {
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: shop.userId },
    });
    const ledger = ctx.app.get(LedgerService);
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'PAYMENT_RECEIVED',
        description: 'Ventes encaissées (test)',
        idempotencyKey: `test-fund:${shop.userId}:${amount}:${Date.now()}`,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount },
          { account: merchantPayable(profile.id), amount: -amount },
        ],
      }),
    );
  }

  /** Le client ouvre le lien reçu par SMS et place son point. */
  async function placePoint(url: string): Promise<void> {
    const token = url.split('/l/')[1] ?? '';
    await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.bonapriso, landmark: 'Face à la boulangerie' })
      .expect(200);
  }

  it('crée un envoi de 100 colis numérotés, avec un seul code, et refuse le 101e', async () => {
    const shop = await merchant(ctx);
    const items = Array.from({ length: 100 }, (_, i) =>
      parcel(i + 1, { dropoffAddressId: shop.dropoffId }),
    );
    const started = Date.now();
    const res = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({ pickupAddressId: shop.pickupId, feePaymentMethod: 'CASH', items })
      .expect(201);
    expect(Date.now() - started).toBeLessThan(25_000);
    expect(res.body.orders).toHaveLength(100);
    expect(res.body.pending).toEqual([]);
    expect(res.body.pickupCode).toMatch(/^\d{4}$/);
    const numbers = res.body.orders.map((o: { batchNumber: number }) => o.batchNumber);
    expect(numbers).toEqual(Array.from({ length: 100 }, (_, i) => i + 1));
    expect(new Set(res.body.orders.map((o: { batchSize: number }) => o.batchSize))).toEqual(
      new Set([100]),
    );
    // Rien n'est gardé en clair ni chiffré : aucun colis n'attend d'adresse.
    const batch = await ctx.prisma.orderBatch.findUniqueOrThrow({
      where: { id: res.body.batchId },
    });
    expect(batch.pickupCodeSealed).toBeNull();

    const tooMany = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({ pickupAddressId: shop.pickupId, feePaymentMethod: 'CASH', items: [...items, items[0]] })
      .expect(400);
    expect(tooMany.body.error.code).toBe('VALIDATION_FAILED');
  });

  it('donne le prix de toute la liste en un appel, erreur par colis', async () => {
    const shop = await merchant(ctx);
    const other = await signIn(ctx);
    const foreign = await createAddress(ctx, other, PLACES.bonapriso);
    const res = await request(ctx.http)
      .post('/v1/orders/quotes')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        items: [
          { dropoffAddressId: shop.dropoffId, packageSize: 'S' },
          { dropoffAddressId: foreign.id, packageSize: 'S' },
          { dropoffAddressId: shop.dropoffId, packageSize: 'M' },
        ],
      })
      .expect(200);
    const [first, second, third] = res.body.items;
    expect(first.quote.totalPrice).toBeGreaterThan(0);
    expect(second).toMatchObject({ quote: null, error: { code: 'ADDRESS_NOT_FOUND' } });
    expect(second.error.message).toBeTruthy();
    expect(res.body.totalPrice).toBe(first.quote.totalPrice + third.quote.totalPrice);
  });

  it('un colis sans adresse attend son client, puis part seul, payé par le solde, même code', async () => {
    const shop = await merchant(ctx);
    await fund(shop, 20_000);
    const awa = randomPhone();
    const res = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'WALLET',
        items: [
          parcel(1, { dropoffAddressId: shop.dropoffId }),
          parcel(2, { recipientName: 'Awa Bali', recipientPhone: awa, askAddress: true, codAmount: 15_000 }),
          parcel(3, { dropoffAddressId: shop.dropoffId }),
        ],
      })
      .expect(201);
    expect(res.body.orders.map((o: { batchNumber: number }) => o.batchNumber)).toEqual([1, 3]);
    expect(res.body.orders[0].batchSize).toBe(3);
    const [waiting] = res.body.pending as PendingBody[];
    expect(waiting).toMatchObject({ batchNumber: 2, status: 'WAITING', orderId: null });
    // Awa a reçu son lien par SMS, au nom de la boutique.
    const sms = ctx.sms.lastTo(awa)?.text ?? '';
    expect(sms).toContain('Indiquez ou le livrer');
    expect(sms).toContain(waiting?.linkUrl ?? '?');

    const listed = await request(ctx.http).get('/v1/orders/pending').set(shop.auth).expect(200);
    expect(listed.body.map((p: PendingBody) => p.id)).toEqual([waiting?.id]);

    await placePoint(waiting?.linkUrl ?? '');

    const after = await request(ctx.http)
      .get('/v1/orders/pending?open=false')
      .set(shop.auth)
      .expect(200);
    const released = (after.body as PendingBody[]).find((p) => p.id === waiting?.id);
    expect(released).toMatchObject({ status: 'RELEASED', orderId: expect.any(String) });
    const order = await ctx.prisma.order.findUniqueOrThrow({
      where: { id: released?.orderId ?? '' },
    });
    expect(order).toMatchObject({
      batchId: res.body.batchId,
      batchNumber: 2,
      recipientName: 'Awa Bali',
      codAmount: 15_000,
      status: 'SEARCHING_RIDER',
    });
    expect(order.feePaidAt).not.toBeNull();
    // Même code d'enlèvement que les autres colis de l'envoi.
    expect(order.pickupCodeHash).toBe(
      hashCode(CODE_SECRET, `pickup:${order.reference}`, res.body.pickupCode as string),
    );
    // Plus rien n'attend : le code chiffré est effacé.
    const batch = await ctx.prisma.orderBatch.findUniqueOrThrow({
      where: { id: res.body.batchId },
    });
    expect(batch.pickupCodeSealed).toBeNull();
    const dto = await request(ctx.http).get(`/v1/orders/${order.id}`).set(shop.auth).expect(200);
    expect(dto.body).toMatchObject({ batchNumber: 2, batchSize: 3 });
    expect(await request(ctx.http).get('/v1/orders/pending').set(shop.auth)).toMatchObject({
      body: [],
    });
  });

  it('solde insuffisant : le colis reste en attente avec la raison, puis part par Mobile Money', async () => {
    const shop = await merchant(ctx);
    const res = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'WALLET',
        items: [parcel(1, { askAddress: true })],
      })
      .expect(201);
    expect(res.body.orders).toEqual([]);
    const [waiting] = res.body.pending as PendingBody[];
    await placePoint(waiting?.linkUrl ?? '');

    const [blocked] = (await request(ctx.http).get('/v1/orders/pending').set(shop.auth).expect(200))
      .body as PendingBody[];
    expect(blocked).toMatchObject({ status: 'BLOCKED', blockedReason: 'INSUFFICIENT_BALANCE' });

    const retried = await request(ctx.http)
      .post(`/v1/orders/pending/${blocked?.id}/release`)
      .set(shop.auth)
      .send({ feePaymentMethod: 'MOMO_MTN' })
      .expect(200);
    expect(retried.body).toMatchObject({ status: 'RELEASED', blockedReason: null });
    const order = await ctx.prisma.order.findUniqueOrThrow({
      where: { id: retried.body.orderId as string },
    });
    // Commande créée, en attente du paiement Mobile Money de l'expéditeur.
    expect(order).toMatchObject({ status: 'CREATED', feePaymentMethod: 'MOMO_MTN', feePaidAt: null });
  });

  it('retirer, renvoyer le lien, garde-fous', async () => {
    const shop = await merchant(ctx);
    const res = await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'CASH',
        items: [parcel(1, { askAddress: true }), parcel(2, { askAddress: true })],
      })
      .expect(201);
    const [first, second] = res.body.pending as PendingBody[];

    // Un lien qui vient de partir n'est pas renvoyé tout de suite.
    const soon = await request(ctx.http)
      .post(`/v1/orders/pending/${first?.id}/resend`)
      .set(shop.auth)
      .expect(409);
    expect(soon.body.error.code).toBe('PENDING_RESEND_TOO_SOON');
    // Lien expiré : un nouveau lien part, l'ancien ne sert plus.
    const link = await ctx.prisma.pendingDelivery.findUniqueOrThrow({ where: { id: first?.id } });
    await ctx.prisma.locationLink.update({
      where: { id: link.locationLinkId },
      data: { expiresAt: new Date(Date.now() - 1000), createdAt: new Date(Date.now() - 4 * 86_400_000) },
    });
    const expired = await request(ctx.http).get('/v1/orders/pending').set(shop.auth).expect(200);
    expect((expired.body as PendingBody[]).find((p) => p.id === first?.id)?.status).toBe('EXPIRED');
    const resent = await request(ctx.http)
      .post(`/v1/orders/pending/${first?.id}/resend`)
      .set(shop.auth)
      .expect(200);
    expect(resent.body.status).toBe('WAITING');
    expect(resent.body.linkUrl).not.toBe(first?.linkUrl);

    // Retiré : le lien ne marche plus, le colis ne compte plus dans l'envoi.
    await request(ctx.http).post(`/v1/orders/pending/${second?.id}/cancel`).set(shop.auth).expect(200);
    const token = (second?.linkUrl ?? '').split('/l/')[1];
    await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.bonapriso, landmark: 'Trop tard' })
      .expect(410);
    await request(ctx.http).post(`/v1/orders/pending/${second?.id}/cancel`).set(shop.auth).expect(409);

    // Un autre compte ne voit ni ne touche ces colis.
    const other = await signIn(ctx);
    await request(ctx.http).post(`/v1/orders/pending/${first?.id}/cancel`).set(other.auth).expect(404);

    // Une adresse connue ET une demande d'adresse : refusé.
    await request(ctx.http)
      .post('/v1/orders/batch')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        feePaymentMethod: 'CASH',
        items: [parcel(1, { askAddress: true, dropoffAddressId: shop.dropoffId })],
      })
      .expect(400);
  });

  it('limite les liens envoyés par SMS par jour et par compte', async () => {
    const limited = await createTestApp({ PENDING_LINKS_DAILY_LIMIT: '2' });
    try {
      const shop = await merchant(limited);
      const res = await request(limited.http)
        .post('/v1/orders/batch')
        .set(shop.auth)
        .send({
          pickupAddressId: shop.pickupId,
          feePaymentMethod: 'CASH',
          items: [1, 2, 3].map((n) => parcel(n, { askAddress: true })),
        })
        .expect(422);
      expect(res.body.error).toMatchObject({ code: 'ADDRESS_REQUESTS_LIMIT' });
      expect(await limited.prisma.orderBatch.count({ where: { senderId: shop.userId } })).toBe(0);
    } finally {
      await limited.app.close();
    }
  });
});
