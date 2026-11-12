/**
 * Demandes fictives pour l'écran Support du back-office (H6) : un colis « non reçu » avec
 * ses preuves, l'appel d'une destinataire sans compte, un double paiement en attente, une
 * demande résolue, un livreur qui signale un bug. Photo de preuve « SPÉCIMEN ».
 *
 * Données entièrement fictives, écrites dans la base de DÉVELOPPEMENT :
 *
 *   DATABASE_URL=… REDIS_URL=… DEMO_DOCS_DIR=… pnpm --filter @tara/api demo:support
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import request from 'supertest';
import { createTestApp, randomPhone, type SignedIn, signIn, staffUser } from '../helpers/app.js';
import { merchant, placeOrder } from '../helpers/orders.js';

const DOCS_DIR = process.env['DEMO_DOCS_DIR'];
if (!DOCS_DIR) throw new Error('DEMO_DOCS_DIR manquant (dossier des images SPÉCIMEN)');

const MINUTE = 60_000;
const ctx = await createTestApp();
const http = ctx.http;
const log = (line: string) => process.stdout.write(`${line}\n`);
const ago = (minutes: number): Date => new Date(Date.now() - minutes * MINUTE);

/** Recule une demande et ses messages (créés à la suite) pour une file réaliste. */
async function backdate(ticketId: string, minutes: number): Promise<void> {
  await ctx.prisma.ticket.update({ where: { id: ticketId }, data: { createdAt: ago(minutes) } });
  const messages = await ctx.prisma.ticketMessage.findMany({
    where: { ticketId },
    orderBy: { createdAt: 'asc' },
  });
  for (const [index, message] of messages.entries()) {
    await ctx.prisma.ticketMessage.update({
      where: { id: message.id },
      data: { createdAt: ago(minutes - index * Math.max(2, Math.floor(minutes / 6))) },
    });
  }
}

async function named(session: SignedIn, fullName: string): Promise<SignedIn> {
  await ctx.prisma.user.update({ where: { id: session.userId }, data: { fullName } });
  return session;
}

