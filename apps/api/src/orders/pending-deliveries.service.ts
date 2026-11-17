import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { decryptWithAny, deriveKey, encrypt, randomToken } from '../common/crypto.js';
import { AppError } from '../common/errors/app-error.js';
import { addMinutes } from '../common/time.js';
import { ENV } from '../config/config.module.js';
import { type Env, storageKeys } from '../config/env.js';
import type { Prisma } from '../generated/prisma/client.js';
import { LocationLinksService } from '../geo/location-links.service.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { BATCH_CODE_KEY_PURPOSE } from './batch-code.js';
import {
  type BatchItem,
  DeliveryItem,
  FeePayerEnum,
  PaymentMethodEnum,
  type PendingDeliveryDto,
  type PendingDeliveryStatusEnum,
} from './orders.schemas.js';

/** Validité du lien envoyé au client, comme un lien demandé à la main (B3). */
export const PENDING_LINK_TTL_HOURS = 72;
/** Un lien encore valable n'est renvoyé qu'une fois par heure au plus. */
export const PENDING_RESEND_MIN_MINUTES = 60;

/** Ce qui est gardé pour créer la commande plus tard : le colis et la partie commune. */
export const StoredPending = z.object({
  item: DeliveryItem.omit({ dropoffAddressId: true }),
  shared: z.object({
    isExpress: z.boolean(),
    scheduledFor: z.string().optional(),
    feePayer: FeePayerEnum,
    feePaymentMethod: PaymentMethodEnum,
  }),
});
export type StoredPending = z.output<typeof StoredPending>;

export type PendingWithLink = Prisma.PendingDeliveryGetPayload<{
  include: { locationLink: true };
}>;
type Status = z.output<typeof PendingDeliveryStatusEnum>;

/** Statuts qui attendent encore quelque chose (du client ou de l'expéditeur). */
const OPEN_STATUSES: readonly Status[] = ['WAITING', 'EXPIRED', 'BLOCKED'];

export function pendingStatus(row: PendingWithLink, now = new Date()): Status {
  if (row.cancelledAt) return 'CANCELLED';
  if (row.orderId) return 'RELEASED';
  if (row.blockedReason) return 'BLOCKED';
  if (!row.locationLink.submittedAt && row.locationLink.expiresAt <= now) return 'EXPIRED';
  return 'WAITING';
}

/**
 * Colis d'un envoi qui attendent l'adresse de leur client (C4, B3) : lien de localisation
 * créé et envoyé par SMS, numéro réservé dans l'envoi, relance et retrait. La commande est
 * créée par OrdersService quand le point arrive.
 */
@Injectable()
export class PendingDeliveriesService {
  private readonly logger = new Logger(PendingDeliveriesService.name);
  private readonly codeKeys: Buffer[];

  constructor(
    private readonly prisma: PrismaService,
    private readonly links: LocationLinksService,
    private readonly notifications: NotificationService,
    @Inject(ENV) private readonly env: Env,
  ) {
    this.codeKeys = storageKeys(env).map((master) => deriveKey(master, BATCH_CODE_KEY_PURPOSE));
  }

  // --- Code d'enlèvement commun de l'envoi ------------------------------------------------

  sealCode(code: string): string {
    return encrypt(this.codeKeys[0] as Buffer, Buffer.from(code, 'utf8')).toString('base64');
  }

  openCode(sealed: string): string {
    return decryptWithAny(this.codeKeys, Buffer.from(sealed, 'base64')).toString('utf8');
  }

  // --- Création, avec l'envoi ---------------------------------------------------------------

  /**
   * Limite les liens envoyés par SMS : au plus PENDING_LINKS_DAILY_LIMIT par compte et par
   * 24 h (envois groupés et relances), pour que Tara ne serve pas à écrire à n'importe qui.
   */
  async assertLinkQuota(userId: string, wanted: number): Promise<void> {
    if (wanted === 0) return;
    const limit = this.env.PENDING_LINKS_DAILY_LIMIT;
    const used = await this.prisma.locationLink.count({
      where: { createdById: userId, createdAt: { gte: addMinutes(new Date(), -24 * 60) } },
    });
    if (used + wanted > limit) {
      throw AppError.unprocessable('ADDRESS_REQUESTS_LIMIT', {
        limit,
        left: Math.max(0, limit - used),
      });
    }
  }

