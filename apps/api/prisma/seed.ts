import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { normalizeCameroonMobile } from '../src/common/phone.js';

/**
 * Données de départ pour Douala, rejouables sans doublon (`pnpm db:seed`) :
 * - zone desservie APPROXIMATIVE (rectangle autour de l'agglomération) : à remplacer par
 *   le polygone tracé par l'équipe des opérations avant le pilote ;
 * - grille tarifaire de lancement du business plan ;
 * - offre de bienvenue BIENVENUE : 5 livraisons à 500 FCFA par compte ;
 * - compte administrateur si SEED_ADMIN_PHONE est défini.
 */
const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env['DATABASE_URL'] ?? '' }),
});

const DOUALA_APPROXIMATE_AREA = {
  type: 'Polygon',
  coordinates: [
    [
      [9.62, 3.95],
      [9.84, 3.95],
      [9.84, 4.15],
      [9.62, 4.15],
      [9.62, 3.95],
    ],
  ],
};

async function seedServiceArea(): Promise<void> {
  const inserted = await prisma.$executeRaw`
    INSERT INTO zones (id, name, city, kind, area, updated_at)
    VALUES (
      ${randomUUID()}::uuid, 'Douala (approximatif, à remplacer)', 'Douala', 'SERVICE_AREA',
      ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(${JSON.stringify(DOUALA_APPROXIMATE_AREA)}), 4326))::geography,
      now()
    )
    ON CONFLICT (city, kind, name) DO NOTHING`;
  console.log(
    inserted ? 'Zone desservie de Douala créée' : 'Zone desservie de Douala déjà présente',
  );
}

async function seedPricing(): Promise<void> {
  const active = await prisma.pricingGrid.findFirst({
    where: { city: 'Douala', vehicleType: 'MOTORBIKE', active: true },
  });
  if (active) {
    console.log(`Grille active déjà présente : ${active.name}`);
    return;
  }
  await prisma.pricingGrid.create({
    data: {
      name: 'Douala moto — tarif de lancement',
      city: 'Douala',
      vehicleType: 'MOTORBIKE',
      // Grille validée le 12 novembre 2026 : 70 % au livreur ; 1 000 F jusqu'à 5 km, +100 F par
      // km commencé jusqu'à 10 km, puis +50 F par km (prix du marché sur les longues courses).
      riderShareBps: 7000,
      perKmBeyondLastTier: 50,
      active: true,
      validFrom: new Date(),
      tiers: {
        create: [
          { upToMeters: 5_000, price: 1000 },
          { upToMeters: 6_000, price: 1100 },
          { upToMeters: 7_000, price: 1200 },
          { upToMeters: 8_000, price: 1300 },
          { upToMeters: 9_000, price: 1400 },
          { upToMeters: 10_000, price: 1500 },
        ],
      },
      surcharges: {
        create: [
          { code: 'EXPRESS', amount: 500 },
          { code: 'HEAVY_PARCEL', amount: 1000 },
          { code: 'NIGHT', amount: 500 },
          { code: 'WEATHER', amount: 300, active: false },
          // Frais d'échec (E6) : nouvelle tentative 500 F, retour la moitié du prix de base.
          { code: 'FAILED_ATTEMPT', amount: 500 },
          { code: 'RETURN', percentBps: 5000 },
        ],
      },
    },
  });
  console.log('Grille tarifaire de lancement créée et activée');
}

/**
 * Grille des gros objets (tricycle) : créée INACTIVE. L'offre « Gros objet » s'ouvre quand
 * l'équipe l'active au back-office, une fois des livreurs en tricycle recrutés. Montants
 * de départ à confirmer auprès de transporteurs de Douala.
 */
async function seedBulkyPricing(): Promise<void> {
  const existing = await prisma.pricingGrid.findFirst({
    where: { city: 'Douala', vehicleType: 'TRICYCLE' },
  });
  if (existing) {
    console.log(`Grille tricycle déjà présente : ${existing.name}`);
    return;
  }
  await prisma.pricingGrid.create({
    data: {
      name: 'Douala tricycle — gros objets',
      city: 'Douala',
      vehicleType: 'TRICYCLE',
      riderShareBps: 7000,
      perKmBeyondLastTier: 300,
      active: false,
      validFrom: new Date(),
      tiers: {
        create: [
          { upToMeters: 5_000, price: 3000 },
          { upToMeters: 10_000, price: 4500 },
          { upToMeters: 15_000, price: 6000 },
        ],
      },
      surcharges: {
        create: [
          { code: 'HANDLING', amount: 1500 },
          { code: 'EXPRESS', amount: 1000 },
          { code: 'NIGHT', amount: 1000 },
          { code: 'WEATHER', amount: 500, active: false },
          { code: 'FAILED_ATTEMPT', amount: 1500 },
          { code: 'RETURN', percentBps: 5000 },
        ],
      },
    },
  });
  console.log('Grille tricycle (gros objets) créée, inactive');
}

async function seedWelcomeOffer(): Promise<void> {
  await prisma.promoCode.upsert({
    where: { code: 'BIENVENUE' },
    create: {
      code: 'BIENVENUE',
      kind: 'FIXED_PRICE',
      value: 500,
      perUserLimit: 5,
      validFrom: new Date(),
    },
    update: {},
  });
  console.log('Offre BIENVENUE disponible');
}

async function seedAdmin(): Promise<void> {
  const raw = process.env['SEED_ADMIN_PHONE'];
  if (!raw) return;
  const phone = normalizeCameroonMobile(raw);
  if (!phone) throw new Error(`SEED_ADMIN_PHONE invalide : ${raw}`);
  await prisma.user.upsert({
    where: { phone },
    create: { phone, roles: ['CUSTOMER', 'ADMIN'] },
    update: { roles: { set: ['CUSTOMER', 'ADMIN'] } },
  });
  console.log(`Administrateur ${phone} prêt (connexion par code SMS)`);
}

try {
  await seedServiceArea();
  await seedPricing();
  await seedBulkyPricing();
  await seedWelcomeOffer();
  await seedAdmin();
} finally {
  await prisma.$disconnect();
}
