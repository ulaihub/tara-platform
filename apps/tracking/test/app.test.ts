import { readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { httpApi, PUBLIC_TRACKING_FIELDS } from '../src/api.js';
import { createApp, fingerprint } from '../src/app.js';
import { FakeApi, NOW, TOKEN, tracking } from './fixtures.js';

const NBSP = ' ';

function setup(api = new FakeApi()) {
  const app = createApp({ api, now: () => NOW });
  return { api, app };
}

async function page(
  app: ReturnType<typeof setup>['app'],
  path = `/t/${TOKEN}`,
  headers: Record<string, string> = {},
) {
  const res = await app.request(path, { headers });
  return { res, html: await res.text() };
}

/** Texte visible, sans balises (les montants gardent leurs espaces insécables). */
const text = (html: string) => html.replace(/<[^>]+>/g, ' ').replace(/[ \n]+/g, ' ');

describe('page de suivi du destinataire (F2)', () => {
  it('colis en route : minutes restantes, livreur à appeler, somme à payer, code à donner', async () => {
    const { app } = setup();
    const { res, html } = await page(app);
    expect(res.status).toBe(200);
    const visible = text(html);
    expect(visible).toContain('Colis d’Awa Fashion');
    expect(visible).toContain('Jean M. arrive chez vous');
    expect(visible).toContain('8 min');
    expect(html).toContain('href="tel:+237677445566"');
    expect(visible).toContain('Appeler Jean');
    expect(html).toContain('href="#point"');
    expect(visible).toContain(`Moto · LT 482 KQ`);
    expect(visible).toContain(`14${NBSP}000${NBSP}F`);
    expect(visible).toContain(`12${NBSP}500${NBSP}F`);
    expect(visible).toContain('code à 4 chiffres reçu par SMS');
    expect(visible).toContain('Bonapriso · Face pharmacie du Rond-point');
    // Barre des étapes : la moto en est à « Récupéré », le code de livraison n'est jamais affiché.
    expect(visible).toMatch(/Commande Livreur Récupéré Livré/);
    expect(html).toContain('aria-current="step">Récupéré');
    expect(html).toContain('class="rider s');
  });

  it('protège la page : CSP à nonce, pas de référent, pas d’indexation, pas de cache', async () => {
    const { app } = setup();
    const { res, html } = await page(app);
    const csp = res.headers.get('content-security-policy') ?? '';
    const nonce = /'nonce-([^']+)'/.exec(csp)?.[1];
    expect(nonce).toBeTruthy();
    expect(csp).toContain("default-src 'none'");
    expect(csp).toContain("form-action 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
    // Chaque script et style en ligne porte le nonce.
    expect(html.match(/<script nonce="([^"]+)"/)?.[1]).toBe(nonce);
    expect(html.match(/<style nonce="([^"]+)"/)?.[1]).toBe(nonce);
    expect(res.headers.get('referrer-policy')).toBe('no-referrer');
    expect(res.headers.get('x-robots-tag')).toContain('noindex');
    expect(res.headers.get('cache-control')).toBe('no-store');
  });

  it('reste légère : bien moins de 200 Ko avec polices et pictogramme', async () => {
    const { app } = setup();
    const { html } = await page(app);
    const assets = ['jakarta-500.woff', 'jakarta-800.woff', 'logo-clair.svg'].map(
      (name) => readFileSync(new URL(`../public/${name}`, import.meta.url)).byteLength,
    );
    const total = gzipSync(html).byteLength + assets.reduce((a, b) => a + b, 0);
    expect(total).toBeLessThan(200_000);
    // La page elle-même tient en quelques Ko compressés ; le seul script fait moins de 1 Ko.
    expect(gzipSync(html).byteLength).toBeLessThan(12_000);
    const script = /<script[^>]*>([\s\S]*?)<\/script>/.exec(html)?.[1] ?? '';
    expect(script.length).toBeLessThan(1_000);
  });

  it('chaque étape a son titre ; une course finie ne se recharge plus', async () => {
    const titles: [Parameters<typeof tracking>, string][] = [
      [['SEARCHING_RIDER'], 'Recherche d’un livreur'],
      [['ASSIGNED'], 'Un livreur va chercher votre colis'],
      [['DELIVERY_FAILED'], 'Le livreur n’a pas pu vous livrer'],
      [['DELIVERY_FAILED', { failureDecision: 'RETRY' }], 'Le livreur repasse vous livrer'],
      [['DELIVERY_FAILED', { failureDecision: 'RETURN' }], 'Le colis retourne chez l’expéditeur'],
      [['DELIVERED'], 'Colis livré'],
      [['RETURNED'], 'Colis rendu à l’expéditeur'],
      [['CANCELLED'], 'Livraison annulée'],
    ];
    for (const [args, title] of titles) {
      const { app } = setup(new FakeApi(tracking(...args)));
      const { html } = await page(app);
      expect(text(html), title).toContain(title);
      const final = ['DELIVERED', 'RETURNED', 'CANCELLED'].includes(args[0]);
      expect(html.includes('<script'), title).toBe(!final);
    }
    const { app } = setup(new FakeApi(tracking('DELIVERED')));
    const { html } = await page(app);
    expect(text(html)).toContain('Remis à 10:35');
    // Livré : plus de somme à payer ni de numéro du livreur.
    expect(html).not.toContain('tel:');
    expect(text(html)).not.toContain('À payer');
  });

  it('livraison programmée : le jour et l’heure', async () => {
    const { app } = setup(
      new FakeApi(tracking('CREATED', { scheduledFor: '2026-11-05T19:00:00.000Z' })),
    );
    const { html } = await page(app);
    expect(text(html)).toContain('Livraison prévue demain à 20:00');
  });

  it('demande Mobile Money du livreur : la page invite à la valider', async () => {
    const { app } = setup(
      new FakeApi(tracking('IN_DELIVERY', { paymentPending: { amount: 14000 } })),
    );
    const { html } = await page(app);
    expect(text(html)).toContain(
      `Une demande de 14${NBSP}000${NBSP}F est arrivée sur votre téléphone`,
    );
  });

  it('paiement par Mobile Money : frais de l’opérateur annoncés, compris dans la demande', async () => {
    const { app } = setup(
      new FakeApi(
        tracking('IN_DELIVERY', { mobileMoneyFee: 894, paymentPending: { amount: 14894 } }),
      ),
    );
    const { html } = await page(app);
    expect(text(html)).toContain(
      `Par Mobile Money, 894${NBSP}F de frais de l’opérateur s’ajoutent.`,
    );
    expect(text(html)).toContain(
      `Une demande de 14${NBSP}894${NBSP}F est arrivée sur votre téléphone`,
    );
  });

  it('frais déjà réglés et pas de colis à payer : rien à payer', async () => {
    const { app } = setup(
      new FakeApi(tracking('IN_DELIVERY', { due: { fee: 0, cod: 0, total: 0 } })),
    );
    const { html } = await page(app);
    expect(text(html)).toContain('Rien à payer');
  });

  it('« Serez-vous là ? » : réponse envoyée, puis merci', async () => {
    const api = new FakeApi(tracking('ASSIGNED'));
    const { app } = setup(api);
    const { html } = await page(app);
    expect(html).toContain(`action="/t/${TOKEN}/reponse"`);

    const res = await app.request(`/t/${TOKEN}/reponse`, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        // Première adresse falsifiée par le visiteur, dernière écrite par le relais.
        'x-forwarded-for': '6.6.6.6, 41.202.1.9',
      },
      body: new URLSearchParams({ available: 'no', note: '  Après 17 h  ' }).toString(),
    });
    expect(res.status).toBe(303);
    expect(res.headers.get('location')).toBe(`/t/${TOKEN}?r=no`);
    expect(api.responses).toEqual([
      { token: TOKEN, body: { available: false, note: 'Après 17 h' }, ip: '41.202.1.9' },
    ]);

    api.data = tracking('ASSIGNED', {
      canRespond: false,
      recipientConfirmedAt: NOW.toISOString(),
      recipientAvailable: false,
    });
    const after = await page(app, `/t/${TOKEN}?r=no`);
    expect(text(after.html)).toContain('L’expéditeur est prévenu et vous recontactera');
    expect(after.html).not.toContain('<form');
  });

  it('réponse déjà donnée, choix invalide : retour à la page sans erreur', async () => {
    const api = new FakeApi(tracking('ASSIGNED'));
    api.respondResult = 'already';
    const { app } = setup(api);
    const form = (available: string) =>
      app.request(`/t/${TOKEN}/reponse?lang=en`, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ available }).toString(),
      });
    expect((await form('yes')).headers.get('location')).toBe(`/t/${TOKEN}?lang=en&r=already`);
    expect((await form('peut-être')).headers.get('location')).toBe(`/t/${TOKEN}?lang=en`);
    expect(api.responses).toHaveLength(1);
  });

  it('lien inconnu ou mal formé : page « lien introuvable » (404)', async () => {
    const api = new FakeApi(null);
    const { app } = setup(api);
    const unknown = await page(app);
    expect(unknown.res.status).toBe(404);
    expect(text(unknown.html)).toContain('Lien introuvable');
    const malformed = await page(app, '/t/abc');
    expect(malformed.res.status).toBe(404);
    // Un jeton mal formé ne va jamais jusqu'à l'API.
    expect(api.views).toHaveLength(1);
  });

  it('API injoignable : page « réessayez » (503)', async () => {
    const api = new FakeApi();
    api.down = true;
    const { app } = setup(api);
    const { res, html } = await page(app);
    expect(res.status).toBe(503);
    expect(text(html)).toContain('Suivi momentanément indisponible');
    expect((await app.request(`/t/${TOKEN}/etat`)).status).toBe(503);
  });

  it('empreinte de l’état pour le rechargement automatique', async () => {
    const api = new FakeApi(tracking('PICKED_UP'));
    const { app } = setup(api);
    const first = (await (await app.request(`/t/${TOKEN}/etat`)).json()) as { v: string };
    expect(first.v).toBe(fingerprint(tracking('PICKED_UP')));
    api.data = tracking('IN_DELIVERY');
    const second = (await (await app.request(`/t/${TOKEN}/etat`)).json()) as { v: string };
    expect(second.v).not.toBe(first.v);
    const { html } = await page(app);
    expect(html).toContain(`data-v="${second.v.replace(/\|/g, '|')}"`);
  });

  it('en anglais selon le téléphone, ou au choix', async () => {
    const { app } = setup();
    const en = await page(app, `/t/${TOKEN}`, { 'accept-language': 'en-GB,en;q=0.9' });
    expect(text(en.html)).toContain('Jean M. is on the way to you');
    expect(en.html).toContain('lang="en"');
    const fr = await page(app, `/t/${TOKEN}?lang=fr`, { 'accept-language': 'en' });
    expect(text(fr.html)).toContain('Jean M. arrive chez vous');
  });

  it('sert les polices et le pictogramme, mis en cache', async () => {
    const { app } = setup();
    const font = await app.request('/static/jakarta-800.woff');
    expect(font.status).toBe(200);
    expect(font.headers.get('content-type')).toBe('font/woff');
    expect(font.headers.get('cache-control')).toContain('max-age=604800');
    expect((await app.request('/static/../package.json')).status).toBe(404);
  });
});