  /** Dans la transaction de l'envoi : le lien du client et le colis, sous son numéro. */
  async createIn(
    tx: Prisma.TransactionClient,
    input: {
      senderId: string;
      merchantId: string | null;
      batchId: string;
      batchNumber: number;
      item: z.output<typeof BatchItem>;
      shared: StoredPending['shared'];
    },
  ): Promise<PendingWithLink> {
    const { dropoffAddressId: _address, askAddress: _ask, ...item } = input.item;
    const link = await tx.locationLink.create({
      data: {
        token: randomToken(16),
        createdById: input.senderId,
        merchantId: input.merchantId,
        recipientName: item.recipientName,
        recipientPhone: item.recipientPhone,
        expiresAt: addMinutes(new Date(), PENDING_LINK_TTL_HOURS * 60),
      },
    });
    const stored: StoredPending = { item, shared: input.shared };
    return tx.pendingDelivery.create({
      data: {
        batchId: input.batchId,
        batchNumber: input.batchNumber,
        senderId: input.senderId,
        locationLinkId: link.id,
        recipientName: item.recipientName,
        recipientPhone: item.recipientPhone,
        item: stored as unknown as Prisma.InputJsonObject,
      },
      include: { locationLink: true },
    });
  }

  /** Après l'envoi : chaque client reçoit son lien par SMS. Un échec n'annule rien. */
  async sendLinks(rows: readonly PendingWithLink[], senderName: string): Promise<void> {
    for (const row of rows) await this.sendLink(row, senderName);
  }

  private async sendLink(row: PendingWithLink, senderName: string): Promise<void> {
    try {
      await this.notifications.toPhone({
        phone: row.recipientPhone,
        template: 'LOCATION_LINK_REQUEST',
        locale: 'fr',
        // Le nom vient du compte : raccourci pour que le SMS reste un seul message.
        params: {
          sender: senderName.trim().slice(0, 30),
          url: this.links.publicUrl(row.locationLink.token),
        },
        smsOnly: true,
      });
    } catch (error) {
      this.logger.warn(`Lien du colis en attente ${row.id} non envoyé : ${String(error)}`);
    }
  }

  // --- Lecture -----------------------------------------------------------------------------

  toDto(row: PendingWithLink, now = new Date()): z.output<typeof PendingDeliveryDto> {
    const stored = StoredPending.parse(row.item);
    return {
      id: row.id,
      batchId: row.batchId,
      batchNumber: row.batchNumber,
      recipientName: row.recipientName,
      recipientPhone: row.recipientPhone,
      packageSize: stored.item.packageSize,
      packageDescription: stored.item.packageDescription ?? null,
      codAmount: stored.item.codAmount,
      status: pendingStatus(row, now),
      blockedReason: row.blockedReason,
      linkUrl: this.links.publicUrl(row.locationLink.token),
      linkExpiresAt: row.locationLink.expiresAt.toISOString(),
      orderId: row.orderId,
      createdAt: row.createdAt.toISOString(),
    };
  }

  async forBatch(batchId: string): Promise<PendingWithLink[]> {
    return this.prisma.pendingDelivery.findMany({
      where: { batchId },
      include: { locationLink: true },
      orderBy: { batchNumber: 'asc' },
    });
  }

  /** Colis en attente de l'expéditeur, les plus récents d'abord (100 au plus). */
  async list(user: AuthUser, open: boolean): Promise<PendingWithLink[]> {
    const rows = await this.prisma.pendingDelivery.findMany({
      where: { senderId: user.id, ...(open ? { orderId: null, cancelledAt: null } : {}) },
      include: { locationLink: true },
      orderBy: [{ createdAt: 'desc' }, { batchNumber: 'asc' }],
      take: 100,
    });
    const now = new Date();
    return open ? rows.filter((row) => OPEN_STATUSES.includes(pendingStatus(row, now))) : rows;
  }

