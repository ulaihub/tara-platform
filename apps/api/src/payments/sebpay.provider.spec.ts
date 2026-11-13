import { createHmac } from 'node:crypto';
import { ProviderUnavailableError } from './payment.provider.js';
import { cameroonOperator, SebpayError, SebpayPaymentProvider } from './sebpay.provider.js';

const json = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const ok = (data: unknown): Response => json(200, { success: true, data, message: 'ok' });
const refused = (status: number, code: string): Response =>
  json(status, { success: false, message: code, errors: { code } });

const SECRET = 'sk_test_secret_de_test_0123456789';
const BASE = 'https://api.sandbox.sebpay.bj/api/v1';

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: Record<string, unknown> | null;
}

function provider(responses: (Response | Error)[]): {
  sebpay: SebpayPaymentProvider;
  calls: Call[];
} {
  const calls: Call[] = [];
  const fetchFake = (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({
      url: typeof input === 'string' ? input : input instanceof URL ? input.href : input.url,
      method: init?.method ?? 'GET',
      headers: (init?.headers ?? {}) as Record<string, string>,
      body:
        typeof init?.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : null,
    });
    const next = responses.shift();
    if (next instanceof Error) return Promise.reject(next);
    return next ? Promise.resolve(next) : Promise.reject(new Error('Aucune réponse prévue'));
  };
  const sebpay = new SebpayPaymentProvider({
    baseUrl: BASE,
    publicKey: 'pk_test_public',
    secretKey: SECRET,
    callbackUrl: 'https://api.tara.test/v1/webhooks/payments/sebpay',
    fetch: fetchFake as typeof fetch,
  });
  return { sebpay, calls };
}

const signed = (payload: object) => {
  const rawBody = Buffer.from(JSON.stringify(payload));
  const signature = createHmac('sha256', SECRET).update(rawBody).digest('hex');
  return { rawBody, signature };
};

