import { Injectable } from '@nestjs/common';
import { AppError } from '../common/errors/app-error.js';
import type { Prisma, PromoCode } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

/** Codes promo et offres de bienvenue (C6). */
@Injectable()
export class PromoService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Vérifie qu'un code est utilisable par cet utilisateur. Dans une création de commande,
   * appeler `lock` d'abord dans la même transaction pour éviter un dépassement de quota
   * lors d'utilisations simultanées.
   */
  async validate(
    rawCode: string,
    userId: string,
    now: Date,
    tx?: Prisma.TransactionClient,
  ): Promise<PromoCode> {
    const client = tx ?? this.prisma;
    const promo = await client.promoCode.findUnique({
      where: { code: rawCode.trim().toUpperCase() },
    });
    if (!promo) throw AppError.unprocessable('PROMO_INVALID');
    if (!promo.active || promo.validFrom > now || (promo.validTo && promo.validTo <= now)) {
      throw AppError.unprocessable('PROMO_EXPIRED');
    }
    if (promo.maxRedemptions !== null) {
      const used = await client.promoRedemption.count({ where: { promoId: promo.id } });
      if (used >= promo.maxRedemptions) throw AppError.unprocessable('PROMO_EXHAUSTED');
    }
    const usedByUser = await client.promoRedemption.count({ where: { promoId: promo.id, userId } });
    if (usedByUser >= promo.perUserLimit) throw AppError.unprocessable('PROMO_EXHAUSTED');
    if (promo.newCustomersOnly) {
      const orders = await client.order.count({
        where: { senderId: userId, status: { not: 'CANCELLED' } },
      });
      if (orders > 0) throw AppError.unprocessable('PROMO_NOT_ELIGIBLE');
    }
    return promo;
  }

  async lock(code: string, tx: Prisma.TransactionClient): Promise<void> {
    await tx.$queryRaw`SELECT 1 FROM promo_codes WHERE code = ${code.trim().toUpperCase()} FOR UPDATE`;
  }
}
