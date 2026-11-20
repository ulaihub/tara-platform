import { readFileSync } from 'node:fs';
import { Hono, type Context } from 'hono';
import { NONCE, secureHeaders } from 'hono/secure-headers';
import {
  ApiUnavailableError,
  type PublicLocationLink,
  type PublicReceipt,
  type PublicTracking,
  RECEIPT_CODE_PATTERN,
  TOKEN_PATTERN,
  type TrackingApi,
} from './api.js';
import { type Locale, pickLocale, strings } from './i18n.js';
import { renderPage } from './render.js';
import { EMPTY_PLACE, type PlaceValues } from './views/place.js';

export interface AppOptions {
  api: TrackingApi;
  /** Horloge (tests). */
  now?: () => Date;
  /** Adresse du visiteur, transmise à l'API pour sa limite de débit. */
  clientIp?: (c: Context) => string | undefined;
}

/**
 * Adresse ajoutée par le relais de confiance : la dernière de X-Forwarded-For. Les premières
 * peuvent venir du visiteur lui-même (falsifiables), la dernière est écrite par le relais.
 */
export function forwardedClientIp(header: string | undefined): string | undefined {
  const last = header?.split(',').at(-1)?.trim();
  return last ? last : undefined;
}

/** Fichiers servis tels quels : polices, logo complet (clair, sombre), pictogramme de l'onglet et logos des opérateurs (7 jours en cache). */
const ASSETS: Record<string, string> = {
  'jakarta-500.woff': 'font/woff',
  'jakarta-800.woff': 'font/woff',
  'logo-clair.svg': 'image/svg+xml',
  'logo-sombre.svg': 'image/svg+xml',
  'marque-clair.svg': 'image/svg+xml',
  'orange-money.png': 'image/png',
  'mtn-momo.png': 'image/png',
};

const FINAL = new Set(['DELIVERED', 'RETURNED', 'CANCELLED']);

/**
 * Mobile camerounais saisi librement (« 6 77 12 34 56 », « +237677123456 ») au format de
 * l'API ; '' si rien n'est saisi, null s'il n'est pas valable.
 */
