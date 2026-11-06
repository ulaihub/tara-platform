/**
 * Lance un script TypeScript de l'API (simulateurs) avec le compilateur des tests (Vite) :
 * tsx ne produit pas les métadonnées de décorateurs dont Nest a besoin pour l'injection.
 *
 *   node test/simulator/launch.mjs test/simulator/demo-city.ts --riders 30
 */
import { runnerImport } from 'vite';

const [script] = process.argv.splice(2, 1);
if (!script) throw new Error('Script à lancer manquant');
// « pnpm demo:city -- --riders 30 » transmet le « -- » : on le retire.
if (process.argv[2] === '--') process.argv.splice(2, 1);
await runnerImport(script, {
  configFile: false,
  root: process.cwd(),
  resolve: { tsconfigPaths: true },
  logLevel: 'warn',
});
