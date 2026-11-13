import { describe, expect, it } from 'vitest';
import { discrepancyLabel, exportRange, lastCheck, payoutView } from '@/lib/finance';

describe('finance au back-office', () => {
  it('ouvre « à valider » par défaut', () => {
    expect(payoutView(undefined)).toBe('TO_APPROVE');
    expect(payoutView('in-progress')).toBe('IN_PROGRESS');
    expect(payoutView('sent')).toBe('SENT');
    expect(payoutView('nimporte')).toBe('TO_APPROVE');
  });

  it('explique chaque écart, et garde le code s’il est inconnu', () => {
    expect(discrepancyLabel('PAYMENT_STUCK')).toBe('Paiement resté en attente');
    expect(discrepancyLabel('NOUVEAU')).toBe('NOUVEAU');
  });

  it('prend le contrôle le plus récent', () => {
    expect(lastCheck([])).toEqual({ report: null, issues: 0 });
    const report = {
      day: '2026-11-11',
      status: 'DISCREPANCIES' as const,
      totals: {},
      discrepancies: [{ type: 'PAYMENT_STUCK', reference: 'p1', detail: '…' }],
      updatedAt: '2026-11-12T01:00:00Z',
    };
    expect(lastCheck([report])).toEqual({ report, issues: 1 });
  });

  it('refuse une période d’export mal formée ou trop longue', () => {
    expect(exportRange('2026-11-01', '2026-11-30')).toBeNull();
    expect(exportRange('2026-11-30', '2026-11-01')).toMatch(/précéder/);
    expect(exportRange('2026-08-01', '2026-11-30')).toMatch(/Trois mois/);
    expect(exportRange('2026-09-01', '2026-11-30')).toBeNull();
    expect(exportRange('', '2026-11-30')).toMatch(/deux dates/);
  });
});
