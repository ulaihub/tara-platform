import { nextCashLimit } from './cash-discipline.service.js';

describe('plafond d’espèces progressif (G5)', () => {
  const rules = { start: 25_000, full: 50_000, courses: 20 };

  it('passe au plafond normal après 20 courses sans retard de dépôt', () => {
    expect(nextCashLimit({ ...rules, limit: 25_000, deliveredSinceLate: 19 })).toBe(25_000);
    expect(nextCashLimit({ ...rules, limit: 25_000, deliveredSinceLate: 20 })).toBe(50_000);
  });

  it('ne touche jamais un plafond fixé à la main par la finance', () => {
    expect(nextCashLimit({ ...rules, limit: 100_000, deliveredSinceLate: 0 })).toBe(100_000);
    expect(nextCashLimit({ ...rules, limit: 10_000, deliveredSinceLate: 50 })).toBe(10_000);
  });
});
