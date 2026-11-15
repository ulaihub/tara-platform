import type { AddressInfo } from 'node:net';
import { io, type Socket } from 'socket.io-client';
import request from 'supertest';
import { OrderTransitionsService } from '../../src/orders/order-transitions.service.js';
import { createTestApp, staffUser, type TestContext } from '../helpers/app.js';
import { createAddress } from '../helpers/geo.js';
import {
  merchant,
  type PlacedOrder,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from '../helpers/orders.js';
import {
  activeRider,
  goOnline,
  proofPhoto,
  resetPresence,
  type TestRider,
} from '../helpers/riders.js';

/**
 * Simulateur d'attribution (critère de sortie de la phase 2) : des livreurs virtuels
 * connectés en temps réel reçoivent les propositions, acceptent, refusent ou laissent
 * passer, puis font la course de bout en bout par l'API, pendant que des boutiques passent
 * des commandes. Le temps est accéléré : `timeScale` = 0,01 fait d'une minute 0,6 s.
 */
export interface SimulationOptions {
  riders: number;
  orders: number;
  /** Facteur d'accélération du temps (1 = temps réel). */
  timeScale: number;
  /** Intervalle moyen entre deux commandes, en secondes simulées. */
  orderIntervalSeconds: number;
  /** Probabilités de réponse d'un livreur à une proposition. */
  acceptRate: number;
  declineRate: number;
  /** Graine du générateur pseudo-aléatoire : deux exécutions identiques donnent le même scénario. */
  seed: number;
  log?: (line: string) => void;
}

export const DEFAULT_SIMULATION: SimulationOptions = {
  riders: 50,
  orders: 100,
  timeScale: 0.02,
  orderIntervalSeconds: 20,
  acceptRate: 0.6,
  declineRate: 0.2,
  seed: 2026,
};

export interface SimulationReport {
  orders: number;
  assigned: number;
  assignedWithin2Min: number;
  /** Part des courses attribuées en moins de 2 minutes simulées. */
  rateWithin2Min: number;
  medianSeconds: number;
  p95Seconds: number;
  maxSeconds: number;
  offersPerOrder: number;
  broadcastRounds: number;
  delivered: number;
  dispatchAlerts: number;
  /** Actions des livreurs virtuels refusées par l'API (doit rester à 0). */
  actionErrors: string[];
  realDurationSeconds: number;
}

/** Générateur pseudo-aléatoire reproductible (mulberry32). */
export function random(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

/** Point au hasard dans Douala (zone de service des tests). */
function somewhere(rng: () => number): { latitude: number; longitude: number } {
  return { latitude: 3.99 + rng() * 0.12, longitude: 9.66 + rng() * 0.12 };
}

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))] ?? 0;
}

interface OfferEvent {
  id: string;
  orderId: string;
}

