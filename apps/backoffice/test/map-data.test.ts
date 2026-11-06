import { describe, expect, it } from 'vitest';
import { ordersData, pointsOf, ridersData, selectedOrderData, taraStyle } from '@/lib/map-data';
import { liveMap, order, rider } from './fixtures/live-map';

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

  it('trace le livreur jusqu’au prochain arrêt de la commande choisie', () => {
    const map = liveMap({
      riders: [rider({ state: 'ON_COURSE' })],
      orders: [order({ status: 'PICKED_UP', riderId: '00000000-0000-4000-8000-000000000001' })],
    });
    const { stops, route } = selectedOrderData(map, { type: 'order', id: map.orders[0]!.id });
    expect(stops.features.map((feature) => feature.properties.label)).toEqual([
      'Vendeur',
      'Client',
    ]);
    expect(route.features[0]?.geometry.coordinates).toEqual([
      [9.7, 4.05],
      [9.75, 4.08],
    ]);
    expect(selectedOrderData(map, null).route.features).toEqual([]);
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
