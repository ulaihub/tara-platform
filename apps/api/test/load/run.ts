/**
 * Test de charge (phase 7), étape 2 : trafic d'une heure de pointe contre une API lancée à
 * part (`node dist/main.js`), comme le feraient les téléphones. Critère du cahier des
 * charges : 5 000 commandes par jour et 500 livreurs connectés, 95 % des appels en moins de
 * 500 ms.
 *
 * - Livreurs : connexion temps réel, en ligne, une position toutes les 10 s ; propositions
 *   acceptées, refusées ou laissées passer ; course complète (photos, codes, encaissement).
 * - Boutiques : devis puis commande, au rythme demandé ; suivi de leurs commandes.
 * - Destinataires : page de suivi publique (adresses IP différentes, comme sur le réseau).
 * - Équipe : carte en direct et liste des commandes du back-office.
 *
 * Le code de livraison part par SMS au destinataire : avec le fournisseur factice, il est
 * lu dans le journal de l'API (`--log`), comme un destinataire lirait son SMS.
 *
 *   node test/simulator/launch.mjs test/load/run.ts --accounts comptes.json --log api.log \
 *     --minutes 20 --orders-per-hour 1000 --report rapport.json
 */
import { execFile } from 'node:child_process';
import { randomInt, randomUUID } from 'node:crypto';
import { closeSync, openSync, readFileSync, readSync, statSync, writeFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { parseArgs } from 'node:util';
import { io, type Socket } from 'socket.io-client';
import { TINY_JPEG } from '../helpers/riders.js';
import { random } from '../simulator/simulation.js';
import type { LoadAccounts } from './setup.js';

const { values } = parseArgs({
  options: {
    api: { type: 'string', default: 'http://127.0.0.1:3000' },
    accounts: { type: 'string' },
    log: { type: 'string' },
    minutes: { type: 'string', default: '20' },
    'warmup-minutes': { type: 'string', default: '3' },
    'orders-per-hour': { type: 'string', default: '1000' },
    'cod-share': { type: 'string', default: '0.4' },
    'trip-scale': { type: 'string', default: '1' },
    'api-pid': { type: 'string' },
    report: { type: 'string' },
    seed: { type: 'string', default: '2026' },
  },
});
if (!values.accounts || !values.log) throw new Error('--accounts et --log sont obligatoires');

const API = values.api.replace(/\/$/, '');
const MINUTES = Number(values.minutes);
const WARMUP_MS = Number(values['warmup-minutes']) * 60_000;
const ORDERS_PER_HOUR = Number(values['orders-per-hour']);
const COD_SHARE = Number(values['cod-share']);
const TRIP_SCALE = Number(values['trip-scale']);
const accounts = JSON.parse(readFileSync(values.accounts, 'utf8')) as LoadAccounts;
const rng = random(Number(values.seed));
const out = (line: string) => process.stdout.write(`${line}\n`);
const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));
const between = (min: number, max: number) => min + rng() * (max - min);
const pick = <T>(items: readonly T[]): T => items[Math.floor(rng() * items.length)] as T;

/** Photo de preuve d'environ 120 Ko (taille des photos réduites par l'app avant envoi). */
const PHOTO = Buffer.concat([TINY_JPEG, Buffer.alloc(120_000 - TINY_JPEG.length, 0x20)]);

// --- Mesures ------------------------------------------------------------------------------

interface Sample {
  at: number;
  ms: number;
}
const started = Date.now();
let running = true;
const samples = new Map<string, Sample[]>();
const failures = new Map<string, Map<string, number>>();
const counters = {
  ordersCreated: 0,
  ordersRefused: 0,
  offersReceived: 0,
  accepted: 0,
  acceptLost: 0,
  pickedUp: 0,
  delivered: 0,
  noCode: 0,
  assignSeconds: [] as number[],
};

function record(name: string, ms: number, outcome: string | null): void {
  const list = samples.get(name) ?? [];
  list.push({ at: Date.now() - started, ms });
  samples.set(name, list);
  if (outcome) {
    const byOutcome = failures.get(name) ?? new Map<string, number>();
    byOutcome.set(outcome, (byOutcome.get(outcome) ?? 0) + 1);
    failures.set(name, byOutcome);
  }
}

