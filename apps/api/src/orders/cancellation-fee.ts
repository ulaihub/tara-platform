import type { Order, Prisma } from '../generated/prisma/client.js';
import type { Env } from '../config/env.js';
import type { PrismaService } from '../prisma/prisma.service.js';

/**
 * Frais d'annulation (C) si l'expéditeur annule maintenant : seulement quand le livreur est
 * déjà en route vers l'enlèvement. Rien si un autre colis du même envoi part quand même avec
 * ce livreur : son trajet n'est pas perdu.
 */
export async function cancellationFee(
  order: Pick<Order, 'id' | 'status' | 'riderId' | 'batchId'>,
  env: Pick<Env, 'CANCELLATION_FEE'>,
  db: Prisma.TransactionClient | PrismaService,
): Promise<number> {
  if (order.status !== 'ASSIGNED' || !order.riderId) return 0;
  if (order.batchId) {
    const others = await db.order.count({
      where: {
        batchId: order.batchId,
        id: { not: order.id },
        riderId: order.riderId,
        status: { in: ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY'] },
      },
    });
    if (others > 0) return 0;
  }
  return env.CANCELLATION_FEE;
}
