import { Redis } from 'ioredis';
import { OrangeSmsProvider } from './orange-sms.provider.js';
import { FailoverSmsProvider, MeteredSmsProvider } from './resilient-sms.provider.js';
import type { SmsProvider } from './sms.provider.js';
import { TwilioSmsProvider } from './twilio-sms.provider.js';

interface Call {
  url: string;
  init: RequestInit;
}

/** Faux `fetch` qui répond dans l'ordre aux appels reçus. */
function fakeFetch(responses: Response[]): { fetch: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];
  const fn = (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    calls.push({ url, init: init ?? {} });
    const next = responses.shift();
    return next ? Promise.resolve(next) : Promise.reject(new Error('Aucune réponse prévue'));
  };
  return { fetch: fn as typeof fetch, calls };
}

/** En-tête d'un appel enregistré. */
function header(call: Call | undefined, name: string): string | undefined {
  return (call?.init.headers as Record<string, string> | undefined)?.[name];
}

/** Corps texte d'un appel enregistré. */
function bodyOf(call: Call | undefined): string {
  const body = call?.init.body;
  return typeof body === 'string' ? body : body instanceof URLSearchParams ? body.toString() : '';
}

const json = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const token = (value: string) =>
  json(200, { token_type: 'Bearer', access_token: value, expires_in: 3600 });

const sent = json(201, {
  outboundSMSMessageRequest: {
    resourceURL:
      'https://api.orange.com/smsmessaging/v1/outbound/tel%3A%2B237690000000/requests/abc-123',
  },
});

describe('fournisseurs SMS', () => {
  describe('Orange', () => {
    it('obtient un jeton, envoie au format smsmessaging et garde le jeton', async () => {
      const { fetch, calls } = fakeFetch([token('t1'), sent, json(201, {})]);
      const orange = new OrangeSmsProvider({
        clientId: 'client',
        clientSecret: 'secret',
        senderPhone: '+237690000000',
        senderName: 'TARA',
        fetch,
      });
      await expect(orange.send('+237677123456', 'Bonjour')).resolves.toEqual({
        providerReference: 'abc-123',
        provider: 'orange',
      });
      expect(calls[0]?.url).toBe('https://api.orange.com/oauth/v3/token');
      expect(header(calls[0], 'Authorization')).toBe(
        `Basic ${Buffer.from('client:secret').toString('base64')}`,
      );
      expect(calls[1]?.url).toBe(
        'https://api.orange.com/smsmessaging/v1/outbound/tel%3A%2B237690000000/requests',
      );
      expect(JSON.parse(bodyOf(calls[1]))).toEqual({
        outboundSMSMessageRequest: {
          address: 'tel:+237677123456',
          senderAddress: 'tel:+237690000000',
          senderName: 'TARA',
          outboundSMSTextMessage: { message: 'Bonjour' },
        },
      });
      await orange.send('+237677123456', 'Encore');
      expect(calls).toHaveLength(3); // Pas de nouveau jeton.
    });

    it('renouvelle un jeton refusé une fois, et rapporte un refus sans le numéro', async () => {
      const { fetch, calls } = fakeFetch([
        token('t1'),
        json(401, {}),
        token('t2'),
        json(403, { requestError: { policyException: { messageId: 'POL3003' } } }),
      ]);
      const orange = new OrangeSmsProvider({
        clientId: 'client',
        clientSecret: 'secret',
        senderPhone: '+237690000000',
        fetch,
      });
      await expect(orange.send('+237677123456', 'Bonjour')).rejects.toThrow(
        'Envoi Orange refusé (403 POL3003)',
      );
      expect(header(calls[3], 'Authorization')).toBe('Bearer t2');
    });
  });

  it('Twilio : envoi en formulaire avec authentification de base', async () => {
    const { fetch, calls } = fakeFetch([json(201, { sid: 'SM123', status: 'queued' })]);
    const twilio = new TwilioSmsProvider({
      accountSid: `AC${'0'.repeat(32)}`,
      authToken: 'jeton-twilio-0000',
      from: 'TARA',
      fetch,
    });
    await expect(twilio.send('+237677123456', 'Bonjour')).resolves.toEqual({
      providerReference: 'SM123',
      provider: 'twilio',
    });
    expect(bodyOf(calls[0])).toBe('To=%2B237677123456&From=TARA&Body=Bonjour');
  });

  it('bascule sur le secours quand le principal échoue', async () => {
    const failing: SmsProvider = {
      name: 'orange',
      send: () => Promise.reject(new Error('panne')),
    };
    const backup: SmsProvider = {
      name: 'twilio',
      send: () => Promise.resolve({ providerReference: 'SM1' }),
    };
    const failover = new FailoverSmsProvider([failing, backup]);
    expect(failover.name).toBe('orange>twilio');
    await expect(failover.send('+237677123456', 'x')).resolves.toEqual({
      providerReference: 'SM1',
      provider: 'twilio',
    });
    await expect(new FailoverSmsProvider([failing]).send('+237677123456', 'x')).rejects.toThrow(
      'panne',
    );
  });

  describe('volume quotidien', () => {
    let redis: Redis;
    beforeAll(async () => {
      redis = new Redis(process.env['TEST_REDIS_URL'] ?? 'redis://localhost:6379/1', {
        keyPrefix: `tara-spec-${Date.now()}:`,
        lazyConnect: true,
      });
      await redis.connect();
    });
    afterAll(async () => {
      await redis.quit();
    });

    it('alerte une seule fois à 80 % puis à 100 % du seuil', async () => {
      const alerts: number[] = [];
      const inner: SmsProvider = {
        name: 'orange',
        send: () => Promise.resolve({ providerReference: 'x' }),
      };
      const metered = new MeteredSmsProvider(inner, redis, 5, (level) => alerts.push(level));
      for (let i = 0; i < 7; i += 1) await metered.send('+237677123456', 'x');
      expect(alerts).toEqual([80, 100]);
    });
  });
});
