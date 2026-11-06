import darkStyle from '@tara-map/tara-dark.json';
import lightStyle from '@tara-map/tara-light.json';
import type { StyleSpecification } from 'maplibre-gl';
import { firstName } from './format';
import { nextStop, type Point } from './live';
import type { LiveMap, LiveRider, RiderTrail } from './schemas';

/** Tuiles et polices de la carte, comme dans les apps (OpenFreeMap en attendant les nôtres). */
const TILES_URL = 'https://tiles.openfreemap.org/planet';
const GLYPHS_URL = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

/** Centre de Douala (Akwa), vue d'ensemble de la ville. */
export const DOUALA = { center: [9.7085, 4.0511] as [number, number], zoom: 12.3 };

/** Style Tara des apps (rues, quartiers, lieux utiles), clair ou sombre. */
export function taraStyle(dark: boolean): StyleSpecification {
  const raw = JSON.stringify(dark ? darkStyle : lightStyle)
    .replaceAll('{{TILES_URL}}', TILES_URL)
    .replaceAll('{{GLYPHS_URL}}', GLYPHS_URL);
  return JSON.parse(raw) as StyleSpecification;
}

interface Feature<P> {
  type: 'Feature';
  geometry:
    | { type: 'Point'; coordinates: [number, number] }
    | { type: 'LineString'; coordinates: [number, number][] };
  properties: P;
}
export interface Collection<P> {
  type: 'FeatureCollection';
  features: Feature<P>[];
}

const point = <P>(longitude: number, latitude: number, properties: P): Feature<P> => ({
  type: 'Feature',
  geometry: { type: 'Point', coordinates: [longitude, latitude] },
  properties,
});

export type Selection =
  | { type: 'rider'; id: string }
  | { type: 'order'; id: string }
  | { type: 'sos'; id: string }
  | null;

export interface RiderProps {
  id: string;
  state: string;
  signalLost: boolean;
  label: string;
  selected: boolean;
}

/** Où dessiner un livreur : sur la rue quand on la connaît, sinon à sa position GPS. */
export function riderPoint(rider: LiveRider): Point | null {
  return rider.roadPosition ?? rider.position;
}

/** Livreurs ayant une position connue. */
export function ridersData(map: LiveMap, selection: Selection): Collection<RiderProps> {
  const selectedRiders = new Set<string>();
  if (selection?.type === 'rider') selectedRiders.add(selection.id);
  if (selection?.type === 'order') {
    const riderId = map.orders.find((order) => order.id === selection.id)?.riderId;
    if (riderId) selectedRiders.add(riderId);
  }
  return {
    type: 'FeatureCollection',
    features: map.riders.flatMap((rider) => {
      const at = riderPoint(rider);
      return at
        ? [
            point(at.longitude, at.latitude, {
              id: rider.id,
              state: rider.state,
              signalLost: rider.signalLost,
              label: firstName(rider.name, rider.phone),
              selected: selectedRiders.has(rider.id),
            }),
          ]
        : [];
    }),
  };
}

export interface OrderProps {
  id: string;
  /** Prochain arrêt : vendeur ou client. */
  stop: 'pickup' | 'dropoff';
  late: boolean;
  waiting: boolean;
  selected: boolean;
}

/** Prochain arrêt de chaque commande en cours (là où le travail se trouve). */
export function ordersData(map: LiveMap, selection: Selection): Collection<OrderProps> {
  return {
    type: 'FeatureCollection',
    features: map.orders.map((order) => {
      const stop = nextStop(order);
      const at = order[stop];
      return point(at.longitude, at.latitude, {
        id: order.id,
        stop,
        late: order.delay !== null,
        waiting: order.riderId === null,
        selected: selection?.type === 'order' && selection.id === order.id,
      });
    }),
  };
}

const EMPTY = { type: 'FeatureCollection' as const, features: [] };

/** Tracé de l'API ([longitude, latitude] par point) en paires sûres. */
function pairs(path: readonly (readonly number[])[]): [number, number][] {
  return path.flatMap((pair) => {
    const [longitude, latitude] = pair;
    return longitude === undefined || latitude === undefined ? [] : [[longitude, latitude]];
  }) as [number, number][];
}

const line = <P>(coordinates: [number, number][], properties: P): Collection<P> => ({
  type: 'FeatureCollection',
  features:
    coordinates.length >= 2
      ? [{ type: 'Feature', geometry: { type: 'LineString', coordinates }, properties }]
      : [],
});

/** Course dont on demande le tracé : celle du livreur ou de la commande choisis. */
export function trailRequest(
  map: LiveMap,
  selection: Selection,
): { riderId: string; orderId?: string } | null {
  if (selection?.type === 'rider') {
    const rider = map.riders.find((item) => item.id === selection.id);
    return rider && rider.orderIds.length > 0 ? { riderId: rider.id } : null;
  }
  if (selection?.type === 'order') {
    const order = map.orders.find((item) => item.id === selection.id);
    return order?.riderId ? { riderId: order.riderId, orderId: order.id } : null;
  }
  return null;
}

