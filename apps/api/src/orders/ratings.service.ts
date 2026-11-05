import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { RateBody, RatingDto } from './orders.schemas.js';

/** Une course se note pendant 7 jours après sa fin (F4). */
export const RATING_WINDOW_DAYS = 7;

type Rating = { raterId: string; score: number; comment: string | null; createdAt: Date };

export function ratingDto(rating: Rating | undefined): z.output<typeof RatingDto> | null {
  return rating
    ? { score: rating.score, comment: rating.comment, at: rating.createdAt.toISOString() }
    : null;
}

/**
 * Notation réciproque après la course (F4) : l'expéditeur note le livreur, le livreur note
 * l'expéditeur, une fois chacun. La note du livreur entre dans son score d'attribution
 * (D1) ; les commentaires ne sont lus que par l'équipe.
 */
@Injectable()
export class RatingsService {
  constructor(private readonly prisma: PrismaService) {}

  /** L'expéditeur note le livreur de sa course. */
  async rateRider(
    user: AuthUser,
    orderId: string,
    body: z.output<typeof RateBody>,
  ): Promise<z.output<typeof RatingDto>> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { rider: { select: { id: true, userId: true } } },
    });
    if (order?.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    this.assertOpen(order);
    const rider = order.rider;
    if (!rider) throw AppError.unprocessable('RATING_NOT_OPEN');
    return this.save(order.id, user.id, rider.userId, body, rider.id);
  }

  /** Le livreur note l'expéditeur de sa course. */
  async rateSender(
    user: AuthUser,
    orderId: string,
    body: z.output<typeof RateBody>,
  ): Promise<z.output<typeof RatingDto>> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { rider: { select: { userId: true } } },
    });
    if (!order || order.rider?.userId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    this.assertOpen(order);
    return this.save(order.id, user.id, order.senderId, body, null);
  }

  /** Course livrée ou rendue, terminée depuis moins de 7 jours. */
  private assertOpen(order: {
    status: string;
    deliveredAt: Date | null;
    returnedAt: Date | null;
  }): void {
    const ended = order.status === 'DELIVERED' ? order.deliveredAt : order.returnedAt;
    const open =
      (order.status === 'DELIVERED' || order.status === 'RETURNED') &&
      ended !== null &&
      Date.now() - ended.getTime() <= RATING_WINDOW_DAYS * 86_400_000;
    if (!open) throw AppError.unprocessable('RATING_NOT_OPEN');
  }

  private async save(
    orderId: string,
    raterId: string,
    rateeId: string,
    body: z.output<typeof RateBody>,
    riderProfileId: string | null,
  ): Promise<z.output<typeof RatingDto>> {
    try {
      const rating = await this.prisma.$transaction(async (tx) => {
        const created = await tx.rating.create({
          data: { orderId, raterId, rateeId, score: body.score, comment: body.comment || null },
        });
        // Score d'attribution du livreur (moyenne des notes reçues).
        if (riderProfileId) {
          await tx.riderProfile.update({
            where: { id: riderProfileId },
            data: { ratingSum: { increment: body.score }, ratingCount: { increment: 1 } },
          });
        }
        return created;
      });
      return ratingDto(rating) as z.output<typeof RatingDto>;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw AppError.conflict('RATING_ALREADY_GIVEN');
      }
      throw error;
    }
  }
}