describe('client de l’API', () => {
  it('lit la page, transmet l’adresse du visiteur, distingue 404 et panne', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fake = (status: number, body: unknown = {}) =>
      (async (url: string | URL | Request, init?: RequestInit) => {
        calls.push({ url: url instanceof Request ? url.url : url.toString(), init: init ?? {} });
        return new Response(JSON.stringify(body), { status });
      }) as typeof fetch;
    const data = tracking('IN_DELIVERY');
    expect(await httpApi('http://api/', fake(200, data)).view(TOKEN, '41.202.1.9')).toEqual(data);
    expect(calls[0]?.url).toBe(`http://api/v1/public/tracking/${TOKEN}`);
    const sent = calls[0]?.init.headers as Record<string, string> | undefined;
    expect(sent?.['x-forwarded-for']).toBe('41.202.1.9');
    expect(await httpApi('http://api', fake(404)).view(TOKEN)).toBeNull();
    await expect(httpApi('http://api', fake(500)).view(TOKEN)).rejects.toThrow('API : 500');
    expect(await httpApi('http://api', fake(409)).respond(TOKEN, { available: true })).toBe(
      'already',
    );
    const failing = (async () => {
      throw new TypeError('fetch failed');
    }) as typeof fetch;
    await expect(httpApi('http://api', failing).view(TOKEN)).rejects.toThrow('API injoignable');
  });

  it('lit des champs que le contrat de l’API publie', () => {
    const contract = JSON.parse(
      readFileSync(new URL('../../api/openapi.json', import.meta.url), 'utf8'),
    ) as {
      components: { schemas: Record<string, { properties?: Record<string, unknown> }> };
    };
    const properties = Object.keys(contract.components.schemas['PublicTracking']?.properties ?? {});
    expect(properties).toEqual(expect.arrayContaining(PUBLIC_TRACKING_FIELDS));
  });
});