/**
 * Course choisie (commande, ou livreur en course) : vendeur et client, itinéraire restant
 * sur les rues, chemin déjà parcouru. Tant que le tracé n'est pas arrivé, un trait
 * pointillé relie le livreur à son prochain arrêt.
 */
export function courseData(
  map: LiveMap,
  selection: Selection,
  trail: RiderTrail | null,
): {
  stops: Collection<{ kind: string; label: string }>;
  route: Collection<{ estimate: boolean }>;
  traveled: Collection<{ onRoads: boolean }>;
} {
  const request = trailRequest(map, selection);
  if (!request) return { stops: EMPTY, route: EMPTY, traveled: EMPTY };
  const fresh = trail?.riderId === request.riderId ? trail : null;
  const orderId =
    request.orderId ??
    fresh?.order?.id ??
    map.riders.find((rider) => rider.id === request.riderId)?.orderIds[0];
  const order = map.orders.find((item) => item.id === orderId);
  if (!order) return { stops: EMPTY, route: EMPTY, traveled: EMPTY };
  const stops = {
    type: 'FeatureCollection' as const,
    features: [
      point(order.pickup.longitude, order.pickup.latitude, { kind: 'pickup', label: 'Vendeur' }),
      point(order.dropoff.longitude, order.dropoff.latitude, { kind: 'dropoff', label: 'Client' }),
    ],
  };
  const traveled = fresh?.traveled
    ? line(pairs(fresh.traveled.path), { onRoads: fresh.traveled.onRoads })
    : EMPTY;
  if (fresh?.order?.id === order.id) {
    return {
      stops,
      route: fresh.remaining
        ? line(pairs(fresh.remaining.path), { estimate: !fresh.remaining.onRoads })
        : EMPTY,
      traveled,
    };
  }
  const rider = map.riders.find((item) => item.id === order.riderId);
  const from = rider ? riderPoint(rider) : null;
  const target = order[nextStop(order)];
  const route =
    from && order.status !== 'DELIVERY_FAILED'
      ? line(
          [
            [from.longitude, from.latitude],
            [target.longitude, target.latitude],
          ],
          { estimate: true },
        )
      : EMPTY;
  return { stops, route, traveled: EMPTY };
}

/** Tous les points du tracé d'une course, pour la cadrer entière. */
export function trailPoints(trail: RiderTrail): Point[] {
  return pairs([...(trail.traveled?.path ?? []), ...(trail.remaining?.path ?? [])]).map(
    ([longitude, latitude]) => ({ latitude, longitude }),
  );
}

/**
 * Points à cadrer pour un élément choisi : la position du livreur ou du SOS ; pour une
 * commande, son prochain arrêt et son livreur, pour voir le chemin qui reste.
 */
export function pointsOf(map: LiveMap, selection: Selection): Point[] {
  if (!selection) return [];
  const at = (position: Point | null | undefined): Point[] =>
    position ? [{ latitude: position.latitude, longitude: position.longitude }] : [];
  if (selection.type === 'rider') {
    const rider = map.riders.find((item) => item.id === selection.id);
    return at(rider ? riderPoint(rider) : null);
  }
  if (selection.type === 'sos') {
    return at(map.safetyAlerts.find((alert) => alert.id === selection.id));
  }
  const order = map.orders.find((item) => item.id === selection.id);
  if (!order) return [];
  const rider = map.riders.find((item) => item.id === order.riderId);
  return [...at(order[nextStop(order)]), ...at(rider ? riderPoint(rider) : null)];
}

/** Au-delà de cette distance (en degrés, ~1,5 km), le livreur saute : pas de glissement. */
const MAX_GLIDE_DEGREES = 0.0135;

/**
 * Position affichée de chaque livreur à l'instant [t] (de 0 à 1) d'un déplacement, pour
 * le faire glisser de son ancienne position à la nouvelle au lieu de sauter.
 */
export function glide(
  from: ReadonlyMap<string, [number, number]>,
  to: Collection<RiderProps>,
  t: number,
): Collection<RiderProps> {
  const eased = t >= 1 ? 1 : 1 - (1 - t) ** 3;
  return {
    type: 'FeatureCollection',
    features: to.features.map((feature) => {
      const start = from.get(feature.properties.id);
      if (!start || feature.geometry.type !== 'Point') return feature;
      const [x, y] = feature.geometry.coordinates;
      if (
        Math.abs(x - start[0]) > MAX_GLIDE_DEGREES ||
        Math.abs(y - start[1]) > MAX_GLIDE_DEGREES
      ) {
        return feature;
      }
      return {
        ...feature,
        geometry: {
          type: 'Point' as const,
          coordinates: [start[0] + (x - start[0]) * eased, start[1] + (y - start[1]) * eased],
        },
      };
    }),
  };
}
