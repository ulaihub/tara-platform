import request from 'supertest';
import { createTestApp, type SignedIn, signIn, staffUser, type TestContext } from './helpers/app.js';
import { nearAkwa, setupDouala } from './helpers/orders.js';

describe('Repères de Douala (carrefours, lieux connus)', () => {
  let ctx: TestContext;
  let admin: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('l’équipe ajoute un repère, les apps le voient, il peut être retiré', async () => {
    const created = await request(ctx.http)
      .post('/v1/admin/landmarks')
      .set(admin.auth)
      .send({ name: '  Carrefour Nkongmondo ', ...nearAkwa(0.001) })
      .expect(201);
    expect(created.body).toMatchObject({ name: 'Carrefour Nkongmondo' });

    const user = await signIn(ctx);
    const seen = await request(ctx.http).get('/v1/map/landmarks').set(user.auth).expect(200);
    expect(seen.body.items).toContainEqual(expect.objectContaining({ name: 'Carrefour Nkongmondo' }));
    const before = seen.body.version as string;

    // Hors de Douala : refusé ; un simple utilisateur ne peut rien ajouter.
    await request(ctx.http)
      .post('/v1/admin/landmarks')
      .set(admin.auth)
      .send({ name: 'Ailleurs', latitude: 3.87, longitude: 11.52 })
      .expect(422);
    await request(ctx.http)
      .post('/v1/admin/landmarks')
      .set(user.auth)
      .send({ name: 'Mon repère', ...nearAkwa(0.002) })
      .expect(403);

    await request(ctx.http).delete(`/v1/admin/landmarks/${created.body.id}`).set(admin.auth).expect(204);
    const after = await request(ctx.http).get('/v1/map/landmarks').set(user.auth).expect(200);
    expect(after.body.items.map((l: { id: string }) => l.id)).not.toContain(created.body.id);
    expect(after.body.version).not.toBe(before);
  });
});