interface Reply {
  status: number;
  // oxlint-disable-next-line no-explicit-any -- corps JSON libre selon la route
  body: any;
}

/** Appel HTTP mesuré. `expected` : statuts normaux pour ce parcours (les autres sont comptés). */
async function call(
  name: string,
  method: string,
  path: string,
  options: {
    token?: string;
    json?: unknown;
    form?: FormData;
    headers?: Record<string, string>;
    expected?: number[];
  } = {},
): Promise<Reply> {
  const headers: Record<string, string> = { ...options.headers };
  if (options.token) headers['Authorization'] = `Bearer ${options.token}`;
  let body: string | FormData | undefined;
  if (options.json !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.json);
  } else if (options.form) body = options.form;
  const t0 = performance.now();
  try {
    const res = await fetch(`${API}/v1${path}`, { method, headers, body });
    const text = await res.text();
    const ms = performance.now() - t0;
    const expected = options.expected ?? [200, 201, 204];
    record(name, ms, expected.includes(res.status) ? null : `HTTP ${res.status}`);
    return { status: res.status, body: text ? (JSON.parse(text) as unknown) : null };
  } catch (error) {
    record(name, performance.now() - t0, error instanceof Error ? error.message : 'erreur');
    return { status: 0, body: null };
  }
}

/** Message temps réel avec accusé de réception, mesuré comme un appel. */
async function emit(socket: Socket, name: string, event: string, payload: unknown) {
  const t0 = performance.now();
  try {
    const ack = (await socket.timeout(10_000).emitWithAck(event, payload)) as {
      ok: boolean;
      error?: string;
    };
    record(`WS ${name}`, performance.now() - t0, ack.ok ? null : (ack.error ?? 'refusé'));
    return ack;
  } catch {
    record(`WS ${name}`, performance.now() - t0, 'sans réponse');
    return { ok: false };
  }
}

function connect(token: string): Promise<Socket> {
  const socket = io(`${API}/realtime`, {
    transports: ['websocket'],
    auth: { token },
    reconnection: true,
  });
  return new Promise((resolve, reject) => {
    socket.once('connect', () => resolve(socket));
    socket.once('connect_error', reject);
  });
}

// --- Codes de livraison lus dans le journal (SMS factice) ---------------------------------

const deliveryCodes = new Map<string, string>();
let logOffset = statSync(values.log).size;
const SMS_CODE =
  /colis (TR-[0-9A-Z]+) est en route\. Verifiez-le avant de donner le code au livreur : (\d{4})/g;
function readLog(): void {
  const size = statSync(values.log as string).size;
  if (size <= logOffset) return;
  const fd = openSync(values.log as string, 'r');
  const chunk = Buffer.alloc(size - logOffset);
  readSync(fd, chunk, 0, chunk.length, logOffset);
  closeSync(fd);
  logOffset = size;
  for (const match of chunk.toString('utf8').matchAll(SMS_CODE)) {
    deliveryCodes.set(match[1] as string, match[2] as string);
  }
}
const logTimer = setInterval(readLog, 500);

// --- Commandes en cours -------------------------------------------------------------------

interface LiveOrder {
  id: string;
  reference: string;
  pickupCode: string;
  trackingToken: string;
  shopToken: string;
  pickup: { latitude: number; longitude: number };
  createdAt: number;
  done: boolean;
}
const orders = new Map<string, LiveOrder>();
const randomIp = () => `10.${randomInt(0, 255)}.${randomInt(0, 255)}.${randomInt(1, 254)}`;

async function recipientViews(order: LiveOrder): Promise<void> {
  await call('GET /public/tracking/:token', 'GET', `/public/tracking/${order.trackingToken}`, {
    headers: { 'X-Forwarded-For': randomIp() },
  });
}

// --- Livreurs -----------------------------------------------------------------------------

