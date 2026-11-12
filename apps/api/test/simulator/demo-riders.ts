/**
 * Livreurs fictifs pour l'écran Livreurs du back-office (H3) : candidats à examiner, un
 * livreur actif avec son activité, un livreur suspendu. Les pièces sont des images
 * « SPÉCIMEN » prises dans un dossier (une par type : NATIONAL_ID_FRONT.jpg…).
 *
 * Données entièrement fictives, écrites dans la base de DÉVELOPPEMENT :
 *
 *   DATABASE_URL=… REDIS_URL=… DEMO_DOCS_DIR=… pnpm --filter @tara/api demo:riders
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import request from 'supertest';
import type { KycDocumentType } from '../../src/generated/prisma/enums.js';
import { REQUIRED_DOCUMENTS } from '../../src/riders/riders.schemas.js';
import { createTestApp, type SignedIn, signIn, staffUser } from '../helpers/app.js';
import { merchant, placeOrder } from '../helpers/orders.js';

const DOCS_DIR = process.env['DEMO_DOCS_DIR'];
if (!DOCS_DIR) throw new Error('DEMO_DOCS_DIR manquant (dossier des images SPÉCIMEN)');

const DAY = 86_400_000;
const MINUTE = 60_000;
const ctx = await createTestApp();
const http = ctx.http;
const log = (line: string) => process.stdout.write(`${line}\n`);

/** Date du calendrier dans [days] jours. */
const inDays = (days: number): string =>
  new Date(Date.now() + days * DAY).toISOString().slice(0, 10);

async function candidate(name: string, plate: string, vehicleType = 'MOTORBIKE') {
  const session = await signIn(ctx);
  await ctx.prisma.user.update({ where: { id: session.userId }, data: { fullName: name } });
  const res = await request(http)
    .post('/v1/riders/apply')
    .set(session.auth)
    .send({
      vehicleType,
      plateNumber: plate,
      guarantorName: 'Garant fictif',
      guarantorPhone: '699000111',
      emergencyContact: { name: 'Proche fictif', phone: '677000222' },
    })
    .expect(201);
  return { ...session, riderId: res.body.id as string };
}

async function upload(session: SignedIn, type: KycDocumentType, expiresOn?: string) {
  const file = await readFile(join(DOCS_DIR as string, `${type}.jpg`));
  const req = request(http)
    .post('/v1/riders/me/documents')
    .set(session.auth)
    .field('type', type)
    .attach('file', file, { filename: `${type}.jpg`, contentType: 'image/jpeg' });
  const res = await (expiresOn ? req.field('expiresOn', expiresOn) : req).expect(201);
  return res.body.id as string;
}

async function review(staff: SignedIn, id: string, rejectionReason?: string) {
  await request(http)
    .post(`/v1/admin/kyc-documents/${id}/review`)
    .set(staff.auth)
    .send(rejectionReason ? { decision: 'REJECTED', rejectionReason } : { decision: 'APPROVED' })
    .expect(200);
}

async function interview(staff: SignedIn, riderId: string, passed: boolean, note: string) {
  await request(http)
    .post(`/v1/admin/riders/${riderId}/interview`)
    .set(staff.auth)
    .send({ passed, note })
    .expect(200);
}

async function decide(staff: SignedIn, riderId: string, decision: string, reason?: string) {
  await request(http)
    .post(`/v1/admin/riders/${riderId}/decision`)
    .set(staff.auth)
    .send({ decision, ...(reason ? { reason } : {}) })
    .expect(200);
}

const firstTypes = REQUIRED_DOCUMENTS.map((group) => group[0] as KycDocumentType);
const expiryOf = (type: KycDocumentType, days = 400): string | undefined =>
  ['NATIONAL_ID_FRONT', 'DRIVING_LICENSE', 'INSURANCE'].includes(type) ? inDays(days) : undefined;

/**
 * Inscription reculée de [days] jours : l'activité fictive tombe après elle. Le journal
 * d'audit, lui, n'est jamais modifié (droits de la base) : l'historique garde ses vraies dates.
 */
async function backdate(riderId: string, days: number): Promise<void> {
  await ctx.prisma.riderProfile.update({
    where: { id: riderId },
    data: { createdAt: new Date(Date.now() - days * DAY) },
  });
}

