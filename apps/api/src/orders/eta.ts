import type { RiderPosition } from '../dispatch/presence.service.js';
import { haversineMeters } from '../routing/distance.service.js';

/** Vitesse prudente d'une moto dans Douala (la même que l'app expéditeur). */
const METERS_PER_MINUTE = 300;

/** Au-delà, la position du livreur est trop vieille pour annoncer une heure. */
const POSITION_MAX_AGE_MS = 5 * 60_000;

interface Point {
  latitude: number;
  longitude: number;
}

export interface Eta {
  minutes: number;
  distanceMeters: number;
  /** Part du trajet faite, de 0 à 1. */
  progress: number;
}

/**
 * Arrivée estimée d'après la dernière position du livreur (à vol d'oiseau, prudente) ;
 * null sans position récente.
 */
export function etaFrom(
  position: RiderPosition | null | undefined,
  pickup: Point,
  dropoff: Point,
  now: Date,
): Eta | null {
  if (!position || now.getTime() - position.at.getTime() > POSITION_MAX_AGE_MS) return null;
  const remaining = haversineMeters(position, dropoff);
  const total = Math.max(haversineMeters(pickup, dropoff), 1);
  return {
    minutes: Math.max(1, Math.ceil(remaining / METERS_PER_MINUTE)),
    distanceMeters: Math.round(remaining),
    progress: Math.round(Math.min(1, Math.max(0, 1 - remaining / total)) * 100) / 100,
  };
}