interface Position {
  latitude: number;
  longitude: number;
}
const inDouala = (): Position => ({
  latitude: 3.99 + rng() * 0.12,
  longitude: 9.66 + rng() * 0.12,
});
/** Avance vers `target` d'environ 70 m (25 km/h pendant 10 s). */
function step(from: Position, target: Position | null): Position {
  if (!target) {
    return {
      latitude: Math.min(4.11, Math.max(3.99, from.latitude + (rng() - 0.5) * 0.0008)),
      longitude: Math.min(9.78, Math.max(9.66, from.longitude + (rng() - 0.5) * 0.0008)),
    };
  }
  const dLat = target.latitude - from.latitude;
  const dLon = target.longitude - from.longitude;
  const dist = Math.hypot(dLat, dLon);
  const max = 0.00063;
  if (dist <= max) return { ...target };
  return {
    latitude: from.latitude + (dLat / dist) * max,
    longitude: from.longitude + (dLon / dist) * max,
  };
}
const fixed = (p: Position) => ({
  latitude: Number(p.latitude.toFixed(6)),
  longitude: Number(p.longitude.toFixed(6)),
});

async function photo(token: string): Promise<string | null> {
  const form = new FormData();
  form.set('kind', 'PROOF_PHOTO');
  form.set('file', new Blob([PHOTO], { type: 'image/jpeg' }), 'preuve.jpg');
  const res = await call('POST /media', 'POST', '/media', { token, form });
  return res.status === 201 ? (res.body.key as string) : null;
}

async function runRider(rider: LoadAccounts['riders'][number], delayMs: number): Promise<void> {
  await sleep(delayMs);
  const token = rider.accessToken;
  let position = inDouala();
  let target: Position | null = null;
  let busy = false;
  const socket = await connect(token);
  await call('GET /rider/config', 'GET', '/rider/config', { token });
  await call('PUT /rider/presence', 'PUT', '/rider/presence', {
    token,
    json: { online: true, ...fixed(position) },
  });
  await call('GET /rider/earnings', 'GET', '/rider/earnings', { token });

  const course = async (offerId: string, orderId: string) => {
    const accepted = await call(
      'POST /rider/offers/:id/accept',
      'POST',
      `/rider/offers/${offerId}/accept`,
      {
        token,
        expected: [200, 409, 410, 422],
      },
    );
    if (accepted.status !== 200) {
      counters.acceptLost += 1;
      busy = false;
      return;
    }
    counters.accepted += 1;
    const order = orders.get(orderId);
    if (order) counters.assignSeconds.push((Date.now() - order.createdAt) / 1000);
    await call('GET /rider/orders/:id', 'GET', `/rider/orders/${orderId}`, { token });
    const here = fixed(position);
    await call(
      'GET /rider/orders/:id/route',
      'GET',
      `/rider/orders/${orderId}/route?latitude=${here.latitude}&longitude=${here.longitude}`,
      { token },
    );
    target = order?.pickup ?? inDouala();
    await sleep(between(3, 8) * 60_000 * TRIP_SCALE);
    if (!order) {
      busy = false;
      return;
    }
    position = { ...order.pickup };
    const pickupPhoto = await photo(token);
    const picked = await call(
      'POST /rider/orders/:id/pickup',
      'POST',
      `/rider/orders/${orderId}/pickup`,
      {
        token,
        json: {
          pickupCode: order.pickupCode,
          photoKey: pickupPhoto,
          ...fixed(position),
          clientEventId: randomUUID(),
        },
      },
    );
    if (picked.status !== 200) {
      busy = false;
      return;
    }
    counters.pickedUp += 1;
    await call('POST /rider/orders/:id/depart', 'POST', `/rider/orders/${orderId}/depart`, {
      token,
      json: { ...fixed(position), clientEventId: randomUUID() },
    });
    target = inDouala();
    await sleep(between(5, 15) * 60_000 * TRIP_SCALE);
    if (!running) return;
    let code = deliveryCodes.get(order.reference);
    for (let i = 0; !code && i < 20; i += 1) {
      await sleep(1_000);
      code = deliveryCodes.get(order.reference);
    }
    if (!code) counters.noCode += 1;
    // L'argent d'abord (E5) : montant à encaisser, puis encaissement en espèces s'il y en a.
    const due = await call(
      'GET /rider/orders/:id/collection',
      'GET',
      `/rider/orders/${orderId}/collection`,
      {
        token,
      },
    );
    if (due.status === 200 && (due.body.due.total as number) > 0 && !due.body.complete) {
      await call('POST /rider/orders/:id/collect', 'POST', `/rider/orders/${orderId}/collect`, {
        token,
        json: { method: 'CASH', ...fixed(position), clientEventId: randomUUID() },
      });
    }
    const deliveryPhoto = await photo(token);
    const delivered = await call(
      'POST /rider/orders/:id/deliver',
      'POST',
      `/rider/orders/${orderId}/deliver`,
      {
        token,
        json: {
          ...(code ? { deliveryCode: code } : { receivedBy: 'Gardien' }),
          photoKey: deliveryPhoto,
          ...fixed(position),
          clientEventId: randomUUID(),
        },
      },
    );
    if (delivered.status === 200) counters.delivered += 1;
    order.done = true;
    target = null;
    busy = false;
    await call('GET /rider/earnings', 'GET', '/rider/earnings', { token });
  };

  socket.on('offer.new', (offer: { id: string; orderId: string }) => {
    counters.offersReceived += 1;
    if (!running || busy) return;
    const roll = rng();
    if (roll >= 0.85) return; // Laisse passer.
    const accept = roll < 0.7;
    if (accept) busy = true;
    void sleep(between(3, 12) * 1000).then(async () => {
      if (!running) return;
      if (accept) {
        await course(offer.id, offer.orderId);
        return;
      }
      await call('POST /rider/offers/:id/decline', 'POST', `/rider/offers/${offer.id}/decline`, {
        token,
        expected: [200, 204, 409, 410],
      });
    });
  });

  // Position toutes les 10 s (temps réel), comme l'app en ligne.
  while (running) {
    await sleep(between(9_500, 10_500));
    if (!running) break;
    position = step(position, target);
    await emit(socket, 'rider.location', 'rider.location', {
      ...fixed(position),
      accuracy: 12,
      speed: target ? 7 : 0,
    });
  }
  socket.disconnect();
}

