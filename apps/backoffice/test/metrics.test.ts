import { describe, expect, it } from 'vitest';
import { change, minutes, periodOf, pointsChange, rate, ticks } from '../src/lib/metrics';

describe('Indicateurs (H7)', () => {
  it('lit la période, 30 jours par défaut', () => {
    expect(periodOf('7')).toBe(7);
    expect(periodOf('90')).toBe(90);
    expect(periodOf('12')).toBe(30);
    expect(periodOf(undefined)).toBe(30);
  });

  it('écrit taux, durées et évolutions à la française', () => {
    expect(rate(0.874)).toBe('87,4 %');
    expect(rate(0.9)).toBe('90 %');
    expect(rate(null)).toBe('—');
    expect(minutes(42.4)).toBe('42 min');
    expect(minutes(95)).toBe('1 h 35');
    expect(minutes(120)).toBe('2 h');
    expect(change(120, 100)).toEqual({ text: '+20 %', up: true });
    expect(change(80, 100)).toEqual({ text: '−20 %', up: false });
    expect(change(5, 0)).toBeNull();
    expect(pointsChange(0.9, 0.85)).toBe('+5 pts');
    expect(pointsChange(0.85, 0.855)).toBe('−0,5 pt');
  });

  it('choisit des graduations rondes qui couvrent le maximum', () => {
    expect(ticks(0)).toEqual([0]);
    expect(ticks(12)).toEqual([0, 5, 10, 15]);
    expect(ticks(120)).toEqual([0, 50, 100, 150]);
    expect(ticks(30)).toEqual([0, 10, 20, 30]);
  });
});
