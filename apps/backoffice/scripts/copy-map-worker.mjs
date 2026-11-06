/**
 * Copie le fichier de calcul de la carte (MapLibre) dans public/ : il est chargé à part par
 * le navigateur, qui ne le trouve pas une fois la bibliothèque regroupée par Next.
 */
import { copyFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(join(root, 'package.json'));
const source = join(
  dirname(require.resolve('maplibre-gl/package.json')),
  'dist',
  'maplibre-gl-worker.mjs',
);
mkdirSync(join(root, 'public'), { recursive: true });
copyFileSync(source, join(root, 'public', 'maplibre-gl-worker.mjs'));
