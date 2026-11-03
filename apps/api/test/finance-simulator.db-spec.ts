import { runFinanceSimulation } from './simulator/finance-simulation.js';

/**
 * Critère de sortie de la phase 3 : 500 commandes simulées, rapprochement à 0 FCFA d'écart,
 * aucun reversement en double après coupure réseau ou notification répétée.
 */
describe('Simulateur financier de 500 commandes (critère de sortie de la phase 3)', () => {
  it(
    'rapproche à 0 FCFA d’écart, sans aucun reversement en double',
    { timeout: 600_000 },
    async () => {
      const report = await runFinanceSimulation({
        orders: 500,
        merchants: 12,
        riders: 30,
        seed: 2026,
        concurrency: 10,
        log: (line) => {
          process.stdout.write(`${line}\n`);
        },
      });
      process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
      expect(report.reconciliation.discrepancies).toEqual([]);
      expect(report.reconciliation.status).toBe('BALANCED');
      expect(report.duplicateDisbursements).toBe(0);
      expect(report.ledgerTotal).toBe(0);
      expect(report.payouts.lostResponses).toBeGreaterThan(0);
      expect(report.payments.duplicateNotifications).toBeGreaterThan(0);
    },
  );
});
