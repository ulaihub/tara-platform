// Capture chaque maquette rendue (tools/design/rendus/*.html) en PNG, à la taille de la maquette.
// Usage : node tools/design/photo.cjs   (après rendre.cjs ; demande Playwright, voir README)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, 'rendus');
const src = path.join(__dirname, '../../docs/design/maquettes');
(async () => {
  const b = await chromium.launch();
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.html'));
  for (const f of files) {
    const base = f.replace(/\.(sombre|clair)\.html$/, '');
    const html = fs.readFileSync(`${src}/${base}.dc.html`, 'utf8');
    const m = /"\$preview": \{"width": (\d+), "height": (\d+)\}/.exec(html);
    const [w, h] = m ? [+m[1], +m[2]] : [390, 844];
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await p.goto('file://' + path.join(dir, f));
    await p.waitForTimeout(1800);
    await p.screenshot({ path: path.join(dir, f.replace('.html', '.png')) });
    await p.close();
  }
  await b.close();
  console.log(`${files.length} captures dans ${dir}`);
})();
