// Aperçus des styles de carte de l'app livreur sur Douala (CI) : rendu MapLibre GL JS dans
// Chromium avec les tuiles OpenFreeMap (même schéma OpenMapTiles que les tuiles Tara).
// Une zone interdite aux motos de démonstration montre leur affichage.
//   node render.mjs <dossier de sortie>
import { readFileSync, mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const out = process.argv[2] ?? 'out';
mkdirSync(out, { recursive: true });
const TILES = 'https://tiles.openfreemap.org/planet';
const GLYPHS = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';
const views = [
  { name: 'akwa-z16', center: [9.6996, 4.0496], zoom: 16 },
  { name: 'akwa-z17_5', center: [9.6985, 4.0478], zoom: 17.5 },
  { name: 'zone-bord-z16_5', center: [9.6985, 4.0455], zoom: 16.5 },
  { name: 'bonapriso-z15', center: [9.6935, 4.0335], zoom: 15 },
  { name: 'douala-z12_5', center: [9.715, 4.05], zoom: 12.5 },
  // Écran 08 : livreur, vendeur et itinéraire de repli (ligne droite estimée, sans OSRM).
  { name: 'course-z15', center: [9.6987, 4.0477], zoom: 15, course: true },
];
const rider = [9.7012, 4.0442];
const pickup = [9.6962, 4.0512];
const demoCourse = {
  rider: { type: 'FeatureCollection', features: [{ type: 'Feature', properties: {}, geometry: { type: 'Point', coordinates: rider } }] },
  stop: {
    type: 'FeatureCollection',
    features: [{ type: 'Feature', properties: { kind: 'pickup', label: 'Boutique Mama Ngo' }, geometry: { type: 'Point', coordinates: pickup } }],
  },
  route: {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', properties: { estimate: true }, geometry: { type: 'LineString', coordinates: [rider, pickup] } },
    ],
  },
};
const empty = { type: 'FeatureCollection', features: [] };
const demoZone = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      properties: { kind: 'NO_MOTORBIKE', label: 'Interdit aux motos (démo)' },
      geometry: {
        type: 'Polygon',
        coordinates: [[[9.6955, 4.0455], [9.7015, 4.0455], [9.7015, 4.0500], [9.6955, 4.0500], [9.6955, 4.0455]]],
      },
    },
  ],
};

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
for (const theme of ['dark', 'light']) {
  const style = JSON.parse(
    readFileSync(new URL(`../../../../packages/tara_map/assets/tara-${theme}.json`, import.meta.url), 'utf8')
      .replaceAll('{{TILES_URL}}', TILES)
      .replaceAll('{{GLYPHS_URL}}', GLYPHS),
  );
  style.sources['tara-zones'].data = demoZone;
  for (const view of views) {
    style.sources['tara-rider'].data = view.course ? demoCourse.rider : empty;
    style.sources['tara-stop'].data = view.course ? demoCourse.stop : empty;
    style.sources['tara-route'].data = view.course ? demoCourse.route : empty;
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
    await page.setContent(`<!doctype html><html><head>
      <link href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" rel="stylesheet">
      <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
      <style>html,body,#map{margin:0;width:100%;height:100%}</style></head>
      <body><div id="map"></div></body></html>`);
    await page.waitForFunction(() => window.maplibregl !== undefined);
    await page.evaluate(
      ({ style, view }) =>
        new Promise((resolve) => {
          const map = new window.maplibregl.Map({
            container: 'map', style, center: view.center, zoom: view.zoom, attributionControl: false,
          });
          map.once('idle', () => setTimeout(resolve, 500));
        }),
      { style, view },
    );
    await page.screenshot({ path: `${out}/${theme}-${view.name}.png` });
    // Copie JPEG légère dans le journal : relecture possible sans télécharger l'artefact.
    const jpeg = await page.screenshot({ type: 'jpeg', quality: 70, scale: 'css' });
    console.log(`PREVIEW-BEGIN ${theme}-${view.name}.jpg`);
    for (const line of jpeg.toString('base64').match(/.{1,4000}/g)) console.log(line);
    console.log('PREVIEW-END');
    await page.close();
  }
}
await browser.close();
