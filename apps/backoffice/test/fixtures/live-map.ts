import type { LiveMap, LiveOrder, LiveRider, SafetyAlert } from '@/lib/schemas';

/** Carte en direct fictive (Douala, 6 novembre 2026 à 10 h, heure universelle). */
export const NOW = Date.parse('2026-11-06T10:00:00Z');
export const minutesAgo = (minutes: number) => new Date(NOW - minutes * 60_000).toISOString();

export function rider(overrides: Partial<LiveRider> = {}): LiveRider {
  return {
    id: '00000000-0000-4000-8000-000000000001',
    name: 'Paul Ndongo',
    phone: '+237677000001',
    vehicleType: 'MOTORBIKE',
    plateNumber: 'LT 123 AB',
    state: 'FREE',
    signalLost: false,
    position: { latitude: 4.05, longitude: 9.7, heading: null, at: minutesAgo(0.2) },
    orderIds: [],
    rating: 4.8,
    ...overrides,
  };
}

export function order(overrides: Partial<LiveOrder> = {}): LiveOrder {
  return {
    id: '00000000-0000-4000-8000-0000000000a1',
    reference: 'TR-7K3P9Q',
    status: 'SEARCHING_RIDER',
    isExpress: false,
    scheduledFor: null,
    senderName: 'Boutique Akwa',
    riderId: null,
    pickup: { latitude: 4.05, longitude: 9.7, neighborhood: 'Akwa', landmark: 'Face pharmacie' },
    dropoff: {
      latitude: 4.08,
      longitude: 9.75,
      neighborhood: 'Bonamoussadi',
      landmark: 'Carrefour Kotto',
    },
    codAmount: 0,
    createdAt: minutesAgo(12),
    assignedAt: null,
    pickedUpAt: null,
    delay: null,
    awaitingValidation: false,
    awaitingDecision: false,
    ...overrides,
  };
}

export function sos(overrides: Partial<SafetyAlert> = {}): SafetyAlert {
  return {
    id: '00000000-0000-4000-8000-0000000000f1',
    riderId: '00000000-0000-4000-8000-000000000001',
    riderName: 'Paul Ndongo',
    riderPhone: '+237677000001',
    riderPlate: 'LT 123 AB',
    orderId: null,
    latitude: 4.06,
    longitude: 9.71,
    accuracy: 12,
    neighborhood: 'Deïdo',
    note: null,
    createdAt: minutesAgo(2),
    acknowledgedAt: null,
    policeCalledAt: null,
    resolvedAt: null,
    cancelledAt: null,
    resolution: null,
    ...overrides,
  };
}

export function liveMap(overrides: Partial<LiveMap> = {}): LiveMap {
  return {
    generatedAt: new Date(NOW).toISOString(),
    riders: [],
    orders: [],
    safetyAlerts: [],
    courseAlerts: [],
    rules: { searchingMinutes: 5, pickupMinutes: 25, deliveryMarginMinutes: 15 },
    ...overrides,
  };
}
