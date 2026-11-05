import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type SignedIn, signIn, type TestContext } from './app.js';
import { createAddress, ensureDoualaServiceArea, PLACES } from './geo.js';

/** Grille du business plan (C2). */
export const DOUALA_GRID = {
  name: 'Douala moto',
  city: 'Douala',
  perKmBeyondLastTier: 150,
  tiers: [
    { upToMeters: 5_000, price: 1000 },
    { upToMeters: 10_000, price: 1500 },
    { upToMeters: 15_000, price: 2000 },
  ],
  surcharges: [
    { code: 'EXPRESS', amount: 500 },
    { code: 'NIGHT', amount: 500 },
    { code: 'FAILED_ATTEMPT', amount: 500 },
    { code: 'RETURN', percentBps: 5000 },
  ],
  activate: true,
};

/** Zone de service de Douala et grille active. */
export async function setupDouala(ctx: TestContext, admin: SignedIn): Promise<void> {
  await ensureDoualaServiceArea(ctx, admin);
  await request(ctx.http)
    .post('/v1/admin/pricing-grids')
    .set(admin.auth)
    .send(DOUALA_GRID)
    .expect(201);
}

export interface TestMerchant extends SignedIn {
  pickupId: string;
  dropoffId: string;
}

/** Boutique d'Akwa qui livre à Bonamoussadi (encaissement possible). */
export async function merchant(ctx: TestContext): Promise<TestMerchant> {
  const user = await signIn(ctx);
  await request(ctx.http)
    .put('/v1/me/merchant')
    .set(user.auth)
    .send({
      shopName: `Boutique ${randomUUID().slice(0, 4)}`,
      payoutPhone: '677000003',
      payoutOperator: 'MTN',
    })
    .expect(200);
  const pickup = await createAddress(ctx, user, PLACES.akwa, { label: 'Boutique' });
  const dropoff = await createAddress(ctx, user, PLACES.bonamoussadi, { contactName: 'Client' });
  return { ...user, pickupId: pickup.id, dropoffId: dropoff.id };
}

export interface PlacedOrder {
  id: string;
  reference: string;
  status: string;
  pickupCode: string;
  recipientPhone: string;
}

/** Commande payée en espèces : elle part tout de suite en recherche de livreur. */
export async function placeOrder(
  ctx: TestContext,
  sender: TestMerchant,
  extra: Record<string, unknown> = {},
): Promise<PlacedOrder> {
  const recipientPhone = `+2376${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
  const res = await request(ctx.http)
    .post('/v1/orders')
    .set(sender.auth)
    .send({
      pickupAddressId: sender.pickupId,
      dropoffAddressId: sender.dropoffId,
      recipientName: 'Client Bonamoussadi',
      recipientPhone,
      packageSize: 'M',
      feePaymentMethod: 'CASH',
      ...extra,
    })
    .expect(201);
  return {
    id: res.body.order.id,
    reference: res.body.order.reference,
    status: res.body.order.status,
    pickupCode: res.body.pickupCode,
    recipientPhone,
  };
}

/** Point à quelques centaines de mètres d'Akwa (0,001° ≈ 110 m). */
export function nearAkwa(offset: number): { latitude: number; longitude: number } {
  return { latitude: PLACES.akwa.latitude + offset, longitude: PLACES.akwa.longitude };
}
