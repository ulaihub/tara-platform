import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { customerWallet, merchantPayable, riderPayable } from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../src/payments/payment.provider.js';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import { createAddress, PLACES } from './helpers/geo.js';
import {
  merchant,
  nearAkwa,
  type PlacedOrder,
  placeOrder,
  RIDER_SHARE_BPS,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, type TestRider } from './helpers/riders.js';

const HERE = nearAkwa(0.001);

/**
 * Frais d'échec (E6) : nouvelle tentative (500 F) et retour (moitié du prix de base), figés à
 * la commande. La tentative est prise sur le solde jusqu'au plafond de dette, au-delà elle se
 * paie d'avance ; le retour se paie toujours d'avance, sans dette (voir office-returns).
 */
describe('Frais de nouvelle tentative et de retour (E6)', () => {
  let ctx: TestContext;
  let ops: SignedIn;
  let ledger: LedgerService;
  let provider: FakePaymentProvider;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  /** Particulier d'Akwa qui envoie à Bonamoussadi. */
  async function customer(): Promise<TestMerchant> {
    const user = await signIn(ctx);
    const pickup = await createAddress(ctx, user, PLACES.akwa);
    const dropoff = await createAddress(ctx, user, PLACES.bonamoussadi);
    return { ...user, pickupId: pickup.id, dropoffId: dropoff.id };
  }

  const go = (placed: PlacedOrder, to: string, extra: Record<string, unknown> = {}) =>
    request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/transition`)
      .set(ops.auth)
      .send({ to, ...extra })
      .expect(200);

  /** Colis enlevé (frais payés en espèces à l'enlèvement), puis échec à la porte. */
  async function failAtTheDoor(placed: PlacedOrder, rider: TestRider): Promise<void> {
    await go(placed, 'ASSIGNED', { riderId: rider.riderId });
    await go(placed, 'PICKED_UP');
    await go(placed, 'IN_DELIVERY');
    await go(placed, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' });
  }

  const decide = (sender: SignedIn, placed: PlacedOrder, decision: 'RETRY' | 'RETURN') =>
    request(ctx.http)
      .post(`/v1/orders/${placed.id}/failure-decision`)
      .set(sender.auth)
      .send({ decision });

  /** Code de retour envoyé par SMS à l'expéditeur au dernier échec. */
  const returnCode = (sender: SignedIn) =>
    /colis : (\d{4})/.exec(ctx.sms.lastTo(sender.phone)?.text ?? '')?.[1] ?? '';

  async function settle(paymentId: string): Promise<void> {
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    const { body, signature } = await provider.settle(payment.providerReference ?? '', 'SUCCEEDED');
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
  }

  it('particulier : frais annoncés, tentative payée d’avance, une seule, retour payé d’avance', async () => {
    const sender = await customer();
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, sender);

    // Annoncés et figés dès la commande.
    const seen = await request(ctx.http)
      .get(`/v1/orders/${placed.id}`)
      .set(sender.auth)
      .expect(200);
    const returnFee = Math.floor(seen.body.pricing.basePrice / 2);
    expect(seen.body.pricing).toMatchObject({ retryFee: 500, returnFee });

    await failAtTheDoor(placed, rider);
    const failed = await request(ctx.http)
      .get(`/v1/orders/${placed.id}`)
      .set(sender.auth)
      .expect(200);
    expect(failed.body.failure).toMatchObject({ retryAllowed: true, decision: null });

    // Solde vide : la tentative se paie d'abord (rien n'est enregistré).
    const refused = await decide(sender, placed, 'RETRY').expect(422);
    expect(refused.body.error).toMatchObject({ code: 'RETRY_PAYMENT_REQUIRED' });
    expect(refused.body.error.message).toContain('500');
    expect(refused.body.error.details).toEqual({ amount: 500 });
    const topUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(sender.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 500, phone: sender.phone, operator: 'MTN' })
      .expect(201);
    await settle(topUp.body.id);
    await decide(sender, placed, 'RETRY').expect(204);
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);

    // Deuxième échec : plus de nouvelle tentative, le colis revient.
    await go(placed, 'IN_DELIVERY');
    await go(placed, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' });
    const second = await request(ctx.http)
      .get(`/v1/orders/${placed.id}`)
      .set(sender.auth)
      .expect(200);
    expect(second.body.failure).toMatchObject({ retryAllowed: false });
    const limit = await decide(sender, placed, 'RETRY').expect(409);
    expect(limit.body.error.code).toBe('RETRY_LIMIT_REACHED');
    // Retour sans dette : solde vide, le retour se paie d'abord (rien n'est enregistré).
    const unpaid = await decide(sender, placed, 'RETURN').expect(422);
    expect(unpaid.body.error).toMatchObject({
      code: 'RETURN_PAYMENT_REQUIRED',
      details: { amount: returnFee, fee: returnFee, fromBalance: 0 },
    });
    const returnTopUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(sender.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: returnFee, phone: sender.phone, operator: 'MTN' })
      .expect(201);
    await settle(returnTopUp.body.id);
    await decide(sender, placed, 'RETURN').expect(204);
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);

    // Payé d'avance : rien à encaisser à la porte de l'expéditeur.
    const code = returnCode(sender);
    const due = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}/collection`)
      .set(rider.auth)
      .expect(200);
    expect(due.body).toMatchObject({ reason: 'RETURN', complete: true, due: { total: 0 } });
    const nothing = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(409);
    expect(nothing.body.error.code).toBe('COLLECTION_NOT_EXPECTED');
    // Le destinataire ne voit jamais ces frais.
    const token = (seen.body.trackingUrl as string).split('/t/')[1];
    const page = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(page.body.due).toEqual({ fee: 0, cod: 0, total: 0 });

    const returned = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/return`)
      .set(rider.auth)
      .send({ senderCode: code, ...HERE })
      .expect(200);
    expect(returned.body.status).toBe('RETURNED');

    // Rien dû par le particulier ; le livreur touche 80 % des frais d'échec en plus de la course.
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);
    const shared = await ctx.prisma.journalEntry.findUniqueOrThrow({
      where: { idempotencyKey: `order:${placed.id}:complete-fees` },
      include: { postings: { include: { account: true } } },
    });
    const riderPart = shared.postings.find(
      (p) => p.account.code === riderPayable(rider.riderId).code,
    );
    expect(riderPart?.amount).toBe(-Math.floor(((500 + returnFee) * RIDER_SHARE_BPS) / 10_000));
    const earnings = await request(ctx.http)
      .get('/v1/rider/earnings?period=day')
      .set(rider.auth)
      .expect(200);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    expect(earnings.body.earnings).toBe(stored.riderEarning - (riderPart?.amount ?? 0));
  });

  it('boutique : tentative prise jusqu’au plafond, mais le retour ne crée pas de dette', async () => {
    const shop = await merchant(ctx);
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: shop.userId },
    });
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });

    await failAtTheDoor(placed, rider);
    await decide(shop, placed, 'RETRY').expect(204);
    expect(await ledger.balance(merchantPayable(profile.id))).toBe(-500);
    await go(placed, 'IN_DELIVERY');
    await go(placed, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' });
    // Le plafond de dette ne sert plus pour un retour : il se paie d'avance.
    const unpaid = await decide(shop, placed, 'RETURN').expect(422);
    expect(unpaid.body.error.details).toMatchObject({ amount: stored.returnFee });
    const topUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(shop.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: stored.returnFee, phone: shop.phone, operator: 'MTN' })
      .expect(201);
    await settle(topUp.body.id);
    await decide(shop, placed, 'RETURN').expect(204);
    await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/return`)
      .set(rider.auth)
      .send({ senderCode: returnCode(shop), ...HERE })
      .expect(200);
    // La dette d'avant (la tentative) reste la même : le retour n'y a rien ajouté.
    expect(await ledger.balance(merchantPayable(profile.id))).toBe(-500);
    expect(await ledger.balance(customerWallet(shop.userId))).toBe(0);
  });
});
