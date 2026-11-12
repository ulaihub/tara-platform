import { describe, expect, it } from 'vitest';
import {
  describeGrid,
  editableGridOf,
  gridProblem,
  km,
  percent,
  simpleGridOf,
  tiersFor,
} from '../src/lib/merchants';

const VALIDATED = {
  startPrice: 1000,
  startKm: 5,
  stepPrice: 100,
  untilKm: 10,
  beyondPerKm: 50,
  riderSharePercent: 70,
};

describe('Marchands et tarifs (H4)', () => {
  it('écrit les pourcentages et distances à la française', () => {
    expect(percent(1000)).toBe('10 %');
    expect(percent(1250)).toBe('12,5 %');
    expect(km(16_800)).toBe('16,8 km');
    expect(km(5000)).toBe('5 km');
  });

  it('traduit la grille validée en paliers d’un km, et la relit', () => {
    const tiers = tiersFor(VALIDATED);
    expect(tiers).toEqual([
      { upToMeters: 5000, price: 1000 },
      { upToMeters: 6000, price: 1100 },
      { upToMeters: 7000, price: 1200 },
      { upToMeters: 8000, price: 1300 },
      { upToMeters: 9000, price: 1400 },
      { upToMeters: 10_000, price: 1500 },
    ]);
    expect(simpleGridOf({ tiers, perKmBeyondLastTier: 50, riderShareBps: 7000 })).toEqual(
      VALIDATED,
    );
    expect(describeGrid(VALIDATED)).toBe(
      '1 000 F jusqu’à 5 km, +100 F par km jusqu’à 10 km, puis +50 F par km.',
    );
  });

  it('reconnaît une grille d’une autre forme', () => {
    expect(
      simpleGridOf({
        tiers: [
          { upToMeters: 5000, price: 1000 },
          { upToMeters: 10_000, price: 1500 },
        ],
        perKmBeyondLastTier: 150,
        riderShareBps: 8000,
      }),
    ).toBeNull();
  });

  it('refuse une grille incohérente avant de l’envoyer', () => {
    expect(gridProblem(VALIDATED)).toBeNull();
    expect(gridProblem({ ...VALIDATED, beyondPerKm: 75 })).toContain('50 F en 50 F');
    expect(gridProblem({ ...VALIDATED, riderSharePercent: 40 })).toContain('part du livreur');
    expect(gridProblem({ ...VALIDATED, untilKm: 3 })).toContain('seconde distance');
  });

  it('propose une grille tricycle équivalente aux mêmes distances', () => {
    const tricycle = {
      tiers: [
        { upToMeters: 5000, price: 3000 },
        { upToMeters: 10_000, price: 4500 },
        { upToMeters: 15_000, price: 6000 },
      ],
      perKmBeyondLastTier: 300,
      riderShareBps: 7000,
    };
    const grid = editableGridOf(tricycle);
    expect(grid).toEqual({
      startPrice: 3000,
      startKm: 5,
      stepPrice: 300,
      untilKm: 10,
      beyondPerKm: 300,
      riderSharePercent: 70,
    });
    // Même prix à 10 et 15 km qu'avant.
    expect(tiersFor(grid).at(-1)).toEqual({ upToMeters: 10_000, price: 4500 });
  });
});
