import { Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import { type AuthUser, isStaffRole } from '../auth/auth.types.js';
import { randomReadableId } from '../common/crypto.js';
import { AppError } from '../common/errors/app-error.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { NotificationService } from '../notifications/notification.service.js';
import type { MerchantProfile } from '../generated/prisma/client.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type {
  ConsentBody,
  ConsentDto,
  MeDto,
  MerchantBody,
  MerchantDto,
  UpdateMeBody,
} from './users.schemas.js';

export function toMerchantDto(merchant: MerchantProfile): z.output<typeof MerchantDto> {
  return {
    id: merchant.id,
    shopName: merchant.shopName,
    category: merchant.category,
    payoutPhone: merchant.payoutPhone,
    payoutOperator: merchant.payoutOperator,
    payoutSchedule: merchant.payoutSchedule,
    plan: merchant.plan,
    rccm: merchant.rccm,
    niu: merchant.niu,
  };
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** [effectiveRoles] : rôles de la session (ceux de l'équipe seulement si le second facteur est vérifié). */
  async me(
    userId: string,
    effectiveRoles: readonly UserRole[] = [],
  ): Promise<z.output<typeof MeDto>> {
    let user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { merchant: true, rider: true },
    });
    if (!user) throw AppError.notFound();
    // Comptes antérieurs au parrainage : le code est attribué à la première lecture.
    if (!user.referralCode) {
      user = await this.prisma.user.update({
        where: { id: userId },
        data: { referralCode: `TARA-${randomReadableId(6)}` },
        include: { merchant: true, rider: true },
      });
    }
    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      locale: user.locale,
      roles: user.roles,
      referralCode: user.referralCode,
      createdAt: user.createdAt.toISOString(),
      merchant: user.merchant ? toMerchantDto(user.merchant) : null,
      rider: user.rider
        ? { id: user.rider.id, status: user.rider.status, vehicleType: user.rider.vehicleType }
        : null,
      staff: user.roles.some(isStaffRole)
        ? {
            mfaEnrolled: user.totpEnabledAt !== null,
            mfaVerified: effectiveRoles.some(isStaffRole),
          }
        : null,
    };
  }

  async update(
    userId: string,
    body: z.output<typeof UpdateMeBody>,
  ): Promise<z.output<typeof MeDto>> {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(body.fullName === undefined ? {} : { fullName: body.fullName }),
        ...(body.locale === undefined ? {} : { locale: body.locale }),
      },
    });
    return this.me(userId);
  }

  /** Crée ou met à jour le profil marchand et ajoute le rôle MERCHANT (A2). */
  async upsertMerchant(
    actor: AuthUser,
    body: z.output<typeof MerchantBody>,
    request: Request,
  ): Promise<z.output<typeof MerchantDto>> {
    const data = {
      shopName: body.shopName,
      category: body.category ?? null,
      payoutPhone: body.payoutPhone,
      payoutOperator: body.payoutOperator,
      rccm: body.rccm ?? null,
      niu: body.niu ?? null,
      ...(body.payoutSchedule ? { payoutSchedule: body.payoutSchedule } : {}),
    };
    const result = await this.prisma.$transaction(async (tx) => {
      const before = await tx.merchantProfile.findUnique({ where: { userId: actor.id } });
      // Nouveau numéro de reversement : reversements gelés, ancien numéro prévenu (SIM swap).
      const phoneChanged = before !== null && before.payoutPhone !== body.payoutPhone;
      const merchant = await tx.merchantProfile.upsert({
        where: { userId: actor.id },
        create: { userId: actor.id, ...data },
        update: { ...data, ...(phoneChanged ? { payoutPhoneChangedAt: new Date() } : {}) },
      });
      if (!actor.roles.includes('MERCHANT')) {
        await tx.user.update({
          where: { id: actor.id },
          data: { roles: { set: [...actor.roles, 'MERCHANT'] } },
        });
      }
      await this.audit.record(
        {
          actor,
          action: before ? 'merchant.updated' : 'merchant.created',
          entityType: 'merchant_profile',
          entityId: merchant.id,
          before,
          after: merchant,
          request,
        },
        tx,
      );
      return {
        dto: toMerchantDto(merchant),
        previousPhone: phoneChanged ? before.payoutPhone : null,
      };
    });
    if (result.previousPhone) {
      const alerted = new Set([result.previousPhone, actor.phone]);
      for (const phone of alerted) {
        await this.notifications.toPhone({
          phone,
          template: 'PAYOUT_PHONE_CHANGED',
          locale: actor.locale === 'EN' ? 'en' : 'fr',
          params: { shop: body.shopName, hours: String(this.env.PAYOUT_HOLD_HOURS) },
          userId: actor.id,
          smsOnly: true,
        });
      }
    }
    return result.dto;
  }

  async recordConsent(
    userId: string,
    body: z.output<typeof ConsentBody>,
  ): Promise<z.output<typeof ConsentDto>> {
    const consent = await this.prisma.consent.create({ data: { userId, ...body } });
    return { ...body, createdAt: consent.createdAt.toISOString() };
  }

  /** Dernier choix enregistré pour chaque type de consentement. */
  async consents(userId: string): Promise<z.output<typeof ConsentDto>[]> {
    const rows = await this.prisma.consent.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      distinct: ['kind'],
    });
    return rows.map((row) => ({
      kind: row.kind,
      version: row.version,
      granted: row.granted,
      createdAt: row.createdAt.toISOString(),
    }));
  }
}
