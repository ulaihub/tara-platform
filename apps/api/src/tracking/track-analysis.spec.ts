import { describe, expect, it } from 'vitest';
import { currentStop, summarizeTrack, type TrackSample } from './track-analysis.js';

const start = new Date('2026-11-04T08:00:00.000Z');
/** Point à `seconds` du départ, décalé de `north` mètres vers le nord depuis Akwa. */
const at = (seconds: number, north = 0, extra: Partial<TrackSample> = {}): TrackSample => ({
  latitude: 4.05 + north / 111_320,
  longitude: 9.7,
  at: new Date(start.getTime() + seconds * 1000),
  ...extra,
});

describe('summarizeTrack', () => {
  it('compte la distance parcourue sans le bruit du GPS à l’arrêt', () => {
    const points = [
      at(0, 0),
      // Immobile : le GPS oscille de quelques mètres.
      at(10, 4),
      at(20, -3),
      at(30, 5),
      // Puis 600 m vers le nord, un point toutes les 10 s (≈ 20 km/h).
      ...Array.from({ length: 11 }, (_, i) => at(40 + i * 10, 5 + (i + 1) * 55)),
    ];
    const summary = summarizeTrack(points);
    expect(summary.distanceMeters).toBeGreaterThan(590);
    expect(summary.distanceMeters).toBeLessThan(620);
    expect(summary.pointCount).toBe(15);
  });

  it('ignore un saut de GPS impossible pour une moto', () => {
    const summary = summarizeTrack([at(0, 0), at(10, 3000), at(20, 30), at(30, 90)]);
    // Le saut de 3 km en 10 s est écarté ; seul le trajet réel compte.
    expect(summary.distanceMeters).toBeLessThan(120);
  });

  it('mesure la plus longue coupure, le plus long arrêt et les positions simulées', () => {
    const summary = summarizeTrack([
      at(0, 0),
      at(60, 10),
      at(900, 20),
      at(1500, 400, { mocked: true }),
      at(1510, 450),
    ]);
    expect(summary.longestGapSeconds).toBe(840);
    expect(summary.longestStopSeconds).toBe(900);
    expect(summary.mockedPoints).toBe(1);
    expect(summary.startedAt).toEqual(start);
  });

  it('trajet vide : rien à résumer', () => {
    expect(summarizeTrack([])).toMatchObject({ pointCount: 0, distanceMeters: 0, startedAt: null });
  });
});

describe('currentStop', () => {
  it('donne depuis quand le livreur reste au même endroit', () => {
    const stop = currentStop([at(0, -500), at(60, 0), at(600, 20), at(1200, 10)]);
    expect(stop?.seconds).toBe(1140);
    expect(stop?.since).toEqual(new Date(start.getTime() + 60_000));
  });

  it('aucun arrêt quand le livreur roule', () => {
    expect(currentStop([at(0, 0), at(10, 100), at(20, 200)])).toBeNull();
  });
});
