import { describe, expect, it } from 'vitest';
import { targetOf } from './rider-trail.service.js';

describe('prochain arrêt d’une course', () => {
  it('va chez le vendeur, puis chez le client', () => {
    expect(targetOf({ status: 'ASSIGNED', failureDecision: null })).toBe('pickup');
    expect(targetOf({ status: 'PICKED_UP', failureDecision: null })).toBe('dropoff');
    expect(targetOf({ status: 'IN_DELIVERY', failureDecision: null })).toBe('dropoff');
  });

  it('après un échec, suit la décision de l’expéditeur', () => {
    expect(targetOf({ status: 'DELIVERY_FAILED', failureDecision: null })).toBeNull();
    expect(targetOf({ status: 'DELIVERY_FAILED', failureDecision: 'RETRY' })).toBe('dropoff');
    expect(targetOf({ status: 'DELIVERY_FAILED', failureDecision: 'RETURN' })).toBe('pickup');
  });

  it('ne vise rien pour une course terminée', () => {
    expect(targetOf({ status: 'DELIVERED', failureDecision: null })).toBeNull();
  });
});
