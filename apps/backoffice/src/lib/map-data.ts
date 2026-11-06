import darkStyle from '@tara-map/tara-dark.json';
import lightStyle from '@tara-map/tara-light.json';
import type { StyleSpecification } from 'maplibre-gl';
import { firstName } from './format';
import { nextStop, type Point } from './live';
import type { LiveMap } from './schemas';

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
    features: map.riders.flatMap((rider) =>
      rider.position
        ? [
            point(rider.position.longitude, rider.position.latitude, {
              id: rider.id,
              state: rider.state,
              signalLost: rider.signalLost,
              label: firstName(rider.name, rider.phone),
              selected: selectedRiders.has(rider.id),
            }),
          ]
        : [],
    ),
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

/** Commande choisie : vendeur, client et trait du livreur jusqu'au prochain arrêt. */
export function selectedOrderData(
  map: LiveMap,
  selection: Selection,
): {
  stops: Collection<{ kind: string; label: string }>;
  route: Collection<{ estimate: boolean }>;
} {
  const empty = { type: 'FeatureCollection' as const, features: [] };
  const order =
    selection?.type === 'order' ? map.orders.find((item) => item.id === selection.id) : undefined;
  if (!order) return { stops: empty, route: empty };
  const stops = {
    type: 'FeatureCollection' as const,
    features: [
      point(order.pickup.longitude, order.pickup.latitude, { kind: 'pickup', label: 'Vendeur' }),
      point(order.dropoff.longitude, order.dropoff.latitude, { kind: 'dropoff', label: 'Client' }),
    ],
  };
  const rider = map.riders.find((item) => item.id === order.riderId);
  const target = order[nextStop(order)];
  const route: Collection<{ estimate: boolean }> =
    rider?.position && order.status !== 'DELIVERY_FAILED'
      ? {
          type: 'FeatureCollection',
          features: [
            {
              type: 'Feature',
              geometry: {
                type: 'LineString',
                coordinates: [
                  [rider.position.longitude, rider.position.latitude],
                  [target.longitude, target.latitude],
                ],
              },
              properties: { estimate: true },
            },
          ],
        }
      : empty;
  return { stops, route };
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
    return at(map.riders.find((rider) => rider.id === selection.id)?.position);
  }
  if (selection.type === 'sos') {
    return at(map.safetyAlerts.find((alert) => alert.id === selection.id));
  }
  const order = map.orders.find((item) => item.id === selection.id);
  if (!order) return [];
  const rider = map.riders.find((item) => item.id === order.riderId);
  return [...at(order[nextStop(order)]), ...at(rider?.position)];
}
