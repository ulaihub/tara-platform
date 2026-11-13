import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Env } from '../config/env.js';
import { MAX_MATCH_POINTS, RoadService, sample } from './road.service.js';

const service = (osrmUrl?: string) => new RoadService({ OSRM_URL: osrmUrl } as unknown as Env);
const reply = (body: unknown, status = 200) =>
  Promise.resolve(new Response(JSON.stringify(body), { status }));

describe('RoadService', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('pose la position sur la rue la plus proche', async () => {
    const calls: string[] = [];
    vi.stubGlobal('fetch', (url: string) => {
      calls.push(url);
      return reply({
        code: 'Ok',
        waypoints: [{ location: [9.70012345, 4.05054321], distance: 12.4 }],
      });
    });
    const road = await service('http://osrm.local/').snap({ latitude: 4.0506, longitude: 9.7002 });
    expect(calls[0]).toBe('http://osrm.local/nearest/v1/driving/9.7002,4.0506?number=1');
    expect(road).toEqual({ latitude: 4.050543, longitude: 9.700123 });
  });

  it('laisse la position telle quelle loin de toute rue ou sans OSRM', async () => {
    vi.stubGlobal('fetch', () =>
      reply({ code: 'Ok', waypoints: [{ location: [9.7, 4.05], distance: 85 }] }),
    );
    expect(await service('http://osrm.local').snap({ latitude: 4.05, longitude: 9.7 })).toBeNull();
    expect(await service(undefined).snap({ latitude: 4.05, longitude: 9.7 })).toBeNull();
    vi.stubGlobal('fetch', () => Promise.reject(new Error('ECONNREFUSED')));
    expect(await service('http://osrm.local').snap({ latitude: 4.05, longitude: 9.7 })).toBeNull();
  });

  it('recale un trajet sur les rues avec horodatages croissants et précision', async () => {
    const calls: string[] = [];
    vi.stubGlobal('fetch', (url: string) => {
      calls.push(url);
      return reply({
        code: 'Ok',
        matchings: [
          {
            geometry: {
              coordinates: [
                [9.7, 4.05],
                [9.701, 4.051],
              ],
            },
          },
          { geometry: { coordinates: [[9.702, 4.052]] } },
        ],
      });
    });
    const at = new Date('2026-11-06T10:00:00Z');
    const path = await service('http://osrm.local').match([
      { latitude: 4.05, longitude: 9.7, at, accuracy: 8 },
      { latitude: 4.051, longitude: 9.701, at, accuracy: 120 },
      { latitude: 4.052, longitude: 9.702, at: new Date(at.getTime() + 15_000) },
    ]);
    expect(path).toEqual([
      [9.7, 4.05],
      [9.701, 4.051],
      [9.702, 4.052],
    ]);
    const url = new URL(calls[0] ?? '');
    expect(url.pathname).toBe('/match/v1/driving/9.7,4.05;9.701,4.051;9.702,4.052');
    const start = at.getTime() / 1000;
    expect(url.searchParams.get('timestamps')).toBe(`${start};${start + 1};${start + 15}`);
    expect(url.searchParams.get('radiuses')).toBe('25;60;25');
    expect(url.searchParams.get('overview')).toBe('full');
  });

  it('ne recale rien sans au moins deux points ou si OSRM refuse', async () => {
    vi.stubGlobal('fetch', () => reply({ code: 'NoMatch' }));
    const at = new Date();
    expect(
      await service('http://osrm.local').match([{ latitude: 4, longitude: 9, at }]),
    ).toBeNull();
    expect(
      await service('http://osrm.local').match([
        { latitude: 4, longitude: 9, at },
        { latitude: 4.001, longitude: 9, at },
      ]),
    ).toBeNull();
  });

  it('échantillonne les longs trajets en gardant le départ et l’arrivée', () => {
    const points = Array.from({ length: 450 }, (_, index) => index);
    const kept = sample(points, MAX_MATCH_POINTS);
    expect(kept).toHaveLength(MAX_MATCH_POINTS);
    expect(kept[0]).toBe(0);
    expect(kept.at(-1)).toBe(449);
    expect(sample([1, 2, 3], 10)).toEqual([1, 2, 3]);
  });
});
