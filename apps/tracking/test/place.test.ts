import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { httpApi, PUBLIC_LOCATION_LINK_FIELDS } from '../src/api.js';
import { cameroonMobile, createApp } from '../src/app.js';
import { FakeApi, locationLink, NOW, TOKEN } from './fixtures.js';

function setup(api = new FakeApi()) {
  const app = createApp({ api, now: () => NOW });
  return { api, app };
}

const text = (html: string) => html.replace(/<[^>]+>/g, ' ').replace(/[ \n]+/g, ' ');

/** Formulaire envoyé comme par le navigateur. */
function send(app: ReturnType<typeof setup>['app'], fields: Record<string, string>, query = '') {
  return app.request(`/l/${TOKEN}${query}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
      'x-forwarded-for': '41.202.1.9',
    },
    body: new URLSearchParams(fields).toString(),
  });
}

const POINT = { latitude: '4.021345', longitude: '9.695123', accuracy: '12' };

describe('lien de localisation : le destinataire place son point (B3)', () => {
  it('explique, demande la position puis un repère ; envoi bloqué sans position', async () => {
    const { app } = setup();
    const res = await app.request(`/l/${TOKEN}`);
    expect(res.status).toBe(200);
    const html = await res.text();
    const visible = text(html);
    expect(visible).toContain('Awa Fashion vous envoie un colis');
    expect(visible).toContain('Placez votre point pour que le livreur vous trouve.');
    expect(visible).toContain('Placez votre point');
    expect(visible).toContain('Ma position');
    expect(visible).toContain('Un repère pour le livreur');
    // Nom du destinataire proposé, numéro libre.
    expect(html).toContain('value="Marie Ngo"');
    // 17:00 UTC = 18:00 à Douala.
    expect(visible).toContain('Lien valable jusqu’au 6 novembre à 18:00.');
    expect(visible).toContain('Lien valable jusqu’au 06/11');
    expect(html).toMatch(/<button id="send" type="submit" class="btn primary block big" disabled/);
    expect(html).toContain('<noscript>');
    expect(res.headers.get('permissions-policy')).toContain('geolocation=(self)');
  });

  it('deux scripts : la lecture de la position et la carte, avec le nonce de la page', async () => {
    const { app } = setup();
    const res = await app.request(`/l/${TOKEN}`);
    const html = await res.text();
    const nonce = /'nonce-([^']+)'/.exec(res.headers.get('content-security-policy') ?? '')?.[1];
    const scripts = [...html.matchAll(/<script nonce="([^"]+)">([\s\S]*?)<\/script>/g)];
    expect(scripts).toHaveLength(2);
    for (const script of scripts) expect(script[1]).toBe(nonce);
    expect(scripts[0]?.[2]).toContain('navigator.geolocation.getCurrentPosition');
    expect(scripts[0]?.[2]?.length).toBeLessThan(2_000);
    // Carte : MapLibre servi par la page, chargé après elle ; épingle déplaçable.
    expect(scripts[1]?.[2]).toContain('import("/carte/maplibre-gl.mjs');
    expect(html).toContain('id="carte"');
    // La page de suivi garde la localisation interdite.
    const tracking = await app.request(`/t/${TOKEN}`);
    expect(tracking.headers.get('permissions-policy')).toContain('geolocation=()');
  });

  it('envoie le point, le repère et le numéro au bon format, puis remercie', async () => {
    const { app, api } = setup();
    const res = await send(app, {
      ...POINT,
      landmark: '  Portail bleu après la pharmacie  ',
      name: 'Marie',
      phone: '6 77 12 34 56',
    });
    expect(res.status).toBe(303);
    expect(res.headers.get('location')).toBe(`/l/${TOKEN}?r=ok`);
    expect(api.submissions).toEqual([
      {
        token: TOKEN,
        ip: '41.202.1.9',
        body: {
          latitude: 4.021345,
          longitude: 9.695123,
          landmark: 'Portail bleu après la pharmacie',
          contactName: 'Marie',
          contactPhone: '+237677123456',
        },
      },
    ]);
    const thanks = await app.request(`/l/${TOKEN}?r=ok`);
    expect(thanks.status).toBe(200);
    const visible = text(await thanks.text());
    expect(visible).toContain('Merci, c’est noté !');
    expect(visible).toContain('Awa Fashion l’a reçu.');
  });

  it('refuse sans position, sans repère ou avec un numéro faux, en gardant la saisie', async () => {
    const { app, api } = setup();
    const noPoint = await send(app, { landmark: 'Portail bleu' });
    expect(noPoint.status).toBe(422);
    const html = await noPoint.text();
    expect(text(html)).toContain('Touchez « Ma position » avant de valider.');
    expect(html).toContain('Portail bleu</textarea>');

    const short = await send(app, { ...POINT, landmark: 'ok' });
    expect(text(await short.text())).toContain('Décrivez un repère');
    const kept = await send(app, { ...POINT, landmark: 'Portail bleu', phone: '590123456' });
    const keptHtml = await kept.text();
    expect(text(keptHtml)).toContain('Numéro invalide');
    // Position déjà prise : gardée, l'envoi reste possible.
    expect(keptHtml).toContain('value="4.021345"');
    expect(keptHtml).not.toMatch(/id="send"[^>]*disabled/);
    expect(api.submissions).toEqual([]);
  });

  it('point hors de Douala : expliqué, à reprendre', async () => {
    const api = new FakeApi();
    api.submitResult = 'out-of-area';
    const { app } = setup(api);
    const res = await send(app, { ...POINT, landmark: 'Portail bleu' });
    expect(res.status).toBe(422);
    expect(text(await res.text())).toContain('hors de la zone desservie par Tara');
  });

  it('lien déjà utilisé ou expiré : message clair, sans formulaire', async () => {
    const api = new FakeApi();
    api.link = locationLink({ status: 'SUBMITTED' });
    const { app } = setup(api);
    const used = await app.request(`/l/${TOKEN}`);
    expect(used.status).toBe(200);
    const usedText = text(await used.text());
    expect(usedText).toContain('Point déjà envoyé');
    expect(usedText).toContain('contactez Awa Fashion');
    expect(usedText).not.toContain('Valider mon point');

    api.link = locationLink({ status: 'EXPIRED', senderName: null });
    const expired = await app.request(`/l/${TOKEN}?lang=en`);
    expect(expired.status).toBe(410);
    const expiredText = text(await expired.text());
    expect(expiredText).toContain('This link has expired');
    expect(expiredText).toContain('Ask the sender for a new link.');
  });

  it('envoyé deux fois ou expiré entre-temps : retour à la page du lien', async () => {
    const api = new FakeApi();
    api.submitResult = 'already';
    const { app } = setup(api);
    const res = await send(app, { ...POINT, landmark: 'Portail bleu' }, '?lang=en');
    expect(res.status).toBe(303);
    expect(res.headers.get('location')).toBe(`/l/${TOKEN}?lang=en`);
  });

  it('lien inconnu, mal formé ou API injoignable', async () => {
    const api = new FakeApi();
    api.link = null;
    const { app } = setup(api);
    expect((await app.request(`/l/${TOKEN}`)).status).toBe(404);
    expect((await app.request('/l/court')).status).toBe(404);
    api.down = true;
    expect((await app.request(`/l/${TOKEN}`)).status).toBe(503);
    expect((await send(app, { ...POINT, landmark: 'Portail bleu' })).status).toBe(503);
  });

  it('numéros camerounais saisis librement', () => {
    expect(cameroonMobile('')).toBe('');
    expect(cameroonMobile('677 12 34 56')).toBe('+237677123456');
    expect(cameroonMobile('+237 6 77 12 34 56')).toBe('+237677123456');
    expect(cameroonMobile('00237677123456')).toBe('+237677123456');
    expect(cameroonMobile('233 42 00 00')).toBeNull();
    expect(cameroonMobile('6771234')).toBeNull();
  });
});

describe('client de l’API : lien de localisation', () => {
  it('lit le lien et traduit les refus de l’API', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fake = (status: number, body: unknown = {}) =>
      (async (url: string | URL | Request, init?: RequestInit) => {
        calls.push({ url: url instanceof Request ? url.url : url.toString(), init: init ?? {} });
        return new Response(JSON.stringify(body), { status });
      }) as typeof fetch;
    const link = locationLink();
    expect(await httpApi('http://api/', fake(200, link)).locationLink(TOKEN, '41.202.1.9')).toEqual(
      link,
    );
    expect(calls[0]?.url).toBe(`http://api/v1/public/location-links/${TOKEN}`);
    expect(await httpApi('http://api', fake(404)).locationLink(TOKEN)).toBeNull();
    const body = { latitude: 4.02, longitude: 9.69, landmark: 'Portail bleu' };
    const submit = (status: number, payload: unknown = {}) =>
      httpApi('http://api', fake(status, payload)).submitLocation(TOKEN, body);
    expect(await submit(200)).toBe('ok');
    expect(JSON.parse(calls.at(-1)?.init.body as string)).toEqual(body);
    expect(await submit(409)).toBe('already');
    expect(await submit(410)).toBe('expired');
    expect(await submit(400)).toBe('invalid');
    expect(await submit(422, { error: { code: 'OUT_OF_SERVICE_AREA' } })).toBe('out-of-area');
    await expect(submit(500)).rejects.toThrow('API : 500');
  });

  it('lit des champs que le contrat de l’API publie', () => {
    const contract = JSON.parse(
      readFileSync(new URL('../../api/openapi.json', import.meta.url), 'utf8'),
    ) as {
      components: { schemas: Record<string, { properties?: Record<string, unknown> }> };
    };
    const properties = Object.keys(
      contract.components.schemas['PublicLocationLink']?.properties ?? {},
    );
    expect(properties).toEqual(expect.arrayContaining(PUBLIC_LOCATION_LINK_FIELDS));
  });
});
