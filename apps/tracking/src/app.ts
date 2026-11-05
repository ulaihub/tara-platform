import { readFileSync } from 'node:fs';
import { Hono, type Context } from 'hono';
import { NONCE, secureHeaders } from 'hono/secure-headers';
import {
  ApiUnavailableError,
  type PublicTracking,
  TOKEN_PATTERN,
  type TrackingApi,
} from './api.js';
import { type Locale, pickLocale, strings } from './i18n.js';
import { renderPage } from './render.js';

export interface AppOptions {
  api: TrackingApi;
  /** Horloge (tests). */
  now?: () => Date;
  /** Adresse du visiteur, transmise à l'API pour sa limite de débit. */
  clientIp?: (c: Context) => string | undefined;
}

/** Fichiers servis tels quels : polices, logo complet (clair, sombre) et pictogramme de l'onglet (7 jours en cache). */
const ASSETS: Record<string, string> = {
  'jakarta-500.woff': 'font/woff',
  'jakarta-800.woff': 'font/woff',
  'logo-clair.svg': 'image/svg+xml',
  'logo-sombre.svg': 'image/svg+xml',
  'marque-clair.svg': 'image/svg+xml',
};

const FINAL = new Set(['DELIVERED', 'RETURNED', 'CANCELLED']);

/** Empreinte de ce qui change à l'écran : la page se recharge quand elle bouge. */
export function fingerprint(data: PublicTracking): string {
  return [
    data.status,
    data.failureDecision ?? '',
    data.paymentPending?.amount ?? '',
    data.due.total,
    data.eta?.minutes ?? '',
    data.rider?.phone ? 1 : 0,
    data.recipientConfirmedAt ?? '',
  ].join('|');
}

/**
 * Page de suivi du destinataire (F2) : rendue côté serveur, sans compte. Le seul JavaScript
 * recharge la page quand l'état change ; tout le reste marche sans.
 */
export function createApp(options: AppOptions): Hono {
  const { api } = options;
  const now = options.now ?? (() => new Date());
  const clientIp =
    options.clientIp ?? ((c: Context) => c.req.header('x-forwarded-for')?.split(',')[0]?.trim());
  const assets = new Map(
    Object.entries(ASSETS).map(([name, type]) => [
      name,
      { type, body: readFileSync(new URL(`../public/${name}`, import.meta.url)) },
    ]),
  );

  const app = new Hono();
  app.use(
    secureHeaders({
      contentSecurityPolicy: {
        defaultSrc: ["'none'"],
        scriptSrc: [NONCE],
        styleSrc: [NONCE],
        imgSrc: ["'self'"],
        fontSrc: ["'self'"],
        connectSrc: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
        baseUri: ["'none'"],
      },
      // Le jeton est dans l'adresse : il ne part jamais vers un autre site.
      referrerPolicy: 'no-referrer',
      crossOriginEmbedderPolicy: false,
      permissionsPolicy: { camera: [], microphone: [], geolocation: [] },
    }),
  );
  app.use(async (c, next) => {
    await next();
    c.header('X-Robots-Tag', 'noindex, nofollow');
    if (!c.res.headers.has('Cache-Control')) c.header('Cache-Control', 'no-store');
  });

  const locale = (c: Context): Locale =>
    pickLocale(c.req.query('lang'), c.req.header('accept-language'));
  const langQuery = (c: Context) => {
    const lang = c.req.query('lang');
    return lang === 'fr' || lang === 'en' ? `?lang=${lang}` : '';
  };
  const nonce = (c: Context) => c.get('secureHeadersNonce') as string;

  app.get('/health', (c) => c.text('ok'));

  app.get('/static/:name', (c) => {
    const asset = assets.get(c.req.param('name'));
    if (!asset) return c.notFound();
    return c.body(new Uint8Array(asset.body), 200, {
      'Content-Type': asset.type,
      'Cache-Control': 'public, max-age=604800',
    });
  });

  app.get('/', (c) => {
    const t = strings(locale(c));
    return c.html(
      renderPage.message(c, t, nonce(c), {
        icon: 'package',
        title: t.title,
        body: t.notFoundBody,
      }),
    );
  });

  app.get('/t/:token', async (c) => {
    const token = c.req.param('token');
    const t = strings(locale(c));
    if (!TOKEN_PATTERN.test(token)) return notFound(c);
    let data: PublicTracking | null;
    try {
      data = await api.view(token, clientIp(c));
    } catch (error) {
      if (error instanceof ApiUnavailableError) return unavailable(c);
      throw error;
    }
    if (!data) return notFound(c);
    const flash = c.req.query('r');
    return c.html(
      renderPage.tracking(c, {
        data,
        t,
        locale: locale(c),
        now: now(),
        nonce: nonce(c),
        token,
        langQuery: langQuery(c),
        fingerprint: FINAL.has(data.status) ? undefined : fingerprint(data),
        flash: flash === 'yes' || flash === 'no' || flash === 'already' ? flash : null,
      }),
    );
  });

  /** Empreinte de l'état, relue toutes les 20 s par la page ouverte. */
  app.get('/t/:token/etat', async (c) => {
    const token = c.req.param('token');
    if (!TOKEN_PATTERN.test(token)) return c.json({ error: 'not-found' }, 404);
    try {
      const data = await api.view(token, clientIp(c));
      if (!data) return c.json({ error: 'not-found' }, 404);
      return c.json({ v: fingerprint(data) });
    } catch (error) {
      if (error instanceof ApiUnavailableError) return c.json({ error: 'unavailable' }, 503);
      throw error;
    }
  });

  /** Réponse du destinataire (C5) : formulaire classique, puis retour à la page. */
  app.post('/t/:token/reponse', async (c) => {
    const token = c.req.param('token');
    if (!TOKEN_PATTERN.test(token)) return notFound(c);
    const form = await c.req.parseBody();
    const available = form['available'];
    const back = `/t/${token}${langQuery(c)}`;
    if (available !== 'yes' && available !== 'no') return c.redirect(back, 303);
    const note = typeof form['note'] === 'string' ? form['note'].trim().slice(0, 300) : '';
    try {
      const result = await api.respond(
        token,
        { available: available === 'yes', ...(note ? { note } : {}) },
        clientIp(c),
      );
      if (result === 'not-found') return notFound(c);
      const flash = result === 'already' ? 'already' : available;
      return c.redirect(`${back}${back.includes('?') ? '&' : '?'}r=${flash}`, 303);
    } catch (error) {
      if (error instanceof ApiUnavailableError) return unavailable(c);
      throw error;
    }
  });

  app.notFound((c) => notFound(c));

  function notFound(c: Context) {
    const t = strings(locale(c));
    return c.html(
      renderPage.message(c, t, nonce(c), {
        icon: 'alert',
        title: t.notFoundTitle,
        body: t.notFoundBody,
      }),
      404,
    );
  }

  function unavailable(c: Context) {
    const t = strings(locale(c));
    return c.html(
      renderPage.message(c, t, nonce(c), {
        icon: 'refresh',
        title: t.unavailableTitle,
        body: t.unavailableBody,
        action: { href: c.req.path + langQuery(c), label: t.retry },
      }),
      503,
    );
  }

  return app;
}
