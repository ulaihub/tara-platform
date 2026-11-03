import type { ActorRole, FailureReason, OrderStatus } from '../generated/prisma/enums.js';

/**
 * Machine à états des commandes : pour chaque statut, les statuts atteignables et les
 * acteurs autorisés à y faire passer la commande. Toute transition passe par ici.
 *
 *   CREATED ─► SEARCHING_RIDER ─► ASSIGNED ─► PICKED_UP ─► IN_DELIVERY ─► DELIVERED
 *      │              │              │  ▲                       │   ▲
 *      ▼              ▼              ▼  └── réattribution       ▼   │ nouvelle tentative
 *   CANCELLED      CANCELLED      CANCELLED            DELIVERY_FAILED ─► RETURNED
 */
export const ORDER_TRANSITIONS: Record<OrderStatus, Partial<Record<OrderStatus, ActorRole[]>>> = {
  CREATED: {
    SEARCHING_RIDER: ['SYSTEM', 'DISPATCHER'],
    CANCELLED: ['SENDER', 'DISPATCHER', 'SUPPORT', 'SYSTEM'],
  },
  SEARCHING_RIDER: {
    // RIDER : le livreur accepte une proposition (D2).
    ASSIGNED: ['SYSTEM', 'DISPATCHER', 'RIDER'],
    CANCELLED: ['SENDER', 'DISPATCHER', 'SUPPORT', 'SYSTEM'],
  },
  ASSIGNED: {
    PICKED_UP: ['RIDER', 'DISPATCHER'],
    SEARCHING_RIDER: ['RIDER', 'DISPATCHER', 'SYSTEM'],
    CANCELLED: ['SENDER', 'DISPATCHER', 'SUPPORT'],
  },
  PICKED_UP: {
    IN_DELIVERY: ['RIDER', 'DISPATCHER', 'SYSTEM'],
  },
  IN_DELIVERY: {
    DELIVERED: ['RIDER', 'DISPATCHER', 'SUPPORT'],
    DELIVERY_FAILED: ['RIDER', 'DISPATCHER'],
  },
  DELIVERY_FAILED: {
    IN_DELIVERY: ['RIDER', 'DISPATCHER'],
    RETURNED: ['RIDER', 'DISPATCHER', 'SUPPORT'],
  },
  DELIVERED: {},
  RETURNED: {},
  CANCELLED: {},
};

export const TERMINAL_STATUSES: OrderStatus[] = ['DELIVERED', 'RETURNED', 'CANCELLED'];

/** Statuts où l'expéditeur peut encore modifier ou annuler : le colis n'est pas enlevé. */
export const BEFORE_PICKUP: OrderStatus[] = ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'];

export interface TransitionCheck {
  from: OrderStatus;
  to: OrderStatus;
  actor: ActorRole;
  riderId?: string | null | undefined;
  failureReason?: FailureReason | null | undefined;
  note?: string | null | undefined;
}

export type TransitionVerdict =
  | { ok: true }
  | {
      ok: false;
      reason:
        'INVALID' | 'FORBIDDEN' | 'RIDER_REQUIRED' | 'FAILURE_REASON_REQUIRED' | 'NOTE_REQUIRED';
    };

export function checkTransition(input: TransitionCheck): TransitionVerdict {
  const actors = ORDER_TRANSITIONS[input.from][input.to];
  if (!actors) return { ok: false, reason: 'INVALID' };
  if (!actors.includes(input.actor)) return { ok: false, reason: 'FORBIDDEN' };
  if (input.to === 'ASSIGNED' && !input.riderId) return { ok: false, reason: 'RIDER_REQUIRED' };
  if (input.to === 'DELIVERY_FAILED' && !input.failureReason) {
    return { ok: false, reason: 'FAILURE_REASON_REQUIRED' };
  }
  if (input.to === 'CANCELLED' && !input.note?.trim())
    return { ok: false, reason: 'NOTE_REQUIRED' };
  return { ok: true };
}
