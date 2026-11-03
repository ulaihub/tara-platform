import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { randomReadableId } from '../common/crypto.js';
import { AppError } from '../common/errors/app-error.js';
import type { MerchantProfile } from '../generated/prisma/client.js';
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
  ) {}

  async me(userId: string): Promise<z.output<typeof MeDto>> {
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
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.merchantProfile.findUnique({ where: { userId: actor.id } });
      const merchant = await tx.merchantProfile.upsert({
        where: { userId: actor.id },
        create: { userId: actor.id, ...data },
        update: data,
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
      return toMerchantDto(merchant);
    });
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