  async owned(user: AuthUser, id: string): Promise<PendingWithLink> {
    const row = await this.prisma.pendingDelivery.findUnique({
      where: { id },
      include: { locationLink: true },
    });
    if (row?.senderId !== user.id) throw AppError.notFound('PENDING_DELIVERY_NOT_FOUND');
    return row;
  }

  // --- Actions de l'expéditeur ----------------------------------------------------------------

  /** Retire le colis de l'envoi : le lien ne sert plus, rien n'a été payé. */
  async cancel(user: AuthUser, id: string): Promise<PendingWithLink> {
    const row = await this.owned(user, id);
    if (row.orderId || row.cancelledAt) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.pendingDelivery.updateMany({
        where: { id, orderId: null, cancelledAt: null },
        data: { cancelledAt: now },
      });
      if (count !== 1) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
      await tx.locationLink.updateMany({
        where: { id: row.locationLinkId, submittedAt: null },
        data: { expiresAt: now },
      });
    });
    await this.forgetCodeIfDone(row.batchId);
    return this.owned(user, id);
  }

  /**
   * Renvoie un lien neuf au client (lien expiré, ou SMS perdu). L'ancien lien ne sert plus.
   * Un lien encore valable n'est renvoyé qu'après une heure.
   */
  async resend(user: AuthUser, id: string, senderName: string): Promise<PendingWithLink> {
    const row = await this.owned(user, id);
    const status = pendingStatus(row);
    if (status !== 'WAITING' && status !== 'EXPIRED') {
      throw AppError.conflict('PENDING_DELIVERY_CLOSED');
    }
    if (row.locationLink.submittedAt) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
    if (
      status === 'WAITING' &&
      row.locationLink.createdAt > addMinutes(new Date(), -PENDING_RESEND_MIN_MINUTES)
    ) {
      throw AppError.conflict('PENDING_RESEND_TOO_SOON', { minutes: PENDING_RESEND_MIN_MINUTES });
    }
    await this.assertLinkQuota(user.id, 1);
    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      const link = await tx.locationLink.create({
        data: {
          token: randomToken(16),
          createdById: row.senderId,
          merchantId: row.locationLink.merchantId,
          recipientName: row.recipientName,
          recipientPhone: row.recipientPhone,
          expiresAt: addMinutes(now, PENDING_LINK_TTL_HOURS * 60),
        },
      });
      const { count } = await tx.pendingDelivery.updateMany({
        where: { id, locationLinkId: row.locationLinkId, orderId: null, cancelledAt: null },
        data: { locationLinkId: link.id },
      });
      if (count !== 1) throw AppError.conflict('PENDING_DELIVERY_CLOSED');
      await tx.locationLink.updateMany({
        where: { id: row.locationLinkId, submittedAt: null },
        data: { expiresAt: now },
      });
      return tx.pendingDelivery.findUniqueOrThrow({
        where: { id },
        include: { locationLink: true },
      });
    });
    await this.sendLink(updated, senderName);
    return updated;
  }

  /** Départ automatique impossible : la raison est gardée pour que l'expéditeur relance. */
  async block(id: string, error: AppError): Promise<void> {
    await this.prisma.pendingDelivery.updateMany({
      where: { id, orderId: null, cancelledAt: null },
      data: { blockedReason: error.code },
    });
  }

  /**
   * Plus aucun colis n'attend dans l'envoi : le code d'enlèvement chiffré ne sert plus, il
   * est effacé (il ne reste lisible que tant qu'il est utile).
   */
  async forgetCodeIfDone(batchId: string): Promise<void> {
    const waiting = await this.prisma.pendingDelivery.count({
      where: { batchId, orderId: null, cancelledAt: null },
    });
    if (waiting === 0) {
      await this.prisma.orderBatch.update({
        where: { id: batchId },
        data: { pickupCodeSealed: null },
      });
    }
  }
}
