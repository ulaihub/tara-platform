import { describe, expect, it } from 'vitest';
import type { GeoPoint } from '../routing/distance.service.js';
import { RoadSnapCache, type TimedPosition } from './road-snap-cache.js';

const at = new Date('2026-11-13T08:00:00Z');
const point = (latitude: number, when = at): TimedPosition => ({
  latitude,
  longitude: 9.7,
  at: when,
});
const onRoad = (p: GeoPoint): GeoPoint => ({ latitude: p.latitude + 0.0001, longitude: 9.7 });
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

describe('RoadSnapCache', () => {
  it('recale chaque nouvelle position une seule fois, puis la sert depuis le cache', async () => {
    let calls = 0;
    const cache = new RoadSnapCache(
      (p) => {
        calls += 1;
        return Promise.resolve(onRoad(p));
      },
      200,
      4,
    );
    const positions = new Map([
      ['a', point(4.05)],
      ['b', point(4.06)],
    ]);
    expect((await cache.positions(positions)).get('a')).toEqual({
      latitude: 4.0501,
      longitude: 9.7,
    });
    expect(calls).toBe(2);
    await cache.positions(positions);
    expect(calls).toBe(2);
    // Nouvelle position de « a » seulement.
    positions.set('a', point(4.07, new Date(at.getTime() + 10_000)));
    expect((await cache.positions(positions)).get('a')).toEqual({
      latitude: 4.0701,
      longitude: 9.7,
    });
    expect(calls).toBe(3);
  });

  it('répond dans le temps imparti et finit le recalage en arrière-plan', async () => {
    let calls = 0;
    const cache = new RoadSnapCache(
      async (p) => {
        calls += 1;
        await wait(60);
        return onRoad(p);
      },
      30,
      2,
    );
    const positions = new Map([
      ['a', point(4.05)],
      ['b', point(4.06)],
      ['c', point(4.07)],
    ]);
    const started = Date.now();
    const first = await cache.positions(positions);
    expect(Date.now() - started).toBeLessThan(55);
    expect(first.size).toBe(0); // Le back-office prend la position GPS.

    // Rafraîchissement pendant le recalage : rien n'est redemandé à OSRM.
    await cache.positions(positions);
    expect(calls).toBe(2);

    await wait(150);
    const later = await cache.positions(positions);
    expect(later.size).toBe(3);
    expect(calls).toBe(3);
  });

  it('oublie les livreurs qui ne sont plus sur la carte', async () => {
    let calls = 0;
    const cache = new RoadSnapCache(
      (p) => {
        calls += 1;
        return Promise.resolve(onRoad(p));
      },
      200,
      2,
    );
    await cache.positions(new Map([['a', point(4.05)]]));
    await cache.positions(new Map());
    await cache.positions(new Map([['a', point(4.05)]]));
    expect(calls).toBe(2);
  });
});