/** Livreur fictif déjà créé par un lancement précédent (le script peut être relancé). */
async function existing(name: string): Promise<{ riderId: string; userId: string } | null> {
  const rider = await ctx.prisma.riderProfile.findFirst({
    where: { user: { fullName: name } },
    select: { id: true, userId: true },
  });
  return rider ? { riderId: rider.id, userId: rider.userId } : null;
}

try {
  const dispatch = await staffUser(ctx, ['DISPATCHER']);
  await ctx.prisma.user.update({
    where: { id: dispatch.userId },
    data: { fullName: 'Mireille Ndongo' },
  });

  // 1. Candidat complet : toutes ses pièces attendent l'examen, pas encore d'entretien.
  if (!(await existing('Ibrahim Nfor'))) {
    const ibrahim = await candidate('Ibrahim Nfor', 'LT 482 KB');
    for (const type of firstTypes) await upload(ibrahim, type, expiryOf(type));
  }
  log('Candidat à examiner : Ibrahim Nfor');

  // 2. Candidate presque prête : pièces validées, selfie flou refusé puis renvoyé, entretien réussi.
  if (!(await existing('Sandrine Mvogo'))) {
    const sandrine = await candidate('Sandrine Mvogo', 'LT 913 SM');
    for (const type of firstTypes.filter((type) => type !== 'SELFIE')) {
      await review(dispatch, await upload(sandrine, type, expiryOf(type)));
    }
    await review(
      dispatch,
      await upload(sandrine, 'SELFIE'),
      'Photo floue, visage caché par le casque',
    );
    await upload(sandrine, 'SELFIE');
    await interview(
      dispatch,
      sandrine.riderId,
      true,
      'Connaît bien Akwa et Bonapriso, moto en bon état, a compris les règles d’encaissement.',
    );
  }
  log('Candidate presque prête : Sandrine Mvogo');

  // 3. Candidat incomplet, entretien échoué.
  if (!(await existing('Jean-Pierre Kamga'))) {
    const jp = await candidate('Jean-Pierre Kamga', 'LT 207 JK');
    for (const type of ['NATIONAL_ID_FRONT', 'NATIONAL_ID_BACK', 'DRIVING_LICENSE'] as const) {
      await review(dispatch, await upload(jp, type, expiryOf(type)));
    }
    await interview(
      dispatch,
      jp.riderId,
      false,
      'Ne connaît pas encore les quartiers ; à revoir dans un mois.',
    );
  }
  log('Candidat incomplet : Jean-Pierre Kamga');

  // 4. Livreuse active depuis 5 mois, assurance qui expire bientôt, activité réaliste.
  let aminatou = await existing('Aminatou Bello');
  if (!aminatou) {
    const session = await candidate('Aminatou Bello', 'LT 655 AB');
    for (const type of firstTypes) {
      const id = await upload(session, type, expiryOf(type, type === 'INSURANCE' ? 12 : 400));
      await review(dispatch, id);
    }
    await interview(
      dispatch,
      session.riderId,
      true,
      'Ancienne livreuse de repas, très à l’aise au guidon et polie au téléphone.',
    );
    await decide(dispatch, session.riderId, 'APPROVE');
    aminatou = { riderId: session.riderId, userId: session.userId };
  }
  // Reprise possible : les courses déjà créées par un lancement interrompu sont gardées.
  if ((await ctx.prisma.riderOnlineSession.count({ where: { riderId: aminatou.riderId } })) === 0) {
    await backdate(aminatou.riderId, 150);
    const done = await ctx.prisma.order.count({ where: { riderId: aminatou.riderId } });
    await activity(aminatou.riderId, aminatou.userId, done);
  }
  log(`Livreuse active : Aminatou Bello (${aminatou.riderId})`);

  // 5. Livreur suspendu après une plainte.
  if (!(await existing('Hervé Tchoupo'))) {
    const herve = await candidate('Hervé Tchoupo', 'LT 318 HT');
    for (const type of firstTypes)
      await review(dispatch, await upload(herve, type, expiryOf(type)));
    await interview(dispatch, herve.riderId, true, 'Bon entretien.');
    await decide(dispatch, herve.riderId, 'APPROVE');
    await decide(
      dispatch,
      herve.riderId,
      'SUSPEND',
      'Plainte d’une boutique : colis livré ouvert, à instruire avec le livreur.',
    );
  }
  log('Livreur suspendu : Hervé Tchoupo');
} finally {
  await ctx.app.close();
}

