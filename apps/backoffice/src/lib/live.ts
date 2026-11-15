import { ago, duration, firstName } from './format';
import type { CourseAlert, LiveMap, LiveOrder, LiveRider, OrderStatus } from './schemas';

/** Rafraîchissement de la carte en direct. */
export const REFRESH_MS = 5_000;

export const STATUS_LABELS: Record<OrderStatus, string> = {
  CREATED: 'Programmée',
  SEARCHING_RIDER: 'Recherche de livreur',
  ASSIGNED: 'Livreur en route vers le vendeur',
  PICKED_UP: 'Colis récupéré',
  IN_DELIVERY: 'En livraison',
  DELIVERED: 'Livrée',
  DELIVERY_FAILED: 'Échec de livraison',
  RETURNED: 'Retournée',
  CANCELLED: 'Annulée',
};

export const RIDER_STATE_LABELS: Record<LiveRider['state'], string> = {
  FREE: 'Libre',
  ON_COURSE: 'En course',
  OFFLINE: 'Hors ligne',
};

export const COURSE_ALERT_LABELS: Record<CourseAlert['kind'], string> = {
  ACTION_FAR: 'action validée loin de l’adresse',
  LONG_STOP: 'arrêt prolongé avec le colis',
  MOCK_LOCATION: 'position falsifiée',
  TRACK_GAP: 'plus de position pendant la course',
  APPROACH_BONUS: 'prime d’approche sans trajet correspondant',
  OVERDUE: 'livraison bien plus longue que prévu',
  MOVING_AWAY: 's’éloigne de la destination avec le colis',
};

export interface Point {
  latitude: number;
  longitude: number;
}

/** Prochain arrêt de la commande : chez le vendeur tant que le colis n'est pas récupéré. */
export function nextStop(order: LiveOrder): 'pickup' | 'dropoff' {
  return order.status === 'CREATED' ||
    order.status === 'SEARCHING_RIDER' ||
    order.status === 'ASSIGNED'
    ? 'pickup'
    : 'dropoff';
}

export function place(stop: LiveOrder['pickup']): string {
  return stop.neighborhood ? `${stop.neighborhood} · ${stop.landmark}` : stop.landmark;
}

/** Retard en quelques mots : « depuis 12 min » sans livreur, « +9 min » sinon. */
export function delayText(order: LiveOrder, rules: LiveMap['rules']): string | null {
  if (!order.delay) return null;
  if (order.delay.kind === 'NO_RIDER') {
    return `depuis ${duration(Math.round(rules.searchingMinutes) + order.delay.minutes)}`;
  }
  return `+${duration(order.delay.minutes)}`;
}

export type AlertLevel = 'critical' | 'high' | 'normal';

export interface AlertItem {
  key: string;
  level: AlertLevel;
  title: string;
  detail: string;
  /** Heure de référence (début du problème), pour le tri. */
  at: string;
  orderId?: string;
  riderId?: string;
  /** Alerte de sécurité : identifiant et prise en charge. */
  safety?: { id: string; acknowledged: boolean; cancelled: boolean; policeCalled: boolean };
  position?: Point;
}

const LEVEL_ORDER: Record<AlertLevel, number> = { critical: 0, high: 1, normal: 2 };

/**
 * Ce qui demande l'attention de l'équipe, du plus grave au moins grave, puis du plus
 * ancien au plus récent : SOS, commandes sans livreur ou en retard, livreur en course
 * injoignable, validations et décisions attendues, alertes de trajet.
 */
