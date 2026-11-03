import { SignJWT } from 'jose';
import { CamPayPaymentProvider } from './campay.provider.js';

const json = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('CamPay', () => {
  const webhookKey = 'cle-webhook-campay-de-test-0123';

  function provider(responses: Response[]): { campay: CamPayPaymentProvider; urls: string[] } {
    const urls: string[] = [];
    const fetchFake = (input: string | URL | Request): Promise<Response> => {
      urls.push(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
      const next = responses.shift();
      return next ? Promise.resolve(next) : Promise.reject(new Error('Aucune réponse prévue'));
    };
    const campay = new CamPayPaymentProvider({
      baseUrl: 'https://demo.campay.net/api',
      username: 'u',
      password: 'p',
      webhookKey,
      fetch: fetchFake as typeof fetch,
    });
    return { campay, urls };
  }

  it('refuse une notification dont la signature est invalide', async () => {
    const { campay } = provider([]);
    await expect(
      campay.parseWebhook({
        rawBody: undefined,
        headers: {},
        query: { reference: 'r1', status: 'SUCCESSFUL', signature: 'faux' },
        body: {},
      }),
    ).rejects.toThrow('Signature CamPay invalide');
  });

  it('ne croit pas le statut annoncé : il est relu par l’API', async () => {
    const { campay, urls } = provider([
      json(200, { token: 't', expires_in: 3600 }),
      json(200, { reference: 'r1', status: 'FAILED', amount: 1500, external_reference: 'p1' }),
    ]);
    const signature = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .sign(new TextEncoder().encode(webhookKey));
    const event = await campay.parseWebhook({
      rawBody: undefined,
      headers: {},
      query: {
        reference: 'r1',
        status: 'SUCCESSFUL',
        amount: '9999',
        signature,
        external_reference: 'p1',
      },
      body: {},
    });
    expect(event.status).toBe('SUCCEEDED');
    const confirmed = await campay.confirmEvent(event);
    expect(confirmed).toMatchObject({ status: 'FAILED', amount: 1500, reference: 'p1' });
    expect(urls.at(-1)).toBe('https://demo.campay.net/api/transaction/r1/');
  });
});
