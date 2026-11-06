import { NextResponse, type NextRequest } from 'next/server';
import { ApiError, api } from './lib/api';
import { config as settings } from './lib/config';
import { type Tokens, refreshOnce } from './lib/refresh';
import {
  SESSION_COOKIE,
  SESSION_MAX_AGE,
  cookieOptions,
  needsRefresh,
  openSession,
  sealSession,
} from './lib/session';

/** Politique de sécurité du contenu : scripts et styles de la page seulement (nonce). */
function contentSecurityPolicy(nonce: string): string {
  const dev = process.env['NODE_ENV'] !== 'production';
  const realtime = process.env['NEXT_PUBLIC_TARA_REALTIME_URL'] ?? '';
  const socket = realtime.replace(/^http/, 'ws');
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ''}`,
    `style-src 'self' 'nonce-${nonce}'${dev ? " 'unsafe-inline'" : ''}`,
    "img-src 'self' data: blob:",
    "font-src 'self'",
    // Carte (tuiles vectorielles OpenFreeMap) et temps réel de l'API.
    `connect-src 'self' https://tiles.openfreemap.org ${realtime} ${socket}`.trim(),
    "worker-src 'self' blob:",
    "frame-ancestors 'none'",
    "form-action 'self'",
    "base-uri 'none'",
    "object-src 'none'",
  ].join('; ');
}

/**
 * Avant chaque page : en-têtes de sécurité, session de l'équipe (renouvelée avant
 * l'expiration du jeton d'accès), accès refusé sans session vérifiée par le second facteur.
 */
export async function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
  const csp = contentSecurityPolicy(nonce);
  const headers = new Headers(request.headers);
  headers.set('x-nonce', nonce);
  headers.set('content-security-policy', csp);

  const secret = settings.sessionSecret;
  let session = openSession(request.cookies.get(SESSION_COOKIE)?.value, secret);
  let sealed: string | null = null;
  let expired = false;
  if (session && needsRefresh(session)) {
    try {
      const tokens = await refreshOnce(session.refreshToken, (refreshToken) =>
        api<Tokens>('/auth/refresh', { method: 'POST', body: { refreshToken } }),
      );
      session = {
        ...session,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessExpiresAt: Date.now() + tokens.expiresIn * 1000,
      };
      sealed = sealSession(session, secret);
      request.cookies.set(SESSION_COOKIE, sealed);
      headers.set('cookie', request.cookies.toString());
    } catch (error) {
      // Jeton refusé : session terminée. Sans réseau, on garde la session telle quelle.
      if (error instanceof ApiError && error.status === 401) {
        session = null;
        expired = true;
      }
    }
  }

  const path = request.nextUrl.pathname;
  const onLogin = path === '/connexion' || path.startsWith('/connexion/');
  let response: NextResponse;
  if (!onLogin && !session?.mfaVerified) {
    const target = new URL('/connexion', request.url);
    if (expired) target.searchParams.set('expiree', '1');
    response = NextResponse.redirect(target);
  } else if (onLogin && session?.mfaVerified) {
    response = NextResponse.redirect(new URL('/', request.url));
  } else {
    response = NextResponse.next({ request: { headers } });
  }

  response.headers.set('content-security-policy', csp);
  response.headers.set('referrer-policy', 'same-origin');
  response.headers.set('x-content-type-options', 'nosniff');
  response.headers.set('permissions-policy', 'camera=(), microphone=(), geolocation=()');
  response.headers.set('x-robots-tag', 'noindex, nofollow');
  if (sealed)
    response.cookies.set(
      SESSION_COOKIE,
      sealed,
      cookieOptions(SESSION_MAX_AGE, settings.secureCookies),
    );
  if (expired) response.cookies.delete(SESSION_COOKIE);
  return response;
}

export const config = {
  matcher: [
    {
      source:
        '/((?!_next/static|_next/image|favicon.ico|logo-clair.svg|logo-sombre.svg|marque-clair.svg).*)',
      missing: [{ type: 'header', key: 'next-router-prefetch' }],
    },
  ],
};
