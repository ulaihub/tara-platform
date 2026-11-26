import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Vraie carte des pages (rues de Douala) : MapLibre et son worker, servis par la page
 * elle-même (aucun script d'un autre site), et le style Tara des apps (clair, sombre), avec
 * l'adresse des tuiles. Chargés après la page : sans carte (vieux téléphone, réseau coupé),
 * la ville dessinée reste et tout fonctionne.
 */

/** Tuiles vectorielles et polices : les mêmes que les apps (OpenFreeMap par défaut). */
export const TILES_URL = process.env['MAP_TILES_URL'] ?? 'https://tiles.openfreemap.org/planet';
export const GLYPHS_URL =
  process.env['MAP_GLYPHS_URL'] ?? 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

/** Origine des tuiles, autorisée par la politique de sécurité des pages. */
export const TILES_ORIGIN = new URL(TILES_URL).origin;

export interface MapAsset {
  type: string;
  body: Buffer;
}

const here = dirname(fileURLToPath(import.meta.url));

/** Style des apps : copié dans `dist/carte` au build, lu dans `packages/tara_map` en dev. */
function styleFile(name: string): string {
  const candidates = [
    join(here, 'carte', name),
    join(here, '..', '..', '..', 'packages', 'tara_map', 'assets', name),
  ];
  const found = candidates.find((path) => existsSync(path));
  if (!found) throw new Error(`Style de carte introuvable : ${name}`);
  return found;
}

function style(name: string): Buffer {
  const raw = readFileSync(styleFile(name), 'utf8')
    .replaceAll('{{TILES_URL}}', TILES_URL)
    .replaceAll('{{GLYPHS_URL}}', GLYPHS_URL);
  return Buffer.from(raw);
}

export function loadMapAssets(): Map<string, MapAsset> {
  const require = createRequire(import.meta.url);
  const dist = join(dirname(require.resolve('maplibre-gl/package.json')), 'dist');
  const js = 'text/javascript; charset=utf-8';
  return new Map<string, MapAsset>([
    ['maplibre-gl.mjs', { type: js, body: readFileSync(join(dist, 'maplibre-gl.mjs')) }],
    [
      'maplibre-gl-worker.mjs',
      { type: js, body: readFileSync(join(dist, 'maplibre-gl-worker.mjs')) },
    ],
    [
      'maplibre-gl.css',
      { type: 'text/css; charset=utf-8', body: readFileSync(join(dist, 'maplibre-gl.css')) },
    ],
    ['style-clair.json', { type: 'application/json', body: style('tara-light.json') }],
    ['style-sombre.json', { type: 'application/json', body: style('tara-dark.json') }],
  ]);
}
