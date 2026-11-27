import type { ActorRole, OrderStatus } from '../generated/prisma/enums.js';
import { checkTransition, ORDER_TRANSITIONS, TERMINAL_STATUSES } from './order-state-machine.js';

const STATUSES = Object.keys(ORDER_TRANSITIONS) as OrderStatus[];
const ACTORS: ActorRole[] = ['SENDER', 'RECIPIENT', 'RIDER', 'DISPATCHER', 'SUPPORT', 'SYSTEM'];

/** Transitions attendues, écrites indépendamment de la table pour la vérifier. */
const EXPECTED: [OrderStatus, OrderStatus][] = [
  ['CREATED', 'SEARCHING_RIDER'],
  ['CREATED', 'CANCELLED'],
  ['SEARCHING_RIDER', 'ASSIGNED'],
  ['SEARCHING_RIDER', 'CANCELLED'],
  ['ASSIGNED', 'PICKED_UP'],
  ['ASSIGNED', 'SEARCHING_RIDER'],
  ['ASSIGNED', 'CANCELLED'],
  ['PICKED_UP', 'IN_DELIVERY'],
  ['IN_DELIVERY', 'DELIVERED'],
  ['IN_DELIVERY', 'DELIVERY_FAILED'],
  ['DELIVERY_FAILED', 'IN_DELIVERY'],
  ['DELIVERY_FAILED', 'RETURNED'],
  ['DELIVERY_FAILED', 'HELD_AT_OFFICE'],
  ['HELD_AT_OFFICE', 'RETURNED'],
  ['HELD_AT_OFFICE', 'UNCLAIMED'],
];

const complete = { riderId: 'r', failureReason: 'RECIPIENT_ABSENT', note: 'motif' } as const;

describe('machine à états des commandes', () => {
  it('autorise exactement les transitions attendues', () => {
    const allowed: [OrderStatus, OrderStatus][] = [];
    for (const from of STATUSES) {
      for (const to of STATUSES) {
        if (ACTORS.some((actor) => checkTransition({ from, to, actor, ...complete }).ok))
          allowed.push([from, to]);
      }
    }
    const key = ([from, to]: [OrderStatus, OrderStatus]) => `${from}→${to}`;
    const sorted = (pairs: [OrderStatus, OrderStatus][]) =>
      pairs.map(key).sort((a, b) => a.localeCompare(b));
    expect(sorted(allowed)).toEqual(sorted(EXPECTED));
  });

  it('ne sort jamais d’un statut final', () => {
    for (const from of TERMINAL_STATUSES) {
      for (const to of STATUSES) {
        for (const actor of ACTORS) {
          expect(checkTransition({ from, to, actor, ...complete })).toEqual({
            ok: false,
            reason: 'INVALID',
          });
        }
      }
    }
  });

  it('ne laisse jamais le destinataire changer le statut', () => {
    for (const [from, to] of EXPECTED) {
      expect(checkTransition({ from, to, actor: 'RECIPIENT', ...complete }).ok).toBe(false);
    }
  });

  it('laisse l’expéditeur annuler avant l’enlèvement, jamais après', () => {
    for (const from of ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'] as const) {
      expect(checkTransition({ from, to: 'CANCELLED', actor: 'SENDER', note: 'erreur' }).ok).toBe(
        true,
      );
    }
    for (const from of ['PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'] as const) {
      expect(checkTransition({ from, to: 'CANCELLED', actor: 'SENDER', note: 'erreur' }).ok).toBe(
        false,
      );
    }
  });

  it('réserve l’enlèvement et la livraison au livreur et aux opérations', () => {
    expect(checkTransition({ from: 'ASSIGNED', to: 'PICKED_UP', actor: 'SENDER' })).toEqual({
      ok: false,
      reason: 'FORBIDDEN',
    });
    expect(checkTransition({ from: 'IN_DELIVERY', to: 'DELIVERED', actor: 'SYSTEM' })).toEqual({
      ok: false,
      reason: 'FORBIDDEN',
    });
    expect(checkTransition({ from: 'IN_DELIVERY', to: 'DELIVERED', actor: 'RIDER' }).ok).toBe(true);
  });

  it('exige les informations propres à chaque transition', () => {
    expect(checkTransition({ from: 'SEARCHING_RIDER', to: 'ASSIGNED', actor: 'SYSTEM' })).toEqual({
      ok: false,
      reason: 'RIDER_REQUIRED',
    });
    expect(checkTransition({ from: 'IN_DELIVERY', to: 'DELIVERY_FAILED', actor: 'RIDER' })).toEqual(
      {
        ok: false,
        reason: 'FAILURE_REASON_REQUIRED',
      },
    );
    expect(
      checkTransition({ from: 'CREATED', to: 'CANCELLED', actor: 'SENDER', note: '  ' }),
    ).toEqual({
      ok: false,
      reason: 'NOTE_REQUIRED',
    });
  });
});
