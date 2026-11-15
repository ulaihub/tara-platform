/**
 * Ville fictive pour le back-office (H1 à H8) et la journée de pilote simulée : des
 * boutiques passent commande, des livreurs virtuels acceptent, roulent dans Douala,
 * récupèrent et livrent ; quelques incidents typiques sont mis en scène (commande sans
 * livreur, retards, livreur sans signal, SOS, remise sans code).
 *
 * Données entièrement fictives, écrites dans la base et le Redis de DÉVELOPPEMENT :
 *
 *   DATABASE_URL=… REDIS_URL=… pnpm --filter @tara/api demo:city -- --riders 30 --minutes 20
 *
 * Options : --riders (30), --minutes de vie de la ville (20), --speed (6 : les livreurs
 * roulent 6 fois plus vite qu'en vrai), --every (45 s entre deux commandes), --seed.
 * Avec DEMO_OSRM_URL (ex. http://localhost:5000), les livreurs suivent les rues.
 */
import { randomUUID } from 'node:crypto';
import { parseArgs } from 'node:util';
import request from 'supertest';
import { createTestApp, type SignedIn, signIn, staffUser } from '../helpers/app.js';
import { createAddress, square } from '../helpers/geo.js';
import {
  DOUALA_GRID,
  DOUALA_TRICYCLE_GRID,
  placeOrder,
  type PlacedOrder,
} from '../helpers/orders.js';
import { activeRider, proofPhoto, type TestRider } from '../helpers/riders.js';
import { DistanceService } from '../../src/routing/distance.service.js';
import { random } from './simulation.js';

const { values } = parseArgs({
  options: {
    riders: { type: 'string' },
    minutes: { type: 'string' },
    speed: { type: 'string' },
    every: { type: 'string' },
    seed: { type: 'string' },
  },
});
const option = (value: string | undefined, fallback: number) =>
  value === undefined ? fallback : Number(value);
const RIDERS = option(values.riders, 30);
const MINUTES = option(values.minutes, 20);
const SPEED = option(values.speed, 6);
const ORDER_EVERY_S = option(values.every, 45);
const rng = random(option(values.seed, 2026));

if (process.env['NODE_ENV'] === 'production') {
  throw new Error('La ville fictive ne tourne jamais sur une base de production.');
}
// Fournisseurs factices, pas de limite de débit (tous les livreurs virtuels partagent une IP).
process.env['NODE_ENV'] = 'test';
process.env['SMS_PROVIDER'] = 'fake';
process.env['PUSH_PROVIDER'] = 'fake';
process.env['WHATSAPP_PROVIDER'] = 'none';
// Plafonds anti-pompage relevés : tous les comptes virtuels se connectent depuis la même IP.
process.env['OTP_MAX_PER_IP_PER_HOUR'] = '1000000';
process.env['OTP_DAILY_GLOBAL_LIMIT'] = '1000000';
// Serveur d'itinéraires facultatif (DEMO_OSRM_URL) : les livreurs suivent alors les rues.
const OSRM_URL = process.env['DEMO_OSRM_URL'];

/** Quartiers de Douala, centres approximatifs (données de démonstration). */
const QUARTIERS = [
  { name: 'Akwa', latitude: 4.0511, longitude: 9.7016 },
  { name: 'Bonanjo', latitude: 4.0425, longitude: 9.6885 },
  { name: 'Bonapriso', latitude: 4.0335, longitude: 9.6955 },
  { name: 'Deïdo', latitude: 4.0645, longitude: 9.7085 },
  { name: 'New Bell', latitude: 4.0375, longitude: 9.7165 },
  { name: 'Ndokoti', latitude: 4.0455, longitude: 9.7405 },
  { name: 'Bépanda', latitude: 4.0625, longitude: 9.7285 },
  { name: 'Makepe', latitude: 4.0785, longitude: 9.7455 },
  { name: 'Bonamoussadi', latitude: 4.0955, longitude: 9.7425 },
  { name: 'Kotto', latitude: 4.0715, longitude: 9.7665 },
  { name: 'Logpom', latitude: 4.0865, longitude: 9.7745 },
  { name: 'Bonabéri', latitude: 4.0705, longitude: 9.6605 },
] as const;

