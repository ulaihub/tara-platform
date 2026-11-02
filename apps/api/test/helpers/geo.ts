import { randomUUID } from 'node:crypto';
import request from 'supertest';
import type { SignedIn, TestContext } from './app.js';

/** Points de référence (coordonnées approximatives). */
export const PLACES = {
  akwa: { latitude: 4.0511, longitude: 9.7016 },
  bonapriso: { latitude: 4.0335, longitude: 9.6925 },
  bonamoussadi: { latitude: 4.095, longitude: 9.745 },
  yaounde: { latitude: 3.848, longitude: 11.5021 },
} as const;

/** Carré GeoJSON centré sur un point (demi-côté en degrés ; 0,01° ≈ 1,1 km). */
export function square(center: { latitude: number; longitude: number }, half: number) {
  const { latitude: y, longitude: x } = center;
  return {
    type: 'Polygon' as const,
    coordinates: [
      [
        [x - half, y - half],
        [x + half, y - half],
        [x + half, y + half],
        [x - half, y + half],
        [x - half, y - half],
      ],
    ],
  };
}

/** Zone de service couvrant Douala, créée par un administrateur. */
export async function ensureDoualaServiceArea(ctx: TestContext, admin: SignedIn): Promise<void> {
  await request(ctx.http)
    .post('/v1/admin/zones')
    .set(admin.auth)
    .send({
      name: `Douala (test ${randomUUID().slice(0, 8)})`,
      city: 'Douala',
      kind: 'SERVICE_AREA',
      geometry: square({ latitude: 4.05, longitude: 9.72 }, 0.12),
    })
    .expect(201);
}

export async function createAddress(
  ctx: TestContext,
  user: SignedIn,
  place: { latitude: number; longitude: number },
  extra: Record<string, unknown> = {},
): Promise<{ id: string }> {
  const res = await request(ctx.http)
    .post('/v1/addresses')
    .set(user.auth)
    .send({ ...place, landmark: 'Portail bleu après la pharmacie', ...extra })
    .expect(201);
  return res.body as { id: string };
}
