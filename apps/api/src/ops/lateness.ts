import type { OrderStatus } from '../generated/prisma/enums.js';

/** Vitesse prudente d'une moto dans Douala (même valeur que l'app expéditeur). */
export const METERS_PER_MINUTE = 300;

export interface LatenessRules {
  /** Recherche de livreur sans succès au-delà de ce délai (alerte de dispatch, D2). */
  searchingSeconds: number;
  /** Livreur attribué mais colis pas encore récupéré au-delà de ce délai. */
  pickupMinutes: number;
  /** Marge ajoutée au trajet estimé entre l'enlèvement et la livraison. */
  deliveryMarginMinutes: number;
}

export interface LatenessInput {
  status: OrderStatus;
  distanceMeters: number;
  createdAt: Date;
  searchingSince: Date | null;
  assignedAt: Date | null;
  pickedUpAt: Date | null;
  failedAt: Date | null;
}

export type DelayKind = 'NO_RIDER' | 'PICKUP' | 'DELIVERY';

export interface Delay {
  kind: DelayKind;
  /** Heure à laquelle l'étape aurait dû être franchie. */
  dueAt: Date;
  /** Minutes de retard, arrondies vers le bas (0 pendant la première minute). */
  minutes: number;
}

const MINUTE = 60_000;

/** Durée attendue de la livraison après l'enlèvement, en minutes. */
export function expectedDeliveryMinutes(distanceMeters: number, marginMinutes: number): number {
  return Math.ceil(distanceMeters / METERS_PER_MINUTE) + marginMinutes;
}

/**
 * Retard d'une commande en cours (H1) : pas de livreur trouvé, livreur pas encore chez le
 * vendeur, colis pas encore livré. Null à l'heure, ou pour une commande qui n'est pas en
 * route (créée, terminée, en attente de décision après un échec).
 */
export function lateness(order: LatenessInput, rules: LatenessRules, now: Date): Delay | null {
  const due = (kind: DelayKind, start: Date | null, minutes: number): Delay | null => {
    if (!start) return null;
    const dueAt = new Date(start.getTime() + minutes * MINUTE);
    if (now.getTime() <= dueAt.getTime()) return null;
    return { kind, dueAt, minutes: Math.floor((now.getTime() - dueAt.getTime()) / MINUTE) };
  };
  switch (order.status) {
    case 'SEARCHING_RIDER':
      return due('NO_RIDER', order.searchingSince ?? order.createdAt, rules.searchingSeconds / 60);
    case 'ASSIGNED':
      return due('PICKUP', order.assignedAt, rules.pickupMinutes);
    case 'PICKED_UP':
    case 'IN_DELIVERY': {
      // Nouvelle tentative après un échec : le compte repart de l'échec.
      const start =
        order.failedAt && order.pickedUpAt && order.failedAt > order.pickedUpAt
          ? order.failedAt
          : order.pickedUpAt;
      return due(
        'DELIVERY',
        start,
        expectedDeliveryMinutes(order.distanceMeters, rules.deliveryMarginMinutes),
      );
    }
    default:
      return null;
  }
}
