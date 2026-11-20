import type { Context } from 'hono';
import type { PublicLocationLink, PublicTracking } from './api.js';
import { formatDayTime } from './format.js';
import type { Locale, Strings } from './i18n.js';
import { City } from './views/city.js';
import { Layout } from './views/layout.js';
import { Message } from './views/message.js';
import { PLACE_SCRIPT, PlacePage, type PlaceValues } from './views/place.js';
import type { IconName } from './views/icons.js';
import { type Flash, riderStep, TrackingPage } from './views/tracking.js';

/** Lien vers l'autre langue, sur la même page. */
function langHref(c: Context, t: Strings): string {
  return `${c.req.path}?lang=${t.lang === 'fr' ? 'en' : 'fr'}`;
}

export const renderPage = {
  tracking(
    c: Context,
    p: {
      data: PublicTracking;
      t: Strings;
      locale: Locale;
      now: Date;
      nonce: string;
      token: string;
      langQuery: string;
      fingerprint: string | undefined;
      flash: Flash;
    },
  ) {
    const page = `/t/${p.token}`;
    return (
      <Layout
        t={p.t}
        nonce={p.nonce}
        reference={p.data.reference}
        fingerprint={p.fingerprint}
        langHref={langHref(c, p.t)}
        refreshHref={p.fingerprint ? `${page}${p.langQuery}` : undefined}
        map={<City rider={riderStep(p.data)} youLabel={p.t.trackTo} />}
      >
        <TrackingPage
          data={p.data}
          t={p.t}
          locale={p.locale}
          now={p.now}
          actionHref={`${page}/reponse${p.langQuery}`}
          flash={p.flash}
        />
      </Layout>
    );
  },

  message(
    c: Context,
    t: Strings,
    nonce: string,
    m: {
      icon: IconName;
      title: string;
      body: string;
      action?: { href: string; label: string };
      tone?: 'ok' | 'muted';
    },
    pageTitle?: string,
  ) {
    return (
      <Layout t={t} nonce={nonce} langHref={langHref(c, t)} title={pageTitle}>
        <Message {...m} />
      </Layout>
    );
  },

  place(
    c: Context,
    p: {
      link: PublicLocationLink;
      t: Strings;
      locale: Locale;
      nonce: string;
      token: string;
      langQuery: string;
      values: PlaceValues;
      error: string | null;
    },
  ) {
    return (
      <Layout
        t={p.t}
        nonce={p.nonce}
        langHref={langHref(c, p.t)}
        title={p.t.place.title}
        script={PLACE_SCRIPT}
      >
        <PlacePage
          link={p.link}
          t={p.t.place}
          actionHref={`/l/${p.token}${p.langQuery}`}
          validUntil={formatDayTime(p.link.expiresAt, p.locale)}
          values={p.values}
          error={p.error}
        />
      </Layout>
    );
  },
};
