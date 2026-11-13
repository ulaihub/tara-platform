import { describe, expect, it } from 'vitest';
import {
  courseData,
  glide,
  ordersData,
  pointsOf,
  riderPoint,
  ridersData,
  taraStyle,
  trailPoints,
  trailRequest,
} from '@/lib/map-data';
import type { RiderTrail } from '@/lib/schemas';
import { liveMap, minutesAgo, order, rider } from './fixtures/live-map';

describe('données de la carte', () => {
  it('prépare le style Tara avec les tuiles et polices', () => {
    for (const dark of [false, true]) {
      const text = JSON.stringify(taraStyle(dark));
      expect(text).not.toContain('{{');
      expect(text).toContain('https://tiles.openfreemap.org/planet');
    }
  });

  it('place les livreurs connus et met en avant celui de la commande choisie', () => {
    const busy = rider({ id: '00000000-0000-4000-8000-000000000002', state: 'ON_COURSE' });
    const map = liveMap({
      riders: [
        rider(),
        busy,
        rider({ id: '00000000-0000-4000-8000-000000000003', position: null }),
      ],
      orders: [order({ riderId: busy.id, status: 'ASSIGNED' })],
    });
    const data = ridersData(map, { type: 'order', id: map.orders[0]!.id });
    expect(
      data.features.map((feature) => [feature.properties.id, feature.properties.selected]),
    ).toEqual([
      ['00000000-0000-4000-8000-000000000001', false],
      [busy.id, true],
    ]);
  });

  it('montre le prochain arrêt de chaque commande', () => {
    const map = liveMap({
      orders: [
        order(),
        order({ id: '00000000-0000-4000-8000-0000000000a2', status: 'IN_DELIVERY', riderId: 'r' }),
      ],
    });
    const features = ordersData(map, null).features;
    expect(
      features.map((feature) => [feature.properties.stop, feature.properties.waiting]),
    ).toEqual([
      ['pickup', true],
      ['dropoff', false],
    ]);
    expect(features[1]?.geometry.coordinates).toEqual([9.75, 4.08]);
  });

  it('relie le livreur à son prochain arrêt en attendant l’itinéraire', () => {
    const map = liveMap({
      riders: [rider({ state: 'ON_COURSE', orderIds: ['00000000-0000-4000-8000-0000000000a1'] })],
      orders: [order({ status: 'PICKED_UP', riderId: '00000000-0000-4000-8000-000000000001' })],
    });
    const { stops, route, traveled } = courseData(
      map,
      { type: 'order', id: map.orders[0]!.id },
      null,
    );
    expect(stops.features.map((feature) => feature.properties.label)).toEqual([
      'Vendeur',
      'Client',
    ]);
    expect(route.features[0]?.geometry.coordinates).toEqual([
      [9.7, 4.05],
      [9.75, 4.08],
    ]);
    expect(route.features[0]?.properties.estimate).toBe(true);
    expect(traveled.features).toEqual([]);
    expect(courseData(map, null, null).route.features).toEqual([]);
  });

  it('dessine l’itinéraire sur les rues et le chemin parcouru, aussi pour le livreur choisi', () => {
    const map = liveMap({
      riders: [rider({ state: 'ON_COURSE', orderIds: ['00000000-0000-4000-8000-0000000000a1'] })],
      orders: [order({ status: 'IN_DELIVERY', riderId: '00000000-0000-4000-8000-000000000001' })],
    });
    const trail: RiderTrail = {
      riderId: '00000000-0000-4000-8000-000000000001',
      order: {
        id: '00000000-0000-4000-8000-0000000000a1',
        reference: 'TR-7K3P9Q',
        status: 'IN_DELIVERY',
        target: 'dropoff',
      },
      position: { latitude: 4.05, longitude: 9.7 },
      traveled: {
        path: [
          [9.69, 4.04],
          [9.695, 4.045],
          [9.7, 4.05],
        ],
        onRoads: true,
      },
      remaining: {
        path: [
          [9.7, 4.05],
          [9.72, 4.06],
          [9.75, 4.08],
        ],
        meters: 4_200,
        seconds: 840,
        onRoads: true,
      },
    };
    const selected = { type: 'rider' as const, id: '00000000-0000-4000-8000-000000000001' };
    expect(trailRequest(map, selected)).toEqual({
      riderId: '00000000-0000-4000-8000-000000000001',
    });
    const { route, traveled } = courseData(map, selected, trail);
    expect(route.features[0]?.geometry.coordinates).toHaveLength(3);
    expect(route.features[0]?.properties.estimate).toBe(false);
    expect(traveled.features[0]?.geometry.coordinates).toHaveLength(3);
    expect(trailPoints(trail)).toHaveLength(6);
    // Un tracé arrivé pour un autre livreur n'est pas mélangé à cette course.
    expect(courseData(map, selected, { ...trail, riderId: 'autre' }).traveled.features).toEqual([]);
  });

  it('pose le livreur sur la rue quand on la connaît', () => {
    const onRoad = rider({ roadPosition: { latitude: 4.0502, longitude: 9.7001 } });
    expect(riderPoint(onRoad)).toEqual({ latitude: 4.0502, longitude: 9.7001 });
    expect(riderPoint(rider())).toMatchObject({ latitude: 4.05, longitude: 9.7 });
  });

  it('fait glisser les livreurs sans les faire traverser la ville', () => {
    const map = liveMap({
      riders: [
        rider({ position: { latitude: 4.06, longitude: 9.71, heading: null, at: minutesAgo(0) } }),
      ],
    });
    const target = ridersData(map, null);
    const from = new Map<string, [number, number]>([
      ['00000000-0000-4000-8000-000000000001', [9.7, 4.05]],
    ]);
    expect(glide(from, target, 0).features[0]?.geometry.coordinates).toEqual([9.7, 4.05]);
    const middle = glide(from, target, 0.5).features[0]?.geometry.coordinates as [number, number];
    expect(middle[0]).toBeGreaterThan(9.7);
    expect(middle[0]).toBeLessThan(9.71);
    expect(glide(from, target, 1).features[0]?.geometry.coordinates).toEqual([9.71, 4.06]);
    const far = new Map<string, [number, number]>([
      ['00000000-0000-4000-8000-000000000001', [9.6, 3.9]],
    ]);
    expect(glide(far, target, 0.2).features[0]?.geometry.coordinates).toEqual([9.71, 4.06]);
  });
});

describe('cadrage', () => {
  it('cadre le prochain arrêt et le livreur d’une commande', () => {
    const map = liveMap({
      riders: [rider({ state: 'ON_COURSE' })],
      orders: [order({ status: 'IN_DELIVERY', riderId: '00000000-0000-4000-8000-000000000001' })],
    });
    expect(pointsOf(map, { type: 'order', id: map.orders[0]!.id })).toEqual([
      { latitude: 4.08, longitude: 9.75 },
      { latitude: 4.05, longitude: 9.7 },
    ]);
    expect(pointsOf(map, { type: 'rider', id: 'inconnu' })).toEqual([]);
    expect(pointsOf(map, null)).toEqual([]);
  });
});
