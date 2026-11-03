import { runSimulation } from './simulator/simulation.js';

/**
 * Critère de sortie de la phase 2 : avec 50 livreurs, 95 % des courses sont attribuées en
 * moins de 2 minutes. Temps accéléré (1 min simulée ≈ 1,5 s) pour tenir dans la CI ; plus
 * accéléré, le temps de réponse de la machine de test pèserait sur le résultat.
 */
describe('Simulateur de 50 livreurs (critère de sortie de la phase 2)', () => {
  it('attribue au moins 95 % des courses en moins de 2 minutes', { timeout: 240_000 }, async () => {
    const report = await runSimulation({
      riders: 50,
      orders: 60,
      timeScale: 0.025,
      orderIntervalSeconds: 20,
      acceptRate: 0.6,
      declineRate: 0.2,
      seed: 2026,
      log: (line) => {
        process.stdout.write(`${line}\n`);
      },
    });
    expect(report.actionErrors).toEqual([]);
    // Le critère porte sur 95 % des courses : une course isolée peut attendre plus longtemps
    // (tous les livreurs proches occupés), c'est alors le dispatch qui est alerté.
    expect(report.rateWithin2Min).toBeGreaterThanOrEqual(0.95);
  });
});