export async function runSimulation(options: SimulationOptions): Promise<SimulationReport> {
  const log = options.log ?? (() => undefined);
  const rng = random(options.seed);
  const scale = options.timeScale;
  /** Durée simulée (s) → délai réel (ms). */
  const real = (simSeconds: number): number => simSeconds * 1000 * scale;
  const sleep = (simSeconds: number) =>
    new Promise((resolve) => setTimeout(resolve, real(simSeconds)));

  await resetPresence();
  const ctx: TestContext = await createTestApp({
    JOBS_ENABLED: 'true',
    QUEUE_PREFIX: `tara-sim-${Date.now()}`,
    DISPATCH_OFFER_TIMEOUT_SECONDS: String(Math.max(0.2, 30 * scale)),
    DISPATCH_RETRY_SECONDS: String(Math.max(0.2, 20 * scale)),
    DISPATCH_ALERT_AFTER_SECONDS: String(Math.max(1, 300 * scale)),
    OPS_ALERT_PHONES: '+237690009999',
  });
  const started = Date.now();
  const sockets: Socket[] = [];
  const work: Promise<unknown>[] = [];
  const actionErrors: string[] = [];
  let running = true;

  try {
    await ctx.app.listen(0);
    const { port } = ctx.app.getHttpServer().address() as AddressInfo;
    const admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);

    // Commandes laissées en recherche par d'autres tests : annulées, pour ne pas fausser la mesure.
    const transitions = ctx.app.get(OrderTransitionsService);
    const leftovers = await ctx.prisma.order.findMany({
      where: { status: { in: ['CREATED', 'SEARCHING_RIDER'] } },
      select: { id: true },
    });
    for (const { id } of leftovers) {
      await transitions
        .apply(
          id,
          'CANCELLED',
          { id: null, role: 'SYSTEM' },
          { note: 'Nettoyage avant simulation' },
        )
        .catch(() => undefined);
    }

    // Boutiques réparties dans la ville, chacune avec quelques destinataires.
    const shops: { shop: TestMerchant; dropoffs: string[] }[] = [];
    for (let i = 0; i < 8; i += 1) {
      const shop = await merchant(ctx);
      const pickup = await createAddress(ctx, shop, somewhere(rng), { label: 'Boutique' });
      const dropoffs: string[] = [];
      for (let j = 0; j < 4; j += 1) {
        dropoffs.push(
          (await createAddress(ctx, shop, somewhere(rng), { contactName: 'Client' })).id,
        );
      }
      shops.push({ shop: { ...shop, pickupId: pickup.id }, dropoffs });
    }

    // Livreurs virtuels : en ligne, connectés en temps réel, une photo de preuve prête.
    const placed = new Map<string, PlacedOrder>();
    const riders: { rider: TestRider; photoKey: string }[] = [];
    for (let i = 0; i < options.riders; i += 1) {
      const rider = await activeRider(ctx);
      await goOnline(ctx, rider, somewhere(rng));
      riders.push({ rider, photoKey: await proofPhoto(ctx, rider) });
    }

    const deliver = async (rider: TestRider, photoKey: string, orderId: string): Promise<void> => {
      const order = placed.get(orderId);
      if (!order) return;
      const here = somewhere(rng);
      await sleep(180 + rng() * 300); // Trajet jusqu'à la boutique.
      await request(ctx.http)
        .post(`/v1/rider/orders/${orderId}/pickup`)
        .set(rider.auth)
        .send({ pickupCode: order.pickupCode, photoKey, ...here })
        .expect(200);
      await request(ctx.http)
        .post(`/v1/rider/orders/${orderId}/depart`)
        .set(rider.auth)
        .send(here)
        .expect(200);
      await sleep(300 + rng() * 600); // Trajet jusqu'au destinataire.
      const code = /le code au livreur : (\d{4})/.exec(
        ctx.sms.lastTo(order.recipientPhone)?.text ?? '',
      )?.[1];
      const there = somewhere(rng);
      await request(ctx.http)
        .post(`/v1/rider/orders/${orderId}/deliver`)
        .set(rider.auth)
        .send({ deliveryCode: code, photoKey, ...there })
        .expect(200);
      await request(ctx.http).post('/v1/rider/location').set(rider.auth).send(there).expect(204);
    };

    for (const { rider, photoKey } of riders) {
      const socket = io(`http://127.0.0.1:${port}/realtime`, {
        transports: ['websocket'],
        auth: { token: rider.accessToken },
        reconnection: false,
      });
      sockets.push(socket);
      socket.on('offer.new', (offer: OfferEvent) => {
        if (!running) return;
        const roll = rng();
        const reaction = 2 + rng() * 12; // 2 à 14 s pour réagir.
        if (roll >= options.acceptRate + options.declineRate) return; // Ne répond pas.
        const accept = roll < options.acceptRate;
        work.push(
          sleep(reaction)
            .then(async () => {
              if (!running) return;
              const res = await request(ctx.http)
                .post(`/v1/rider/offers/${offer.id}/${accept ? 'accept' : 'decline'}`)
                .set(rider.auth);
              if (accept && res.status === 200) await deliver(rider, photoKey, offer.orderId);
            })
            .catch((error: unknown) => {
              actionErrors.push(error instanceof Error ? error.message : String(error));
            }),
        );
      });
      await new Promise<void>((resolve, reject) => {
        socket.once('connect', () => resolve());
        socket.once('connect_error', reject);
      });
    }
    log(
      `${options.riders} livreurs en ligne, ${shops.length} boutiques ; ${options.orders} commandes à passer`,
    );

    // Commandes à intervalles aléatoires (loi exponentielle).
    for (let i = 0; i < options.orders; i += 1) {
      const { shop, dropoffs } = shops[Math.floor(rng() * shops.length)] as (typeof shops)[number];
      const dropoffId = dropoffs[Math.floor(rng() * dropoffs.length)] as string;
      const order = await placeOrder(ctx, { ...shop, dropoffId });
      placed.set(order.id, order);
      await sleep(-Math.log(1 - rng()) * options.orderIntervalSeconds);
    }

    // Attente des dernières attributions (au plus 5 minutes simulées).
    const ids = [...placed.keys()];
    const deadline = Date.now() + real(300);
    while (Date.now() < deadline) {
      const waiting = await ctx.prisma.order.count({
        where: { id: { in: ids }, assignedAt: null },
      });
      if (waiting === 0) break;
      await sleep(5);
    }
    running = false;
    await Promise.allSettled(work);

    const orders = await ctx.prisma.order.findMany({
      where: { id: { in: ids } },
      select: { createdAt: true, assignedAt: true, status: true, dispatchAlertedAt: true },
    });
    const latencies = orders
      .flatMap((order) =>
        order.assignedAt
          ? [(order.assignedAt.getTime() - order.createdAt.getTime()) / 1000 / scale]
          : [],
      )
      .sort((a, b) => a - b);
    const offers = await ctx.prisma.dispatchOffer.groupBy({
      by: ['orderId', 'round'],
      where: { orderId: { in: ids } },
      _count: true,
    });
    const within = latencies.filter((seconds) => seconds <= 120).length;
    const report: SimulationReport = {
      orders: ids.length,
      assigned: latencies.length,
      assignedWithin2Min: within,
      rateWithin2Min: ids.length > 0 ? within / ids.length : 0,
      medianSeconds: Math.round(percentile(latencies, 50)),
      p95Seconds: Math.round(percentile(latencies, 95)),
      maxSeconds: Math.round(latencies.at(-1) ?? 0),
      offersPerOrder: Number(
        (offers.reduce((sum, row) => sum + row._count, 0) / Math.max(1, ids.length)).toFixed(2),
      ),
      broadcastRounds: offers.filter((row) => row._count > 1).length,
      delivered: orders.filter((order) => order.status === 'DELIVERED').length,
      dispatchAlerts: orders.filter((order) => order.dispatchAlertedAt !== null).length,
      actionErrors,
      realDurationSeconds: Math.round((Date.now() - started) / 100) / 10,
    };
    log(JSON.stringify(report, null, 2));
    return report;
  } finally {
    running = false;
    for (const socket of sockets) socket.disconnect();
    await ctx.app.close();
  }
}