// --- Boutiques ----------------------------------------------------------------------------

const shopSockets = new Map<string, Socket>();

async function placeOrder(): Promise<void> {
  const shop = pick(accounts.shops);
  const token = shop.accessToken;
  const dropoffAddressId = pick(shop.dropoffIds);
  const packageSize = pick(['S', 'M', 'M', 'L'] as const);
  await call('POST /orders/quote', 'POST', '/orders/quote', {
    token,
    json: {
      pickup: { addressId: shop.pickupId },
      dropoff: { addressId: dropoffAddressId },
      packageSize,
    },
  });
  await sleep(between(1_000, 4_000));
  const orderedAt = Date.now();
  const cod = rng() < COD_SHARE ? Math.round(between(5_000, 50_000) / 500) * 500 : 0;
  const created = await call('POST /orders', 'POST', '/orders', {
    token,
    headers: { 'Idempotency-Key': randomUUID() },
    json: {
      pickupAddressId: shop.pickupId,
      dropoffAddressId,
      recipientName: 'Client charge',
      recipientPhone: `+2376${String(randomInt(0, 100_000_000)).padStart(8, '0')}`,
      packageSize,
      codAmount: cod,
      feePaymentMethod: 'CASH',
    },
    expected: [201, 422],
  });
  if (created.status !== 201) {
    counters.ordersRefused += 1;
    return;
  }
  counters.ordersCreated += 1;
  const order: LiveOrder = {
    id: created.body.order.id as string,
    reference: created.body.order.reference as string,
    pickupCode: created.body.pickupCode as string,
    trackingToken: String(created.body.order.trackingUrl).split('/').at(-1) as string,
    shopToken: token,
    pickup: shop.pickup,
    createdAt: orderedAt,
    done: false,
  };
  orders.set(order.id, order);
  const socket = shopSockets.get(shop.userId);
  if (socket) await emit(socket, 'order.subscribe', 'order.subscribe', { orderId: order.id });
  void sleep(between(20_000, 120_000)).then(async () => {
    if (running) await recipientViews(order);
  });
  // Écran de suivi ouvert de temps en temps par la boutique, jusqu'à la livraison.
  void (async () => {
    while (running && !order.done) {
      await sleep(between(45_000, 90_000));
      if (!running || order.done) break;
      await call('GET /orders/:id', 'GET', `/orders/${order.id}`, { token });
    }
    if (running && socket)
      await emit(socket, 'order.unsubscribe', 'order.unsubscribe', { orderId: order.id });
  })();
}

