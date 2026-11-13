import 'server-only';
import { config } from './config';

/** Erreur renvoyée par l'API (`{ error: { code, message, details } }`) ou par le réseau. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details: Record<string, unknown> = {},
  ) {
    super(message);
  }

  static readonly network = 'NETWORK';
}

const TIMEOUT_MS = 10_000;

/**
 * Appel à l'API depuis le serveur du back-office : le jeton d'accès ne quitte jamais le
 * serveur. Réponses JSON ; 204 → null.
 */
export async function api<T>(
  path: string,
  options: {
    method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
    body?: unknown;
    token?: string;
    query?: Record<string, string | number | undefined>;
    headers?: Record<string, string>;
    fetcher?: typeof fetch;
  } = {},
): Promise<T> {
  const url = new URL(`${config.apiUrl}/v1${path}`);
  for (const [name, value] of Object.entries(options.query ?? {})) {
    if (value !== undefined && value !== '') url.searchParams.set(name, String(value));
  }
  let response: Response;
  try {
    response = await (options.fetcher ?? fetch)(url, {
      method: options.method ?? 'GET',
      headers: {
        accept: 'application/json',
        'accept-language': 'fr',
        ...(options.body === undefined ? {} : { 'content-type': 'application/json' }),
        ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
        ...options.headers,
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      cache: 'no-store',
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    throw new ApiError(0, ApiError.network, 'L’API Tara ne répond pas. Réessayez dans un instant.');
  }
  if (response.status === 204) return null as T;
  const json = (await response.json().catch(() => null)) as
    (T & { error?: { code?: string; message?: string; details?: Record<string, unknown> } }) | null;
  if (!response.ok) {
    const error = json?.error;
    throw new ApiError(
      response.status,
      error?.code ?? `HTTP_${response.status}`,
      error?.message ?? 'Une erreur est survenue.',
      error?.details ?? {},
    );
  }
  return json as T;
}
