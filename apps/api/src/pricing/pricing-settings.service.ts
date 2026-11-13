import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { periodStart } from '../common/time.js';
import type { Prisma, RiderBoost } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { approachBonusFor, volumeDiscountFor } from './pricing.engine.js';
import {
  type PricingSettingsBody,
  type PricingSettingsDto,
  type RiderBoostBody,
  type RiderBoostDto,
  VolumeDiscountTier,
} from './pricing.schemas.js';

type Db = PrismaService | Prisma.TransactionClient;

/** Valeurs validées le 8 novembre 2026 : elles s'appliquent tant que l'équipe n'a rien changé. */
export const DEFAULT_VOLUME_DISCOUNTS = [
  { fromDeliveries: 100, percentBps: 1000 },
  { fromDeliveries: 300, percentBps: 1500 },
];
export const DEFAULT_APPROACH_BONUS_AMOUNT = 200;
export const DEFAULT_APPROACH_BONUS_FROM_METERS = 3000;

export interface CitySettings {
  city: string;
  volumeDiscounts: z.output<typeof VolumeDiscountTier>[];
  approachBonusAmount: number;
  approachBonusFromMeters: number;
  updatedAt: Date | null;
}

export interface OfferBonuses {
  approachBonus: number;
  boostBonus: number;
}

/**
 * Réglages commerciaux par ville (H4), modifiables au back-office sans nouvelle version des
 * apps : tarif pro des boutiques selon leurs livraisons du mois, prime d'approche et primes
 * de renfort des livreurs. Ces remises et primes sont prises sur la part de Tara.
 */
