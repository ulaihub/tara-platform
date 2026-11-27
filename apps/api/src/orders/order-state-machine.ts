import type { ActorRole, FailureReason, OrderStatus } from '../generated/prisma/enums.js';

/**
 * Machine à états des commandes : pour chaque statut, les statuts atteignables et les
 * acteurs autorisés à y faire passer la commande. Toute transition passe par ici.
 *
 *   CREATED ─► SEARCHING_RIDER ─► ASSIGNED ─► PICKED_UP ─► IN_DELIVERY ─► DELIVERED
 *      │              │              │  ▲                       │   ▲
 *      ▼              ▼              ▼  └── réattribution       ▼   │ nouvelle tentative
 *   CANCELLED      CANCELLED      CANCELLED            DELIVERY_FAILED ─► RETURNED
 *                                                             │              ▲
 *                     retour non payé : bureau Tara           ▼              │ payé, rendu
 *                                                       HELD_AT_OFFICE ──────┘
 *                                                             │ jamais réclamé (garde finie)
 *                                                             ▼
 *                                                         UNCLAIMED
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
    // RIDER : colis refusé à l'enlèvement, non conforme à la commande (photo à l'appui).
    CANCELLED: ['SENDER', 'DISPATCHER', 'SUPPORT', 'RIDER'],
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
    // Retour non payé : le livreur dépose le colis au bureau Tara (photo).
    HELD_AT_OFFICE: ['RIDER', 'DISPATCHER', 'SUPPORT'],
  },
  // Au bureau : l'équipe rend le colis payé, ou constate qu'il n'a pas été réclamé.
  HELD_AT_OFFICE: {
    RETURNED: ['DISPATCHER', 'SUPPORT'],
    UNCLAIMED: ['DISPATCHER', 'SUPPORT'],
  },
  DELIVERED: {},
  RETURNED: {},
  CANCELLED: {},
  UNCLAIMED: {},
};

export const TERMINAL_STATUSES: OrderStatus[] = ['DELIVERED', 'RETURNED', 'CANCELLED', 'UNCLAIMED'];

/** Course finie pour le livreur : livrée, rendue, annulée, ou colis déposé au bureau Tara. */
export const RIDER_DONE_STATUSES: OrderStatus[] = [...TERMINAL_STATUSES, 'HELD_AT_OFFICE'];

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
