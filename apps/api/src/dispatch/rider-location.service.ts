import { Injectable } from '@nestjs/common';
import { AppError } from '../common/errors/app-error.js';
import { cameroonDate } from '../common/time.js';
import type { RiderProfile } from '../generated/prisma/client.js';
import { requiredVersions, termsAccepted } from '../legal/legal-versions.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CourseTrackService } from '../tracking/course-track.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { uncoveredDocuments } from '../riders/riders.service.js';
import { ACTIVE_RIDER_STATUSES, DispatchService } from './dispatch.service.js';
import { OnlineTimeService } from './online-time.service.js';
import { PresenceService, type RiderPosition } from './presence.service.js';

/** Position transmise au back-office au plus une fois par livreur sur cet intervalle. */
const OPS_POSITION_INTERVAL_MS = 10_000;
/** Une position datée de plus loin dans le futur est refusée (horloge du téléphone fausse). */
const MAX_CLOCK_SKEW_MS = 120_000;

/**
 * Passage en ligne ou hors ligne (E1) et positions envoyées par l'app livreur (F1) : mises
 * à jour de la présence, puis diffusion aux expéditeurs qui suivent ses courses en cours.
 */
@Injectable()
export class RiderLocationService {
  private readonly lastOpsEmit = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly dispatch: DispatchService,
    private readonly realtime: RealtimeService,
    private readonly onlineTime: OnlineTimeService,
    private readonly tracks: CourseTrackService,
  ) {}

  async riderOf(userId: string): Promise<RiderProfile & { documents: { id: string }[] }> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { userId },
      include: { documents: true },
    });
    if (!rider) throw AppError.forbidden();
    return rider;
  }

  /** Raisons qui empêchent le livreur de recevoir des courses (D4). */
  async blockers(userId: string): Promise<string[]> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { userId },
      include: {
        documents: true,
        user: {
          select: {
            consents: {
              where: { granted: true, version: { in: requiredVersions('rider') } },
              select: { version: true },
            },
          },
        },
      },
    });
    if (!rider) return ['NOT_A_RIDER'];
    const reasons: string[] = [];
    if (rider.status !== 'ACTIVE') reasons.push(`STATUS_${rider.status}`);
    // Nouvelle version des conditions : à lire et signer dans l'app avant de reprendre.
    const accepted = rider.user.consents.map((consent) => consent.version);
    if (!termsAccepted('rider', accepted)) reasons.push('TERMS');
    // Espèces non déposées dans le délai (G5) : plus de courses jusqu'au dépôt.
    if (rider.cashOverdueSince) reasons.push('CASH_OVERDUE');
    const missing = uncoveredDocuments(rider.documents, ['APPROVED'], cameroonDate(new Date()));
    reasons.push(...missing.map((type) => `DOCUMENT_${type}`));
    return reasons;
  }

  async setPresence(
    userId: string,
    online: boolean,
    position: RiderPosition,
  ): Promise<{ online: boolean; blockers: string[] }> {
    const rider = await this.riderOf(userId);
    if (!online) {
      await this.presence.goOffline(rider.id);
      await this.onlineTime.stop(rider.id, new Date());
      await this.dispatch.declineAllFor(rider.id);
      await this.update(userId, position);
      return { online: false, blockers: [] };
    }
    const blockers = await this.blockers(userId);
    if (blockers.length > 0) {
      throw AppError.unprocessable('RIDER_NOT_ELIGIBLE', { reasons: blockers.join(', ') });
    }
    checkClock(position.at);
    await this.presence.goOnline(rider.id, position);
    await this.onlineTime.start(rider.id, new Date());
    return { online: true, blockers: [] };
  }

  async isOnline(userId: string): Promise<boolean> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    return rider ? this.presence.isOnline(rider.id) : false;
  }

  /** Nouvelle position : présence, suivi des courses en cours, carte du back-office. */
  async update(userId: string, position: RiderPosition, riderId?: string): Promise<void> {
    checkClock(position.at);
    const id = riderId ?? (await this.riderOf(userId)).id;
    const accepted = await this.presence.update(id, position);
    if (!accepted) return;
    if (await this.presence.isOnline(id)) await this.onlineTime.touch(id, new Date());
    const payload = {
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading ?? null,
      speed: position.speed ?? null,
      at: position.at.toISOString(),
    };
    const active = await this.prisma.order.findMany({
      where: { riderId: id, status: { in: [...ACTIVE_RIDER_STATUSES] } },
      select: { id: true },
    });
    for (const order of active) {
      this.realtime.toOrder(order.id, 'rider.position', { orderId: order.id, ...payload });
    }
    // Trajet de la course enregistré pendant la course seulement (sécurité, litiges).
    if (active.length > 0) {
      await this.tracks.record(
        id,
        active.map((order) => order.id),
        position,
      );
    }
    const now = Date.now();
    if ((this.lastOpsEmit.get(id) ?? 0) + OPS_POSITION_INTERVAL_MS <= now) {
      this.lastOpsEmit.set(id, now);
      this.realtime.toOps('ops.rider-position', {
        riderId: id,
        activeOrders: active.length,
        ...payload,
      });
    }
  }
}

function checkClock(at: Date): void {
  if (at.getTime() > Date.now() + MAX_CLOCK_SKEW_MS)
    throw AppError.badRequest('ACTION_TIME_INVALID');
}