async function runShops(): Promise<void> {
  for (const shop of accounts.shops) {
    shopSockets.set(shop.userId, await connect(shop.accessToken));
  }
  // Liste des commandes ouverte de temps en temps par chaque boutique.
  for (const shop of accounts.shops) {
    void (async () => {
      await sleep(between(0, 120_000));
      while (running) {
        await call('GET /orders', 'GET', '/orders', { token: shop.accessToken });
        await sleep(between(120_000, 300_000));
      }
    })();
  }
  const meanGapMs = 3_600_000 / ORDERS_PER_HOUR;
  while (running) {
    void placeOrder();
    await sleep(-Math.log(1 - rng()) * meanGapMs);
  }
}

// --- Équipe (back-office) -----------------------------------------------------------------

async function runStaff(member: LoadAccounts['staff'][number]): Promise<void> {
  const token = member.accessToken;
  const socket = await connect(token);
  let tick = 0;
  while (running) {
    await call('GET /admin/live-map', 'GET', '/admin/live-map', { token });
    if (tick % 3 === 0) await call('GET /admin/orders', 'GET', '/admin/orders', { token });
    tick += 1;
    await sleep(between(9_000, 11_000));
  }
  socket.disconnect();
}

// --- Ressources de l'API ------------------------------------------------------------------

const resources: { at: number; cpu: number; rssMb: number }[] = [];
function sampleResources(): void {
  if (!values['api-pid']) return;
  execFile('ps', ['-o', '%cpu=,rss=', '-p', values['api-pid']], (error, stdout) => {
    if (error) return;
    const [cpu, rss] = stdout.trim().split(/\s+/).map(Number);
    resources.push({
      at: Date.now() - started,
      cpu: cpu ?? 0,
      rssMb: Math.round((rss ?? 0) / 1024),
    });
  });
}
const resourceTimer = setInterval(sampleResources, 10_000);

// --- Rapport ------------------------------------------------------------------------------

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)] ?? 0;
}

function summary(fromMs: number) {
  const rows = [...samples.entries()].map(([name, list]) => {
    const ms = list
      .filter((sample) => sample.at >= fromMs)
      .map((sample) => sample.ms)
      .sort((a, b) => a - b);
    return {
      name,
      count: ms.length,
      p50: Math.round(percentile(ms, 50)),
      p95: Math.round(percentile(ms, 95)),
      p99: Math.round(percentile(ms, 99)),
      max: Math.round(ms.at(-1) ?? 0),
      failures: Object.fromEntries(failures.get(name) ?? new Map<string, number>()),
    };
  });
  const all = [...samples.values()]
    .flat()
    .filter((sample) => sample.at >= fromMs)
    .map((sample) => sample.ms)
    .sort((a, b) => a - b);
  const under500 = all.filter((ms) => ms < 500).length;
  return {
    calls: all.length,
    perSecond: Number(
      (all.length / Math.max(1, (Date.now() - started - fromMs) / 1000)).toFixed(1),
    ),
    p50: Math.round(percentile(all, 50)),
    p95: Math.round(percentile(all, 95)),
    p99: Math.round(percentile(all, 99)),
    shareUnder500: Number(((under500 / Math.max(1, all.length)) * 100).toFixed(2)),
    routes: rows.sort((a, b) => b.count - a.count),
  };
}

