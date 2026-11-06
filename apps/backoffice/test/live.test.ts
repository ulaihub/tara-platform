import { describe, expect, it } from 'vitest';
import { alertsOf, countsOf, nextStop } from '@/lib/live';
import { NOW, liveMap, minutesAgo, order, rider, sos } from './fixtures/live-map';

describe('alertes de la carte en direct', () => {
  it('met les SOS en tête, puis les retards, puis le reste', () => {
    const map = liveMap({
      riders: [rider({ state: 'ON_COURSE', orderIds: ['00000000-0000-4000-8000-0000000000a2'] })],
      orders: [
        order({
          awaitingDecision: true,
          status: 'DELIVERY_FAILED',
          id: '00000000-0000-4000-8000-0000000000a3',
          reference: 'TR-ECHEC1',
        }),
        order({ delay: { kind: 'NO_RIDER', dueAt: minutesAgo(7), minutes: 7 } }),
        order({
          id: '00000000-0000-4000-8000-0000000000a2',
          reference: 'TR-RETARD',
          status: 'IN_DELIVERY',
          riderId: '00000000-0000-4000-8000-000000000001',
          delay: { kind: 'DELIVERY', dueAt: minutesAgo(9), minutes: 9 },
        }),
      ],
      safetyAlerts: [sos()],
    });
    const alerts = alertsOf(map, NOW);
    expect(alerts.map((alert) => alert.title)).toEqual([
      'SOS · Paul Ndongo',
      'TR-RETARD : livraison en retard',
      'TR-7K3P9Q sans livreur',
      'TR-ECHEC1 : échec de livraison',
    ]);
    expect(alerts[0]).toMatchObject({
      level: 'critical',
      detail: 'Deïdo · il y a 2 min · à prendre en charge',
      safety: { acknowledged: false },
      position: { latitude: 4.06, longitude: 9.71 },
    });
    expect(alerts[1]?.detail).toBe('9 min de retard · Paul → Bonamoussadi · Carrefour Kotto');
    expect(alerts[2]?.detail).toBe('Depuis 12 min · Akwa · Face pharmacie');
  });

  it('dit où en est un SOS', () => {
    const state = (overrides: Parameters<typeof sos>[0]) =>
      alertsOf(liveMap({ safetyAlerts: [sos(overrides)] }), NOW)[0]
        ?.detail.split(' · ')
        .at(-1);
    expect(state({ acknowledgedAt: minutesAgo(1) })).toBe('prise en charge');
    expect(state({ acknowledgedAt: minutesAgo(1), policeCalledAt: minutesAgo(0.5) })).toBe(
      'police appelée',
    );
    expect(state({ cancelledAt: minutesAgo(1) })).toBe('annulée par le livreur, à rappeler');
  });

  it('signale un livreur en course qui ne répond plus, pas un livreur libre', () => {
    const map = liveMap({
      riders: [
        rider({
          state: 'ON_COURSE',
          signalLost: true,
          position: { latitude: 4, longitude: 9, heading: null, at: minutesAgo(4) },
        }),
        rider({ id: '00000000-0000-4000-8000-000000000002', state: 'FREE', signalLost: true }),
      ],
    });
    const alerts = alertsOf(map, NOW);
    expect(alerts).toHaveLength(1);
    expect(alerts[0]).toMatchObject({
      title: 'Paul ne répond plus',
      detail: 'En course · dernière position il y a 4 min',
    });
  });

  it('nomme les alertes de trajet', () => {
    const map = liveMap({
      courseAlerts: [
        {
          id: '00000000-0000-4000-8000-0000000000c1',
          orderId: '00000000-0000-4000-8000-0000000000a1',
          reference: 'TR-7K3P9Q',
          riderId: '00000000-0000-4000-8000-000000000001',
          kind: 'MOCK_LOCATION',
          details: {},
          createdAt: minutesAgo(3),
          acknowledgedAt: null,
          note: null,
        },
      ],
    });
    expect(alertsOf(map, NOW)[0]).toMatchObject({
      level: 'high',
      title: 'TR-7K3P9Q : position falsifiée',
    });
  });
});

describe('compteurs et arrêts', () => {
  it('compte livreurs et commandes', () => {
    const map = liveMap({
      riders: [
        rider(),
        rider({ state: 'ON_COURSE' }),
        rider({ state: 'OFFLINE' }),
        rider({ state: 'OFFLINE' }),
      ],
      orders: [
        order(),
        order({ status: 'ASSIGNED', delay: { kind: 'PICKUP', dueAt: minutesAgo(1), minutes: 1 } }),
      ],
    });
    expect(countsOf(map)).toEqual({
      free: 1,
      onCourse: 1,
      offline: 2,
      orders: 2,
      searching: 1,
      late: 1,
    });
  });

  it('vise le vendeur avant l’enlèvement, le client après', () => {
    expect(nextStop(order({ status: 'ASSIGNED' }))).toBe('pickup');
    expect(nextStop(order({ status: 'PICKED_UP' }))).toBe('dropoff');
    expect(nextStop(order({ status: 'DELIVERY_FAILED' }))).toBe('dropoff');
  });
});