export function cameroonMobile(input: string): string | null {
  if (input.trim() === '') return '';
  const digits = input.replace(/\D/g, '').replace(/^(00)?237(?=\d{9}$)/, '');
  return /^6\d{8}$/.test(digits) ? `+237${digits}` : null;
}

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
    options.clientIp ?? ((c: Context) => forwardedClientIp(c.req.header('x-forwarded-for')));
  const assets = new Map(
    Object.entries(ASSETS).map(([name, type]) => [
      name,
      { type, body: readFileSync(new URL(`../public/${name}`, import.meta.url)) },
    ]),
  );

  const app = new Hono();
  /**
   * Lien de localisation (B3) : seule page qui lit la position du téléphone. Posé avant les
   * en-têtes de sécurité pour passer après eux sur la réponse.
   */
  app.use('/l/*', async (c, next) => {
    await next();
    c.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=(self)');
  });

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

  app.get('/l/:token', async (c) => {
    const token = c.req.param('token');
    if (!TOKEN_PATTERN.test(token)) return notFound(c);
    let link: PublicLocationLink | null;
    try {
      link = await api.locationLink(token, clientIp(c));
    } catch (error) {
      if (error instanceof ApiUnavailableError) return unavailable(c);
      throw error;
    }
    if (!link) return notFound(c);
    return place(c, token, link, EMPTY_PLACE, null, c.req.query('r') === 'ok');
  });

  /**
   * « Vérifier un reçu » : le QR du reçu imprimé ouvre /r/<code signé>. Un code mal formé
   * n'est pas transmis à l'API ; faux ou inconnu, la page dit « Reçu introuvable » (404).
   */
  app.get('/r/:code', async (c) => {
    const code = c.req.param('code');
    const t = strings(locale(c));
    let receipt: PublicReceipt | null = null;
    if (RECEIPT_CODE_PATTERN.test(code)) {
      try {
        receipt = await api.receipt(code, clientIp(c));
      } catch (error) {
        if (error instanceof ApiUnavailableError) return unavailable(c);
        throw error;
      }
    }
    return c.html(renderPage.receipt(c, t, nonce(c), receipt), receipt ? 200 : 404);
  });

  /** Point envoyé par le destinataire : vérifié ici, puis transmis à l'API. */
  app.post('/l/:token', async (c) => {
    const token = c.req.param('token');
    if (!TOKEN_PATTERN.test(token)) return notFound(c);
    const t = strings(locale(c)).place;
    const form = await c.req.parseBody();
    const field = (name: string, max: number) => {
      const value = form[name];
      return typeof value === 'string' ? value.trim().slice(0, max) : '';
    };
    const values: PlaceValues = {
      latitude: field('latitude', 20),
      longitude: field('longitude', 20),
      accuracy: field('accuracy', 8).replace(/\D/g, ''),
      landmark: field('landmark', 300),
      name: field('name', 80),
      phone: field('phone', 20),
    };
    const latitude = Number(values.latitude);
    const longitude = Number(values.longitude);
    const located =
      values.latitude !== '' &&
      values.longitude !== '' &&
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      Math.abs(latitude) <= 90 &&
      Math.abs(longitude) <= 180;
    const phone = cameroonMobile(values.phone);
    const error = !located
      ? t.errorPosition
      : values.landmark.length < 3
        ? t.errorLandmark
        : values.phone !== '' && phone === null
          ? t.errorPhone
          : null;
    const kept = located ? values : { ...values, latitude: '', longitude: '', accuracy: '' };

    try {
      if (error) return await placeAgain(c, token, kept, error);
      const result = await api.submitLocation(
        token,
        {
          latitude,
          longitude,
          landmark: values.landmark,
          ...(values.name ? { contactName: values.name } : {}),
          ...(phone ? { contactPhone: phone } : {}),
        },
        clientIp(c),
      );
      const back = `/l/${token}${langQuery(c)}`;
      switch (result) {
        case 'ok':
          return c.redirect(`${back}${back.includes('?') ? '&' : '?'}r=ok`, 303);
        case 'already':
        case 'expired':
          return c.redirect(back, 303);
        case 'not-found':
          return notFound(c);
        case 'out-of-area':
          return await placeAgain(c, token, values, t.errorArea);
        case 'invalid':
          return await placeAgain(c, token, values, t.errorInvalid);
      }
    } catch (error) {
      if (error instanceof ApiUnavailableError) return unavailable(c);
      throw error;
    }
  });

  /** Formulaire rendu de nouveau, avec la saisie et l'erreur. */
  async function placeAgain(c: Context, token: string, values: PlaceValues, error: string) {
    const link = await api.locationLink(token, clientIp(c));
    if (!link) return notFound(c);
    return place(c, token, link, values, error, false, 422);
  }

  /** Selon l'état du lien : formulaire, point déjà envoyé (merci) ou lien expiré. */
  function place(
    c: Context,
    token: string,
    link: PublicLocationLink,
    values: PlaceValues,
    error: string | null,
    sent: boolean,
    status: 200 | 422 = 200,
  ) {
    const t = strings(locale(c));
    if (link.status === 'SUBMITTED') {
      return c.html(
        renderPage.message(
          c,
          t,
          nonce(c),
          sent
            ? {
                icon: 'check',
                tone: 'ok',
                title: t.place.sentTitle,
                body: t.place.sentBody(link.senderName),
              }
            : { icon: 'pin', title: t.place.usedTitle, body: t.place.usedBody(link.senderName) },
          t.place.title,
          true,
        ),
      );
    }
    if (link.status === 'EXPIRED') {
      return c.html(
        renderPage.message(
          c,
          t,
          nonce(c),
          {
            icon: 'clock',
            title: t.place.expiredTitle,
            body: t.place.expiredBody(link.senderName),
          },
          t.place.title,
          true,
        ),
        410,
      );
    }
    return c.html(
      renderPage.place(c, {
        link,
        t,
        locale: locale(c),
        nonce: nonce(c),
        token,
        langQuery: langQuery(c),
        values,
        error,
      }),
      status,
    );
  }

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
