/**
 * Test de charge (phase 7), étape 1 : comptes fictifs dans une base DÉDIÉE (jamais celle de
 * production ni de démonstration). Zone de Douala et grille de prix, livreurs validés au
 * solde prépayé rechargé, boutiques avec leur adresse et des adresses de destinataires,
 * comptes de l'équipe. Les sessions sont écrites dans un fichier JSON lu par `run.ts`.
 *
 *   DATABASE_URL=…/tara_load REDIS_URL=…/3 JWT_ACCESS_TTL_SECONDS=3600 \
 *     node test/simulator/launch.mjs test/load/setup.ts --riders 500 --shops 150 --out comptes.json
 *
 * Le fichier contient des jetons de session de cette base de test : à garder hors du dépôt.
 */
import { writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import request from 'supertest';
import { createTestApp, signIn, staffUser, type TestContext } from '../helpers/app.js';
import { createAddress } from '../helpers/geo.js';
import { setupDouala } from '../helpers/orders.js';
import { activeRider } from '../helpers/riders.js';
import { random } from '../simulator/simulation.js';

const { values } = parseArgs({
  options: {
    riders: { type: 'string', default: '500' },
    shops: { type: 'string', default: '150' },
    dropoffs: { type: 'string', default: '10' },
    staff: { type: 'string', default: '5' },
    out: { type: 'string' },
    seed: { type: 'string', default: '2026' },
  },
});
if (!values.out) throw new Error('--out manquant : fichier JSON des comptes');

// Mode test : SMS factices lus en mémoire, pas de limitation de débit pendant la création.
process.env['NODE_ENV'] = 'test';
process.env['SMS_PROVIDER'] = 'fake';
process.env['PUSH_PROVIDER'] = 'fake';
process.env['WHATSAPP_PROVIDER'] = 'none';
process.env['JOBS_ENABLED'] = 'false';
process.env['OTP_MAX_PER_IP_PER_HOUR'] = '1000000';
process.env['OTP_DAILY_GLOBAL_LIMIT'] = '1000000';

export interface LoadAccounts {
  createdAt: string;
  riders: { userId: string; riderId: string; accessToken: string }[];
  shops: {
    userId: string;
    accessToken: string;
    pickupId: string;
    pickup: { latitude: number; longitude: number };
    dropoffIds: string[];
  }[];
  staff: { userId: string; accessToken: string }[];
}

const rng = random(Number(values.seed));
/** Point au hasard dans la zone servie de Douala. */
const somewhere = () => ({
  latitude: Number((3.99 + rng() * 0.12).toFixed(6)),
  longitude: Number((9.66 + rng() * 0.12).toFixed(6)),
});

/** Exécute `task` pour 0…count-1, `width` à la fois. */
async function pool<T>(count: number, width: number, task: (i: number) => Promise<T>) {
  const out: T[] = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: width }, async () => {
      while (next < count) {
        const i = next;
        next += 1;
        out[i] = await task(i);
      }
    }),
  );
  return out;
}

const log = (line: string) => process.stdout.write(`${line}\n`);
const ctx: TestContext = await createTestApp();
try {
  const admin = await staffUser(ctx, ['ADMIN']);
  await setupDouala(ctx, admin);

  const riderCount = Number(values.riders);
  const riders = await pool(riderCount, 10, async (i) => {
    const rider = await activeRider(ctx);
    await ctx.prisma.user.update({
      where: { id: rider.userId },
      data: { fullName: `Livreur charge ${String(i + 1).padStart(3, '0')}` },
    });
    return { userId: rider.userId, riderId: rider.riderId, accessToken: rider.accessToken };
  });
  log(`${riders.length} livreurs validés`);

  const shops = await pool(Number(values.shops), 10, async (i) => {
    const owner = await signIn(ctx);
    await request(ctx.http)
      .put('/v1/me/merchant')
      .set(owner.auth)
      .send({
        shopName: `Boutique charge ${String(i + 1).padStart(3, '0')}`,
        payoutPhone: '677000003',
        payoutOperator: 'MTN',
      })
      .expect(200);
    const pickup = somewhere();
    const { id: pickupId } = await createAddress(ctx, owner, pickup, { label: 'Boutique' });
    const dropoffIds: string[] = [];
    for (let j = 0; j < Number(values.dropoffs); j += 1) {
      const dropoff = await createAddress(ctx, owner, somewhere(), { contactName: 'Client' });
      dropoffIds.push(dropoff.id);
    }
    return { userId: owner.userId, accessToken: owner.accessToken, pickupId, pickup, dropoffIds };
  });
  log(`${shops.length} boutiques, ${values.dropoffs} adresses de destinataires chacune`);

  const staff = await pool(Number(values.staff), 1, async () => {
    const member = await staffUser(ctx, ['DISPATCHER', 'SUPPORT']);
    return { userId: member.userId, accessToken: member.accessToken };
  });

  const accounts: LoadAccounts = { createdAt: new Date().toISOString(), riders, shops, staff };
  writeFileSync(values.out, JSON.stringify(accounts));
  log(`Comptes écrits dans ${values.out}`);
} finally {
  await ctx.app.close();
}