function printTable(title: string, data: ReturnType<typeof summary>): void {
  out(`\n${title}`);
  out(
    `${data.calls} appels (${data.perSecond}/s) · médiane ${data.p50} ms · 95 % ${data.p95} ms · 99 % ${data.p99} ms · ${data.shareUnder500} % sous 500 ms`,
  );
  out(
    'route'.padEnd(36) +
      'appels'.padStart(8) +
      'p50'.padStart(7) +
      'p95'.padStart(7) +
      'p99'.padStart(7) +
      'max'.padStart(8) +
      '  écarts',
  );
  for (const row of data.routes) {
    const fails = Object.entries(row.failures)
      .map(([key, count]) => `${key}×${String(count)}`)
      .join(' ');
    out(
      row.name.padEnd(36) +
        String(row.count).padStart(8) +
        String(row.p50).padStart(7) +
        String(row.p95).padStart(7) +
        String(row.p99).padStart(7) +
        String(row.max).padStart(8) +
        (fails ? `  ${fails}` : ''),
    );
  }
}

// --- Déroulé ------------------------------------------------------------------------------

out(
  `Charge : ${accounts.riders.length} livreurs, ${accounts.shops.length} boutiques, ${accounts.staff.length} membres de l'équipe ; ${ORDERS_PER_HOUR} commandes/heure pendant ${MINUTES} min (dont ${WARMUP_MS / 60_000} min de montée)`,
);
const ridersDone = accounts.riders.map((rider, i) =>
  runRider(rider, (i / accounts.riders.length) * Math.min(WARMUP_MS, 60_000)).catch(
    (error: unknown) => {
      record('connexion livreur', 0, error instanceof Error ? error.message : 'erreur');
    },
  ),
);
const staffDone = accounts.staff.map((member) => runStaff(member));
void runShops();
const progress = setInterval(() => {
  const minute = Math.round((Date.now() - started) / 60_000);
  const last = summary(Math.max(0, Date.now() - started - 60_000));
  out(
    `[${minute} min] ${counters.ordersCreated} commandes, ${counters.accepted} acceptées, ${counters.delivered} livrées · dernière minute : ${last.calls} appels, 95 % < ${last.p95} ms`,
  );
}, 60_000);

await sleep(MINUTES * 60_000);
running = false;
clearInterval(progress);
await Promise.race([Promise.allSettled([...ridersDone, ...staffDone]), sleep(15_000)]);
clearInterval(logTimer);
clearInterval(resourceTimer);
for (const socket of shopSockets.values()) socket.disconnect();

const whole = summary(0);
const steady = summary(WARMUP_MS);
printTable('Toute la durée', whole);
printTable(`Régime établi (après ${WARMUP_MS / 60_000} min)`, steady);
const assign = [...counters.assignSeconds].sort((a, b) => a - b);
out(
  `\nCommandes : ${counters.ordersCreated} passées, ${counters.ordersRefused} refusées ; propositions reçues ${counters.offersReceived} ; acceptées ${counters.accepted} (perdues ${counters.acceptLost}) ; enlevées ${counters.pickedUp} ; livrées ${counters.delivered} (sans code lu : ${counters.noCode})`,
);
out(
  `Commande acceptée par un livreur : médiane ${Math.round(percentile(assign, 50))} s, 95 % ${Math.round(percentile(assign, 95))} s après la commande`,
);
if (resources.length > 0) {
  const cpu = resources.map((r) => r.cpu).sort((a, b) => a - b);
  out(
    `API : processeur médian ${percentile(cpu, 50)} %, max ${cpu.at(-1)} % (100 % = un cœur) ; mémoire max ${Math.max(...resources.map((r) => r.rssMb))} Mo`,
  );
}
const ok = steady.shareUnder500 >= 95;
out(
  `\n${ok ? 'OK' : 'ÉCHEC'} : ${steady.shareUnder500} % des appels en moins de 500 ms en régime établi (objectif 95 %)`,
);
if (values.report) {
  writeFileSync(
    values.report,
    JSON.stringify(
      {
        options: values,
        counters: { ...counters, assignSeconds: undefined },
        whole,
        steady,
        resources,
      },
      null,
      2,
    ),
  );
}
process.exit(ok ? 0 : 1);
