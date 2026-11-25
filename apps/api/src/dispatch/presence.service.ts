import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { REDIS } from '../redis/redis.constants.js';

/** Livreurs en ligne, indexés par position (GEO) : seuls eux reçoivent des propositions. */
const GEO_KEY = 'riders:geo';
/** Livreurs en ligne → heure de la dernière position (ms), pour écarter les positions périmées. */
const SEEN_KEY = 'riders:seen';
/** Dernier signe de vie reçu du téléphone (heure du serveur), en ligne ou non. */
const HEARD_KEY = 'riders:heard';
const positionKey = (riderId: string): string => `rider:${riderId}:pos`;

export interface RiderPosition {
  latitude: number;
  longitude: number;
  /** Heure de la mesure sur le téléphone. */
  at: Date;
  heading?: number | undefined;
  speed?: number | undefined;
  accuracy?: number | undefined;
  /** Position simulée signalée par le téléphone. */
  mocked?: boolean | undefined;
}

export interface NearbyRider {
  riderId: string;
  /** Distance à vol d'oiseau, en mètres. */
  distanceMeters: number;
}

/**
 * Présence et positions des livreurs dans Redis (D1, F1). Une position reçue toutes les
 * 10 à 15 s ne passe pas par PostgreSQL : seule la dernière est gardée, avec une durée de
 * vie. Un livreur dont le téléphone ne donne plus signe de vie sort de lui-même des
 * propositions au bout de RIDER_POSITION_TTL_SECONDS.
 */
@Injectable()
export class PresenceService {
  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private get ttlMs(): number {
    return this.env.RIDER_POSITION_TTL_SECONDS * 1000;
  }

  async goOnline(riderId: string, position: RiderPosition): Promise<void> {
    await this.redis
      .multi()
      .geoadd(GEO_KEY, position.longitude, position.latitude, riderId)
      .zadd(SEEN_KEY, Date.now(), riderId)
      .zadd(HEARD_KEY, Date.now(), riderId)
      .hset(positionKey(riderId), serialize(position))
      .pexpire(positionKey(riderId), this.ttlMs * 10)
      .exec();
  }

