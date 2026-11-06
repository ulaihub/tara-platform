/**
 * Renouvellement des jetons, un seul à la fois par jeton de rafraîchissement. L'API ne
 * laisse servir un jeton qu'une fois : deux renouvellements simultanés (pages et actions
 * en parallèle) seraient pris pour un vol et fermeraient toutes les sessions. Les demandes
 * concurrentes partagent donc le même appel, et son résultat reste en mémoire une minute.
 */
export interface Tokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

const inflight = new Map<string, Promise<Tokens>>();
const recent = new Map<string, { tokens: Tokens; at: number }>();
const KEEP_MS = 60_000;

export function refreshOnce(
  refreshToken: string,
  call: (refreshToken: string) => Promise<Tokens>,
  now = Date.now(),
): Promise<Tokens> {
  for (const [token, entry] of recent) if (now - entry.at > KEEP_MS) recent.delete(token);
  const done = recent.get(refreshToken);
  if (done) return Promise.resolve(done.tokens);
  const running = inflight.get(refreshToken);
  if (running) return running;
  const promise = call(refreshToken)
    .then((tokens) => {
      recent.set(refreshToken, { tokens, at: Date.now() });
      return tokens;
    })
    .finally(() => inflight.delete(refreshToken));
  inflight.set(refreshToken, promise);
  return promise;
}
