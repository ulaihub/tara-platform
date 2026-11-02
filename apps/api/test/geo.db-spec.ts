import { randomUUID } from 'node:crypto';
import request from 'supertest';
import {
  createTestApp,
  signIn,
  staffUser,
  type SignedIn,
  type TestContext,
} from './helpers/app.js';
import { createAddress, ensureDoualaServiceArea, PLACES, square } from './helpers/geo.js';

describe('Adresses, zones et lien de localisation (B1 à B6)', () => {
  let ctx: TestContext;
  let admin: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    await ensureDoualaServiceArea(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('refuse une géométrie invalide et réserve l’import des zones aux administrateurs', async () => {
    const bowtie = {
      type: 'Polygon',
      coordinates: [
        [
          [9.7, 4.0],
          [9.8, 4.1],
          [9.8, 4.0],
          [9.7, 4.1],
          [9.7, 4.0],
        ],
      ],
    };
    const res = await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({ name: 'Invalide', city: 'Douala', kind: 'NEIGHBORHOOD', geometry: bowtie })
      .expect(422);
    expect(res.body.error.code).toBe('ZONE_GEOMETRY_INVALID');

    const user = await signIn(ctx);
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(user.auth)
      .send({
        name: 'X',
        city: 'Douala',
        kind: 'NEIGHBORHOOD',
        geometry: square(PLACES.akwa, 0.01),
      })
      .expect(403);
  });

  it('crée une adresse dans la zone desservie, avec quartier déduit et alerte zone moto (B1, B6)', async () => {
    const suffix = randomUUID().slice(0, 8);
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: `Akwa ${suffix}`,
        city: 'Douala',
        kind: 'NEIGHBORHOOD',
        geometry: square(PLACES.akwa, 0.008),
      })
      .expect(201);
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: `Centre ${suffix}`,
        city: 'Douala',
        kind: 'NO_MOTORBIKE',
        geometry: square(PLACES.akwa, 0.002),
      })
      .expect(201);

    const user = await signIn(ctx);
    const res = await request(ctx.http)
      .post('/v1/addresses')
      .set(user.auth)
      .send({
        ...PLACES.akwa,
        landmark: '  Immeuble jaune en face de la station  ',
        contactPhone: '699 99 88 77',
      })
      .expect(201);
    expect(res.body).toMatchObject({
      city: 'Douala',
      landmark: 'Immeuble jaune en face de la station',
      contactPhone: '+237699998877',
      source: 'SENDER',
      motorbikeRestricted: true,
      neighborhood: { name: expect.stringMatching(/^Akwa /) },
    });

    const elsewhere = await request(ctx.http)
      .post('/v1/addresses')
      .set(user.auth)
      .send({ ...PLACES.bonamoussadi, landmark: 'Derrière le marché' })
      .expect(201);
    expect(elsewhere.body.motorbikeRestricted).toBe(false);

    const zones = await request(ctx.http)
      .get('/v1/zones?city=Douala&kind=NEIGHBORHOOD')
      .set(user.auth)
      .expect(200);
    expect(zones.body.some((zone: { name: string }) => zone.name === `Akwa ${suffix}`)).toBe(true);
  });

  it('refuse une adresse hors zone desservie et un repère vide', async () => {
    const user = await signIn(ctx);
    const outside = await request(ctx.http)
      .post('/v1/addresses')
      .set(user.auth)
      .send({ ...PLACES.yaounde, landmark: 'Carrefour Warda' })
      .expect(422);
    expect(outside.body.error.code).toBe('OUT_OF_SERVICE_AREA');

    const empty = await request(ctx.http)
      .post('/v1/addresses')
      .set(user.auth)
      .send({ ...PLACES.akwa, landmark: '  ' })
      .expect(400);
    expect(empty.body.error.details[0].path).toBe('landmark');
  });

  it('n’accepte que ses propres photos de façade (B2)', async () => {
    const owner = await signIn(ctx);
    const other = await signIn(ctx);
    const png = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      'base64',
    );
    const upload = await request(ctx.http)
      .post('/v1/media')
      .set(owner.auth)
      .field('kind', 'ADDRESS_PHOTO')
      .attach('file', png, { filename: 'facade.png', contentType: 'image/png' })
      .expect(201);

    await createAddress(ctx, owner, PLACES.bonapriso, { photoKey: upload.body.key });
    const res = await request(ctx.http)
      .post('/v1/addresses')
      .set(other.auth)
      .send({ ...PLACES.bonapriso, landmark: 'Portail vert', photoKey: upload.body.key })
      .expect(422);
    expect(res.body.error.code).toBe('MEDIA_NOT_FOUND');
  });

  it('gère le carnet d’adresses (B5)', async () => {
    const user = await signIn(ctx);
    const a = await createAddress(ctx, user, PLACES.akwa, { label: 'Boutique' });
    await createAddress(ctx, user, PLACES.bonapriso, { label: 'Maison' });
    const list = await request(ctx.http).get('/v1/addresses').set(user.auth).expect(200);
    expect(list.body.map((x: { label: string }) => x.label).sort()).toEqual(['Boutique', 'Maison']);

    await request(ctx.http).delete(`/v1/addresses/${a.id}`).set(user.auth).expect(204);
    const after = await request(ctx.http).get('/v1/addresses').set(user.auth).expect(200);
    expect(after.body).toHaveLength(1);

    const stranger = await signIn(ctx);
    await request(ctx.http).get(`/v1/addresses/${after.body[0].id}`).set(stranger.auth).expect(404);
  });

  it('laisse le destinataire placer lui-même son point avec le lien (B3)', async () => {
    const merchant = await signIn(ctx);
    await request(ctx.http)
      .put('/v1/me/merchant')
      .set(merchant.auth)
      .send({ shopName: 'Mode Akwa', payoutPhone: '677000002', payoutOperator: 'MTN' })
      .expect(200);

    const link = await request(ctx.http)
      .post('/v1/location-links')
      .set(merchant.auth)
      .send({ recipientName: 'Brenda', recipientPhone: '655 11 22 33' })
      .expect(201);
    expect(link.body).toMatchObject({
      status: 'PENDING',
      url: expect.stringMatching(/^https:\/\/tara\.test\/l\//),
    });
    const token = (link.body.url as string).split('/l/')[1];

    const view = await request(ctx.http).get(`/v1/public/location-links/${token}`).expect(200);
    expect(view.body).toMatchObject({
      senderName: 'Mode Akwa',
      recipientName: 'Brenda',
      status: 'PENDING',
    });

    await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.yaounde, landmark: 'Trop loin' })
      .expect(422);
    await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.bonamoussadi, landmark: 'Maison rose derrière l’église' })
      .expect(200);
    const again = await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.bonamoussadi, landmark: 'Autre' })
      .expect(409);
    expect(again.body.error.code).toBe('LOCATION_LINK_ALREADY_USED');

    const submitted = await request(ctx.http)
      .get(`/v1/location-links/${link.body.id}`)
      .set(merchant.auth)
      .expect(200);
    expect(submitted.body).toMatchObject({
      status: 'SUBMITTED',
      address: { source: 'LOCATION_LINK', contactName: 'Brenda', contactPhone: '+237655112233' },
    });
    // L'adresse rejoint le carnet du marchand, prête pour une commande.
    const book = await request(ctx.http).get('/v1/addresses').set(merchant.auth).expect(200);
    expect(book.body.some((a: { id: string }) => a.id === submitted.body.address.id)).toBe(true);
  });

  it('refuse un lien expiré ou inconnu', async () => {
    const user = await signIn(ctx);
    const link = await request(ctx.http)
      .post('/v1/location-links')
      .set(user.auth)
      .send({})
      .expect(201);
    await ctx.prisma.locationLink.update({
      where: { id: link.body.id },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const token = (link.body.url as string).split('/l/')[1];
    const res = await request(ctx.http)
      .post(`/v1/public/location-links/${token}`)
      .send({ ...PLACES.akwa, landmark: 'Trop tard' })
      .expect(410);
    expect(res.body.error.code).toBe('LOCATION_LINK_EXPIRED');
    await request(ctx.http).get('/v1/public/location-links/inconnu-inconnu-inconnu').expect(404);
  });
});
