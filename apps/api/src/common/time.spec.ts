import { describe, expect, it } from 'vitest';
import { damageClaimDeadline } from './time.js';

describe('délai pour signaler un colis abîmé', () => {
  it('7 jours après la livraison, dimanches non compris, jusqu’à minuit au Cameroun', () => {
    // Livré le lundi 16 novembre 2026 à 15 h (Douala) : du mardi 17 au mardi 24, le dimanche 22
    // ne compte pas ; le délai court jusqu'au mardi 24 inclus.
    expect(damageClaimDeadline(new Date('2026-11-16T15:00:00+01:00')).toISOString()).toBe(
      new Date('2026-11-25T00:00:00+01:00').toISOString(),
    );
    // Livré le samedi 21 novembre à 23 h 30 : le dimanche 22 ne compte pas → dimanche 29 sauté,
    // le 7e jour compté est le lundi 30 ; fin du délai le 1er décembre à minuit.
    expect(damageClaimDeadline(new Date('2026-11-21T23:30:00+01:00')).toISOString()).toBe(
      new Date('2026-12-01T00:00:00+01:00').toISOString(),
    );
  });
});