const SHOPS = [
  { name: 'Chez Mama Ngo', quartier: 'Akwa' },
  { name: 'Bijou Mode', quartier: 'Deïdo' },
  { name: 'Électro Kotto', quartier: 'Kotto' },
  { name: 'Saveurs de Makepe', quartier: 'Makepe' },
  { name: 'Tech Bonapriso', quartier: 'Bonapriso' },
  { name: 'Pagne Royal', quartier: 'New Bell' },
] as const;

const LANDMARKS = [
  'Portail bleu après la pharmacie',
  'Face au carrefour, immeuble jaune',
  'Derrière la boulangerie',
  'À côté de la station-service',
  'Deuxième ruelle après l’église',
  'Immeuble avec la grande antenne',
];

const NAMES = [
  'Alain Fotso',
  'Boris Tchana',
  'Cédric Abena',
  'Didier Kamga',
  'Éric Nana',
  'Franck Mvondo',
  'Gaston Ewane',
  'Hervé Tagne',
  'Ibrahim Moussa',
  'Joël Ngono',
  'Kevin Essomba',
  'Landry Fouda',
  'Marcel Djeumo',
  'Nicolas Ebode',
  'Olivier Manga',
  'Patrice Owona',
  'Roméo Tchuente',
  'Samuel Ekane',
  'Thierry Biyong',
  'Ulrich Nkwenti',
  'Vincent Atangana',
  'William Ndjock',
  'Yannick Simo',
  'Zacharie Ondoa',
  'Armel Kuete',
  'Bertrand Nguene',
  'Christelle Mballa',
  'Danielle Eyenga',
  'Emmanuel Bekolo',
  'Fabrice Moukoko',
];

type Point = { latitude: number; longitude: number };
const MINUTE = 60_000;
const TICK_MS = 4_000;
/** 300 m par minute en vrai (vitesse prudente d'une moto en ville), accélérée. */
const STEP_M = (300 / 60) * (TICK_MS / 1000) * SPEED;

const pick = <T>(items: readonly T[]): T => items[Math.floor(rng() * items.length)] as T;
const near = (place: Point, spread = 0.006): Point => ({
  latitude: place.latitude + (rng() - 0.5) * spread,
  longitude: place.longitude + (rng() - 0.5) * spread,
});
const quartier = (name: string): Point =>
  QUARTIERS.find((item) => item.name === name) ?? QUARTIERS[0];

function metersBetween(a: Point, b: Point): number {
  const dy = (b.latitude - a.latitude) * 111_320;
  const dx = (b.longitude - a.longitude) * 111_320 * Math.cos((a.latitude * Math.PI) / 180);
  return Math.hypot(dx, dy);
}

function stepToward(from: Point, to: Point, meters: number): { at: Point; heading: number } {
  const distance = metersBetween(from, to);
  const heading =
    ((Math.atan2(to.longitude - from.longitude, to.latitude - from.latitude) * 180) / Math.PI +
      360) %
    360;
  if (distance <= meters) return { at: to, heading };
  const ratio = meters / distance;
  return {
    at: {
      latitude: from.latitude + (to.latitude - from.latitude) * ratio,
      longitude: from.longitude + (to.longitude - from.longitude) * ratio,
    },
    heading,
  };
}

interface Shop extends SignedIn {
  name: string;
  pickupId: string;
  pickup: Point;
  dropoffs: { id: string; at: Point }[];
}

interface Course {
  order: PlacedOrder;
  pickup: Point;
  dropoff: Point;
  /** Livreur figé (retard ou signal perdu mis en scène). */
  frozen?: 'still' | 'silent';
  /** Remise sans code (le destinataire n'a pas son code). */
  withoutCode?: boolean;
}

interface Bot {
  rider: TestRider;
  name: string;
  at: Point;
  online: boolean;
  photoKey: string;
  course: Course | null;
  /** Livreur immobile (SOS mis en scène) : il garde sa position sans prendre de course. */
  paused?: boolean;
  /** Itinéraire en cours (sur les rues si OSRM répond), et sa destination. */
  route?: { to: Point; path: Point[] };
}