  /**
   * Heure (ms, horloge du serveur) du dernier envoi reçu de chaque livreur, même d'une
   * position ancienne rejouée au retour du réseau : il est joignable à ce moment-là.
   */
  async heardAt(riderIds: string[]): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    if (riderIds.length === 0) return result;
    const scores = await this.redis.zmscore(HEARD_KEY, ...riderIds);
    riderIds.forEach((id, index) => {
      const at = scores[index];
      if (at !== null && at !== undefined) result.set(id, Number(at));
    });
    return result;
  }

  async goOffline(riderId: string): Promise<void> {
    await this.redis.multi().zrem(GEO_KEY, riderId).zrem(SEEN_KEY, riderId).exec();
  }

  async isOnline(riderId: string): Promise<boolean> {
    const seen = await this.redis.zscore(SEEN_KEY, riderId);
    return seen !== null && Number(seen) >= Date.now() - this.ttlMs;
  }

  /**
   * Nouvelle position. Elle est toujours gardée (suivi des courses en cours, même hors
   * ligne) ; l'index des propositions n'est mis à jour que pour un livreur en ligne.
   * Renvoie false si la position est plus ancienne que celle déjà connue (envoi hors ligne).
   */
  async update(riderId: string, position: RiderPosition): Promise<boolean> {
    await this.redis.zadd(HEARD_KEY, Date.now(), riderId);
    const previous = await this.redis.hget(positionKey(riderId), 'at');
    if (previous && Number(previous) > position.at.getTime()) return false;
    const online = (await this.redis.zscore(SEEN_KEY, riderId)) !== null;
    const multi = this.redis
      .multi()
      .hset(positionKey(riderId), serialize(position))
      .pexpire(positionKey(riderId), this.ttlMs * 10);
    if (online) {
      multi
        .geoadd(GEO_KEY, position.longitude, position.latitude, riderId)
        .zadd(SEEN_KEY, Date.now(), riderId);
    }
    await multi.exec();
    return true;
  }

  /** Livreurs passés en ligne → heure de leur dernier signe de vie (ms), frais ou non. */
  async onlineRiders(): Promise<Map<string, number>> {
    const raw = await this.redis.zrange(SEEN_KEY, 0, -1, 'WITHSCORES');
    const result = new Map<string, number>();
    for (let index = 0; index + 1 < raw.length; index += 2) {
      result.set(raw[index] as string, Number(raw[index + 1]));
    }
    return result;
  }

  /** Délai au-delà duquel une position est périmée (signal perdu), en ms. */
  get staleAfterMs(): number {
    return this.ttlMs;
  }

  async position(riderId: string): Promise<RiderPosition | null> {
    const raw = await this.redis.hgetall(positionKey(riderId));
    return deserialize(raw);
  }

  async positions(riderIds: string[]): Promise<Map<string, RiderPosition>> {
    const result = new Map<string, RiderPosition>();
    if (riderIds.length === 0) return result;
    const pipeline = this.redis.pipeline();
    for (const id of riderIds) pipeline.hgetall(positionKey(id));
    const replies = (await pipeline.exec()) ?? [];
    replies.forEach(([, raw], index) => {
      const position = deserialize(raw as Record<string, string>);
      const id = riderIds[index];
      if (position && id) result.set(id, position);
    });
    return result;
  }

  /** Livreurs en ligne dans un rayon, du plus proche au plus éloigné, positions fraîches. */
  async nearby(
    latitude: number,
    longitude: number,
    radiusMeters: number,
    limit: number,
  ): Promise<NearbyRider[]> {
    const raw = (await this.redis.geosearch(
      GEO_KEY,
      'FROMLONLAT',
      longitude,
      latitude,
      'BYRADIUS',
      radiusMeters,
      'm',
      'ASC',
      'COUNT',
      limit * 2,
      'WITHDIST',
    )) as [string, string][];
    if (raw.length === 0) return [];
    const seen = await this.redis.zmscore(SEEN_KEY, ...raw.map(([id]) => id));
    const freshAfter = Date.now() - this.ttlMs;
    const fresh: NearbyRider[] = [];
    const stale: string[] = [];
    raw.forEach(([riderId, distance], index) => {
      const at = seen[index];
      if (at !== null && at !== undefined && Number(at) >= freshAfter) {
        fresh.push({ riderId, distanceMeters: Math.round(Number(distance)) });
      } else {
        stale.push(riderId);
      }
    });
    if (stale.length > 0) await this.removeFromIndex(stale);
    return fresh.slice(0, limit);
  }

  /** Livreurs sans position récente : sortis de l'index des propositions. */
  async purgeStale(): Promise<string[]> {
    const stale = await this.redis.zrangebyscore(SEEN_KEY, '-inf', Date.now() - this.ttlMs);
    if (stale.length > 0) await this.removeFromIndex(stale);
    return stale;
  }

  async onlineCount(): Promise<number> {
    return this.redis.zcount(SEEN_KEY, Date.now() - this.ttlMs, '+inf');
  }

  private async removeFromIndex(riderIds: string[]): Promise<void> {
    await this.redis
      .multi()
      .zrem(GEO_KEY, ...riderIds)
      .zrem(SEEN_KEY, ...riderIds)
      .exec();
  }
}

function serialize(position: RiderPosition): Record<string, string> {
  const out: Record<string, string> = {
    lat: String(position.latitude),
    lng: String(position.longitude),
    at: String(position.at.getTime()),
  };
  if (position.heading !== undefined) out['heading'] = String(position.heading);
  if (position.speed !== undefined) out['speed'] = String(position.speed);
  if (position.accuracy !== undefined) out['accuracy'] = String(position.accuracy);
  return out;
}

function deserialize(raw: Record<string, string> | null | undefined): RiderPosition | null {
  if (!raw?.['lat'] || !raw['lng'] || !raw['at']) return null;
  const optional = (key: string): number | undefined =>
    raw[key] === undefined ? undefined : Number(raw[key]);
  return {
    latitude: Number(raw['lat']),
    longitude: Number(raw['lng']),
    at: new Date(Number(raw['at'])),
    heading: optional('heading'),
    speed: optional('speed'),
    accuracy: optional('accuracy'),
  };
}
