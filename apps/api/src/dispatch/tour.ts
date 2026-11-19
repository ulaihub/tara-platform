import type { PackageSize } from '../generated/prisma/enums.js';
import { haversineMeters, type GeoPoint } from '../routing/distance.service.js';

/**
 * Tournée (étape 2c) : plusieurs colis d'un même envoi confiés à un seul livreur. Règles de
 * charge validées par le fondateur : une moto prend jusqu'à 5 petits ou moyens colis, ou un
 * seul grand ; un tricycle (ou une voiture) prend un gros objet et des petits colis. Fonctions
 * pures, testées seules.
 */

/** Colis qui voyagent à plusieurs : petits et moyens. */
const SMALL: readonly PackageSize[] = ['S', 'M'];

export interface TourParcel {
  id: string;
  packageSize: PackageSize;
}

/**
 * Colis qui partent avec [lead] : des petits et moyens colis, dans la limite de [maxSmall]
 * en tout (gros objet non compté). Un grand colis (L, XL) part seul.
 */
export function tourMembers<T extends TourParcel>(lead: T, others: T[], maxSmall: number): T[] {
  if (lead.packageSize === 'L' || lead.packageSize === 'XL') return [];
  const room = lead.packageSize === 'BULKY' ? maxSmall : maxSmall - 1;
  return others.filter((parcel) => SMALL.includes(parcel.packageSize)).slice(0, Math.max(0, room));
}

/** Ordre des arrêts : chaque fois le client le plus proche, en partant du point d'enlèvement. */
export function stopOrder<T extends { id: string; dropoff: GeoPoint }>(
  pickup: GeoPoint,
  stops: T[],
): T[] {
  const left = [...stops];
  const ordered: T[] = [];
  let here = pickup;
  while (left.length > 0) {
    let best = 0;
    for (let i = 1; i < left.length; i += 1) {
      const candidate = left[i];
      const current = left[best];
      if (
        candidate &&
        current &&
        haversineMeters(here, candidate.dropoff) < haversineMeters(here, current.dropoff)
      ) {
        best = i;
      }
    }
    const [next] = left.splice(best, 1);
    if (!next) break;
    ordered.push(next);
    here = next.dropoff;
  }
  return ordered;
}

/** Les rues ne vont pas en ligne droite : le trajet réel est un peu plus long. */
export const ROAD_FACTOR = 1.3;

/** Longueur estimée de la tournée : enlèvement, puis chaque arrêt dans l'ordre. */
export function tourMeters(pickup: GeoPoint, stops: { dropoff: GeoPoint }[]): number {
  let here = pickup;
  let total = 0;
  for (const stop of stops) {
    total += haversineMeters(here, stop.dropoff);
    here = stop.dropoff;
  }
  return Math.round(total * ROAD_FACTOR);
}