describe('Sebpay', () => {
  it('reconnaît l’opérateur d’un numéro camerounais', () => {
    expect(cameroonOperator('+237670112233')).toBe('MTN');
    expect(cameroonOperator('+237652112233')).toBe('MTN');
    expect(cameroonOperator('+237683112233')).toBe('MTN');
    expect(cameroonOperator('+237690112233')).toBe('ORANGE');
    expect(cameroonOperator('+237656112233')).toBe('ORANGE');
    expect(cameroonOperator('+237687112233')).toBe('ORANGE');
    expect(cameroonOperator('+237662112233')).toBeNull();
    expect(cameroonOperator('+22997000000')).toBeNull();
  });

  it('demande un paiement : clés, XAF, Cameroun, opérateur, notre référence, adresse de rappel', async () => {
    const { sebpay, calls } = provider([
      ok({ transaction_id: 'sp-1', status: 'pending', external_reference: 'pay-1' }),
    ]);
    const operation = await sebpay.collect({
      reference: 'pay-1',
      amount: 1500,
      phone: '+237690112233',
      description: 'Course TR-1',
    });
    expect(operation).toEqual({ providerReference: 'sp-1', status: 'PENDING' });
    expect(calls[0]).toMatchObject({
      url: `${BASE}/collections`,
      method: 'POST',
      headers: { 'X-Public-Key': 'pk_test_public', 'X-Secret-Key': SECRET },
      body: {
        amount: 1500,
        currency: 'XAF',
        phone: '237690112233',
        operator: 'orange',
        country: 'CM',
        external_reference: 'pay-1',
        callback_url: 'https://api.tara.test/v1/webhooks/payments/sebpay',
      },
    });
  });

  it('suit l’opérateur choisi par le payeur plutôt que le numéro', async () => {
    const { sebpay, calls } = provider([ok({ transaction_id: 'sp-2', status: 'pending' })]);
    await sebpay.collect({
      reference: 'pay-2',
      amount: 500,
      phone: '+237690112233',
      operator: 'MTN',
      description: 'x',
    });
    expect(calls[0]?.body).toMatchObject({ operator: 'mtn' });
  });

  it('refus de l’opérateur : erreur nette ; serveur indisponible ou coupure : issue inconnue', async () => {
    const declined = provider([refused(400, 'PAYMENT_DECLINED')]);
    await expect(
      declined.sebpay.collect({
        reference: 'p',
        amount: 500,
        phone: '+237670112233',
        description: 'x',
      }),
    ).rejects.toBeInstanceOf(SebpayError);

    for (const answer of [
      refused(503, 'OPERATOR_MAINTENANCE'),
      refused(429, 'RATE_LIMITED'),
      refused(409, 'REQUEST_IN_PROGRESS'),
      new TypeError('fetch failed'),
    ]) {
      const { sebpay } = provider([answer]);
      await expect(
        sebpay.collect({ reference: 'p', amount: 500, phone: '+237670112233', description: 'x' }),
      ).rejects.toBeInstanceOf(ProviderUnavailableError);
    }
  });

  it('reverse : nom du bénéficiaire, frais rendus ; solde Sebpay vide = à réessayer, pas un échec', async () => {
    const { sebpay, calls } = provider([
      ok({ transaction_id: 'po-1', status: 'pending', fee_amount: 125, total_deducted: 5125 }),
    ]);
    const operation = await sebpay.disburse({
      reference: 'payout-1',
      amount: 5000,
      phone: '+237670112233',
      operator: 'MTN',
      recipientName: 'Chez Mama Ngo',
      description: 'Tara reversement',
    });
    expect(operation).toEqual({ providerReference: 'po-1', status: 'PENDING', fee: 125 });
    expect(calls[0]).toMatchObject({
      url: `${BASE}/payouts`,
      body: {
        recipient_name: 'Chez Mama Ngo',
        phone: '237670112233',
        operator: 'mtn',
        country: 'CM',
        amount: 5000,
        currency: 'XAF',
        external_reference: 'payout-1',
      },
    });

    const empty = provider([refused(400, 'INSUFFICIENT_BALANCE')]);
    await expect(
      empty.sebpay.disburse({
        reference: 'p2',
        amount: 5000,
        phone: '+237670112233',
        description: 'x',
      }),
    ).rejects.toBeInstanceOf(ProviderUnavailableError);
  });

  it('statut d’un reversement par notre référence ; inconnu de Sebpay : null (renvoi sans risque)', async () => {
    const { sebpay, calls } = provider([
      ok({
        transaction_id: 'po-1',
        external_reference: 'payout-1',
        status: 'approved',
        amount: 5000,
        fee_amount: 125,
      }),
      json(404, { success: false, message: 'Not found' }),
    ]);
    expect(await sebpay.disburseStatus('payout-1')).toEqual({
      providerReference: 'po-1',
      status: 'SUCCEEDED',
      amount: 5000,
      fee: 125,
    });
    expect(calls[0]?.url).toBe(`${BASE}/payouts/payout-1`);
    expect(await sebpay.disburseStatus('payout-2')).toBeNull();
  });

  it('paiement réussi : frais lus au tarif du compte', async () => {
    const { sebpay, calls } = provider([
      ok({ transaction_id: 'sp-1', status: 'approved', amount: 1500 }),
      ok({ fee_amount: 52.5, fee_percentage: 3.5, pricing: 'account' }),
    ]);
    expect(await sebpay.collectStatus('sp-1')).toEqual({
      providerReference: 'sp-1',
      status: 'SUCCEEDED',
      amount: 1500,
      fee: 53,
    });
    expect(calls[1]?.url).toBe(
      `${BASE}/c/calculate-fee?amount=1500&source_country=cm&transaction_type=collection`,
    );
  });

  it('notification : signature HMAC du corps brut exigée', async () => {
    const { sebpay } = provider([]);
    const payload = {
      transaction_id: 'sp-1',
      external_reference: 'pay-1',
      status: 'approved',
      amount: 1500,
      currency: 'XAF',
    };
    const { rawBody, signature } = signed(payload);
    const event = await sebpay.parseWebhook({
      rawBody,
      headers: { 'x-sebpay-signature': signature },
      query: {},
      body: payload,
    });
    expect(event).toEqual({
      eventId: 'sp-1:SUCCEEDED',
      reference: 'pay-1',
      providerReference: 'sp-1',
      status: 'SUCCEEDED',
      amount: 1500,
    });

    // Corps modifié après signature (montant gonflé) : refusé.
    const forged = Buffer.from(JSON.stringify({ ...payload, amount: 150000 }));
    await expect(
      sebpay.parseWebhook({
        rawBody: forged,
        headers: { 'x-sebpay-signature': signature },
        query: {},
        body: {},
      }),
    ).rejects.toThrow('Signature Sebpay invalide');
    await expect(
      sebpay.parseWebhook({ rawBody, headers: {}, query: {}, body: {} }),
    ).rejects.toThrow('Signature Sebpay absente');
  });

  it('notification confirmée par l’API : la collecte d’abord, sinon le payout', async () => {
    const { sebpay, calls } = provider([
      json(404, { success: false, message: 'Not found' }),
      ok({
        transaction_id: 'po-1',
        external_reference: 'payout-1',
        status: 'rejected',
        amount: 5000,
      }),
    ]);
    const confirmed = await sebpay.confirmEvent({
      eventId: 'po-1:SUCCEEDED',
      reference: 'payout-1',
      providerReference: 'po-1',
      status: 'SUCCEEDED',
      amount: 5000,
    });
    expect(confirmed).toMatchObject({ status: 'FAILED', reference: 'payout-1', amount: 5000 });
    expect(calls.map((c) => c.url)).toEqual([`${BASE}/collections/po-1`, `${BASE}/payouts/po-1`]);
  });

  it('rapprochement : chaque opération relue par notre référence', async () => {
    const { sebpay } = provider([
      ok({
        transaction_id: 'sp-9',
        external_reference: 'pay-9',
        status: 'approved',
        amount: 2000,
        created_at: '2026-11-11T10:00:00.000000Z',
      }),
      ok({ fee_amount: 70 }),
      json(404, { success: false, message: 'Not found' }),
    ]);
    expect(await sebpay.lookup('COLLECT', 'pay-9')).toEqual({
      providerReference: 'sp-9',
      reference: 'pay-9',
      kind: 'COLLECT',
      amount: 2000,
      fee: 70,
      status: 'SUCCEEDED',
      at: new Date('2026-11-11T10:00:00.000Z'),
    });
    expect(await sebpay.lookup('DISBURSE', 'payout-x')).toBeNull();
  });
});
