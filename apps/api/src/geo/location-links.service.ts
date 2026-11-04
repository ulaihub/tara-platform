import { Inject, Injectable, Logger } from '@nestjs/common';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { randomToken } from '../common/crypto.js';
import type { LocationLink } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { AddressesService } from './addresses.service.js';
import type {
  LocationLinkBody,
  LocationLinkDto,
  LocationLinkListQuery,
  LocationLinkStatusEnum,
  PublicLocationLinkDto,
  PublicLocationSubmitBody,
} from './geo.schemas.js';

type Status = z.output<typeof LocationLinkStatusEnum>;

function statusOf(link: Pick<LocationLink, 'submittedAt' | 'expiresAt'>, now = new Date()): Status {
  if (link.submittedAt) return 'SUBMITTED';
  return link.expiresAt <= now ? 'EXPIRED' : 'PENDING';
}

/**
 * Lien de localisation (B3) : le marchand partage un lien, le destinataire place lui-même
 * son point et son repère depuis son téléphone, sans compte ni application.
 */
@Injectable()
export class LocationLinksService {
  private readonly logger = new Logger(LocationLinksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly addresses: AddressesService,
    private readonly notifications: NotificationService,
    private readonly realtime: RealtimeService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private url(token: string): string {
    return `${this.env.PUBLIC_WEB_URL.replace(/\/$/, '')}/l/${token}`;
  }

  private async toDto(link: LocationLink): Promise<z.output<typeof LocationLinkDto>> {
    let address: z.output<typeof LocationLinkDto>['address'] = null;
    if (link.addressId) {
      const row = await this.prisma.address.findUniqueOrThrow({
        where: { id: link.addressId },
        include: { neighborhood: { select: { id: true, name: true } } },
      });
      address = (await this.addresses.toDtos([row]))[0] ?? null;
    }
    return {
      id: link.id,
      url: this.url(link.token),
      recipientName: link.recipientName,
      recipientPhone: link.recipientPhone,
      expiresAt: link.expiresAt.toISOString(),
      status: statusOf(link),
      address,
      createdAt: link.createdAt.toISOString(),
    };
  }

  async create(
    user: AuthUser,
    body: z.output<typeof LocationLinkBody>,
  ): Promise<z.output<typeof LocationLinkDto>> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    const link = await this.prisma.locationLink.create({
      data: {
        token: randomToken(16),
        createdById: user.id,
        merchantId: merchant?.id ?? null,
        recipientName: body.recipientName ?? null,
        recipientPhone: body.recipientPhone ?? null,
        expiresAt: new Date(Date.now() + body.ttlHours * 3_600_000),
      },
    });
    return this.toDto(link);
  }

  async list(
    user: AuthUser,
    query: z.output<typeof LocationLinkListQuery>,
  ): Promise<z.output<typeof LocationLinkDto>[]> {
    const now = new Date();
    const where =
      query.status === 'SUBMITTED'
        ? { submittedAt: { not: null } }
        : query.status === 'PENDING'
          ? { submittedAt: null, expiresAt: { gt: now } }
          : query.status === 'EXPIRED'
            ? { submittedAt: null, expiresAt: { lte: now } }
            : {};
    const links = await this.prisma.locationLink.findMany({
      where: { createdById: user.id, ...where },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return Promise.all(links.map((link) => this.toDto(link)));
  }

  async get(user: AuthUser, id: string): Promise<z.output<typeof LocationLinkDto>> {
    const link = await this.prisma.locationLink.findUnique({ where: { id } });
    if (!link || link.createdById !== user.id) throw AppError.notFound('LOCATION_LINK_NOT_FOUND');
    return this.toDto(link);
  }

  // --- Pages publiques (sans connexion) ---------------------------------------------------

  async publicView(token: string): Promise<z.output<typeof PublicLocationLinkDto>> {
    const link = await this.prisma.locationLink.findUnique({
      where: { token },
      include: { merchant: true, createdBy: true },
    });
    if (!link) throw AppError.notFound('LOCATION_LINK_NOT_FOUND');
    return {
      senderName: link.merchant?.shopName ?? link.createdBy.fullName ?? null,
      recipientName: link.recipientName,
      expiresAt: link.expiresAt.toISOString(),
      status: statusOf(link),
    };
  }

  async publicSubmit(
    token: string,
    body: z.output<typeof PublicLocationSubmitBody>,
  ): Promise<z.output<typeof PublicLocationLinkDto>> {
    const link = await this.prisma.locationLink.findUnique({ where: { token } });
    if (!link) throw AppError.notFound('LOCATION_LINK_NOT_FOUND');
    const status = statusOf(link);
    if (status === 'SUBMITTED') throw AppError.conflict('LOCATION_LINK_ALREADY_USED');
    if (status === 'EXPIRED') throw new AppError('LOCATION_LINK_EXPIRED', 410);

    const addressId = await this.prisma.$transaction(async (tx) => {
      const address = await this.addresses.createAddress(
        {
          ownerId: link.createdById,
          source: 'LOCATION_LINK',
          latitude: body.latitude,
          longitude: body.longitude,
          landmark: body.landmark,
          contactName: body.contactName ?? link.recipientName,
          contactPhone: body.contactPhone ?? link.recipientPhone,
        },
        tx,
      );
      const { count } = await tx.locationLink.updateMany({
        where: { id: link.id, submittedAt: null },
        data: { submittedAt: new Date(), addressId: address.id },
      });
      if (count !== 1) throw AppError.conflict('LOCATION_LINK_ALREADY_USED');
      return address.id;
    });
    await this.notifySubmitted(link, addressId, body.landmark, body.contactName);
    return this.publicView(token);
  }

  /**
   * Prévient l'expéditeur que l'adresse est arrivée : push (app fermée) et événement temps
   * réel (app ouverte sur la commande). Un échec d'envoi n'annule pas l'adresse.
   */
  private async notifySubmitted(
    link: LocationLink,
    addressId: string,
    landmark: string,
    contactName: string | undefined,
  ): Promise<void> {
    const data = { type: 'location_link.submitted', linkId: link.id, addressId };
    this.realtime.toUser(link.createdById, 'location-link.submitted', data);
    const name = (link.recipientName ?? contactName ?? '').trim();
    try {
      await this.notifications.toUser(link.createdById, {
        template: name ? 'LOCATION_LINK_SUBMITTED' : 'LOCATION_LINK_SUBMITTED_ANONYMOUS',
        params: { name, landmark: landmark.trim() },
        data,
      });
    } catch (error) {
      this.logger.warn(`Lien ${link.id} rempli, expéditeur non prévenu : ${String(error)}`);
    }
  }
}
