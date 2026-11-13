import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { addDays, periodStart } from '../common/time.js';
import { merchantPayable } from '../finance/ledger.accounts.js';
import { LedgerService } from '../finance/ledger.service.js';
import type { Prisma } from '../generated/prisma/client.js';
import { volumeDiscountFor } from '../pricing/pricing.engine.js';
import { PricingSettingsService } from '../pricing/pricing-settings.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type {
  AdminMerchantDto,
  AdminMerchantListQuery,
  AdminMerchantPageDto,
  AdminMerchantRowDto,
} from './admin-merchants.schemas.js';

const PAGE_SIZE = 30;
/** Ville des réglages commerciaux appliqués aux boutiques (une seule ville au pilote). */
const CITY = 'Douala';

type Profile = Prisma.MerchantProfileGetPayload<{
  include: { user: { select: { fullName: true; phone: true } } };
}>;

/**
 * Boutiques vues par l'équipe (H4) : les plus actives du mois d'abord, avec leur tarif pro
 * et leur solde. Au pilote, quelques centaines de boutiques : le tri se fait en mémoire.
 */
@Injectable()
export class AdminMerchantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly settings: PricingSettingsService,
  ) {}

  async list(
    query: z.output<typeof AdminMerchantListQuery>,
    now = new Date(),
  ): Promise<z.output<typeof AdminMerchantPageDto>> {
    const q = query.q?.trim();
    const digits = q?.replace(/\D/g, '') ?? '';
    const where: Prisma.MerchantProfileWhereInput = q
      ? {
          OR: [
            { shopName: { contains: q, mode: 'insensitive' } },
            { user: { fullName: { contains: q, mode: 'insensitive' } } },
            ...(digits.length >= 4 ? [{ user: { phone: { contains: digits } } }] : []),
          ],
        }
      : {};
    const profiles = await this.prisma.merchantProfile.findMany({
      where,
      include: { user: { select: { fullName: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
      take: 2000,
    });
    const monthly = await this.monthlyDeliveries(
      profiles.map((profile) => profile.id),
      now,
    );
    const tiers = (await this.settings.get(CITY)).volumeDiscounts;
    const sorted = [...profiles].sort(
      (a, b) => (monthly.get(b.id) ?? 0) - (monthly.get(a.id) ?? 0),
    );
    const pages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
    const page = Math.min(query.page, pages);
    const slice = sorted.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
    const rows = await this.rows(slice, monthly, tiers);
    return {
      items: rows,
      total: profiles.length,
      page,
      pages,
      onProRate: profiles.filter(
        (profile) => volumeDiscountFor(tiers, monthly.get(profile.id) ?? 0) > 0,
      ).length,
    };
  }

  async detail(id: string, now = new Date()): Promise<z.output<typeof AdminMerchantDto>> {
    const profile = await this.prisma.merchantProfile.findUnique({
      where: { id },
      include: { user: { select: { fullName: true, phone: true } } },
    });
    if (!profile) throw AppError.notFound('MERCHANT_NOT_FOUND');
    const monthly = await this.monthlyDeliveries([id], now);
    const tiers = (await this.settings.get(CITY)).volumeDiscounts;
    const [row] = await this.rows([profile], monthly, tiers);
    if (!row) throw AppError.notFound('MERCHANT_NOT_FOUND');
    const since = addDays(now, -30);
    const [delivered, failed, returned, orders, payouts] = await Promise.all([
      this.prisma.order.count({ where: { merchantId: id, deliveredAt: { gte: since } } }),
      this.prisma.order.count({ where: { merchantId: id, failedAt: { gte: since } } }),
      this.prisma.order.count({ where: { merchantId: id, returnedAt: { gte: since } } }),
      this.prisma.order.findMany({
        where: { merchantId: id },
        orderBy: { createdAt: 'desc' },
        take: 8,
        select: {
          id: true,
          reference: true,
          status: true,
          totalPrice: true,
          proDiscountBps: true,
          createdAt: true,
        },
      }),
      this.prisma.payout.findMany({
        where: { merchantId: id },
        orderBy: { requestedAt: 'desc' },
        take: 5,
        select: { id: true, amount: true, status: true, requestedAt: true },
      }),
    ]);
    const next = [...tiers]
      .sort((a, b) => a.fromDeliveries - b.fromDeliveries)
      .find((tier) => tier.fromDeliveries > row.deliveriesThisMonth);
    return {
      ...row,
      payoutPhone: profile.payoutPhone,
      payoutOperator: profile.payoutOperator,
      payoutSchedule: profile.payoutSchedule,
      freePayoutFrom: profile.freePayoutFrom,
      rccm: profile.rccm,
      niu: profile.niu,
      last30Days: { delivered, failed, returned },
      nextTier: next ?? null,
      recentOrders: orders.map((order) => ({ ...order, createdAt: order.createdAt.toISOString() })),
      recentPayouts: payouts.map((payout) => ({
        ...payout,
        requestedAt: payout.requestedAt.toISOString(),
      })),
    };
  }

  private async monthlyDeliveries(ids: string[], now: Date): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const groups = await this.prisma.order.groupBy({
      by: ['merchantId'],
      where: {
        merchantId: { in: ids },
        status: 'DELIVERED',
        deliveredAt: { gte: periodStart('month', now) },
      },
      _count: { _all: true },
    });
    return new Map(groups.map((group) => [group.merchantId ?? '', group._count._all]));
  }

  private async rows(
    profiles: Profile[],
    monthly: Map<string, number>,
    tiers: { fromDeliveries: number; percentBps: number }[],
  ): Promise<z.output<typeof AdminMerchantRowDto>[]> {
    if (profiles.length === 0) return [];
    const ids = profiles.map((profile) => profile.id);
    const [balances, last] = await Promise.all([
      this.ledger.balances(ids.map((id) => merchantPayable(id))),
      this.prisma.order.groupBy({
        by: ['merchantId'],
        where: { merchantId: { in: ids } },
        _max: { createdAt: true },
      }),
    ]);
    const lastOf = new Map(last.map((group) => [group.merchantId ?? '', group._max.createdAt]));
    return profiles.map((profile) => {
      const deliveries = monthly.get(profile.id) ?? 0;
      return {
        id: profile.id,
        shopName: profile.shopName,
        ownerName: profile.user.fullName,
        phone: profile.user.phone,
        category: profile.category,
        plan: profile.plan,
        createdAt: profile.createdAt.toISOString(),
        deliveriesThisMonth: deliveries,
        proDiscountBps: volumeDiscountFor(tiers, deliveries),
        balance: balances.get(merchantPayable(profile.id).code) ?? 0,
        lastOrderAt: lastOf.get(profile.id)?.toISOString() ?? null,
      };
    });
  }
}
