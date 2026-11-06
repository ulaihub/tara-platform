import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface RouteEstimate {
  meters: number;
  seconds: number | null;
  /** « osrm » : itinéraire routier réel ; « estimate » : vol d'oiseau corrigé (repli). */
  source: 'osrm' | 'estimate';
}

/** Itinéraire avec son tracé, en paires [longitude, latitude] (ordre GeoJSON). */
export interface RoutePath extends RouteEstimate {
  path: [number, number][];
}

/**
 * Facteur de détour du réseau routier par rapport au vol d'oiseau. Hypothèse à recaler
 * sur les trajets réels du pilote (valeur courante en ville : 1,2 à 1,4).
 */
export const ROAD_DETOUR_FACTOR = 1.3;

/** Vitesse moyenne d'une moto en ville, embouteillages compris (hypothèse : 18 km/h). */
const URBAN_SPEED_METERS_PER_SECOND = 5;

/** Plafond du tracé renvoyé à l'app (un trajet urbain simplifié en compte bien moins). */
const MAX_PATH_POINTS = 1_000;

const round6 = (value: number) => Math.round(value * 1e6) / 1e6;

export function haversineMeters(a: GeoPoint, b: GeoPoint): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
}

/** Distance routière entre deux points (C2) : OSRM si disponible, estimation sinon. */
@Injectable()
export class DistanceService {
  private readonly logger = new Logger(DistanceService.name);

  constructor(@Inject(ENV) private readonly env: Env) {}

  async route(from: GeoPoint, to: GeoPoint): Promise<RouteEstimate> {
    if (this.env.OSRM_URL) {
      try {
        return await this.osrm(this.env.OSRM_URL, from, to);
      } catch (error) {
        this.logger.warn(`OSRM indisponible, distance estimée : ${String(error)}`);
      }
    }
    const meters = Math.round(haversineMeters(from, to) * ROAD_DETOUR_FACTOR);
    return {
      meters,
      seconds: Math.round(meters / URBAN_SPEED_METERS_PER_SECOND),
      source: 'estimate',
    };
  }

  /**
   * Itinéraire à dessiner sur la carte du livreur (E2) : tracé routier simplifié par OSRM,
   * ou ligne droite si OSRM est absent ou indisponible (la distance est alors estimée).
   */
  async path(from: GeoPoint, to: GeoPoint): Promise<RoutePath> {
    if (this.env.OSRM_URL) {
      try {
        return await this.osrmPath(this.env.OSRM_URL, from, to);
      } catch (error) {
        this.logger.warn(`OSRM indisponible, itinéraire estimé : ${String(error)}`);
      }
    }
    const meters = Math.round(haversineMeters(from, to) * ROAD_DETOUR_FACTOR);
    return {
      meters,
      seconds: Math.round(meters / URBAN_SPEED_METERS_PER_SECOND),
      source: 'estimate',
      path: [
        [from.longitude, from.latitude],
        [to.longitude, to.latitude],
      ],
    };
  }

  private async osrmPath(baseUrl: string, from: GeoPoint, to: GeoPoint): Promise<RoutePath> {
    const coordinates = `${from.longitude},${from.latitude};${to.longitude},${to.latitude}`;
    const response = await fetch(
      `${baseUrl.replace(/\/$/, '')}/route/v1/driving/${coordinates}?overview=simplified&geometries=geojson`,
      { signal: AbortSignal.timeout(2_500) },
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = (await response.json()) as {
      code?: string;
      routes?: {
        distance: number;
        duration: number;
        geometry?: { type?: string; coordinates?: unknown };
      }[];
    };
    const route = body.routes?.[0];
    if (body.code !== 'Ok' || !route) throw new Error(`réponse OSRM ${body.code ?? 'vide'}`);
    const coordinatesList = route.geometry?.coordinates;
    if (!Array.isArray(coordinatesList) || coordinatesList.length < 2) {
      throw new Error('tracé OSRM absent');
    }
    const path = coordinatesList
      .filter(
        (point): point is [number, number] =>
          Array.isArray(point) &&
          typeof point[0] === 'number' &&
          typeof point[1] === 'number' &&
          Number.isFinite(point[0]) &&
          Number.isFinite(point[1]),
      )
      .slice(0, MAX_PATH_POINTS)
      .map(([lng, lat]): [number, number] => [round6(lng), round6(lat)]);
    if (path.length < 2) throw new Error('tracé OSRM invalide');
    return {
      meters: Math.round(route.distance),
      seconds: Math.round(route.duration),
      source: 'osrm',
      path,
    };
  }

  private async osrm(baseUrl: string, from: GeoPoint, to: GeoPoint): Promise<RouteEstimate> {
    const coordinates = `${from.longitude},${from.latitude};${to.longitude},${to.latitude}`;
    const response = await fetch(
      `${baseUrl.replace(/\/$/, '')}/route/v1/driving/${coordinates}?overview=false`,
      { signal: AbortSignal.timeout(2_500) },
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = (await response.json()) as {
      code?: string;
      routes?: { distance: number; duration: number }[];
    };
    const route = body.routes?.[0];
    if (body.code !== 'Ok' || !route) throw new Error(`réponse OSRM ${body.code ?? 'vide'}`);
    return {
      meters: Math.round(route.distance),
      seconds: Math.round(route.duration),
      source: 'osrm',
    };
  }
}