const ctx = await createTestApp({
  JOBS_ENABLED: 'true',
  // File de tâches propre à la ville fictive : ses SMS (codes de livraison) restent ici.
  QUEUE_PREFIX: `tara-demo-${Date.now()}`,
  ...(OSRM_URL ? { OSRM_URL } : {}),
});
const distance = ctx.app.get(DistanceService);

/**
 * Avance le livreur vers [to] le long des rues (itinéraire OSRM, calculé une fois par
 * destination) ou en ligne droite sans OSRM. Renvoie le cap pour la position envoyée.
 */
async function drive(bot: Bot, to: Point): Promise<number> {
  if (!bot.route || bot.route.to !== to) {
    const route = await distance.path(bot.at, to, 'full');
    bot.route = {
      to,
      path: route.path.map(([longitude, latitude]) => ({ latitude, longitude })).concat([to]),
    };
  }
  let budget = STEP_M;
  let heading = 0;
  while (budget > 0 && bot.route.path.length > 0) {
    const next = bot.route.path[0] as Point;
    const gap = metersBetween(bot.at, next);
    const step = stepToward(bot.at, next, budget);
    heading = step.heading;
    bot.at = step.at;
    if (gap <= budget) {
      bot.route.path.shift();
      budget -= gap;
    } else {
      budget = 0;
    }
  }
  return heading;
}
const log = (line: string) =>
  process.stdout.write(`${new Date().toLocaleTimeString('fr-FR')} ${line}\n`);

