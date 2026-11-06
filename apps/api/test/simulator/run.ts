/**
 * Lancement du simulateur hors des tests, sur la base et le Redis de développement (les
 * commandes en attente de livreur y sont annulées avant de commencer) :
 *
 *   pnpm --filter @tara/api simulate -- --riders 50 --orders 200 --scale 0.05
 *
 * Toutes les options : --riders, --orders, --scale, --interval (s), --accept, --decline, --seed.
 */
import { parseArgs } from 'node:util';
import { DEFAULT_SIMULATION, runSimulation } from './simulation.js';

const { values } = parseArgs({
  options: {
    riders: { type: 'string' },
    orders: { type: 'string' },
    scale: { type: 'string' },
    interval: { type: 'string' },
    accept: { type: 'string' },
    decline: { type: 'string' },
    seed: { type: 'string' },
  },
});

const number = (value: string | undefined, fallback: number): number =>
  value === undefined ? fallback : Number(value);

// Mode test : fournisseurs factices, pas de limitation de débit (tous les livreurs virtuels
// partagent la même adresse IP).
process.env['NODE_ENV'] = 'test';
process.env['SMS_PROVIDER'] = 'fake';
process.env['PUSH_PROVIDER'] = 'fake';
process.env['WHATSAPP_PROVIDER'] = 'none';
// Plafonds anti-pompage relevés : tous les comptes virtuels se connectent depuis la même IP.
process.env['OTP_MAX_PER_IP_PER_HOUR'] = '1000000';
process.env['OTP_DAILY_GLOBAL_LIMIT'] = '1000000';
delete process.env['OSRM_URL']; // Distances à vol d'oiseau corrigées, sans serveur d'itinéraires.

const report = await runSimulation({
  riders: number(values.riders, DEFAULT_SIMULATION.riders),
  orders: number(values.orders, DEFAULT_SIMULATION.orders),
  timeScale: number(values.scale, DEFAULT_SIMULATION.timeScale),
  orderIntervalSeconds: number(values.interval, DEFAULT_SIMULATION.orderIntervalSeconds),
  acceptRate: number(values.accept, DEFAULT_SIMULATION.acceptRate),
  declineRate: number(values.decline, DEFAULT_SIMULATION.declineRate),
  seed: number(values.seed, DEFAULT_SIMULATION.seed),
  log: (line) => process.stdout.write(`${line}\n`),
});
const ok = report.rateWithin2Min >= 0.95;
process.stdout.write(
  `\n${ok ? 'OK' : 'ÉCHEC'} : ${(report.rateWithin2Min * 100).toFixed(1)} % des courses attribuées en moins de 2 min (objectif 95 %)\n`,
);
process.exit(ok ? 0 : 1);
