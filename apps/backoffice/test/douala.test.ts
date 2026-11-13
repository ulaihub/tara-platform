import { describe, expect, it } from 'vitest';
import { doualaDay, doualaHour, greeting, longDate, periodRange } from '@/lib/douala';

describe('heure de Douala', () => {
  it('ajoute une heure à l’heure universelle', () => {
    expect(doualaHour(new Date('2026-11-06T05:50:00Z'))).toBe(6);
    expect(doualaHour(new Date('2026-11-06T23:30:00Z'))).toBe(0);
  });

  it.each([
    ['2026-11-06T03:59:00Z', 'Bonsoir'],
    ['2026-11-06T04:00:00Z', 'Bonjour'],
    ['2026-11-06T05:50:00Z', 'Bonjour'],
    ['2026-11-06T16:59:00Z', 'Bonjour'],
    ['2026-11-06T17:00:00Z', 'Bonsoir'],
  ])('à %s : %s', (iso, expected) => {
    expect(greeting(new Date(iso))).toBe(expected);
  });

  it('écrit la date du jour de Douala', () => {
    expect(longDate.format(new Date('2026-11-06T23:30:00Z'))).toBe('samedi 7 novembre');
  });
});

describe('périodes de la liste des commandes', () => {
  const now = new Date('2026-11-06T23:30:00Z'); // 7 novembre, 0 h 30 à Douala
  it('compte les jours à l’heure de Douala', () => {
    expect(doualaDay(now)).toBe('2026-11-07');
    expect(periodRange('jour', now)).toEqual({ from: '2026-11-07', to: '2026-11-07' });
    expect(periodRange('hier', now)).toEqual({ from: '2026-11-06', to: '2026-11-06' });
    expect(periodRange('7j', now)).toEqual({ from: '2026-11-01', to: '2026-11-07' });
    expect(periodRange('tout', now)).toEqual({});
  });
});
