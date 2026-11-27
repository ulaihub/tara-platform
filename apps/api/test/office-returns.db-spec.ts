import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
} from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../src/payments/payment.provider.js';
import { OfficeReturnsService } from '../src/returns/office-returns.service.js';
import { OrderSupportService } from '../src/rider-app/order-support.service.js';
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
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, proofPhoto, type TestRider } from './helpers/riders.js';

const HERE = nearAkwa(0.001);
const DAY = 86_400_000;
/** Bureau Tara par défaut (Bonabéri, valeurs réglables sur le serveur). */
const OFFICE = { latitude: 4.0717, longitude: 9.6625 };

/**
 * Retour du colis sans dette : le retour se paie d'avance (solde, puis Mobile Money) ; sans
 * paiement à temps, le colis part au bureau Tara, gardé 30 jours, rendu contre paiement
 * (dans l'app ou en espèces au bureau) ; jamais réclamé, Tara en dispose et rien n'est dû.
 * Aucun retour ne fait passer un solde sous zéro, rien n'est encaissé à la porte.
 */
describe('Retour du colis sans dette (bureau Tara)', () => {
  let ctx: TestContext;
  let ops: SignedIn;
  let ledger: LedgerService;
  let provider: FakePaymentProvider;
  let support: OrderSupportService;
  let office: OfficeReturnsService;

  beforeAll(async () => {
    ctx = await createTestApp();
    const admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    ledger = ctx.app.get(LedgerService);
    provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
    support = ctx.app.get(OrderSupportService);
    office = ctx.app.get(OfficeReturnsService);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

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

  const quote = (sender: SignedIn, placed: PlacedOrder) =>
    request(ctx.http).get(`/v1/orders/${placed.id}/return-quote`).set(sender.auth).expect(200);

  async function topUp(sender: SignedIn, amount: number): Promise<void> {
    const res = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(sender.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount, phone: sender.phone, operator: 'MTN' })
      .expect(201);
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: res.body.id } });
    const { body, signature } = await provider.settle(payment.providerReference ?? '', 'SUCCEEDED');
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', signature)
      .send(body)
      .expect(200);
  }

  /** Fin du compte à rebours sans paiement : le retour automatique passe. */
  async function timeOut(placed: PlacedOrder): Promise<void> {
    await ctx.prisma.order.update({
      where: { id: placed.id },
      data: { failedAt: new Date(Date.now() - 60 * 60_000) },
    });
    await support.sweepFailures();
  }

  async function dropAtOffice(placed: PlacedOrder, rider: TestRider) {
    const photoKey = await proofPhoto(ctx, rider);
    return request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/office-drop`)
      .set(rider.auth)
      .send({ photoKey, ...OFFICE })
      .expect(200);
  }

  const codeIn = (phone: string) =>
    /code[^:]*: (\d{4})/.exec(ctx.sms.lastTo(phone)?.text ?? '')?.[1] ?? '';

  it('solde suffisant : le retour est payé tout de suite, sans rien encaisser à la porte', async () => {
    const sender = await customer();
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, sender);
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    await topUp(sender, 5_000);
    await failAtTheDoor(placed, rider);

    // Annoncé avant de choisir : frais, part du solde, reste à payer.
    const before = await quote(sender, placed);
    expect(before.body).toEqual({ fee: stored.returnFee, fromBalance: stored.returnFee, toPay: 0 });

    await decide(sender, placed, 'RETURN').expect(204);
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(5_000 - stored.returnFee);
    const after = await quote(sender, placed);
    expect(after.body).toEqual({ fee: 0, fromBalance: 0, toPay: 0 });
    const seen = await request(ctx.http)
      .get(`/v1/orders/${placed.id}`)
      .set(sender.auth)
      .expect(200);
    expect(seen.body.failure.decision).toBe('RETURN');
    expect(seen.body.office).toBeNull();

    // Le retour payé ne peut plus être changé en autre chose par le support.
    const locked = await request(ctx.http)
      .post(`/v1/admin/orders/${placed.id}/failure-decision`)
      .set(ops.auth)
      .send({ decision: 'RETRY' })
      .expect(409);
    expect(locked.body.error.code).toBe('RETURN_ALREADY_PAID');
  });

  it('impayé à temps : colis au bureau, payé dans l’app, rendu contre le code de retrait', async () => {
    const sender = await customer();
    const rider = await activeRider(ctx);
    // Le destinataire devait payer la course : le retour la fait payer à l'expéditeur.
    const placed = await placeOrder(ctx, sender, { feePayer: 'RECIPIENT' });
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    const charges = stored.returnFee + stored.totalPrice;
    await failAtTheDoor(placed, rider);

    const unpaid = await decide(sender, placed, 'RETURN').expect(422);
    expect(unpaid.body.error).toMatchObject({
      code: 'RETURN_PAYMENT_REQUIRED',
      details: { amount: charges, fee: charges, fromBalance: 0 },
    });
    await timeOut(placed);

    // Le livreur va au bureau Tara, pas chez l'expéditeur.
    const job = await request(ctx.http)
      .get(`/v1/rider/orders/${placed.id}`)
      .set(rider.auth)
      .expect(200);
    expect(job.body.failureDecision).toBe('OFFICE');
    expect(job.body.office).toMatchObject({
      latitude: OFFICE.latitude,
      longitude: OFFICE.longitude,
    });
    expect(job.body.office.address).toContain('Bonabéri');
    expect(job.body.navigation.googleMaps).toContain(`${OFFICE.latitude},${OFFICE.longitude}`);
    const wrongPlace = await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/return`)
      .set(rider.auth)
      .send({ senderCode: '0000', ...HERE })
      .expect(409);
    expect(wrongPlace.body.error.code).toBe('OFFICE_DROP_REQUIRED');

    const dropped = await dropAtOffice(placed, rider);
    expect(dropped.body.status).toBe('HELD_AT_OFFICE');
    // Le livreur est payé pour le retour, comme avant.
    const paid = await ctx.prisma.journalEntry.findUnique({
      where: { idempotencyKey: `order:${placed.id}:complete` },
    });
    expect(paid).not.toBeNull();
    // Aucune dette : le solde de l'expéditeur reste à zéro, Tara attend les frais.
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);

    // L'expéditeur voit le bureau, le montant et la fin de la garde (30 jours) ; prévenu par SMS.
    const held = await request(ctx.http)
      .get(`/v1/orders/${placed.id}`)
      .set(sender.auth)
      .expect(200);
    expect(held.body.status).toBe('HELD_AT_OFFICE');
    expect(held.body.office).toMatchObject({ due: charges, paidAt: null });
    const until = new Date(held.body.office.until).getTime();
    expect(Math.round((until - new Date(held.body.office.heldSince).getTime()) / DAY)).toBe(30);
    expect(ctx.sms.lastTo(sender.phone)?.text).toContain('bureau Tara');
    // La page du destinataire ne montre aucun frais.
    const token = (held.body.trackingUrl as string).split('/t/')[1];
    const page = await request(ctx.http).get(`/v1/public/tracking/${token}`).expect(200);
    expect(page.body).toMatchObject({ status: 'HELD_AT_OFFICE', due: { total: 0 } });

    // L'équipe le voit dans sa liste.
    const list = await request(ctx.http).get('/v1/admin/office-returns').set(ops.auth).expect(200);
    expect(list.body.find((row: { orderId: string }) => row.orderId === placed.id)).toMatchObject({
      daysLeft: 30,
      due: charges,
      paidAt: null,
    });

    // Rien à remettre tant que ce n'est pas payé, même avec un code.
    const early = await request(ctx.http)
      .post(`/v1/admin/office-returns/${placed.id}/hand-over`)
      .set(ops.auth)
      .send({ code: '1234' })
      .expect(409);
    expect(early.body.error.code).toBe('OFFICE_PAYMENT_REQUIRED');

    // Paiement dans l'app : le solde d'abord, le reste par Mobile Money.
    await topUp(sender, 300);
    expect((await quote(sender, placed)).body).toEqual({
      fee: charges,
      fromBalance: 300,
      toPay: charges - 300,
    });
    const short = await request(ctx.http)
      .post(`/v1/orders/${placed.id}/office-payment`)
      .set(sender.auth)
      .expect(422);
    expect(short.body.error).toMatchObject({
      code: 'RETURN_PAYMENT_REQUIRED',
      details: { amount: charges - 300 },
    });
    await topUp(sender, charges - 300);
    await request(ctx.http)
      .post(`/v1/orders/${placed.id}/office-payment`)
      .set(sender.auth)
      .expect(204);
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);
    const code = codeIn(sender.phone);
    expect(code).toMatch(/^\d{4}$/);

    const wrong = await request(ctx.http)
      .post(`/v1/admin/office-returns/${placed.id}/hand-over`)
      .set(ops.auth)
      .send({ code: code === '0000' ? '1111' : '0000' })
      .expect(422);
    expect(wrong.body.error.code).toBe('PICKUP_CODE_INVALID');
    await request(ctx.http)
      .post(`/v1/admin/office-returns/${placed.id}/hand-over`)
      .set(ops.auth)
      .send({ code })
      .expect(204);
    const done = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    expect(done.status).toBe('RETURNED');
    // Tout ce que Tara avait avancé est rentré.
    const receivable = await ctx.prisma.ledgerPosting.aggregate({
      where: {
        entry: { orderId: placed.id },
        account: { code: PLATFORM_ACCOUNTS.officeReceivables.code },
      },
      _sum: { amount: true },
    });
    expect(receivable._sum.amount).toBe(0);
  });

  it('payé en espèces au bureau, et colis jamais réclamé : rien n’est dû', async () => {
    const sender = await customer();
    const rider = await activeRider(ctx);
    const cash = await placeOrder(ctx, sender);
    const forgotten = await placeOrder(ctx, sender);
    for (const placed of [cash, forgotten]) {
      await failAtTheDoor(placed, rider);
      await timeOut(placed);
      await dropAtOffice(placed, rider);
    }

    // Espèces au bureau : l'équipe confirme, le colis est rendu.
    await request(ctx.http)
      .post(`/v1/admin/office-returns/${cash.id}/hand-over`)
      .set(ops.auth)
      .send({ cashReceived: true })
      .expect(204);
    const returned = await ctx.prisma.order.findUniqueOrThrow({ where: { id: cash.id } });
    expect(returned.status).toBe('RETURNED');
    const counted = await ctx.prisma.journalEntry.findUniqueOrThrow({
      where: { idempotencyKey: `order:${cash.id}:office-paid` },
      include: { postings: { include: { account: true } } },
    });
    expect(
      counted.postings.find((p) => p.account.code === PLATFORM_ACCOUNTS.officeCash.code)?.amount,
    ).toBe(returned.officeDue);

    // Pas avant la fin de la garde…
    const tooSoon = await request(ctx.http)
      .post(`/v1/admin/office-returns/${forgotten.id}/unclaimed`)
      .set(ops.auth)
      .send({ note: 'Donné à une association' })
      .expect(409);
    expect(tooSoon.body.error.code).toBe('OFFICE_HOLD_NOT_OVER');
    // … puis Tara en dispose ; les frais sont abandonnés, l'expéditeur ne doit rien.
    await ctx.prisma.order.update({
      where: { id: forgotten.id },
      data: { officeUntil: new Date(Date.now() - 60_000) },
    });
    await request(ctx.http)
      .post(`/v1/admin/office-returns/${forgotten.id}/unclaimed`)
      .set(ops.auth)
      .send({ note: 'Donné à une association' })
      .expect(204);
    const gone = await ctx.prisma.order.findUniqueOrThrow({ where: { id: forgotten.id } });
    expect(gone.status).toBe('UNCLAIMED');
    expect(
      await ctx.prisma.journalEntry.findUnique({
        where: { idempotencyKey: `order:${forgotten.id}:office-written-off` },
      }),
    ).not.toBeNull();
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(0);
  });

  it('rappels à J+1, J+7, J+25, puis à la fin de la garde, une seule fois chacun', async () => {
    const sender = await customer();
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, sender);
    await failAtTheDoor(placed, rider);
    await timeOut(placed);
    await dropAtOffice(placed, rider);
    const held = await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } });
    const at = (days: number) => new Date((held.officeAt as Date).getTime() + days * DAY + 60_000);
    const mine = async (now: Date) => {
      await office.sendReminders(now);
      return (await ctx.prisma.order.findUniqueOrThrow({ where: { id: placed.id } }))
        .officeReminders;
    };

    expect(await mine(at(0))).toBe(0);
    expect(await mine(at(1))).toBe(1);
    expect(ctx.sms.lastTo(sender.phone)?.text).toContain('29 jours');
    expect(await mine(at(1))).toBe(1);
    expect(await mine(at(8))).toBe(2);
    expect(await mine(at(25))).toBe(3);
    expect(await mine(at(30))).toBe(4);
    expect(ctx.sms.lastTo(sender.phone)?.text).toContain('delai de garde');
    expect(await mine(at(40))).toBe(4);
  });

  it('boutique en dette : le retour ne s’ajoute jamais à la dette', async () => {
    const shop = await merchant(ctx);
    const profile = await ctx.prisma.merchantProfile.findUniqueOrThrow({
      where: { userId: shop.userId },
    });
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop);
    await failAtTheDoor(placed, rider);
    await decide(shop, placed, 'RETRY').expect(204);
    await go(placed, 'IN_DELIVERY');
    await go(placed, 'DELIVERY_FAILED', { failureReason: 'RECIPIENT_ABSENT' });
    expect(await ledger.balance(merchantPayable(profile.id))).toBe(-500);

    await decide(shop, placed, 'RETURN').expect(422);
    await timeOut(placed);
    await dropAtOffice(placed, rider);
    expect(await ledger.balance(merchantPayable(profile.id))).toBe(-500);
    expect(await ledger.balance(customerWallet(shop.userId))).toBe(0);
  });
});