try {
  const admin = await staffUser(ctx, ['ADMIN']);

  // Zone de service et grille : celles de la base si elles existent.
  const hasArea = await ctx.prisma.zone.count({ where: { kind: 'SERVICE_AREA' } });
  if (hasArea === 0) {
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: 'Douala (démo)',
        city: 'Douala',
        kind: 'SERVICE_AREA',
        geometry: square({ latitude: 4.06, longitude: 9.72 }, 0.1),
      })
      .expect(201);
  }
  // Grille moto (colis ordinaires) et grille tricycle (gros objets).
  for (const grid of [DOUALA_GRID, DOUALA_TRICYCLE_GRID]) {
    const vehicleType = 'vehicleType' in grid ? 'TRICYCLE' : 'MOTORBIKE';
    const active = await ctx.prisma.pricingGrid.count({ where: { active: true, vehicleType } });
    if (active > 0) continue;
    await request(ctx.http).post('/v1/admin/pricing-grids').set(admin.auth).send(grid).expect(201);
  }
  // Quartiers (approximatifs) : les adresses portent un nom de quartier lisible.
  for (const place of QUARTIERS) {
    const exists = await ctx.prisma.zone.count({
      where: { kind: 'NEIGHBORHOOD', name: place.name },
    });
    if (exists > 0) continue;
    await request(ctx.http)
      .post('/v1/admin/zones')
      .set(admin.auth)
      .send({
        name: place.name,
        city: 'Douala',
        kind: 'NEIGHBORHOOD',
        geometry: square(place, 0.0075),
      })
      .expect(201);
  }

  // Boutiques, chacune avec quelques clients dans d'autres quartiers.
  const shops: Shop[] = [];
  for (const spec of SHOPS) {
    const user = await signIn(ctx);
    await ctx.prisma.user.update({
      where: { id: user.userId },
      data: { fullName: `Gérant ${spec.name}` },
    });
    await request(ctx.http)
      .put('/v1/me/merchant')
      .set(user.auth)
      .send({ shopName: spec.name, payoutPhone: '677000003', payoutOperator: 'MTN' })
      .expect(200);
    const pickup = near(quartier(spec.quartier), 0.004);
    const created = await createAddress(ctx, user, pickup, {
      label: spec.name,
      landmark: pick(LANDMARKS),
    });
    const dropoffs = [];
    for (let index = 0; index < 5; index += 1) {
      const target = pick(QUARTIERS.filter((item) => item.name !== spec.quartier));
      const at = near(target, 0.008);
      const address = await createAddress(ctx, user, at, {
        contactName: 'Client',
        landmark: pick(LANDMARKS),
      });
      dropoffs.push({ id: address.id, at });
    }
    shops.push({ ...user, name: spec.name, pickupId: created.id, pickup, dropoffs });
  }
  log(`${shops.length} boutiques prêtes`);

  // Livreurs : la plupart en ligne, quelques-uns rentrés chez eux, d'autres jamais connectés.
  const bots: Bot[] = [];
  for (let index = 0; index < RIDERS; index += 1) {
    const rider = await activeRider(ctx);
    const name = NAMES[index % NAMES.length] as string;
    await ctx.prisma.user.update({ where: { id: rider.userId }, data: { fullName: name } });
    await ctx.prisma.riderProfile.update({
      where: { id: rider.riderId },
      data: {
        plateNumber: `LT ${String(100 + Math.floor(rng() * 900))} ${String.fromCharCode(65 + Math.floor(rng() * 26))}${String.fromCharCode(65 + Math.floor(rng() * 26))}`,
        ratingSum: Math.round((4 + rng()) * 20),
        ratingCount: 20,
        // Un livreur sur six roule en tricycle : lui seul prend les gros objets.
        vehicleType: index % 6 === 5 ? 'TRICYCLE' : 'MOTORBIKE',
      },
    });
    const at = near(pick(QUARTIERS), 0.012);
    const roll = rng();
    const bot: Bot = {
      rider,
      name,
      at,
      online: false,
      photoKey: await proofPhoto(ctx, rider),
      course: null,
    };
    if (roll < 0.85) {
      await request(ctx.http)
        .put('/v1/rider/presence')
        .set(rider.auth)
        .send({ online: true, ...at })
        .expect(200);
      bot.online = true;
      if (roll >= 0.75) {
        // Rentré il y a peu : dernière position gardée, grisée sur la carte.
        await request(ctx.http)
          .put('/v1/rider/presence')
          .set(rider.auth)
          .send({ online: false, ...at })
          .expect(200);
        bot.online = false;
      }
    }
    bots.push(bot);
  }
  log(`${bots.length} livreurs, ${bots.filter((bot) => bot.online).length} en ligne`);

  const stuck = new Set<string>();
  const courses = new Map<string, Course>();

  async function order(shop: Shop, extra: Record<string, unknown> = {}): Promise<Course> {
    const dropoff = pick(shop.dropoffs);
    const placed = await placeOrder(ctx, { ...shop, dropoffId: dropoff.id }, extra);
    const course = { order: placed, pickup: shop.pickup, dropoff: dropoff.at };
    courses.set(placed.id, course);
    return course;
  }

  async function send(bot: Bot, heading?: number): Promise<void> {
    if (!bot.online || bot.course?.frozen === 'silent') return;
    await request(ctx.http)
      .post('/v1/rider/location')
      .set(bot.rider.auth)
      .send({ ...bot.at, ...(heading === undefined ? {} : { heading }), speed: 8, accuracy: 10 });
  }

  /** Le livreur libre le plus proche accepte la proposition qu'il a reçue pour cette commande. */
  async function acceptFor(course: Course, bot?: Bot): Promise<Bot | null> {
    const candidates = bot
      ? [bot]
      : bots.filter((item) => item.online && !item.course && !item.paused);
    for (const candidate of candidates.sort(
      (a, b) => metersBetween(a.at, course.pickup) - metersBetween(b.at, course.pickup),
    )) {
      const offers = await request(ctx.http).get('/v1/rider/offers').set(candidate.rider.auth);
      const offer = (offers.body as { id: string; orderId: string }[]).find(
        (item) => item.orderId === course.order.id,
      );
      if (!offer) continue;
      const accepted = await request(ctx.http)
        .post(`/v1/rider/offers/${offer.id}/accept`)
        .set(candidate.rider.auth);
      if (accepted.status !== 200) continue;
      candidate.course = course;
      return candidate;
    }
    return null;
  }

  async function pickUp(bot: Bot, course: Course): Promise<void> {
    await request(ctx.http)
      .post(`/v1/rider/orders/${course.order.id}/pickup`)
      .set(bot.rider.auth)
      .send({ pickupCode: course.order.pickupCode, photoKey: bot.photoKey, ...bot.at })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/rider/orders/${course.order.id}/depart`)
      .set(bot.rider.auth)
      .send(bot.at)
      .expect(200);
  }

  async function deliver(bot: Bot, course: Course): Promise<void> {
    const code = /le code au livreur : (\d{4})/.exec(
      ctx.sms.lastTo(course.order.recipientPhone)?.text ?? '',
    )?.[1];
    const body =
      course.withoutCode || !code
        ? { receivedBy: 'Sa sœur Brigitte', photoKey: bot.photoKey, ...bot.at }
        : { deliveryCode: code, photoKey: bot.photoKey, ...bot.at };
    await request(ctx.http)
      .post(`/v1/rider/orders/${course.order.id}/deliver`)
      .set(bot.rider.auth)
      .send(body)
      .expect(200);
  }

  const scene = async (label: string, run: () => Promise<void>) => {
    try {
      await run();
      log(`Scène : ${label}`);
    } catch (error) {
      log(
        `Scène « ${label} » impossible : ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  };

  // Gros objets, tant que les tricycles sont libres.
  await scene('gros objet en tricycle, chargement à deux', async () => {
    const course = await order(shops[2] as Shop, {
      packageSize: 'BULKY',
      loadingHelp: true,
      packageContents: 'HOUSEHOLD',
      packageDescription: 'Réfrigérateur 2 portes',
    });
    if (!(await acceptFor(course))) throw new Error('aucun tricycle disponible');
  });
  await scene('colis non conforme refusé à l’enlèvement', async () => {
    const course = await order(shops[0] as Shop, {
      packageSize: 'BULKY',
      packageContents: 'HOUSEHOLD',
      packageDescription: 'Cuisinière 4 feux',
    });
    const bot = await acceptFor(course);
    if (!bot) throw new Error('aucun tricycle disponible');
    bot.at = near(course.pickup, 0.0004);
    await send(bot);
    await request(ctx.http)
      .post(`/v1/rider/orders/${course.order.id}/refuse-parcel`)
      .set(bot.rider.auth)
      .send({
        reason: 'NOT_AS_DECLARED',
        note: 'Armoire 3 portes, ne tient pas dans le tricycle',
        photoKey: bot.photoKey,
        clientEventId: randomUUID(),
        ...bot.at,
      })
      .expect(200);
    courses.delete(course.order.id);
    bot.course = null;
  });

  // Premières commandes, prises par les livreurs proches.
  for (let index = 0; index < 8; index += 1) {
    const course = await order(pick(shops));
    await new Promise((resolve) => setTimeout(resolve, 300));
    await acceptFor(course);
  }

  // Incidents mis en scène.
  await scene('commande sans livreur depuis 9 min (Bonabéri)', async () => {
    const shop = shops[0] as Shop;
    const far = await createAddress(ctx, shop, near(quartier('Bonabéri'), 0.004), {
      contactName: 'Client',
      landmark: 'Après le pont, marché de Bonabéri',
    });
    const placed = await placeOrder(ctx, { ...shop, dropoffId: far.id });
    stuck.add(placed.id);
    await ctx.prisma.order.update({
      where: { id: placed.id },
      data: {
        searchingSince: new Date(Date.now() - 9 * MINUTE),
        createdAt: new Date(Date.now() - 9 * MINUTE),
      },
    });
  });
  await scene('enlèvement en retard (livreur arrêté loin du vendeur)', async () => {
    const course = await order(shops[2] as Shop);
    const bot = await acceptFor(course);
    if (!bot) throw new Error('aucun livreur disponible');
    course.frozen = 'still';
    await ctx.prisma.order.update({
      where: { id: course.order.id },
      data: {
        createdAt: new Date(Date.now() - 35 * MINUTE),
        assignedAt: new Date(Date.now() - 32 * MINUTE),
      },
    });
  });
  await scene('livraison en retard (colis à bord depuis 55 min)', async () => {
    const course = await order(shops[3] as Shop);
    const bot = await acceptFor(course);
    if (!bot) throw new Error('aucun livreur disponible');
    bot.at = near(course.pickup, 0.0005);
    await send(bot);
    await pickUp(bot, course);
    const midway = stepToward(
      course.pickup,
      course.dropoff,
      metersBetween(course.pickup, course.dropoff) / 2,
    );
    bot.at = midway.at;
    await send(bot, midway.heading);
    course.frozen = 'still';
    await ctx.prisma.order.update({
      where: { id: course.order.id },
      data: {
        createdAt: new Date(Date.now() - 74 * MINUTE),
        assignedAt: new Date(Date.now() - 70 * MINUTE),
        pickedUpAt: new Date(Date.now() - 55 * MINUTE),
      },
    });
  });
  await scene('livreur en course sans signal', async () => {
    const course = await order(shops[4] as Shop);
    const bot = await acceptFor(course);
    if (!bot) throw new Error('aucun livreur disponible');
    course.frozen = 'silent';
  });
  await scene('remise sans code à valider', async () => {
    const course = await order(shops[5] as Shop);
    const bot = await acceptFor(course);
    if (!bot) throw new Error('aucun livreur disponible');
    course.withoutCode = true;
    bot.at = near(course.pickup, 0.0005);
    await send(bot);
    await pickUp(bot, course);
    bot.at = near(course.dropoff, 0.0004);
    await send(bot);
    await deliver(bot, course);
    course.frozen = 'still';
  });
  await scene('SOS d’un livreur à Ndokoti', async () => {
    const bot = bots.find((item) => item.online && !item.course);
    if (!bot) throw new Error('aucun livreur libre');
    bot.at = near(quartier('Ndokoti'), 0.002);
    await send(bot);
    await request(ctx.http)
      .post('/v1/rider/alerts')
      .set(bot.rider.auth)
      .send({
        ...bot.at,
        accuracy: 15,
        note: 'Deux individus me suivent depuis le carrefour',
        clientEventId: randomUUID(),
      })
      .expect(201);
    bot.paused = true;
  });

  // La ville vit : nouvelles commandes, livreurs qui roulent, propositions acceptées.
  const end = Date.now() + MINUTES * MINUTE;
  let nextOrder = Date.now() + ORDER_EVERY_S * 1000;
  let ticks = 0;
  log(`La ville vit pendant ${MINUTES} min (Ctrl+C pour arrêter)`);
  while (Date.now() < end) {
    ticks += 1;
    if (Date.now() >= nextOrder) {
      const bulky = rng() < 0.125;
      const course = await order(
        pick(shops),
        bulky ? { packageSize: 'BULKY', loadingHelp: rng() < 0.5 } : {},
      );
      log(`Nouvelle commande ${course.order.reference}${bulky ? ' (gros objet)' : ''}`);
      nextOrder = Date.now() + ORDER_EVERY_S * 1000 * (0.5 + rng());
    }
    for (const course of courses.values()) {
      if (stuck.has(course.order.id)) continue;
      const current = await ctx.prisma.order.findUnique({
        where: { id: course.order.id },
        select: { status: true },
      });
      if (current?.status === 'SEARCHING_RIDER' && !bots.some((bot) => bot.course === course)) {
        await acceptFor(course);
      }
    }
    for (const bot of bots) {
      if (!bot.online) continue;
      const course = bot.course;
      if (bot.paused) {
        await send(bot);
        continue;
      }
      if (!course) {
        // Livreur libre : il attend près de là où il est, position toujours fraîche.
        if (ticks % 15 === 0 && rng() < 0.3) bot.at = near(bot.at, 0.0003);
        await send(bot);
        continue;
      }
      if (course.frozen) {
        if (course.frozen === 'still') await send(bot);
        continue;
      }
      const status = (
        await ctx.prisma.order.findUnique({
          where: { id: course.order.id },
          select: { status: true },
        })
      )?.status;
      if (status === 'ASSIGNED') {
        await send(bot, await drive(bot, course.pickup));
        if (metersBetween(bot.at, course.pickup) < 30) await pickUp(bot, course);
      } else if (status === 'IN_DELIVERY' || status === 'PICKED_UP') {
        await send(bot, await drive(bot, course.dropoff));
        if (metersBetween(bot.at, course.dropoff) < 30) {
          await deliver(bot, course);
          log(`${bot.name} a livré ${course.order.reference}`);
          courses.delete(course.order.id);
          bot.course = null;
        }
      } else {
        // Commande terminée, annulée ou retirée : le livreur redevient libre.
        courses.delete(course.order.id);
        bot.course = null;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, TICK_MS));
  }
  log('Fin de la ville fictive');
} finally {
  await ctx.app.close();
}
process.exit(0);
