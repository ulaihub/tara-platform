// Rend les maquettes (.dc.html) en HTML statique, thèmes clair et sombre, avec leur état par
// défaut. Le code de chaque maquette (valeurs d'affichage) est évalué dans un contexte vm vide,
// sans accès au réseau ni aux fichiers.
// Usage : node tools/design/rendre.cjs [Page ...]   (sans nom : toutes les maquettes)
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const src = path.join(__dirname, '../../docs/design/maquettes');
const outDir = path.join(__dirname, 'rendus');
fs.mkdirSync(outDir, { recursive: true });
let names = process.argv.slice(2);
if (names.length === 0) {
  names = fs
    .readdirSync(src)
    .filter((f) => f.endsWith('.dc.html'))
    .map((f) => f.replace('.dc.html', ''));
}

function evalVals(code, theme) {
  const ctx = vm.createContext({});
  vm.runInContext(
    `class DCLogic { constructor(props) { this.props = props || {}; this.state = this.state || {}; } setState() {} }
     ${code}
     globalThis.__out = (() => { const c = new Component({ theme: ${JSON.stringify(theme)}, glass: 'equilibre' }); return c.renderVals(); })();`,
    ctx,
    { timeout: 2000 },
  );
  return ctx.__out;
}

function lookup(scope, p) {
  p = p.trim();
  if (p === 'true') return true;
  if (p === 'false') return false;
  let v = scope;
  for (const k of p.split('.')) {
    if (v == null) return undefined;
    v = v[k];
  }
  return v;
}

function matchClose(s, tag, from) {
  const open = new RegExp(`<${tag}[\\s>]`, 'g');
  const close = `</${tag}>`;
  let depth = 1;
  let i = from;
  while (depth > 0) {
    const c = s.indexOf(close, i);
    open.lastIndex = i;
    const o = open.exec(s);
    if (o && o.index < c) {
      depth++;
      i = o.index + 1;
    } else {
      depth--;
      i = c + close.length;
      if (depth === 0) return [c, i];
    }
  }
}

function render(s, scope) {
  let out = '';
  for (;;) {
    const m = /<sc-(if|for)\b([^>]*)>/.exec(s);
    if (!m) break;
    out += subst(s.slice(0, m.index), scope);
    const tag = 'sc-' + m[1];
    const [innerEnd, after] = matchClose(s, tag, m.index + m[0].length);
    const inner = s.slice(m.index + m[0].length, innerEnd);
    const attr = (name) => {
      const a = new RegExp(`${name}="\\{\\{([^}]*)\\}\\}"`).exec(m[2]);
      return a ? a[1] : null;
    };
    if (m[1] === 'if') {
      if (lookup(scope, attr('value'))) out += render(inner, scope);
    } else {
      const list = lookup(scope, attr('list')) || [];
      const as = /as="([^"]*)"/.exec(m[2])[1];
      for (const item of list) out += render(inner, { ...scope, [as]: item });
    }
    s = s.slice(after);
  }
  return out + subst(s, scope);
}

function subst(s, scope) {
  return s.replace(/\{\{([^}]*)\}\}/g, (_, p) => {
    const v = lookup(scope, p);
    return typeof v === 'function' || v == null ? '' : String(v);
  });
}

for (const name of names) {
  const html = fs.readFileSync(`${src}/${name}.dc.html`, 'utf8');
  const found = /class Component extends DCLogic \{[\s\S]*?\n\}\n/.exec(html);
  if (!found) continue;
  const body = html
    .replace(/<script[\s\S]*?<\/script>/g, '')
    .replace(/<script[^>]*src=[^>]*>/g, '');
  for (const theme of ['sombre', 'clair']) {
    try {
      fs.writeFileSync(`${outDir}/${name}.${theme}.html`, render(body, evalVals(found[0], theme)));
    } catch (e) {
      console.error(name, theme, e.message);
    }
  }
}
console.log(`Rendus dans ${outDir}`);
