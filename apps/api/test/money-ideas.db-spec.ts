import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderPayable,
} from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { RiderOrdersService } from '../src/rider-app/rider-orders.service.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, proofPhoto, type TestRider } from './helpers/riders.js';

/**
 * Revenus validés par le fondateur : garantie de la valeur déclarée (A), frais d'annulation
 * quand le livreur est en route (C), frais d'attente au point d'enlèvement (D).
 */
describe('Garantie, annulation et attente payantes', () => {
  let ctx: TestContext;
  let shop: TestMerchant;
  let ops: SignedIn;
  let ledger: LedgerService;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    shop = await merchant(ctx);
  });

  /** Ventes encaissées pour la boutique, pour payer ses courses. */
  async function sales(who: TestMerchant, amount: number): Promise<void> {
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: who.userId },
    });
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'COD_COLLECTED',
        description: 'Ventes encaissées (test)',
        idempotencyKey: `test-sales:${profile.id}:${randomUUID()}`,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount },
          { account: merchantPayable(profile.id), amount: -amount },
        ],
      }),
    );
  }

  async function assignTo(orderId: string): Promise<TestRider> {
    const rider = await activeRider(ctx);
    await request(ctx.http)
      .post(`/v1/admin/orders/${orderId}/assign`)
      .set(ops.auth)
      .send({ riderId: rider.riderId })
      .expect(200);
    return rider;
  }

  async function assign(orderId: string): Promise<string> {
    return (await assignTo(orderId)).riderId;
  }

  const cancel = (who: SignedIn, orderId: string) =>
    request(ctx.http)
      .post(`/v1/orders/${orderId}/cancel`)
      .set(who.auth)
      .send({ reason: 'Client injoignable' });
  afterAll(async () => {
    await ctx.app.close();
  });

  describe('A · garantie de la valeur déclarée', () => {
    it('annoncée au devis, comprise dans le prix, tout pour Tara', async () => {
      const quote = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(shop.auth)
        .send({
          pickup: { addressId: shop.pickupId },
          dropoff: { addressId: shop.dropoffId },
          packageSize: 'S',
          declaredValue: 150_000,
        })
        .expect(200);
      const free = await request(ctx.http)
        .post('/v1/orders/quote')
        .set(shop.auth)
        .send({
          pickup: { addressId: shop.pickupId },
          dropoff: { addressId: shop.dropoffId },
          packageSize: 'S',
          declaredValue: 25_000,
        })
        .expect(200);
      expect(quote.body.valueFee).toBe(1250);
      expect(free.body.valueFee).toBe(0);
      expect(quote.body.totalPrice).toBe(free.body.totalPrice + 1250);

      const placed = await placeOrder(ctx, shop, { packageSize: 'S', declaredValue: 150_000 });
      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(stored.valueFee).toBe(1250);
      expect(stored.totalPrice).toBe(free.body.totalPrice + 1250);
      // La part du livreur ne change pas : la garantie revient à Tara, qui en porte le risque.
      const plain = await placeOrder(ctx, shop, { packageSize: 'S' });
      const plainStored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: plain.id } });
      expect(stored.riderEarning).toBe(plainStored.riderEarning);
      expect(stored.platformFee).toBe(plainStored.platformFee + 1250);

      const detail = await request(ctx.http)
        .get(`/v1/orders/${placed.id}`)
        .set(shop.auth)
        .expect(200);
      expect(detail.body.pricing.valueFee).toBe(1250);
    });

    it('envoi en masse : prix de chaque colis avec sa garantie', async () => {
      const res = await request(ctx.http)
        .post('/v1/orders/quotes')
        .set(shop.auth)
        .send({
          pickupAddressId: shop.pickupId,
          items: [
            { dropoffAddressId: shop.dropoffId, packageSize: 'S', declaredValue: 100_000 },
            { dropoffAddressId: shop.dropoffId, packageSize: 'S' },
          ],
        })
        .expect(200);
      expect(res.body.items.map((i: { quote: { valueFee: number } }) => i.quote.valueFee)).toEqual([
        750, 0,
      ]);
    });
  });

  describe('C · annulation quand le livreur est en route', () => {
    it('gratuite tant qu’aucun livreur n’a accepté', async () => {
      const placed = await placeOrder(ctx, shop);
      const detail = await request(ctx.http)
        .get(`/v1/orders/${placed.id}`)
        .set(shop.auth)
        .expect(200);
      expect(detail.body.pricing.cancellationFee).toBe(0);
      await cancel(shop, placed.id).expect(200);
      const fee = await ctx.prisma.journalEntry.findUnique({
        where: { idempotencyKey: `order:${placed.id}:cancel-fee` },
      });
      expect(fee).toBeNull();
    });

    it('300 F annoncés puis pris : 200 F au livreur, 100 F à Tara, le reste rendu', async () => {
      const other = await merchant(ctx);
      await sales(other, 5_000);
      const placed = await placeOrder(ctx, other, { feePaymentMethod: 'WALLET' });
      const order = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
        where: { userId: other.userId },
      });
      const riderId = await assign(placed.id);
      const detail = await request(ctx.http)
        .get(`/v1/orders/${placed.id}`)
        .set(other.auth)
        .expect(200);
      expect(detail.body.pricing.cancellationFee).toBe(300);
      const commission = await ledger.balance(PLATFORM_ACCOUNTS.commission);
      const riderBefore = await ledger.balance(riderPayable(riderId));

      await cancel(other, placed.id).expect(200);
      // Course rendue, 300 F gardés : 200 F au livreur, 100 F à Tara.
      expect(await ledger.balance(merchantPayable(profile.id))).toBe(5_000 - 300);
      expect(await ledger.balance(customerWallet(other.userId))).toBe(0);
      expect(await ledger.balance(riderPayable(riderId))).toBe(riderBefore + 200);
      expect(await ledger.balance(PLATFORM_ACCOUNTS.commission)).toBe(commission + 100);
      expect(order.totalPrice).toBeGreaterThan(300);
    });

    it('payée en espèces : les 300 F restent dus, rien si l’équipe annule', async () => {
      const person = await merchant(ctx);
      const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
        where: { userId: person.userId },
      });
      const placed = await placeOrder(ctx, person);
      await assign(placed.id);
      await cancel(person, placed.id).expect(200);
      // Rien de payé d'avance : les 300 F sont une petite dette sur les ventes.
      expect(await ledger.balance(merchantPayable(profile.id))).toBe(-300);

      const byOps = await placeOrder(ctx, person);
      await assign(byOps.id);
      await request(ctx.http)
        .post(`/v1/admin/orders/${byOps.id}/cancel`)
        .set(ops.auth)
        .send({ reason: 'Doublon' })
        .expect(200);
      const fee = await ctx.prisma.journalEntry.findUnique({
        where: { idempotencyKey: `order:${byOps.id}:cancel-fee` },
      });
      expect(fee).toBeNull();
    });
  });

  describe('D · attente au point d’enlèvement', () => {
    it('arrivée sur place seulement ; 17 min d’attente : 200 F, 140 F au livreur', async () => {
      const other = await merchant(ctx);
      await sales(other, 5_000);
      const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
        where: { userId: other.userId },
      });
      const placed = await placeOrder(ctx, other, { feePaymentMethod: 'WALLET' });
      const rider = await assignTo(placed.id);

      const far = await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/arrived`)
        .set(rider.auth)
        .send(nearAkwa(0.01))
        .expect(422);
      expect(far.body.error.code).toBe('NOT_AT_PICKUP');
      const arrived = await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/arrived`)
        .set(rider.auth)
        .send(nearAkwa(0.001))
        .expect(200);
      expect(arrived.body.arrivedPickupAt).toEqual(expect.any(String));
      const seen = await request(ctx.http)
        .get(`/v1/orders/${placed.id}`)
        .set(other.auth)
        .expect(200);
      expect(seen.body.pricing.riderArrivedAt).toBe(arrived.body.arrivedPickupAt);

      // Le livreur attend depuis 17 minutes : 10 gratuites, puis 2 tranches de 5 min.
      await ctx.prisma.order.update({
        where: { id: placed.id },
        data: { arrivedPickupAt: new Date(Date.now() - 17 * 60_000) },
      });
      const afterOrder = await ledger.balance(merchantPayable(profile.id));
      const riderBefore = await ledger.balance(riderPayable(rider.riderId));
      const commission = await ledger.balance(PLATFORM_ACCOUNTS.commission);
      const photoKey = await proofPhoto(ctx, rider);
      await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/pickup`)
        .set(rider.auth)
        .send({ pickupCode: placed.pickupCode, photoKey, ...nearAkwa(0.001) })
        .expect(200);

      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(stored.waitingFee).toBe(200);
      expect(await ledger.balance(merchantPayable(profile.id))).toBe(afterOrder - 200);
      expect(await ledger.balance(riderPayable(rider.riderId))).toBe(riderBefore + 140);
      expect(await ledger.balance(PLATFORM_ACCOUNTS.commission)).toBe(commission + 60);
    });

    it('enlevé dans les 10 minutes : rien à payer', async () => {
      const placed = await placeOrder(ctx, shop);
      const rider = await assignTo(placed.id);
      await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/arrived`)
        .set(rider.auth)
        .send(nearAkwa(0.001))
        .expect(200);
      const photoKey = await proofPhoto(ctx, rider);
      await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/pickup`)
        .set(rider.auth)
        .send({ pickupCode: placed.pickupCode, photoKey, ...nearAkwa(0.001) })
        .expect(200);
      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(stored.waitingFee).toBe(0);
    });
  });

  describe('D · expéditeur absent après 30 minutes', () => {
    it('prévenu à 25 min ; départ du livreur sur place après 2 appels : 700 F, 480 F pour lui', async () => {
      const other = await merchant(ctx);
      await sales(other, 5_000);
      const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
        where: { userId: other.userId },
      });
      const placed = await placeOrder(ctx, other, { feePaymentMethod: 'WALLET' });
      const rider = await assignTo(placed.id);
      await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/arrived`)
        .set(rider.auth)
        .send(nearAkwa(0.001))
        .expect(200);
      const absent = (body: object) =>
        request(ctx.http)
          .post(`/v1/rider/orders/${placed.id}/sender-absent`)
          .set(rider.auth)
          .send({ ...nearAkwa(0.001), ...body });

      const early = await absent({}).expect(422);
      expect(early.body.error.code).toBe('SENDER_ABSENT_TOO_EARLY');

      // 26 minutes d'attente : l'expéditeur est prévenu, une seule fois.
      const riders = ctx.app.get(RiderOrdersService);
      await ctx.prisma.order.update({
        where: { id: placed.id },
        data: { arrivedPickupAt: new Date(Date.now() - 26 * 60_000) },
      });
      await riders.warnLongWaits();
      const warned = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(warned.waitingWarnedAt).not.toBeNull();
      // Second passage : pas de nouvel avertissement, l'heure reste la même.
      expect(await riders.warnLongWaits()).toBe(0);
      const still = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(still.waitingWarnedAt).toEqual(warned.waitingWarnedAt);

      // 31 minutes : il faut encore les 2 appels, et être sur place.
      const arrivedAt = new Date(Date.now() - 31 * 60_000);
      await ctx.prisma.order.update({
        where: { id: placed.id },
        data: { arrivedPickupAt: arrivedAt },
      });
      const call = (minutes: number) => ({
        to: 'SENDER',
        at: new Date(arrivedAt.getTime() + minutes * 60_000).toISOString(),
        durationSeconds: 20,
      });
      const oneCall = await absent({ callLog: [call(5)] }).expect(422);
      expect(oneCall.body.error.code).toBe('SENDER_CALLS_REQUIRED');
      const far = await request(ctx.http)
        .post(`/v1/rider/orders/${placed.id}/sender-absent`)
        .set(rider.auth)
        .send({ ...nearAkwa(0.01), callLog: [call(5), call(15)] })
        .expect(422);
      expect(far.body.error.code).toBe('NOT_AT_PICKUP');

      const riderBefore = await ledger.balance(riderPayable(rider.riderId));
      const commission = await ledger.balance(PLATFORM_ACCOUNTS.commission);
      const salesBefore = await ledger.balance(merchantPayable(profile.id));
      const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      const left = await absent({ callLog: [call(5), call(15)] }).expect(200);
      expect(left.body.status).toBe('CANCELLED');

      // La course payée revient, puis 300 F d'annulation et 400 F d'attente sont pris.
      expect(await ledger.balance(merchantPayable(profile.id))).toBe(
        salesBefore + stored.totalPrice - 700,
      );
      expect(await ledger.balance(riderPayable(rider.riderId))).toBe(riderBefore + 480);
      expect(await ledger.balance(PLATFORM_ACCOUNTS.commission)).toBe(commission + 220);
      const proof = await ctx.prisma.deliveryProof.findFirstOrThrow({
        where: { orderId: placed.id, kind: 'SENDER_ABSENT' },
      });
      expect(proof.callLog).toHaveLength(2);
      const after = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
      expect(after.waitingFee).toBe(400);
    });
  });
});