@Injectable()
export class PricingSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationService,
  ) {}

  async get(city: string, db: Db = this.prisma): Promise<CitySettings> {
    const row = await db.pricingSettings.findUnique({ where: { city } });
    if (!row) {
      return {
        city,
        volumeDiscounts: DEFAULT_VOLUME_DISCOUNTS,
        approachBonusAmount: DEFAULT_APPROACH_BONUS_AMOUNT,
        approachBonusFromMeters: DEFAULT_APPROACH_BONUS_FROM_METERS,
        updatedAt: null,
      };
    }
    return {
      city,
      volumeDiscounts: z.array(VolumeDiscountTier).parse(row.volumeDiscounts),
      approachBonusAmount: row.approachBonusAmount,
      approachBonusFromMeters: row.approachBonusFromMeters,
      updatedAt: row.updatedAt,
    };
  }

  toDto(settings: CitySettings): z.output<typeof PricingSettingsDto> {
    return {
      city: settings.city,
      volumeDiscounts: [...settings.volumeDiscounts].sort(
        (a, b) => a.fromDeliveries - b.fromDeliveries,
      ),
      approachBonusAmount: settings.approachBonusAmount,
      approachBonusFromMeters: settings.approachBonusFromMeters,
      updatedAt: settings.updatedAt?.toISOString() ?? null,
    };
  }

  async update(
    actor: AuthUser,
    city: string,
    body: z.output<typeof PricingSettingsBody>,
    request: Request,
  ): Promise<z.output<typeof PricingSettingsDto>> {
    const before = this.toDto(await this.get(city));
    const volumeDiscounts = [...body.volumeDiscounts].sort(
      (a, b) => a.fromDeliveries - b.fromDeliveries,
    );
    const data = {
      volumeDiscounts,
      approachBonusAmount: body.approachBonusAmount,
      approachBonusFromMeters: body.approachBonusFromMeters,
      updatedById: actor.id,
    };
    await this.prisma.pricingSettings.upsert({
      where: { city },
      create: { city, ...data },
      update: data,
    });
    const after = this.toDto(await this.get(city));
    await this.audit.record({
      actor,
      action: 'pricing_settings.updated',
      entityType: 'pricing_settings',
      entityId: city,
      before,
      after,
      request,
    });
    return after;
  }

  /** Livraisons réussies de la boutique depuis le début du mois, heure du Cameroun. */
  deliveriesThisMonth(merchantId: string, now: Date, db: Db = this.prisma): Promise<number> {
    return db.order.count({
      where: { merchantId, status: 'DELIVERED', deliveredAt: { gte: periodStart('month', now) } },
    });
  }

  /** Tarif pro (points de base) d'une boutique pour une commande passée maintenant. */
  async volumeDiscountBps(
    merchantId: string,
    city: string,
    now: Date,
    db: Db = this.prisma,
  ): Promise<number> {
    const settings = await this.get(city, db);
    if (settings.volumeDiscounts.length === 0) return 0;
    return volumeDiscountFor(
      settings.volumeDiscounts,
      await this.deliveriesThisMonth(merchantId, now, db),
    );
  }

  /** Primes annoncées dans une proposition : approche selon la distance, renfort en cours. */
  async offerBonuses(
    city: string,
    approachMeters: number | null,
    at: Date,
    db: Db = this.prisma,
  ): Promise<OfferBonuses> {
    const settings = await this.get(city, db);
    return {
      approachBonus: approachBonusFor(settings, approachMeters),
      boostBonus: await this.activeBoostAmount(city, at, db),
    };
  }

  /** Prime de renfort en cours ; si plusieurs se chevauchent, la plus forte (jamais cumulées). */
  async activeBoostAmount(city: string, at: Date, db: Db = this.prisma): Promise<number> {
    const boost = await db.riderBoost.findFirst({
      where: { city, cancelledAt: null, startsAt: { lte: at }, endsAt: { gt: at } },
      orderBy: { amount: 'desc' },
      select: { amount: true },
    });
    return boost?.amount ?? 0;
  }

  // --- Primes de renfort ----------------------------------------------------------------------

  async listBoosts(
    city: string | undefined,
    now = new Date(),
  ): Promise<z.output<typeof RiderBoostDto>[]> {
    const boosts = await this.prisma.riderBoost.findMany({
      where: city ? { city } : {},
      orderBy: { startsAt: 'desc' },
      take: 50,
    });
    return this.boostDtos(boosts, now);
  }

  async createBoost(
    actor: AuthUser,
    body: z.output<typeof RiderBoostBody>,
    request: Request,
  ): Promise<z.output<typeof RiderBoostDto>> {
    const now = new Date();
    const startsAt = body.startsAt ? new Date(body.startsAt) : now;
    if (new Date(body.endsAt) <= now) {
      throw AppError.unprocessable('VALIDATION_FAILED', {}, [
        { path: 'endsAt', message: 'la période est déjà terminée' },
      ]);
    }
    const boost = await this.prisma.riderBoost.create({
      data: {
        city: body.city,
        amount: body.amount,
        reason: body.reason,
        startsAt,
        endsAt: new Date(body.endsAt),
        createdById: actor.id,
      },
    });
    await this.audit.record({
      actor,
      action: 'rider_boost.created',
      entityType: 'rider_boost',
      entityId: boost.id,
      after: {
        city: boost.city,
        amount: boost.amount,
        reason: boost.reason,
        startsAt,
        endsAt: boost.endsAt,
      },
      request,
    });
    // Prime créée par un répartiteur : les administrateurs sont prévenus (revue de sécurité,
    // phase 7). Elle est payée par Tara : une prime abusive doit se voir tout de suite.
    if (!actor.roles.includes('ADMIN')) await this.alertAdmins(actor, boost);
    const [dto] = await this.boostDtos([boost], now);
    if (!dto) throw AppError.notFound();
    return dto;
  }

  private async alertAdmins(actor: AuthUser, boost: RiderBoost): Promise<void> {
    const [author, admins] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: actor.id },
        select: { fullName: true, phone: true },
      }),
      this.prisma.user.findMany({
        where: { roles: { has: 'ADMIN' }, status: 'ACTIVE', id: { not: actor.id } },
        select: { phone: true },
      }),
    ]);
    const until = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Africa/Douala',
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    }).format(boost.endsAt);
    for (const admin of admins) {
      await this.notifications
        .toPhone({
          phone: admin.phone,
          template: 'OPS_RIDER_BOOST',
          locale: 'fr',
          smsOnly: true,
          params: {
            author: author?.fullName ?? author?.phone ?? 'un membre de l equipe',
            amount: String(boost.amount),
            city: boost.city,
            until,
            reason: boost.reason,
          },
        })
        .catch(() => undefined);
    }
  }

  /** Arrête une prime : les courses déjà acceptées la gardent. */
  async cancelBoost(
    actor: AuthUser,
    id: string,
    request: Request,
  ): Promise<z.output<typeof RiderBoostDto>> {
    const now = new Date();
    const { count } = await this.prisma.riderBoost.updateMany({
      where: { id, cancelledAt: null, endsAt: { gt: now } },
      data: { cancelledAt: now },
    });
    const boost = await this.prisma.riderBoost.findUnique({ where: { id } });
    if (!boost) throw AppError.notFound('RIDER_BOOST_NOT_FOUND');
    if (count === 1) {
      await this.audit.record({
        actor,
        action: 'rider_boost.cancelled',
        entityType: 'rider_boost',
        entityId: id,
        request,
      });
    }
    const [dto] = await this.boostDtos([boost], now);
    if (!dto) throw AppError.notFound('RIDER_BOOST_NOT_FOUND');
    return dto;
  }

  private async boostDtos(
    boosts: RiderBoost[],
    now: Date,
  ): Promise<z.output<typeof RiderBoostDto>[]> {
    if (boosts.length === 0) return [];
    const authors = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(boosts.map((boost) => boost.createdById))] } },
      select: { id: true, fullName: true },
    });
    const nameOf = new Map(authors.map((author) => [author.id, author.fullName]));
    // Courses acceptées pendant la période avec une prime de renfort de ce montant.
    const usage = await Promise.all(
      boosts.map((boost) =>
        this.prisma.order.aggregate({
          where: {
            boostBonus: boost.amount,
            assignedAt: { gte: boost.startsAt, lt: boost.cancelledAt ?? boost.endsAt },
          },
          _count: { _all: true },
          _sum: { boostBonus: true },
        }),
      ),
    );
    return boosts.map((boost, index) => ({
      id: boost.id,
      city: boost.city,
      amount: boost.amount,
      reason: boost.reason,
      startsAt: boost.startsAt.toISOString(),
      endsAt: boost.endsAt.toISOString(),
      cancelledAt: boost.cancelledAt?.toISOString() ?? null,
      status: boost.cancelledAt
        ? 'CANCELLED'
        : boost.endsAt <= now
          ? 'ENDED'
          : boost.startsAt > now
            ? 'SCHEDULED'
            : 'ACTIVE',
      createdBy: nameOf.get(boost.createdById) ?? null,
      orders: usage[index]?._count._all ?? 0,
      paid: usage[index]?._sum.boostBonus ?? 0,
    }));
  }
}