/** Activité fictive : courses livrées (dont quelques retards), propositions, notes, alertes. */
async function activity(riderId: string, userId: string, skip = 0): Promise<void> {
  const shop = await merchant(ctx);
  const now = Date.now();
  const raters: SignedIn[] = [];
  for (let i = 0; i < 6; i += 1) raters.push(await signIn(ctx));
  // 42 courses ces 30 jours (3 en retard), 96 plus anciennes.
  const plan = [
    ...Array.from({ length: 42 }, (_, i) => ({ days: 1 + (i % 29), late: i % 14 === 3 })),
    ...Array.from({ length: 96 }, (_, i) => ({ days: 32 + (i % 115), late: i % 9 === 0 })),
  ];
  for (const [index, item] of plan.entries()) {
    if (index < skip) continue;
    const placed = await placeOrder(ctx, shop);
    const pickedUpAt = new Date(now - item.days * DAY - (index % 9) * 37 * MINUTE);
    await ctx.prisma.order.update({
      where: { id: placed.id },
      data: {
        status: 'DELIVERED',
        riderId,
        assignedAt: new Date(pickedUpAt.getTime() - 12 * MINUTE),
        pickedUpAt,
        deliveredAt: new Date(pickedUpAt.getTime() + (item.late ? 95 : 18) * MINUTE),
      },
    });
    const outcome = index % 11 === 5 ? 'DECLINED' : index % 17 === 8 ? 'EXPIRED' : 'ACCEPTED';
    await ctx.prisma.dispatchOffer.create({
      data: {
        orderId: placed.id,
        riderId,
        round: 1,
        offeredAt: new Date(pickedUpAt.getTime() - 15 * MINUTE),
        expiresAt: new Date(pickedUpAt.getTime() - 15 * MINUTE + 30_000),
        respondedAt: new Date(pickedUpAt.getTime() - 15 * MINUTE + 9_000),
        outcome,
      },
    });
    if (index % 3 === 0) {
      await ctx.prisma.rating.create({
        data: {
          orderId: placed.id,
          raterId: (raters[index % raters.length] as SignedIn).userId,
          rateeId: userId,
          score: index % 12 === 0 ? 3 : index % 5 === 0 ? 4 : 5,
          createdAt: new Date(pickedUpAt.getTime() + 2 * 60 * MINUTE),
        },
      });
    }
    if (index === 4 || index === 60) {
      await ctx.prisma.orderEvent.create({
        data: {
          orderId: placed.id,
          toStatus: 'DELIVERY_FAILED',
          actorId: userId,
          actorRole: 'RIDER',
          failureReason: 'RECIPIENT_ABSENT',
          occurredAt: new Date(pickedUpAt.getTime() + 10 * MINUTE),
        },
      });
    }
    if (index === 10) {
      await ctx.prisma.courseAlert.create({
        data: {
          orderId: placed.id,
          riderId,
          kind: 'LONG_STOP',
          dedupeKey: 'LONG_STOP:demo',
          details: { minutes: 14 },
          createdAt: pickedUpAt,
        },
      });
    }
  }
  // Temps en ligne : 6 h par jour, 5 jours sur 7.
  for (let day = 1; day <= 140; day += 1) {
    if (day % 7 === 0 || day % 7 === 6) continue;
    const startedAt = new Date(now - day * DAY);
    await ctx.prisma.riderOnlineSession.create({
      data: {
        riderId,
        startedAt,
        lastSeenAt: new Date(startedAt.getTime() + 6 * 60 * MINUTE),
        endedAt: new Date(startedAt.getTime() + 6 * 60 * MINUTE),
      },
    });
  }
  const ratings = await ctx.prisma.rating.aggregate({
    where: { rateeId: userId },
    _sum: { score: true },
    _count: { _all: true },
  });
  await ctx.prisma.riderProfile.update({
    where: { id: riderId },
    data: { ratingSum: ratings._sum.score ?? 0, ratingCount: ratings._count._all },
  });
}
