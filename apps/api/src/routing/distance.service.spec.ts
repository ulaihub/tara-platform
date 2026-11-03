import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Env } from '../config/env.js';
import { DistanceService, ROAD_DETOUR_FACTOR, haversineMeters } from './distance.service.js';

const akwa = { latitude: 4.0511, longitude: 9.6942 };
const bonapriso = { latitude: 4.0283, longitude: 9.6957 };

const service = (osrmUrl?: string) => new DistanceService({ OSRM_URL: osrmUrl } as unknown as Env);

describe('DistanceService.path', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renvoie le tracé routier simplifié d’OSRM, en [longitude, latitude]', async () => {
    const calls: string[] = [];
    vi.stubGlobal('fetch', (url: string) => {
      calls.push(url);
      return Promise.resolve(
        new Response(
          JSON.stringify({
            code: 'Ok',
            routes: [
              {
                distance: 3120.4,
                duration: 612.6,
                geometry: {
                  type: 'LineString',
                  coordinates: [
                    [9.69420012345, 4.0511],
                    [9.6951, 4.04],
                    [9.6957, 4.0283],
                  ],
                },
              },
            ],
          }),
          { status: 200 },
        ),
      );
    });

    const route = await service('http://osrm.local/').path(akwa, bonapriso);

    expect(calls[0]).toBe(
      'http://osrm.local/route/v1/driving/9.6942,4.0511;9.6957,4.0283?overview=simplified&geometries=geojson',
    );
    expect(route).toEqual({
      meters: 3120,
      seconds: 613,
      source: 'osrm',
      path: [
        [9.6942, 4.0511],
        [9.6951, 4.04],
        [9.6957, 4.0283],
      ],
    });
  });

  it('se replie sur une ligne droite estimée si OSRM échoue', async () => {
    vi.stubGlobal('fetch', () => Promise.resolve(new Response('indisponible', { status: 503 })));

    const route = await service('http://osrm.local').path(akwa, bonapriso);

    const meters = Math.round(haversineMeters(akwa, bonapriso) * ROAD_DETOUR_FACTOR);
    expect(route.source).toBe('estimate');
    expect(route.meters).toBe(meters);
    expect(route.seconds).toBe(Math.round(meters / 5));
    expect(route.path).toEqual([
      [akwa.longitude, akwa.latitude],
      [bonapriso.longitude, bonapriso.latitude],
    ]);
  });

  it('se replie aussi quand le tracé d’OSRM est absent', async () => {
    vi.stubGlobal('fetch', () =>
      Promise.resolve(
        new Response(JSON.stringify({ code: 'Ok', routes: [{ distance: 10, duration: 5 }] }), {
          status: 200,
        }),
      ),
    );

    const route = await service('http://osrm.local').path(akwa, bonapriso);

    expect(route.source).toBe('estimate');
    expect(route.path).toHaveLength(2);
  });

  it('sans OSRM configuré, n’appelle aucun service', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);

    const route = await service().path(akwa, bonapriso);

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(route.source).toBe('estimate');
  });
});