export function alertsOf(map: LiveMap, now: number): AlertItem[] {
  const riders = new Map(map.riders.map((rider) => [rider.id, rider]));
  const orders = new Map(map.orders.map((order) => [order.id, order]));
  const riderName = (id: string | null | undefined) => {
    const rider = id ? riders.get(id) : undefined;
    return rider ? firstName(rider.name, rider.phone) : 'livreur';
  };
  const items: AlertItem[] = [];

  for (const alert of map.safetyAlerts) {
    const name = alert.riderName ?? riderName(alert.riderId);
    const where = alert.neighborhood ?? 'position sur la carte';
    const state = alert.cancelledAt
      ? 'annulée par le livreur, à rappeler'
      : alert.policeCalledAt
        ? 'police appelée'
        : alert.acknowledgedAt
          ? 'prise en charge'
          : 'à prendre en charge';
    items.push({
      key: `sos:${alert.id}`,
      level: 'critical',
      title: `SOS · ${name}`,
      detail: `${where} · ${ago(alert.createdAt, now)} · ${state}`,
      at: alert.createdAt,
      riderId: alert.riderId,
      ...(alert.orderId ? { orderId: alert.orderId } : {}),
      safety: {
        id: alert.id,
        acknowledged: alert.acknowledgedAt !== null,
        cancelled: alert.cancelledAt !== null,
        policeCalled: alert.policeCalledAt !== null,
      },
      position: { latitude: alert.latitude, longitude: alert.longitude },
    });
  }

  for (const order of map.orders) {
    const stop = order[nextStop(order)];
    const position = { latitude: stop.latitude, longitude: stop.longitude };
    const base = {
      orderId: order.id,
      position,
      ...(order.riderId ? { riderId: order.riderId } : {}),
    };
    if (order.delay?.kind === 'NO_RIDER') {
      const since = delayText(order, map.rules) ?? '';
      items.push({
        key: `late:${order.id}`,
        level: 'high',
        title: `${order.reference} sans livreur`,
        detail: `${since.charAt(0).toUpperCase()}${since.slice(1)} · ${place(order.pickup)}`,
        at: order.delay.dueAt,
        ...base,
      });
    } else if (order.delay) {
      const what = order.delay.kind === 'PICKUP' ? 'enlèvement' : 'livraison';
      items.push({
        key: `late:${order.id}`,
        level: 'high',
        title: `${order.reference} : ${what} en retard`,
        detail: `${duration(order.delay.minutes)} de retard · ${riderName(order.riderId)} → ${place(stop)}`,
        at: order.delay.dueAt,
        ...base,
      });
    }
    if (order.awaitingValidation) {
      items.push({
        key: `validation:${order.id}`,
        level: 'normal',
        title: `${order.reference} : remise sans code à valider`,
        detail: `${riderName(order.riderId)} attend la validation du support`,
        at: order.pickedUpAt ?? order.createdAt,
        ...base,
      });
    }
    if (order.awaitingDecision) {
      items.push({
        key: `decision:${order.id}`,
        level: 'normal',
        title: `${order.reference} : échec de livraison`,
        detail: 'Choix de l’expéditeur attendu : nouvelle tentative ou retour',
        at: order.pickedUpAt ?? order.createdAt,
        ...base,
      });
    }
  }

  for (const rider of map.riders) {
    if (rider.state !== 'ON_COURSE' || !rider.signalLost) continue;
    items.push({
      key: `signal:${rider.id}`,
      level: 'high',
      title: `${firstName(rider.name, rider.phone)} ne répond plus`,
      detail: rider.position
        ? `En course · dernière position ${ago(rider.position.at, now)}`
        : 'En course · aucune position reçue',
      at: rider.position?.at ?? map.generatedAt,
      riderId: rider.id,
      ...(rider.position
        ? { position: { latitude: rider.position.latitude, longitude: rider.position.longitude } }
        : {}),
    });
  }

  for (const alert of map.courseAlerts) {
    const order = orders.get(alert.orderId);
    const rider = riders.get(alert.riderId);
    items.push({
      key: `course:${alert.id}`,
      level: alert.kind === 'MOCK_LOCATION' ? 'high' : 'normal',
      title: `${alert.reference} : ${COURSE_ALERT_LABELS[alert.kind]}`,
      detail: `${riderName(alert.riderId)} · ${ago(alert.createdAt, now)}`,
      at: alert.createdAt,
      orderId: alert.orderId,
      riderId: alert.riderId,
      ...(rider?.position
        ? { position: { latitude: rider.position.latitude, longitude: rider.position.longitude } }
        : order
          ? { position: { latitude: order.dropoff.latitude, longitude: order.dropoff.longitude } }
          : {}),
    });
  }

  return items.sort(
    (a, b) => LEVEL_ORDER[a.level] - LEVEL_ORDER[b.level] || a.at.localeCompare(b.at),
  );
}

export interface Counts {
  free: number;
  onCourse: number;
  offline: number;
  orders: number;
  searching: number;
  late: number;
}

export function countsOf(map: LiveMap): Counts {
  return {
    free: map.riders.filter((rider) => rider.state === 'FREE').length,
    onCourse: map.riders.filter((rider) => rider.state === 'ON_COURSE').length,
    offline: map.riders.filter((rider) => rider.state === 'OFFLINE').length,
    orders: map.orders.length,
    searching: map.orders.filter((order) => order.status === 'SEARCHING_RIDER').length,
    late: map.orders.filter((order) => order.delay !== null).length,
  };
}
