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
  DOUALA_TRICYCLE_GRID,
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import {
  activeRider,
  goOnline,
  proofPhoto,
  RIDER_START_BALANCE,
  resetPresence,
  type TestRider,
} from './helpers/riders.js';

/**
 * Gros objets (frigo, cuisinière…) : prix de la grille tricycle, course proposée seulement aux
 * tricycles et voitures, refus d'un colis non conforme à l'enlèvement avec déplacement payé.
 * Un livreur qui a lancé un SOS ne reçoit plus de course.
 */
describe('Gros objets et livreurs en alerte', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;
  let shop: TestMerchant;
  let ledger: LedgerService;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    // Base partagée entre les fichiers de tests : aucune grille tricycle active au départ.
    await deactivateTricycleGrids();
    shop = await merchant(ctx);
    ledger = ctx.app.get(LedgerService);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await resetPresence();
    await deactivateTricycleGrids();
    await ctx.app.close();
  });

  async function deactivateTricycleGrids(): Promise<void> {
    await ctx.prisma.pricingGrid.updateMany({
      where: { city: 'Douala', vehicleType: 'TRICYCLE', active: true },
      data: { active: false },
    });
  }

  async function onlineRider(
    offset: number,
    vehicleType: 'MOTORBIKE' | 'TRICYCLE' | 'CAR',
  ): Promise<TestRider> {
    const rider = await activeRider(ctx);
    await ctx.prisma.riderProfile.update({ where: { id: rider.riderId }, data: { vehicleType } });
    await goOnline(ctx, rider, nearAkwa(offset));
    return rider;
  }

  async function pendingOffers(orderId: string) {
    return ctx.prisma.dispatchOffer.findMany({
      where: { orderId, outcome: 'PENDING' },
      orderBy: { approachMeters: 'asc' },
    });
  }

  async function candidates(orderId: string): Promise<Map<string, string[]>> {
    const res = await request(ctx.http)
      .get(`/v1/admin/orders/${orderId}/candidates`)
      .set(ops.auth)
      .expect(200);
    return new Map(
      (res.body as { riderId: string; ineligibleBecause: string[] }[]).map((c) => [
        c.riderId,
        c.ineligibleBecause,
      ]),
    );
  }

  const quote = (extra: Record<string, unknown>) =>
    request(ctx.http)
      .post('/v1/orders/quote')
      .set(shop.auth)
      .send({ pickup: PLACES.akwa, dropoff: PLACES.bonamoussadi, packageSize: 'BULKY', ...extra });

  it('annonce le prix tricycle, avec manutention à la demande, seulement si un tricycle roule', async () => {
    // Pas de grille tricycle : pas de gros objet dans cette ville (ni devis ni commande).
    const unavailable = await quote({}).expect(422);
    expect(unavailable.body.error).toMatchObject({ code: 'BULKY_UNAVAILABLE' });
    const refused = await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        dropoffAddressId: shop.dropoffId,
        recipientName: 'Client',
        recipientPhone: '+237677001122',
        packageSize: 'BULKY',
        feePaymentMethod: 'CASH',
      })
      .expect(422);
    expect(refused.body.error.code).toBe('BULKY_UNAVAILABLE');

    await request(ctx.http)
      .post('/v1/admin/pricing-grids')
      .set(admin.auth)
      .send(DOUALA_TRICYCLE_GRID)
      .expect(201);

    const plain = await quote({}).expect(200);
    expect(plain.body).toMatchObject({
      vehicleType: 'TRICYCLE',
      basePrice: 4500,
      surcharges: [],
      totalPrice: 4500,
      retryFee: 1500,
      returnFee: 2250,
    });
    const helped = await quote({ loadingHelp: true }).expect(200);
    expect(helped.body).toMatchObject({
      vehicleType: 'TRICYCLE',
      surcharges: [{ code: 'HANDLING', amount: 1500 }],
      totalPrice: 6000,
    });

    // Un colis ordinaire reste à moto, au prix moto, même avec la case cochée.
    const parcel = await quote({ packageSize: 'L', loadingHelp: true }).expect(200);
    expect(parcel.body).toMatchObject({ vehicleType: 'MOTORBIKE', basePrice: 1500 });
    // (La grille moto peut ajouter son supplément de nuit selon l'heure du test.)
    expect(parcel.body.surcharges).not.toContainEqual(
      expect.objectContaining({ code: 'HANDLING' }),
    );
  });

  it('propose un gros objet au tricycle seulement, jamais à une moto, même à la main', async () => {
    const moto = await onlineRider(0.001, 'MOTORBIKE');
    const tricycle = await onlineRider(0.006, 'TRICYCLE');
    const order = await placeOrder(ctx, shop, { packageSize: 'BULKY', loadingHelp: true });
    expect(order.status).toBe('SEARCHING_RIDER');

    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(stored).toMatchObject({ packageSize: 'BULKY', loadingHelp: true, totalPrice: 6000 });

    // La moto est plus proche, mais la course part au tricycle.
    const offers = await pendingOffers(order.id);
    expect(offers.map((offer) => offer.riderId)).toEqual([tricycle.riderId]);
    const listed = await request(ctx.http).get('/v1/rider/offers').set(tricycle.auth).expect(200);
    expect(listed.body[0]).toMatchObject({ orderId: order.id, loadingHelp: true });

    const byId = await candidates(order.id);
    expect(byId.get(moto.riderId)).toEqual(['VEHICLE']);
    expect(byId.get(tricycle.riderId)).toEqual(['PENDING_OFFER']);

    const manual = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(ops.auth)
      .send({ riderId: moto.riderId })
      .expect(422);
    expect(manual.body.error.code).toBe('VEHICLE_NOT_SUITABLE');

    // Une voiture peut le prendre.
    const car = await activeRider(ctx);
    await ctx.prisma.riderProfile.update({
      where: { id: car.riderId },
      data: { vehicleType: 'CAR' },
    });
    const assigned = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(ops.auth)
      .send({ riderId: car.riderId })
      .expect(200);
    expect(assigned.body).toMatchObject({ status: 'ASSIGNED', riderId: car.riderId });
  });

  it('ne propose aucune course à un livreur qui a un SOS ouvert', async () => {
    const inDanger = await onlineRider(0.001, 'MOTORBIKE');
    const safe = await onlineRider(0.008, 'MOTORBIKE');
    await ctx.prisma.safetyAlert.create({
      data: { riderId: inDanger.riderId, ...nearAkwa(0.001) },
    });
    const order = await placeOrder(ctx, shop);

    const offers = await pendingOffers(order.id);
    expect(offers.map((offer) => offer.riderId)).toEqual([safe.riderId]);
    const byId = await candidates(order.id);
    expect(byId.get(inDanger.riderId)).toEqual(['SAFETY_ALERT']);

    const manual = await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/assign`)
      .set(ops.auth)
      .send({ riderId: inDanger.riderId })
      .expect(422);
    expect(manual.body.error.code).toBe('RIDER_NOT_ELIGIBLE');

    // Alerte close : il redevient disponible.
    await ctx.prisma.safetyAlert.updateMany({
      where: { riderId: inDanger.riderId },
      data: { resolvedAt: new Date() },
    });
    const next = await placeOrder(ctx, shop);
    const [offer] = await pendingOffers(next.id);
    expect(offer?.riderId).toBe(inDanger.riderId);
  });

  it('colis non conforme : course annulée, photo gardée, déplacement payé par l’expéditeur', async () => {
    const tricycle = await onlineRider(0.002, 'TRICYCLE');
    const sender = await merchant(ctx);
    const order = await placeOrder(ctx, sender, { packageSize: 'BULKY' });
    const [offer] = await pendingOffers(order.id);
    expect(offer?.riderId).toBe(tricycle.riderId);
    await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(tricycle.auth)
      .expect(200);
    const merchantId = (await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } }))
      .merchantId;
    expect(merchantId).not.toBeNull();
    const shopBefore = await ledger.balance(merchantPayable(merchantId ?? ''));

    // Une photo est exigée.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/refuse-parcel`)
      .set(tricycle.auth)
      .send({ reason: 'TOO_HEAVY', ...nearAkwa(0) })
      .expect(400);

    const photoKey = await proofPhoto(ctx, tricycle);
    const body = {
      reason: 'TOO_HEAVY',
      note: 'Armoire 2 m, pas un frigo',
      photoKey,
      clientEventId: randomUUID(),
      ...nearAkwa(0),
    };
    const refused = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/refuse-parcel`)
      .set(tricycle.auth)
      .send(body)
      .expect(200);
    expect(refused.body.status).toBe('CANCELLED');
    // Renvoyée au retour du réseau : rien n'est facturé deux fois.
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/refuse-parcel`)
      .set(tricycle.auth)
      .send(body)
      .expect(200);

    const stored = await ctx.prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { proofs: true },
    });
    expect(stored.status).toBe('CANCELLED');
    expect(stored.cancelReason).toBe('Colis non conforme : trop lourd · Armoire 2 m, pas un frigo');
    expect(stored.proofs).toEqual([
      expect.objectContaining({ kind: 'PICKUP_REFUSED', photoKey, codeVerified: false }),
    ]);

    // L'expéditeur doit le déplacement (1 500 F) ; le livreur en touche 80 %.
    expect(await ledger.balance(merchantPayable(merchantId ?? ''))).toBe(shopBefore - 1500);
    expect(await ledger.balance(riderPayable(tricycle.riderId))).toBe(RIDER_START_BALANCE + 1200);

    // L'équipe voit le motif dans la fiche.
    const sheet = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}`)
      .set(ops.auth)
      .expect(200);
    expect(sheet.body.cancelReason).toContain('Colis non conforme');
    expect(sheet.body.proofs).toEqual([
      expect.objectContaining({ kind: 'PICKUP_REFUSED', hasPhoto: true }),
    ]);
  });

  it('commande payée d’avance : tout est rendu, sauf le déplacement', async () => {
    const tricycle = await onlineRider(0.002, 'TRICYCLE');
    const user = await signIn(ctx);
    const pickup = await createAddress(ctx, user, PLACES.akwa);
    const dropoff = await createAddress(ctx, user, PLACES.bonamoussadi);
    const sender: TestMerchant = { ...user, pickupId: pickup.id, dropoffId: dropoff.id };
    // Solde rechargé de 6 000 F par Mobile Money.
    const topUp = await request(ctx.http)
      .post('/v1/me/wallet/topup')
      .set(sender.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 6000, phone: sender.phone, operator: 'MTN' })
      .expect(201);
    const payment = await ctx.prisma.payment.findUniqueOrThrow({ where: { id: topUp.body.id } });
    const provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);
    const settled = await provider.settle(payment.providerReference ?? '', 'SUCCEEDED');
    await request(ctx.http)
      .post('/v1/webhooks/payments/fake')
      .set('Content-Type', 'application/json')
      .set('X-Fake-Signature', settled.signature)
      .send(settled.body)
      .expect(200);

    const order = await placeOrder(ctx, sender, {
      packageSize: 'BULKY',
      feePaymentMethod: 'WALLET',
    });
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(1500);
    const [offer] = await pendingOffers(order.id);
    await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(tricycle.auth)
      .expect(200);
    const photoKey = await proofPhoto(ctx, tricycle);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/refuse-parcel`)
      .set(tricycle.auth)
      .send({ reason: 'NOT_AS_DECLARED', photoKey, ...nearAkwa(0) })
      .expect(200);

    // 4 500 F rendus, 1 500 F de déplacement gardés : il reste 4 500 F.
    expect(await ledger.balance(customerWallet(sender.userId))).toBe(4500);
    expect(await ledger.balance(riderPayable(tricycle.riderId))).toBe(RIDER_START_BALANCE + 1200);
  });

  it('refuse le refus de colis une fois le colis enlevé', async () => {
    const tricycle = await onlineRider(0.002, 'TRICYCLE');
    const order = await placeOrder(ctx, shop, { packageSize: 'BULKY' });
    const [offer] = await pendingOffers(order.id);
    await request(ctx.http)
      .post(`/v1/rider/offers/${offer?.id}/accept`)
      .set(tricycle.auth)
      .expect(200);
    await request(ctx.http)
      .post(`/v1/admin/orders/${order.id}/transition`)
      .set(ops.auth)
      .send({ to: 'PICKED_UP' })
      .expect(200);

    const photoKey = await proofPhoto(ctx, tricycle);
    const res = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/refuse-parcel`)
      .set(tricycle.auth)
      .send({ reason: 'TOO_BIG', photoKey, ...nearAkwa(0) })
      .expect(409);
    expect(res.body.error.code).toBe('PARCEL_REFUSAL_NOT_ALLOWED');
  });
});
