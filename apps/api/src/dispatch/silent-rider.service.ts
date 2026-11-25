import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { OrderEventsBus, type OrderChange } from '../events/order-events.bus.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { REDIS } from '../redis/redis.constants.js';
import { PresenceService } from './presence.service.js';

/** Étapes où le colis est à bord : on ne peut plus confier la course à un autre livreur. */
const PARCEL_ON_BOARD = ['PICKED_UP', 'IN_DELIVERY'] as const;

/**
 * Livreur muet pendant une course (plus aucun signe de son téléphone) :
 * - colis pas encore enlevé : la course lui est retirée et repart vers un autre livreur
 *   (le plus proche d'abord), sans frais pour l'expéditeur ; l'argent mis de côté sur son
 *   solde lui revient ; le retrait compte dans sa fiabilité ;
 * - colis à bord : rien ne peut être réattribué ; l'expéditeur est prévenu une fois, et
 *   l'équipe suit le livreur sur la carte (« sans signal »).
 */
@Injectable()
export class SilentRiderService {
  private readonly logger = new Logger(SilentRiderService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly transitions: OrderTransitionsService,
    private readonly bus: OrderEventsBus,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron('*/15 * * * * *', { name: 'silent-riders' })
  async scheduledScan(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.scan();
  }

  /** `only` : limiter à certaines commandes (tests). */
  async scan(
    now = new Date(),
    only?: string[],
  ): Promise<{ withdrawn: number; warned: number }> {
    const limitMs = this.env.RIDER_SILENT_WITHDRAW_SECONDS * 1000;
    const before = new Date(now.getTime() - limitMs);
    const orders = await this.prisma.order.findMany({
      where: {
        ...(only ? { id: { in: only } } : {}),
        riderId: { not: null },
        OR: [
          { status: 'ASSIGNED', assignedAt: { lte: before } },
          { status: { in: [...PARCEL_ON_BOARD] }, pickedUpAt: { lte: before } },
        ],
      },
      select: { id: true, status: true, riderId: true, assignedAt: true, pickedUpAt: true },
      take: 1000,
    });
    if (orders.length === 0) return { withdrawn: 0, warned: 0 };
    const heard = await this.presence.heardAt([...new Set(orders.map((o) => o.riderId as string))]);
    let withdrawn = 0;
    let warned = 0;
    for (const order of orders) {
      const riderId = order.riderId as string;
      // Repère : le dernier signe du téléphone, sinon le début de l'étape en cours.
      const since = Math.max(
        heard.get(riderId) ?? 0,
        (order.status === 'ASSIGNED' ? order.assignedAt : order.pickedUpAt)?.getTime() ?? 0,
      );
      const silentMs = now.getTime() - since;
      if (silentMs < limitMs) continue;
      try {
        if (order.status === 'ASSIGNED') {
          if (await this.withdraw(order.id, riderId, Math.round(silentMs / 60_000))) withdrawn += 1;
        } else if (await this.warnSender(order.id, riderId)) {
          warned += 1;
        }
      } catch (error) {
        this.logger.error(`Livreur muet : traitement en échec (${order.id})`, error);
      }
    }
    return { withdrawn, warned };
  }

  /** Retire la course au livreur muet ; false si elle a changé entre-temps. */
  private async withdraw(orderId: string, riderId: string, minutes: number): Promise<boolean> {
    let change: OrderChange | null = null;
    try {
      change = await this.prisma.$transaction(async (tx) => {
        const order = await tx.order.findUnique({ where: { id: orderId } });
        if (order?.status !== 'ASSIGNED' || order.riderId !== riderId) return null;
        await tx.courseAlert.upsert({
          where: { orderId_dedupeKey: { orderId, dedupeKey: `RIDER_SILENT:${riderId}` } },
          create: {
            orderId,
            riderId,
            kind: 'RIDER_SILENT',
            dedupeKey: `RIDER_SILENT:${riderId}`,
            details: { minutes, withdrawn: true },
          },
          update: {},
        });
        const result = await this.transitions.applyIn(
          tx,
          order,
          'SEARCHING_RIDER',
          { id: null, role: 'SYSTEM' },
          { note: `Livreur sans signal depuis ${minutes} min : course confiée à un autre livreur` },
        );
        return result.change;
      });
    } catch (error) {
      if (error instanceof AppError) return false; // Déjà traitée par une autre instance.
      throw error;
    }
    if (!change) return false;
    await this.bus.publish(change);
    const reference = change.order.reference;
    const rider = await this.prisma.riderProfile.findUnique({
      where: { id: riderId },
      select: { userId: true },
    });
    if (rider) {
      this.realtime.toUser(rider.userId, 'order.status', {
        orderId,
        reference,
        status: 'REASSIGNED',
        at: new Date().toISOString(),
      });
      await this.notifications.toUser(rider.userId, {
        template: 'RIDER_ORDER_SILENT_WITHDRAWN',
        params: { reference },
        data: { type: 'order.reassigned', orderId },
        orderId,
      });
    }
    await this.notifications.toUser(change.order.senderId, {
      template: 'ORDER_RIDER_REPLACED',
      params: { reference },
      data: { type: 'order.status', orderId },
      orderId,
    });
    return true;
  }

  /** Colis à bord, livreur muet : l'expéditeur est prévenu une seule fois par coupure. */
  private async warnSender(orderId: string, riderId: string): Promise<boolean> {
    // Une fois par livreur et par commande dans l'heure : pas de rafale si le signal va et vient.
    const first = await this.redis.set(`silent-warned:${orderId}:${riderId}`, '1', 'EX', 3600, 'NX');
    if (first !== 'OK') return false;
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      select: { reference: true, senderId: true },
    });
    await this.notifications.toUser(order.senderId, {
      template: 'ORDER_RIDER_NO_SIGNAL',
      params: { reference: order.reference },
      data: { type: 'order.status', orderId },
      orderId,
    });
    return true;
  }
}
