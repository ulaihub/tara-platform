import { describe, expect, it } from 'vitest';
import { cameroonMobile, displayPhone } from '@/lib/phone';

describe('numéro camerounais', () => {
  it.each([
    ['6 77 12 34 56', '+237677123456'],
    ['677123456', '+237677123456'],
    ['+237 677 12 34 56', '+237677123456'],
    ['00237677123456', '+237677123456'],
    ['237-690-000-777', '+237690000777'],
  ])('« %s » → %s', (input, expected) => {
    expect(cameroonMobile(input)).toBe(expected);
  });

  it.each(['', '233 12 34 56', '77123456', '6771234567', '+33 6 12 34 56 78'])(
    'refuse « %s »',
    (input) => {
      expect(cameroonMobile(input)).toBeNull();
    },
  );

  it('s’affiche par groupes', () => {
    expect(displayPhone('+237677123456')).toBe('+237 6 77 12 34 56');
    expect(displayPhone('inconnu')).toBe('inconnu');
  });
});
