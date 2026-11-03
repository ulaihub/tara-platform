import { type GeoPoint, haversineMeters } from '../routing/distance.service.js';

/** Point de trajet tel qu'analysé (heure de la mesure sur le téléphone). */
export interface TrackSample extends GeoPoint {
  at: Date;
  mocked?: boolean;
}

export interface TrackSummary {
  pointCount: number;
  distanceMeters: number;
  startedAt: Date | null;
  endedAt: Date | null;
  longestGapSeconds: number;
  longestStopSeconds: number;
  mockedPoints: number;
}

/** Déplacement minimal compté : en dessous, c'est l'imprécision du GPS à l'arrêt. */
export const MIN_MOVE_METERS = 15;
/** Au-delà (≈ 120 km/h), c'est un saut de GPS, pas un déplacement de moto en ville. */
export const MAX_SPEED_MPS = 33;
/** Rayon d'un arrêt : le livreur reste dans ce cercle. */
export const STOP_RADIUS_METERS = 60;

/**
 * Résumé d'un trajet : distance parcourue (sans le bruit du GPS à l'arrêt ni ses sauts),
 * plus longue coupure entre deux points, plus long arrêt, positions simulées.
 */
export function summarizeTrack(samples: readonly TrackSample[]): TrackSummary {
  const points = [...samples].sort((a, b) => a.at.getTime() - b.at.getTime());
  let distance = 0;
  let longestGap = 0;
  let longestStop = 0;
  let anchor = points[0];
  let stopStart = points[0];
  for (let i = 1; i < points.length; i++) {
    const point = points[i] as TrackSample;
    const previous = points[i - 1] as TrackSample;
    longestGap = Math.max(longestGap, seconds(previous.at, point.at));

    if (anchor) {
      const moved = haversineMeters(anchor, point);
      const elapsed = seconds(anchor.at, point.at);
      const plausible = elapsed > 0 ? moved / elapsed <= MAX_SPEED_MPS : moved < MIN_MOVE_METERS;
      if (moved >= MIN_MOVE_METERS && plausible) {
        distance += moved;
        anchor = point;
      }
    }

    if (stopStart && haversineMeters(stopStart, point) <= STOP_RADIUS_METERS) {
      longestStop = Math.max(longestStop, seconds(stopStart.at, point.at));
    } else {
      stopStart = point;
    }
  }
  return {
    pointCount: points.length,
    distanceMeters: Math.round(distance),
    startedAt: points[0]?.at ?? null,
    endedAt: points.at(-1)?.at ?? null,
    longestGapSeconds: longestGap,
    longestStopSeconds: longestStop,
    mockedPoints: points.filter((p) => p.mocked).length,
  };
}

/**
 * Arrêt en cours à la fin du trajet : depuis quand le livreur reste dans un cercle de
 * STOP_RADIUS_METERS autour de sa dernière position. null s'il bouge.
 */
export function currentStop(
  samples: readonly TrackSample[],
): { since: Date; at: TrackSample; seconds: number } | null {
  const points = [...samples].sort((a, b) => a.at.getTime() - b.at.getTime());
  const last = points.at(-1);
  if (!last) return null;
  let since = last.at;
  for (let i = points.length - 2; i >= 0; i--) {
    const point = points[i] as TrackSample;
    if (haversineMeters(point, last) > STOP_RADIUS_METERS) break;
    since = point.at;
  }
  const duration = seconds(since, last.at);
  return duration > 0 ? { since, at: last, seconds: duration } : null;
}

function seconds(from: Date, to: Date): number {
  return Math.max(0, Math.round((to.getTime() - from.getTime()) / 1000));
}
