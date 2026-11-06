import { describe, expect, it } from 'vitest';
import { expectedDeliveryMinutes, type LatenessInput, lateness } from './lateness.js';

const rules = { searchingSeconds: 300, pickupMinutes: 25, deliveryMarginMinutes: 15 };
const at = (minutes: number) => new Date(Date.UTC(2026, 10, 6, 9, 0) + minutes * 60_000);

const order = (overrides: Partial<LatenessInput>): LatenessInput => ({
  status: 'SEARCHING_RIDER',
  distanceMeters: 6_000,
  createdAt: at(0),
  searchingSince: at(0),
  assignedAt: null,
  pickedUpAt: null,
  failedAt: null,
  ...overrides,
});

describe('retards des commandes en cours (H1)', () => {
  it('signale une recherche de livreur au-delà de 5 minutes', () => {
    expect(lateness(order({}), rules, at(5))).toBeNull();
    expect(lateness(order({}), rules, at(7.5))).toEqual({
      kind: 'NO_RIDER',
      dueAt: at(5),
      minutes: 2,
    });
  });

  it('compte depuis la création sans heure de recherche', () => {
    expect(
      lateness(order({ searchingSince: null, createdAt: at(-10) }), rules, at(0))?.minutes,
    ).toBe(5);
  });

  it('attend le livreur chez le vendeur 25 minutes après l’attribution', () => {
    const assigned = order({ status: 'ASSIGNED', assignedAt: at(10) });
    expect(lateness(assigned, rules, at(35))).toBeNull();
    expect(lateness(assigned, rules, at(40))).toEqual({
      kind: 'PICKUP',
      dueAt: at(35),
      minutes: 5,
    });
  });

  it('laisse le trajet estimé plus 15 minutes pour livrer', () => {
    expect(expectedDeliveryMinutes(6_000, 15)).toBe(35);
    expect(expectedDeliveryMinutes(6_100, 15)).toBe(36);
    const enRoute = order({ status: 'IN_DELIVERY', assignedAt: at(5), pickedUpAt: at(20) });
    expect(lateness(enRoute, rules, at(55))).toBeNull();
    expect(lateness(enRoute, rules, at(61))).toEqual({
      kind: 'DELIVERY',
      dueAt: at(55),
      minutes: 6,
    });
    expect(lateness({ ...enRoute, status: 'PICKED_UP' }, rules, at(61))?.kind).toBe('DELIVERY');
  });

  it('repart de l’échec pour une nouvelle tentative', () => {
    const retry = order({ status: 'IN_DELIVERY', pickedUpAt: at(0), failedAt: at(60) });
    expect(lateness(retry, rules, at(90))).toBeNull();
    expect(lateness(retry, rules, at(100))?.minutes).toBe(5);
  });

  it.each(['CREATED', 'DELIVERY_FAILED', 'DELIVERED', 'RETURNED', 'CANCELLED'] as const)(
    'ne signale rien pour une commande %s',
    (status) => {
      expect(
        lateness(order({ status, assignedAt: at(0), pickedUpAt: at(0) }), rules, at(500)),
      ).toBeNull();
    },
  );
});
