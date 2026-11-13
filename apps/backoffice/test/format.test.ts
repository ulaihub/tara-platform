import { describe, expect, it } from 'vitest';
import { ago, distance, duration, firstName, money, time } from '@/lib/format';

describe('mise en forme', () => {
  it('donne l’heure de Douala', () => {
    expect(time('2026-11-06T13:05:00Z')).toBe('14:05');
  });

  it('écrit les montants en francs', () => {
    expect(money(12_500).replace(/\s/g, ' ')).toBe('12 500 F');
    expect(money(0)).toBe('0 F');
  });

  it('dit depuis quand', () => {
    const now = Date.parse('2026-11-06T10:00:00Z');
    expect(ago('2026-11-06T09:59:58Z', now)).toBe('à l’instant');
    expect(ago('2026-11-06T09:59:15Z', now)).toBe('il y a 45 s');
    expect(ago('2026-11-06T09:48:00Z', now)).toBe('il y a 12 min');
    expect(ago('2026-11-06T07:55:00Z', now)).toBe('il y a 2 h 05');
    expect(ago('2026-11-06T10:00:30Z', now)).toBe('à l’instant');
  });

  it('écrit les durées', () => {
    expect(duration(0)).toBe('0 min');
    expect(duration(60)).toBe('1 h');
    expect(duration(125)).toBe('2 h 05');
  });

  it('garde le prénom', () => {
    expect(firstName('Awa Mbappé', '+237690000777')).toBe('Awa');
    expect(firstName(null, '+237690000777')).toBe('…0777');
    expect(firstName('  ', '+237690000777')).toBe('…0777');
  });

  it('écrit les distances', () => {
    expect(distance(846)).toBe('850 m');
    expect(distance(2_430)).toBe('2,4 km');
  });
});
