import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { REDIS } from '../redis/redis.constants.js';

/** Au plus une écriture par minute et par livreur pour prolonger sa session en ligne. */
const TOUCH_INTERVAL_MS = 60_000;

/**
 * Temps passé en ligne par les livreurs (E9), en sessions dans PostgreSQL. Une session
 * s'ouvre au passage en ligne et se ferme au passage hors ligne ; les positions la
 * prolongent. Si le téléphone ne donne plus de nouvelles (batterie, réseau), elle s'arrête
 * à la dernière position reçue : on ne compte pas de temps en ligne sans signe de vie.
 */
@Injectable()
export class OnlineTimeService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Sans nouvelles depuis le délai de présence (plus l'espacement des écritures). */
  private get staleMs(): number {
    return this.env.RIDER_POSITION_TTL_SECONDS * 1000 + TOUCH_INTERVAL_MS;
  }

  /** Passage en ligne : reprend la session encore vivante, ou en ouvre une nouvelle. */
  async start(riderId: string, at: Date): Promise<void> {
    const open = await this.prisma.riderOnlineSession.findFirst({
      where: { riderId, endedAt: null },
    });
    if (open && open.lastSeenAt.getTime() >= at.getTime() - this.staleMs) {
      if (at > open.lastSeenAt) {
        await this.prisma.riderOnlineSession.update({
          where: { id: open.id },
          data: { lastSeenAt: at },
        });
      }
      return;
    }
    if (open) {
      // Session abandonnée (plus de nouvelles) : close à la dernière position reçue.
      await this.prisma.riderOnlineSession.update({
        where: { id: open.id },
        data: { endedAt: open.lastSeenAt },
      });
    }
    try {
      await this.prisma.riderOnlineSession.create({
        data: { riderId, startedAt: at, lastSeenAt: at },
      });
    } catch (error) {
      // Deux passages en ligne simultanés : l'autre requête a ouvert la session.
      if ((error as { code?: string }).code !== 'P2002') throw error;
    }
  }

  /** Position d'un livreur en ligne : prolonge sa session, au plus une fois par minute. */
  async touch(riderId: string, at: Date): Promise<void> {
    const first = await this.redis.set(
      `online-touch:${riderId}`,
      '1',
      'PX',
      TOUCH_INTERVAL_MS,
      'NX',
    );
    if (first !== 'OK') return;
    await this.start(riderId, at);
  }

  /** Passage hors ligne. */
  async stop(riderId: string, at: Date): Promise<void> {
    const open = await this.prisma.riderOnlineSession.findFirst({
      where: { riderId, endedAt: null },
    });
    if (!open) return;
    const stale = open.lastSeenAt.getTime() < at.getTime() - this.staleMs;
    const end = stale ? open.lastSeenAt : at > open.startedAt ? at : open.startedAt;
    await this.prisma.riderOnlineSession.update({
      where: { id: open.id },
      data: { endedAt: end, lastSeenAt: end > open.lastSeenAt ? end : open.lastSeenAt },
    });
    await this.redis.del(`online-touch:${riderId}`);
  }

  /** Secondes passées en ligne entre `from` et `to`. */
  async seconds(riderId: string, from: Date, to: Date, now = new Date()): Promise<number> {
    const sessions = await this.prisma.riderOnlineSession.findMany({
      where: {
        riderId,
        startedAt: { lt: to },
        OR: [{ endedAt: null }, { endedAt: { gt: from } }],
      },
    });
    let total = 0;
    for (const session of sessions) {
      const alive = session.lastSeenAt.getTime() >= now.getTime() - this.staleMs;
      const end = session.endedAt ?? (alive ? now : session.lastSeenAt);
      const start = Math.max(session.startedAt.getTime(), from.getTime());
      const stop = Math.min(end.getTime(), to.getTime());
      if (stop > start) total += stop - start;
    }
    return Math.round(total / 1000);
  }
}
