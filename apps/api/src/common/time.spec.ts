import { describe, expect, it } from 'vitest';
import { damageClaimDeadline } from './time.js';

const at = (local: string) => new Date(`${local}+01:00`).toISOString();

describe('délai pour signaler un colis abîmé', () => {
  it('7 jours après la livraison, dimanches et jours fériés non compris, plus 2 jours de marge', () => {
    // Livré le lundi 16 novembre 2026 : du mardi 17 au mardi 24 (dimanche 22 exclu), marge
    // jusqu'au jeudi 26 inclus.
    expect(damageClaimDeadline(new Date(at('2026-11-16T15:00:00'))).toISOString()).toBe(
      at('2026-11-27T00:00:00'),
    );
    // Livré le samedi 19 décembre à 23 h 30 : dimanches 20 et 27 et Noël (25) exclus ; le 7e
    // jour compté est le mardi 29, marge jusqu'au jeudi 31 inclus.
    expect(damageClaimDeadline(new Date(at('2026-12-19T23:30:00'))).toISOString()).toBe(
      at('2027-01-01T00:00:00'),
    );
  });
});
