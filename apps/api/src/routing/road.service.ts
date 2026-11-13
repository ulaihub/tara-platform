import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import type { GeoPoint } from './distance.service.js';

/** Au-delà de cette distance de toute rue, la position est gardée telle quelle (cour, marché…). */
export const MAX_SNAP_METERS = 40;
/** Points envoyés à OSRM pour recaler un trajet (limite par défaut d'osrm-routed). */
export const MAX_MATCH_POINTS = 100;
/** Rayon de recherche autour de chaque point GPS, en mètres. */
const DEFAULT_RADIUS_METERS = 25;
const TIMEOUT_MS = 2_500;

export interface TimedPoint extends GeoPoint {
  at: Date;
  /** Précision annoncée par le téléphone, en mètres. */
  accuracy?: number | null;
}

const round6 = (value: number) => Math.round(value * 1e6) / 1e6;

/** Garde au plus [max] points, le premier et le dernier compris, répartis régulièrement. */
export function sample<T>(points: readonly T[], max: number): T[] {
  if (points.length <= max) return [...points];
  const step = (points.length - 1) / (max - 1);
  return Array.from({ length: max }, (_, index) => points[Math.round(index * step)] as T);
}

function isPair(value: unknown): value is [number, number] {
  return (
    Array.isArray(value) &&
    typeof value[0] === 'number' &&
    typeof value[1] === 'number' &&
    Number.isFinite(value[0]) &&
    Number.isFinite(value[1])
  );
}

/**
 * Positions et trajets posés sur les rues (H1), par OSRM : la position GPS d'un livreur
 * ramenée sur la rue la plus proche, son trajet recalé sur le réseau routier. Sans OSRM, ou
 * s'il ne répond pas, rien n'est inventé : les fonctions renvoient null et l'appelant
 * garde le GPS brut.
 */
@Injectable()
export class RoadService {
  private readonly logger = new Logger(RoadService.name);
  private warnedAt = 0;

  constructor(@Inject(ENV) private readonly env: Env) {}

  get available(): boolean {
    return Boolean(this.env.OSRM_URL);
  }

  private url(path: string): string {
    return `${(this.env.OSRM_URL ?? '').replace(/\/$/, '')}${path}`;
  }

  /** Une alerte par minute au plus : OSRM absent ne doit pas noyer les journaux. */
  private warn(what: string, error: unknown): void {
    const now = Date.now();
    if (now - this.warnedAt < 60_000) return;
    this.warnedAt = now;
    this.logger.warn(`OSRM indisponible (${what}) : ${String(error)}`);
  }

  /** Point de la rue la plus proche, ou null (OSRM absent, rue à plus de [maxMeters]). */
  async snap(point: GeoPoint, maxMeters = MAX_SNAP_METERS): Promise<GeoPoint | null> {
    if (!this.available) return null;
    try {
      const response = await fetch(
        this.url(`/nearest/v1/driving/${point.longitude},${point.latitude}?number=1`),
        { signal: AbortSignal.timeout(TIMEOUT_MS) },
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = (await response.json()) as {
        code?: string;
        waypoints?: { location?: unknown; distance?: number }[];
      };
      const waypoint = body.waypoints?.[0];
      if (body.code !== 'Ok' || !waypoint || !isPair(waypoint.location)) return null;
      if ((waypoint.distance ?? Infinity) > maxMeters) return null;
      return { longitude: round6(waypoint.location[0]), latitude: round6(waypoint.location[1]) };
    } catch (error) {
      this.warn('position', error);
      return null;
    }
  }

  /**
   * Trajet GPS recalé sur les rues, en paires [longitude, latitude]. Les trous (tunnel,
   * téléphone éteint) sont rejoints par la route la plus probable. Null si impossible.
   */
  async match(points: readonly TimedPoint[]): Promise<[number, number][] | null> {
    if (!this.available || points.length < 2) return null;
    const kept = sample(points, MAX_MATCH_POINTS);
    const coordinates = kept.map((point) => `${point.longitude},${point.latitude}`).join(';');
    // Horodatages strictement croissants, exigés par OSRM.
    let last = 0;
    const timestamps = kept.map((point) => {
      last = Math.max(last + 1, Math.floor(point.at.getTime() / 1000));
      return last;
    });
    const radiuses = kept.map((point) =>
      Math.round(Math.min(60, Math.max(DEFAULT_RADIUS_METERS, point.accuracy ?? 0))),
    );
    const query = [
      `timestamps=${timestamps.join(';')}`,
      `radiuses=${radiuses.join(';')}`,
      'overview=full',
      'geometries=geojson',
      'gaps=ignore',
      'tidy=true',
    ].join('&');
    try {
      const response = await fetch(this.url(`/match/v1/driving/${coordinates}?${query}`), {
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = (await response.json()) as {
        code?: string;
        matchings?: { geometry?: { coordinates?: unknown } }[];
      };
      if (body.code !== 'Ok' || !body.matchings?.length) return null;
      const path = body.matchings.flatMap((matching) =>
        Array.isArray(matching.geometry?.coordinates)
          ? (matching.geometry.coordinates as unknown[]).filter(isPair)
          : [],
      );
      return path.length >= 2
        ? path.map(([lng, lat]): [number, number] => [round6(lng), round6(lat)])
        : null;
    } catch (error) {
      this.warn('trajet', error);
      return null;
    }
  }
}
