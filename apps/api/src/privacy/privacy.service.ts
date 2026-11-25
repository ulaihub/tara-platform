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
import {
  customerWallet,
  merchantPayable,
  riderCashHeld,
  riderPayable,
} from '../finance/ledger.accounts.js';
import { LedgerService } from '../finance/ledger.service.js';
import type { PinProof } from '../pin/pin.schemas.js';
import { PinService } from '../pin/pin.service.js';
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
    private readonly ledger: LedgerService,
    private readonly pin: PinService,
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
                accuracy: true,
                neighborhood: true,
                note: true,
                createdAt: true,
                policeCalledAt: true,
                cancelledAt: true,
                resolvedAt: true,
              },
            },
          },
        },
        consents: { orderBy: { createdAt: 'asc' } },
        addresses: true,
        locationLinks: true,
        pendingDeliveries: { orderBy: { createdAt: 'asc' } },
        ratingsGiven: {
          orderBy: { createdAt: 'asc' },
          select: {
            score: true,
            comment: true,
            createdAt: true,
            order: { select: { reference: true } },
          },
        },
        // Demandes au service client (H6) : ses messages et les réponses, sans les notes internes.
        ticketsRequested: {
          orderBy: { createdAt: 'asc' },
          select: {
            number: true,
            category: true,
            status: true,
            subject: true,
            createdAt: true,
            order: { select: { reference: true } },
            messages: {
              where: { isInternal: false },
              orderBy: { createdAt: 'asc' },
              select: { body: true, createdAt: true, authorId: true },
            },
          },
        },
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
    // Trajets de ses courses (droit d'accès du livreur ; consultation réservée à l'équipe).
    const trackPoints = user.rider
      ? await this.prisma.courseTrackPoint.findMany({
          where: { riderId: user.rider.id },
          orderBy: { recordedAt: 'asc' },
          select: {
            recordedAt: true,
            latitude: true,
            longitude: true,
            accuracy: true,
            speed: true,
            mocked: true,
            order: { select: { reference: true } },
          },
        })
      : [];
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
            courseTracks: trackPoints.map(({ order, ...point }) => ({
              reference: order.reference,
              ...point,
            })),
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
      // Notes données après ses courses (F4), avec le mot laissé à l'équipe.
      ratingsGiven: user.ratingsGiven.map(({ score, comment, createdAt, order }) => ({
        reference: order.reference,
        score,
        comment,
        createdAt,
      })),
      supportRequests: user.ticketsRequested.map((ticket) => ({
        reference: `SUP-${ticket.number}`,
        category: ticket.category,
        status: ticket.status,
        subject: ticket.subject,
        order: ticket.order?.reference ?? null,
        createdAt: ticket.createdAt,
        messages: ticket.messages.map((message) => ({
          from: message.authorId === actor.id ? 'vous' : 'Tara',
          body: message.body,
          createdAt: message.createdAt,
        })),
      })),
      locationLinks: user.locationLinks.map(
        ({ recipientName, recipientPhone, createdAt, submittedAt }) => ({
          recipientName,
          recipientPhone,
          createdAt,
          submittedAt,
        }),
      ),
      // Colis d'un envoi en masse qui attendaient l'adresse de leur client.
      pendingDeliveries: user.pendingDeliveries.map(
        ({ batchNumber, recipientName, recipientPhone, createdAt, cancelledAt, orderId }) => ({
          batchNumber,
          recipientName,
          recipientPhone,
          createdAt,
          left: orderId !== null,
          cancelledAt,
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
    // Une dette envers Tara ne disparaît pas avec le compte (le numéro redevient libre).
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId } });
    const balances = await this.ledger.balances([
      customerWallet(userId),
      ...(merchant ? [merchantPayable(merchant.id)] : []),
    ]);
    const debt = [...balances.values()].reduce((sum, balance) => sum + Math.max(0, -balance), 0);
    if (debt > 0) throw AppError.unprocessable('ACCOUNT_HAS_DEBT', { debt });
    // L'argent du client ne disparaît pas avec son compte : il le retire d'abord (gratuit,
    // même sous le minimum quand le retrait vide le solde), et attend qu'il soit arrivé.
    const balance = [...balances.values()].reduce((sum, value) => sum + Math.max(0, value), 0);
    if (balance > 0) throw AppError.unprocessable('ACCOUNT_HAS_BALANCE', { balance });
    const payout = await this.prisma.payout.count({
      where: {
        OR: [{ userId }, ...(merchant ? [{ merchantId: merchant.id }] : [])],
        status: { in: ['PENDING', 'AWAITING_APPROVAL', 'PROCESSING'] },
      },
    });
    if (payout > 0) throw AppError.unprocessable('ACCOUNT_HAS_PAYOUT_IN_PROGRESS');
  }

  /**
   * Effacement du compte, confirmé par le code secret (ou l'empreinte) une fois choisi, sinon
   * par un code SMS. Les données personnelles sont supprimées ou anonymisées ; les commandes
   * et écritures financières restent (obligations comptables), rattachées à un compte
   * anonyme. Le numéro de téléphone redevient libre.
   */
  async deleteAccount(
    actor: AuthUser,
    confirm: { challengeId?: string; code?: string } & PinProof,
    request: Request,
  ): Promise<void> {
    await this.assertDeletable(actor.id);
    if (confirm.challengeId && confirm.code) {
      await this.otp.confirm(actor.phone, confirm.challengeId, confirm.code, 'ACCOUNT_DELETION');
    } else {
      await this.pin.assert(actor, confirm, { required: true, request });
    }

    const media = await this.prisma.$transaction(async (tx) => {
      const files = await this.anonymize(tx, actor.id);
      await this.audit.record(
        { actor, action: 'user.deleted', entityType: 'user', entityId: actor.id, request },
        tx,
      );
      return files;
    });
    await this.deleteFiles(media);
  }

  /** Fichiers effacés du stockage après la transaction ; un échec est seulement journalisé. */
  private async deleteFiles(keys: string[]): Promise<void> {
    for (const key of keys) {
      await this.storage.delete(key).catch((error: unknown) => {
        this.logger.error(`Fichier non supprimé du stockage (${key})`, error);
      });
    }
  }

  /**
   * Efface ou anonymise les données personnelles d'un compte ; commandes, notes et écritures
   * restent (obligations comptables), rattachées à un compte anonyme. Le numéro redevient libre.
   */
  private async anonymize(tx: Prisma.TransactionClient, userId: string): Promise<string[]> {
    // Photos de façade et notes vocales de ses adresses : effacées (fichiers après la transaction).
    const media = await tx.mediaFile.findMany({
      where: { ownerId: userId, kind: { in: ['ADDRESS_PHOTO', 'VOICE_NOTE'] } },
      select: { id: true, storageKey: true },
    });
    await tx.user.update({
      where: { id: userId },
      data: {
        phone: `deleted:${randomUUID()}`,
        fullName: null,
        status: 'DELETED',
        deletedAt: new Date(),
        referralCode: null,
        totpSecretEnc: null,
        totpEnabledAt: null,
        pinHash: null,
        pinSetAt: null,
        pinFailedAttempts: 0,
        pinLockedAt: null,
      },
    });
    await this.tokens.revokeAll(userId, tx);
    await tx.device.deleteMany({ where: { userId } });
    await tx.pinDeviceKey.deleteMany({ where: { userId } });
    // Ses messages aux livreurs ou aux expéditeurs : effacés avec le compte.
    await tx.orderMessage.deleteMany({ where: { authorId: userId } });
    await tx.address.updateMany({
      where: { ownerId: userId },
      data: {
        ownerId: null,
        label: null,
        contactName: null,
        contactPhone: null,
        photoKey: null,
        voiceNoteKey: null,
      },
    });
    // Colis qui attendaient l'adresse d'un client : retirés, avec les données de ce client.
    await tx.pendingDelivery.deleteMany({ where: { senderId: userId } });
    await tx.locationLink.updateMany({
      where: { createdById: userId },
      data: { recipientName: null, recipientPhone: null },
    });
    await tx.merchantProfile.updateMany({
      where: { userId },
      data: { payoutPhone: '' },
    });
    await maskOrdersWhere(tx, Prisma.sql`sender_id = ${userId}::uuid`);
    // Notes : les étoiles restent (score des livreurs), les mots libres disparaissent.
    await tx.rating.updateMany({
      where: { OR: [{ raterId: userId }, { rateeId: userId }] },
      data: { comment: null },
    });
    await tx.$executeRaw`
      UPDATE notifications SET recipient_phone = NULL
       WHERE order_id IN (SELECT id FROM orders WHERE sender_id = ${userId}::uuid)`;
    await tx.mediaFile.deleteMany({ where: { id: { in: media.map((m) => m.id) } } });
    return media.map((m) => m.storageKey);
  }

  /**
   * Fermeture du compte d'un livreur par l'équipe, à sa demande (le livreur ne peut pas la faire
   * seul : pièces d'identité, argent, courses). Seulement sans course en cours, sans argent dû
   * dans un sens ou dans l'autre, ni retrait en cours. Pièces d'identité, garant et contact
   * d'urgence effacés ; courses, notes et écritures gardées, anonymes.
   */
  async closeRiderAccount(staff: AuthUser, riderId: string, request: Request): Promise<void> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { id: riderId },
      include: { user: true },
    });
    if (!rider || rider.user.status === 'DELETED') throw AppError.notFound();
    if (rider.user.roles.some(isStaffRole)) {
      throw new AppError('ACCOUNT_DELETION_NOT_ALLOWED', HttpStatus.UNPROCESSABLE_ENTITY);
    }
    const active = await this.prisma.order.count({
      where: { riderId, status: { notIn: TERMINAL_STATUSES } },
    });
    if (active > 0) throw AppError.unprocessable('ACCOUNT_HAS_ACTIVE_ORDERS');
    const balances = await this.ledger.balances([riderPayable(riderId), riderCashHeld(riderId)]);
    const earnings = balances.get(riderPayable(riderId).code) ?? 0;
    const cash = Math.max(0, balances.get(riderCashHeld(riderId).code) ?? 0);
    const debt = Math.max(0, -earnings) + cash;
    if (debt > 0) throw AppError.unprocessable('ACCOUNT_HAS_DEBT', { debt });
    if (earnings > 0) throw AppError.unprocessable('ACCOUNT_HAS_BALANCE', { balance: earnings });
    const payouts = await this.prisma.payout.count({
      where: { riderId, status: { in: ['PENDING', 'AWAITING_APPROVAL', 'PROCESSING'] } },
    });
    if (payouts > 0) throw AppError.unprocessable('ACCOUNT_HAS_PAYOUT_IN_PROGRESS');

    const documents = await this.prisma.kycDocument.findMany({
      where: { riderId },
      select: { id: true, storageKey: true },
    });
    const media = await this.prisma.$transaction(async (tx) => {
      const files = await this.anonymize(tx, rider.userId);
      await tx.riderProfile.update({
        where: { id: riderId },
        data: {
          status: 'SUSPENDED',
          plateNumber: null,
          guarantorName: null,
          guarantorPhone: null,
          emergencyContactName: null,
          emergencyContactPhone: null,
        },
      });
      await tx.mediaFile.deleteMany({
        where: { storageKey: { in: documents.map((d) => d.storageKey) } },
      });
      await tx.kycDocument.deleteMany({ where: { riderId } });
      await this.audit.record(
        {
          actor: staff,
          action: 'rider.account_closed',
          entityType: 'rider',
          entityId: riderId,
          request,
        },
        tx,
      );
      return files;
    });
    await this.deleteFiles([...media, ...documents.map((d) => d.storageKey)]);
  }
}
