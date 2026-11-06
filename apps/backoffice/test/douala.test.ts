import { describe, expect, it } from 'vitest';
import { doualaHour, greeting, longDate } from '@/lib/douala';

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
