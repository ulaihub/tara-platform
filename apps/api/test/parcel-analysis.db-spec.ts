import request from 'supertest';
import {
  FakeParcelVision,
  PARCEL_VISION,
  ParcelVisionUnavailableError,
} from '../src/parcel-analysis/parcel-vision.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, resetPresence, TINY_JPEG } from './helpers/riders.js';

/**
 * Photo du colis analysée (C1) : taille, nature et fragilité proposées, objets interdits
 * signalés ; l'avertissement suit la commande jusqu'au livreur et à l'équipe.
 */
describe('Photo du colis analysée', () => {
  let ctx: TestContext;
  let ops: SignedIn;
  let shop: TestMerchant;
  let vision: FakeParcelVision;

  beforeAll(async () => {
    ctx = await createTestApp({ PARCEL_ANALYSIS_PER_HOUR: '3' });
    const admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    vision = ctx.app.get<FakeParcelVision>(PARCEL_VISION);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await resetPresence();
    await ctx.app.close();
  });

  async function photo(user: SignedIn): Promise<string> {
    const res = await request(ctx.http)
      .post('/v1/media')
      .set(user.auth)
      .field('kind', 'PARCEL_PHOTO')
      .attach('file', TINY_JPEG, { filename: 'colis.jpg', contentType: 'image/jpeg' })
      .expect(201);
    return res.body.key as string;
  }

  const analyze = (user: SignedIn, photoKey: string) =>
    request(ctx.http).post('/v1/orders/parcel-analysis').set(user.auth).send({ photoKey });

  it('propose taille, nature et fragilité ; une seule analyse par photo', async () => {
    const key = await photo(shop);
    vision.next = {
      is_parcel: true,
      size: 'BULKY',
      contents: 'HOUSEHOLD',
      description: '  Réfrigérateur 2 portes ',
      fragile: true,
      prohibited: [],
      confidence: 'high',
    };
    const calls = vision.calls.length;
    const first = await analyze(shop, key).expect(200);
    expect(first.body).toEqual({
      photoKey: key,
      isParcel: true,
      suggestion: {
        size: 'BULKY',
        contents: 'HOUSEHOLD',
        description: 'Réfrigérateur 2 portes',
        fragile: true,
      },
      prohibited: [],
      confidence: 'high',
    });
    expect(vision.calls.at(-1)?.buffer.equals(TINY_JPEG)).toBe(true);
    // Même photo : la première analyse est rendue, sans nouvel appel au modèle.
    const again = await analyze(shop, key).expect(200);
    expect(again.body).toEqual(first.body);
    expect(vision.calls.length).toBe(calls + 1);

    // La photo d'un autre n'est pas analysable.
    const other = await merchant(ctx);
    const refused = await analyze(other, key).expect(422);
    expect(refused.body.error.code).toBe('MEDIA_NOT_FOUND');
  });

  it('objet interdit vu sur la photo : signalé à la commande, au livreur et à l’équipe', async () => {
    const key = await photo(shop);
    vision.next = {
      is_parcel: true,
      size: 'L',
      contents: 'HOUSEHOLD',
      description: 'Bouteille de gaz',
      fragile: false,
      prohibited: ['DANGEROUS_GOODS', 'DANGEROUS_GOODS'],
      confidence: 'high',
    };
    const res = await analyze(shop, key).expect(200);
    expect(res.body.prohibited).toEqual([
      { code: 'DANGEROUS_GOODS', label: 'matière dangereuse (gaz, carburant…)' },
    ]);

    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.001));
    const order = await placeOrder(ctx, shop, { packageSize: 'L', parcelPhotoKey: key });
    const stored = await ctx.prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(stored).toMatchObject({
      parcelPhotoKey: key,
      parcelAiWarning: 'matière dangereuse (gaz, carburant…)',
    });

    const sheet = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}`)
      .set(ops.auth)
      .expect(200);
    expect(sheet.body.parcel).toMatchObject({
      hasPhoto: true,
      aiWarning: 'matière dangereuse (gaz, carburant…)',
    });

    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: order.id, outcome: 'PENDING' },
    });
    const accepted = await request(ctx.http)
      .post(`/v1/rider/offers/${offer.id}/accept`)
      .set(rider.auth)
      .expect(200);
    expect(accepted.body).toMatchObject({
      hasParcelPhoto: true,
      parcelWarning: 'matière dangereuse (gaz, carburant…)',
    });
    const image = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}/parcel-photo`)
      .set(rider.auth)
      .buffer(true)
      .parse((res, done) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => done(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect((image.body as Buffer).equals(TINY_JPEG)).toBe(true);
    expect(image.headers['content-type']).toBe('image/jpeg');

    // Photo d'un autre jointe à une commande : refusée.
    const stranger = await merchant(ctx);
    const strangerKey = await photo(stranger);
    await request(ctx.http)
      .post('/v1/orders')
      .set(shop.auth)
      .send({
        pickupAddressId: shop.pickupId,
        dropoffAddressId: shop.dropoffId,
        recipientName: 'Client',
        recipientPhone: '+237677001144',
        packageSize: 'M',
        feePaymentMethod: 'CASH',
        parcelPhotoKey: strangerKey,
      })
      .expect(422);
  });

  it('moteur indisponible ou trop de photos en une heure : l’expéditeur choisit lui-même', async () => {
    const sender = await merchant(ctx);
    vision.next = new ParcelVisionUnavailableError('Claude 529 : Overloaded');
    const down = await analyze(sender, await photo(sender)).expect(503);
    expect(down.body.error.code).toBe('PARCEL_ANALYSIS_UNAVAILABLE');

    for (let index = 0; index < 3; index += 1)
      await analyze(sender, await photo(sender)).expect(200);
    const limited = await analyze(sender, await photo(sender)).expect(429);
    expect(limited.body.error.code).toBe('PARCEL_ANALYSIS_LIMIT');
  });
});
