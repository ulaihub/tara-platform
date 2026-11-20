import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { httpApi, PUBLIC_RECEIPT_FIELDS } from '../src/api.js';
import { createApp } from '../src/app.js';
import { FakeApi, NOW, RECEIPT_CODE, receipt } from './fixtures.js';

const NBSP = '\u00a0';
const text = (html: string) => html.replace(/<[^>]+>/g, ' ').replace(/[ \n]+/g, ' ');

function setup(api = new FakeApi()) {
  return { api, app: createApp({ api, now: () => NOW }) };
}

describe('vérifier un reçu (QR du reçu imprimé)', () => {
  it('reçu authentique : ce qui est imprimé, à comparer au papier', async () => {
    const { app, api } = setup();
    const res = await app.request(`/r/${RECEIPT_CODE}`);
    expect(res.status).toBe(200);
    const visible = text(await res.text());
    expect(api.receiptCodes).toEqual([RECEIPT_CODE]);
    expect(visible).toContain('Reçu authentique');
    expect(visible).toContain('N° TR-48301K');
    // 13:32 UTC = 14:32 à Douala.
    expect(visible).toContain('19/11/2026 à 14:32');
    expect(visible).toContain('Awa Fashion');
    expect(visible).toContain('Marie N. · Bonapriso');
    expect(visible).toContain(`1${NBSP}200${NBSP}F · payée`);
    expect(visible).toContain('19/11/2026 à 15:24');
    expect(visible).toContain(`15${NBSP}000${NBSP}F`);
    expect(visible).toContain('il ne permet jamais de retirer un colis');
  });

  it('code faux ou inconnu : « Reçu introuvable » en 404', async () => {
    const { app, api } = setup();
    api.receiptData = null;
    const res = await app.request(`/r/${RECEIPT_CODE}`);
    expect(res.status).toBe(404);
    const visible = text(await res.text());
    expect(visible).toContain('Reçu introuvable');
    expect(visible).not.toContain('N° TR-');
  });

  it('code mal formé : rien n’est demandé à l’API', async () => {
    const { app, api } = setup();
    const res = await app.request('/r/TR-48301K');
    expect(res.status).toBe(404);
    expect(text(await res.text())).toContain('Reçu introuvable');
    expect(api.receiptCodes).toEqual([]);
  });

  it('course annulée, rien encaissé : pas de ligne de livraison ni d’encaissement', async () => {
    const { app, api } = setup();
    api.receiptData = receipt({
      status: 'CANCELLED',
      deliveredAt: null,
      collectedForSender: null,
      feePaid: false,
    });
    const visible = text(await (await app.request(`/r/${RECEIPT_CODE}`)).text());
    expect(visible).toContain('Commande annulée');
    expect(visible).toContain('à payer');
    expect(visible).not.toContain('Livré le');
    expect(visible).not.toContain('Encaissé');
  });

  it('API injoignable : page « réessayer » en 503', async () => {
    const { app, api } = setup();
    api.down = true;
    const res = await app.request(`/r/${RECEIPT_CODE}`);
    expect(res.status).toBe(503);
  });

  it('en anglais au choix', async () => {
    const { app } = setup();
    const visible = text(await (await app.request(`/r/${RECEIPT_CODE}?lang=en`)).text());
    expect(visible).toContain('Genuine receipt');
    expect(visible).toContain('No. TR-48301K');
  });

  it('client HTTP : chemin de l’API, 404 → null', async () => {
    const calls: string[] = [];
    const fake = (status: number, body: unknown) =>
      (async (input: string) => {
        calls.push(input);
        return new Response(JSON.stringify(body), { status });
      }) as unknown as typeof fetch;
    const data = receipt();
    expect(await httpApi('http://api/', fake(200, data)).receipt(RECEIPT_CODE)).toEqual(data);
    expect(calls[0]).toBe(`http://api/v1/public/receipts/${RECEIPT_CODE}`);
    expect(await httpApi('http://api', fake(404, {})).receipt(RECEIPT_CODE)).toBeNull();
    await expect(httpApi('http://api', fake(500, {})).receipt(RECEIPT_CODE)).rejects.toThrow(
      'API : 500',
    );
  });

  it('lit des champs que le contrat de l’API publie', () => {
    const contract = JSON.parse(
      readFileSync(new URL('../../api/openapi.json', import.meta.url), 'utf8'),
    ) as {
      components: { schemas: Record<string, { properties?: Record<string, unknown> }> };
    };
    const properties = Object.keys(contract.components.schemas['PublicReceipt']?.properties ?? {});
    expect(properties).toEqual(expect.arrayContaining(PUBLIC_RECEIPT_FIELDS));
    expect(properties).not.toContain('recipientPhone');
  });
});