try {
  if (
    (await ctx.prisma.ticket.count({ where: { subject: 'Ma cliente dit n’avoir rien reçu' } })) > 0
  ) {
    log('Demandes fictives déjà créées.');
  } else {
    const agent = await named(await staffUser(ctx, ['SUPPORT']), 'Nadège Ekwalla');
    const shop = await merchant(ctx);
    await named(shop, 'Mama Ngono');
    await ctx.prisma.merchantProfile.update({
      where: { userId: shop.userId },
      data: { shopName: 'Chez Mama Ngono' },
    });

    // Livreuse de la démo Livreurs si elle existe, sinon un livreur de la ville fictive.
    const rider = await ctx.prisma.riderProfile.findFirstOrThrow({
      where: { status: 'ACTIVE' },
      orderBy: { createdAt: 'asc' },
      select: { id: true, userId: true, user: { select: { phone: true } } },
    });
    const riderSession = await signIn(ctx, rider.user.phone);

    // 1. Colis « non reçu » : livré avec le code, photo de remise, note sévère de la boutique.
    const placed = await placeOrder(ctx, shop, { codAmount: 18_500 });
    const pickedUpAt = ago(26 * 60);
    await ctx.prisma.order.update({
      where: { id: placed.id },
      data: {
        status: 'DELIVERED',
        riderId: rider.id,
        createdAt: new Date(pickedUpAt.getTime() - 25 * MINUTE),
        assignedAt: new Date(pickedUpAt.getTime() - 12 * MINUTE),
        pickedUpAt,
        deliveredAt: new Date(pickedUpAt.getTime() + 24 * MINUTE),
      },
    });
    const photo = await request(http)
      .post('/v1/media')
      .set(riderSession.auth)
      .field('kind', 'PROOF_PHOTO')
      .attach('file', await readFile(join(DOCS_DIR, 'PROOF.jpg')), {
        filename: 'remise.jpg',
        contentType: 'image/jpeg',
      })
      .expect(201);
    await ctx.prisma.deliveryProof.createMany({
      data: [
        {
          orderId: placed.id,
          kind: 'PICKUP',
          codeVerified: true,
          latitude: 4.0469,
          longitude: 9.6953,
          occurredAt: pickedUpAt,
        },
        {
          orderId: placed.id,
          kind: 'FAILED_ATTEMPT',
          latitude: 4.0611,
          longitude: 9.7429,
          occurredAt: new Date(pickedUpAt.getTime() + 14 * MINUTE),
          callLog: [
            {
              to: 'RECIPIENT',
              at: new Date(pickedUpAt.getTime() + 8 * MINUTE).toISOString(),
              durationSeconds: 0,
            },
            {
              to: 'RECIPIENT',
              at: new Date(pickedUpAt.getTime() + 13 * MINUTE).toISOString(),
              durationSeconds: 38,
            },
          ],
        },
        {
          orderId: placed.id,
          kind: 'DELIVERY',
          photoKey: photo.body.key as string,
          codeVerified: true,
          latitude: 4.0612,
          longitude: 9.7431,
          occurredAt: new Date(pickedUpAt.getTime() + 24 * MINUTE),
        },
      ],
    });
    await ctx.prisma.rating.create({
      data: {
        orderId: placed.id,
        raterId: shop.userId,
        rateeId: rider.userId,
        score: 1,
        comment: 'Ma cliente n’a rien reçu.',
      },
    });
    const lost = await request(http)
      .post('/v1/support/tickets')
      .set(shop.auth)
      .send({
        category: 'LOST_PARCEL',
        subject: 'Ma cliente dit n’avoir rien reçu',
        message:
          'Bonjour, ma cliente de Bonamoussadi dit qu’elle n’a jamais reçu sa robe, alors que l’app affiche « livrée ». Elle refuse de payer.',
        orderId: placed.id,
      })
      .expect(201);
    await request(http)
      .post(`/v1/admin/support/tickets/${lost.body.id}/messages`)
      .set(agent.auth)
      .send({
        body: 'Le code de livraison a été donné au livreur et la photo montre le colis devant la porte. Rappeler la cliente avant de répondre.',
        internal: true,
      })
      .expect(200);
    await backdate(lost.body.id, 55);
    log(`Colis non reçu : ${lost.body.reference}`);

    // 2. Appel d'une destinataire sans compte : livreur impoli, urgent.
    const call = await request(http)
      .post('/v1/admin/support/tickets')
      .set(agent.auth)
      .send({
        phone: randomPhone(),
        orderReference: placed.reference,
        category: 'RIDER_BEHAVIOR',
        priority: 'URGENT',
        subject: 'Livreur impoli à la porte',
        message:
          'La destinataire appelle : le livreur a haussé le ton quand elle a demandé à voir le colis avant de payer.',
      })
      .expect(201);
    await backdate(call.body.id, 18);
    log(`Appel d'une destinataire : ${call.body.reference}`);

    // 3. Double paiement, en attente de réponse.
    const customer = await named(await signIn(ctx), 'Brice Tchakounté');
    const paid = await request(http)
      .post('/v1/support/tickets')
      .set(customer.auth)
      .send({
        category: 'PAYMENT',
        subject: 'Débité deux fois pour la même course',
        message: 'J’ai payé 1 500 F par MTN MoMo et j’ai été débité deux fois. Merci de vérifier.',
      })
      .expect(201);
    await backdate(paid.body.id, 95);
    log(`Double paiement : ${paid.body.reference}`);

    // 4. Demande résolue : colis abîmé, avoir accordé.
    const damaged = await request(http)
      .post('/v1/support/tickets')
      .set(customer.auth)
      .send({
        category: 'DAMAGED_PARCEL',
        subject: 'Carton écrasé à l’arrivée',
        message: 'Le carton de téléphone est arrivé écrasé, l’écran est fissuré.',
      })
      .expect(201);
    await request(http)
      .post(`/v1/admin/support/tickets/${damaged.body.id}/messages`)
      .set(agent.auth)
      .send({
        body: 'Bonjour, nous sommes désolés. Un avoir de 1 500 F a été ajouté à votre solde Tara.',
      })
      .expect(200);
    await request(http)
      .patch(`/v1/admin/support/tickets/${damaged.body.id}`)
      .set(agent.auth)
      .send({ status: 'RESOLVED' })
      .expect(200);
    await backdate(damaged.body.id, 60 * 26);
    log(`Résolue : ${damaged.body.reference}`);

    // 5. Un livreur signale un bug de l'app.
    const bug = await request(http)
      .post('/v1/support/tickets')
      .set(riderSession.auth)
      .send({
        category: 'APP_BUG',
        subject: 'L’app se ferme à la photo de remise',
        message: 'Quand je prends la photo de remise, l’app se ferme. Téléphone Tecno Spark 10.',
      })
      .expect(201);
    await backdate(bug.body.id, 140);
    log(`Bug signalé par un livreur : ${bug.body.reference}`);
  }
} finally {
  await ctx.app.close();
}
