import { randomUUID } from 'node:crypto';
import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import { type AuthUser, isStaffRole } from '../auth/auth.types.js';
import { OtpService } from '../auth/otp.service.js';
import { TokenService } from '../auth/token.service.js';
import { AppError } from '../common/errors/app-error.js';
import type { AppLocale } from '../common/i18n/locale.js';
import { Prisma } from '../generated/prisma/client.js';
import { TERMINAL_STATUSES } from '../orders/order-state-machine.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../storage/object-storage.js';
import { maskOrdersWhere } from './masking.js';

/** Droits des personnes (loi n° 2024/017) : accès à ses données et effacement du compte. */
@Injectable()
export class PrivacyService {
  private readonly logger = new Logger(PrivacyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
    private readonly audit: AuditService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  /** Toutes les données personnelles du compte, dans un format lisible et réutilisable. */
  async export(actor: AuthUser, request: Request): Promise<Record<string, unknown>> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: actor.id },
      include: {
        merchant: true,
        rider: {
          include: {
            documents: { select: { type: true, status: true, expiresOn: true, createdAt: true } },
            safetyAlerts: {
              select: {
                latitude: true,
                longitude: true,
                note: true,
                createdAt: true,
                resolvedAt: true,
              },
            },
          },
        },
        consents: { orderBy: { createdAt: 'asc' } },
        addresses: true,
        locationLinks: true,
      },
    });
    const orders = await this.prisma.order.findMany({
      where: { senderId: actor.id },
      orderBy: { createdAt: 'asc' },
      select: {
        reference: true,
        status: true,
        createdAt: true,
        deliveredAt: true,
        recipientName: true,
        recipientPhone: true,
        totalPrice: true,
        codAmount: true,
        pickupAddress: { select: { landmark: true } },
        dropoffAddress: { select: { landmark: true } },
      },
    });
    await this.audit.record({
      actor,
      action: 'user.data_exported',
      entityType: 'user',
      entityId: actor.id,
      request,
    });
    return {
      exportedAt: new Date().toISOString(),
      account: {
        id: user.id,
        phone: user.phone,
        fullName: user.fullName,
        locale: user.locale,
        roles: user.roles,
        createdAt: user.createdAt,
        referralCode: user.referralCode,
      },
      merchant: user.merchant,
      rider: user.rider
        ? {
            status: user.rider.status,
            vehicleType: user.rider.vehicleType,
            plateNumber: user.rider.plateNumber,
            guarantorName: user.rider.guarantorName,
            guarantorPhone: user.rider.guarantorPhone,
            documents: user.rider.documents,
            safetyAlerts: user.rider.safetyAlerts,
          }
        : null,
      consents: user.consents.map(({ kind, version, granted, createdAt }) => ({
        kind,
        version,
        granted,
        createdAt,
      })),
      addresses: user.addresses.map(
        ({ label, landmark, latitude, longitude, contactName, contactPhone, createdAt }) => ({
          label,
          landmark,
          latitude,
          longitude,
          contactName,
          contactPhone,
          createdAt,
        }),
      ),
      orders: orders.map((order) => ({
        reference: order.reference,
        status: order.status,
        createdAt: order.createdAt,
        deliveredAt: order.deliveredAt,
        recipientName: order.recipientName,
        recipientPhone: order.recipientPhone,
        pickup: order.pickupAddress.landmark,
        dropoff: order.dropoffAddress.landmark,
        totalPrice: order.totalPrice,
        codAmount: order.codAmount,
      })),
      locationLinks: user.locationLinks.map(
        ({ recipientName, recipientPhone, createdAt, submittedAt }) => ({
          recipientName,
          recipientPhone,
          createdAt,
          submittedAt,
        }),
      ),
    };
  }

  async requestDeletionCode(actor: AuthUser, locale: AppLocale, ip: string | undefined) {
    await this.assertDeletable(actor.id);
    return this.otp.request(actor.phone, locale, ip, 'ACCOUNT_DELETION');
  }

  private async assertDeletable(userId: string): Promise<void> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { rider: true },
    });
    // Livreurs (pièces d'identité à conserver) et équipe : suppression par le support.
    if (user.rider || user.roles.some(isStaffRole)) {
      throw new AppError('ACCOUNT_DELETION_NOT_ALLOWED', HttpStatus.UNPROCESSABLE_ENTITY);
    }
    const active = await this.prisma.order.count({
      where: { senderId: userId, status: { notIn: TERMINAL_STATUSES } },
    });
    if (active > 0) throw AppError.unprocessable('ACCOUNT_HAS_ACTIVE_ORDERS');
  }

  /**
   * Effacement du compte, confirmé par un code SMS. Les données personnelles sont supprimées
   * ou anonymisées ; les commandes et écritures financières restent (obligations comptables),
   * rattachées à un compte anonyme. Le numéro de téléphone redevient libre.
   */
  async deleteAccount(
    actor: AuthUser,
    challengeId: string,
    code: string,
    request: Request,
  ): Promise<void> {
    await this.assertDeletable(actor.id);
    await this.otp.confirm(actor.phone, challengeId, code, 'ACCOUNT_DELETION');

    const media = await this.prisma.mediaFile.findMany({
      where: { ownerId: actor.id, kind: { in: ['ADDRESS_PHOTO', 'VOICE_NOTE'] } },
    });
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: actor.id },
        data: {
          phone: `deleted:${randomUUID()}`,
          fullName: null,
          status: 'DELETED',
          deletedAt: new Date(),
          referralCode: null,
          totpSecretEnc: null,
          totpEnabledAt: null,
        },
      });
      await this.tokens.revokeAll(actor.id, tx);
      await tx.device.deleteMany({ where: { userId: actor.id } });
      await tx.address.updateMany({
        where: { ownerId: actor.id },
        data: {
          ownerId: null,
          label: null,
          contactName: null,
          contactPhone: null,
          photoKey: null,
          voiceNoteKey: null,
        },
      });
      await tx.locationLink.updateMany({
        where: { createdById: actor.id },
        data: { recipientName: null, recipientPhone: null },
      });
      await tx.merchantProfile.updateMany({
        where: { userId: actor.id },
        data: { payoutPhone: '' },
      });
      await maskOrdersWhere(tx, Prisma.sql`sender_id = ${actor.id}::uuid`);
      await tx.$executeRaw`
        UPDATE notifications SET recipient_phone = NULL
         WHERE order_id IN (SELECT id FROM orders WHERE sender_id = ${actor.id}::uuid)`;
      await tx.mediaFile.deleteMany({ where: { id: { in: media.map((m) => m.id) } } });
      await this.audit.record(
        { actor, action: 'user.deleted', entityType: 'user', entityId: actor.id, request },
        tx,
      );
    });

    for (const file of media) {
      await this.storage.delete(file.storageKey).catch((error: unknown) => {
        this.logger.error(`Fichier ${file.id} non supprimé du stockage`, error);
      });
    }
  }
}
