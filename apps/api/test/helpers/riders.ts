import { randomUUID } from 'node:crypto';
import { Redis } from 'ioredis';
import request from 'supertest';
import { REQUIRED_DOCUMENTS } from '../../src/riders/riders.schemas.js';
import { type SignedIn, signIn, type TestContext } from './app.js';
import { PLATFORM_ACCOUNTS, riderPayable } from '../../src/finance/ledger.accounts.js';
import { LedgerService } from '../../src/finance/ledger.service.js';

/** Solde prépayé de départ d'un livreur de test (décision 36). */
export const RIDER_START_BALANCE = 100_000;

export interface TestRider extends SignedIn {
  riderId: string;
  pushToken: string;
}

/**
 * Livreur validé (pièces approuvées), avec un jeton de notifications, créé directement en
 * base pour aller vite. `expiredDocuments` simule une pièce expirée (D4).
 */
export async function activeRider(
  ctx: TestContext,
  options: { cashLimit?: number; expiredDocuments?: boolean; balance?: number } = {},
): Promise<TestRider> {
  const user = await signIn(ctx);
  await ctx.prisma.user.update({
    where: { id: user.userId },
    data: { roles: ['CUSTOMER', 'RIDER'], fullName: 'Livreur Test' },
  });
  const expiresOn = new Date(Date.now() + (options.expiredDocuments ? -2 : 365) * 86_400_000);
  const rider = await ctx.prisma.riderProfile.create({
    data: {
      userId: user.userId,
      status: 'ACTIVE',
      approvedAt: new Date(),
      // Livreur confirmé : plafond normal (un nouveau livreur commence à 25 000 FCFA).
      cashLimit: options.cashLimit ?? 50_000,
      guarantorName: 'Garant Test',
      guarantorPhone: '+237699000111',
      documents: {
        create: REQUIRED_DOCUMENTS.map((group) => ({
          type: group[0] ?? 'SELFIE',
          storageKey: `test/${randomUUID()}`,
          status: 'APPROVED' as const,
          expiresOn: new Date(expiresOn.toISOString().slice(0, 10)),
          reviewedAt: new Date(),
        })),
      },
    },
  });
  // Livreur confirmé : solde prépayé déjà rechargé (couvre les courses avec encaissement).
  const balance = options.balance ?? RIDER_START_BALANCE;
  if (balance > 0) {
    const ledger = ctx.app.get(LedgerService);
    await ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'PAYMENT_RECEIVED',
        description: 'Recharge de départ (test)',
        idempotencyKey: `test-start-balance:${rider.id}`,
        postings: [
          { account: PLATFORM_ACCOUNTS.officeCash, amount: balance },
          { account: riderPayable(rider.id), amount: -balance },
        ],
      }),
    );
  }
  const pushToken = `push-${randomUUID()}-${randomUUID()}`;
  await request(ctx.http)
    .put(`/v1/me/devices/${user.installationId}/push-token`)
    .set(user.auth)
    .send({ pushToken })
    .expect(204);
  return { ...user, riderId: rider.id, pushToken };
}

export async function goOnline(
  ctx: TestContext,
  rider: SignedIn,
  place: { latitude: number; longitude: number },
): Promise<void> {
  await request(ctx.http)
    .put('/v1/rider/presence')
    .set(rider.auth)
    .send({ online: true, ...place })
    .expect(200);
}

/** Efface la présence des livreurs : aucun livreur d'un autre test ne reste « en ligne ». */
export async function resetPresence(): Promise<void> {
  const redis = new Redis(process.env['REDIS_URL'] ?? 'redis://localhost:6379/1');
  const keys = await redis.keys('tara:rider*');
  if (keys.length > 0) await redis.del(...keys);
  await redis.quit();
}

/** Petite image JPEG valide (les types de fichiers sont vérifiés sur le contenu). */
export const TINY_JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64',
);

/** Photo de preuve envoyée par le livreur ; renvoie la clé à joindre à l'action. */
export async function proofPhoto(ctx: TestContext, rider: SignedIn): Promise<string> {
  const res = await request(ctx.http)
    .post('/v1/media')
    .set(rider.auth)
    .field('kind', 'PROOF_PHOTO')
    .attach('file', TINY_JPEG, { filename: 'preuve.jpg', contentType: 'image/jpeg' })
    .expect(201);
  return res.body.key as string;
}
