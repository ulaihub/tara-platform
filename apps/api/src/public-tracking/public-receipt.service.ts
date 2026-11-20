import { Inject, Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { shortName } from '../orders/orders.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { PublicReceiptDto } from './public-receipt.schemas.js';
import { readReceiptCode } from './receipt-code.js';

/** Vérification d'un reçu Tara depuis son QR (page publique « Vérifier un reçu »). */
@Injectable()
export class PublicReceiptService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async verify(code: string): Promise<z.output<typeof PublicReceiptDto>> {
    // Signature fausse et reçu inconnu donnent la même réponse : rien à deviner.
    const reference = readReceiptCode(this.env.CODE_HASH_SECRET, code);
    if (!reference) throw AppError.notFound('ORDER_NOT_FOUND');
    const order = await this.prisma.order.findUnique({
      where: { reference },
      select: {
        reference: true,
        status: true,
        createdAt: true,
        recipientName: true,
        totalPrice: true,
        feePaidAt: true,
        deliveredAt: true,
        merchant: { select: { shopName: true } },
        sender: { select: { fullName: true } },
        dropoffAddress: { select: { neighborhood: { select: { name: true } } } },
        codCollection: { select: { collectedAmount: true } },
      },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    return {
      reference: order.reference,
      status: order.status,
      issuedAt: order.createdAt.toISOString(),
      senderName: order.merchant?.shopName ?? order.sender.fullName ?? null,
      recipientName: shortName(order.recipientName),
      dropoffNeighborhood: order.dropoffAddress.neighborhood?.name ?? null,
      fee: order.totalPrice,
      feePaid: order.feePaidAt !== null,
      deliveredAt: order.deliveredAt?.toISOString() ?? null,
      collectedForSender: order.codCollection?.collectedAmount ?? null,
    };
  }
}
