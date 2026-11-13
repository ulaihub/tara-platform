import { describe, expect, it, vi } from 'vitest';
import { type Tokens, refreshOnce } from '@/lib/refresh';

const tokens = (n: number): Tokens => ({
  accessToken: `a${n}`,
  refreshToken: `r${n}`,
  expiresIn: 900,
});

describe('renouvellement des jetons', () => {
  it('partage un seul appel entre demandes simultanées', async () => {
    let release: (value: Tokens) => void = () => undefined;
    const call = vi.fn(() => new Promise<Tokens>((resolve) => (release = resolve)));
    const first = refreshOnce('simultane', call);
    const second = refreshOnce('simultane', call);
    release(tokens(1));
    expect(await first).toEqual(tokens(1));
    expect(await second).toEqual(tokens(1));
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('rend le même résultat à une demande arrivée juste après', async () => {
    const call = vi.fn(() => Promise.resolve(tokens(2)));
    await refreshOnce('apres', call);
    expect(await refreshOnce('apres', call)).toEqual(tokens(2));
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('oublie ce résultat au bout d’une minute', async () => {
    const call = vi.fn(() => Promise.resolve(tokens(3)));
    await refreshOnce('minute', call);
    await refreshOnce('minute', call, Date.now() + 61_000);
    expect(call).toHaveBeenCalledTimes(2);
  });

  it('laisse réessayer après un échec', async () => {
    const call = vi
      .fn<(token: string) => Promise<Tokens>>()
      .mockRejectedValueOnce(new Error('réseau'))
      .mockResolvedValueOnce(tokens(4));
    await expect(refreshOnce('echec', call)).rejects.toThrow('réseau');
    expect(await refreshOnce('echec', call)).toEqual(tokens(4));
    expect(call).toHaveBeenCalledTimes(2);
  });
});
