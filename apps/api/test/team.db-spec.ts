import request from 'supertest';
import {
  createTestApp,
  randomPhone,
  type SignedIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';

/** Équipe et journal d'audit (H8). */
describe('Back-office · équipe et audit (H8)', () => {
  let ctx: TestContext;
  let admin: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    await ctx.prisma.user.update({ where: { id: admin.userId }, data: { fullName: 'Awa Admin' } });
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('ajoute un membre, change ses rôles, retire son accès ; tout est au journal', async () => {
    const phone = randomPhone();
    const added = await request(ctx.http)
      .post('/v1/admin/team')
      .set(admin.auth)
      .send({ phone, fullName: 'Nadège Ekwalla', roles: ['SUPPORT'] })
      .expect(201);
    expect(added.body).toMatchObject({ phone, roles: ['SUPPORT'], mfaEnabled: false });

    const listed = await request(ctx.http).get('/v1/admin/team').set(admin.auth).expect(200);
    expect(listed.body.some((m: { id: string }) => m.id === added.body.id)).toBe(true);

    const changed = await request(ctx.http)
      .put(`/v1/admin/team/${added.body.id as string}/roles`)
      .set(admin.auth)
      .send({ roles: ['SUPPORT', 'DISPATCHER'] })
      .expect(200);
    expect(changed.body.roles.sort()).toEqual(['DISPATCHER', 'SUPPORT']);

    // Personne ne retire ses propres droits d'administrateur.
    const self = await request(ctx.http)
      .put(`/v1/admin/team/${admin.userId}/roles`)
      .set(admin.auth)
      .send({ roles: ['SUPPORT'] })
      .expect(422);
    expect(self.body.error.code).toBe('TEAM_SELF_DEMOTION');

    await request(ctx.http)
      .delete(`/v1/admin/team/${added.body.id as string}`)
      .set(admin.auth)
      .expect(204);
    const after = await ctx.prisma.user.findUniqueOrThrow({ where: { id: added.body.id } });
    expect(after.roles.some((role) => ['SUPPORT', 'DISPATCHER'].includes(role))).toBe(false);

    const log = await request(ctx.http)
      .get(`/v1/admin/audit-log?entityType=user&entityId=${added.body.id as string}`)
      .set(admin.auth)
      .expect(200);
    expect(log.body.items.map((entry: { action: string }) => entry.action)).toEqual([
      'team.member_removed',
      'team.roles_changed',
      'team.member_added',
    ]);
    expect(log.body.items[0]).toMatchObject({ actor: { name: 'Awa Admin' } });
    expect(log.body.entityTypes).toContain('user');

    const support = await staffUser(ctx, ['SUPPORT']);
    await request(ctx.http).get('/v1/admin/audit-log').set(support.auth).expect(403);
  });
});
