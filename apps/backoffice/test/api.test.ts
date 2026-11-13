import { describe, expect, it, vi } from 'vitest';
import { ApiError, api } from '@/lib/api';

function reply(status: number, body?: unknown) {
  return vi.fn<typeof fetch>(() =>
    Promise.resolve(
      new Response(body === undefined ? null : JSON.stringify(body), {
        status,
        headers: { 'content-type': 'application/json' },
      }),
    ),
  );
}

describe('appel à l’API', () => {
  it('envoie le jeton, la langue et les paramètres utiles', async () => {
    const fetcher = reply(200, { ok: true });
    await api('/admin/orders', {
      token: 'jeton',
      query: { status: 'ASSIGNED', page: 2, q: '', x: undefined },
      fetcher,
    });
    const [url, init] = fetcher.mock.calls[0] ?? [];
    expect(url).toEqual(new URL('http://localhost:3000/v1/admin/orders?status=ASSIGNED&page=2'));
    expect(init?.headers).toMatchObject({ authorization: 'Bearer jeton', 'accept-language': 'fr' });
    expect(init?.body).toBeUndefined();
  });

  it('envoie le corps en JSON', async () => {
    const fetcher = reply(200, {});
    await api('/auth/otp/request', { method: 'POST', body: { phone: '+237677123456' }, fetcher });
    const init = fetcher.mock.calls[0]?.[1];
    expect(init?.method).toBe('POST');
    expect(init?.body).toBe('{"phone":"+237677123456"}');
    expect(init?.headers).toMatchObject({ 'content-type': 'application/json' });
  });

  it('rend null sur 204', async () => {
    expect(await api('/auth/logout', { method: 'POST', fetcher: reply(204) })).toBeNull();
  });

  it('transmet le code et les détails d’une erreur', async () => {
    const fetcher = reply(401, {
      error: { code: 'MFA_REQUIRED', message: 'Second facteur', details: { enrolled: true } },
    });
    const error = await api('/me', { fetcher }).catch((caught: unknown) => caught);
    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({ status: 401, code: 'MFA_REQUIRED', details: { enrolled: true } });
  });

  it('signale une API injoignable', async () => {
    const fetcher = vi.fn<typeof fetch>(() => Promise.reject(new TypeError('fetch failed')));
    await expect(api('/me', { fetcher })).rejects.toMatchObject({
      status: 0,
      code: ApiError.network,
    });
  });
});
