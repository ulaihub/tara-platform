import type { Context } from 'hono';
import type { PublicLocationLink, PublicReceipt, PublicTracking } from './api.js';
import { formatDayTime, formatShortDay } from './format.js';
import type { Locale, Strings } from './i18n.js';
import { City } from './views/city.js';
import { RealMap } from './views/realmap.js';
import { Layout } from './views/layout.js';
import { Message } from './views/message.js';
import { ReceiptPage } from './views/receipt.js';
import { PLACE_SCRIPT, PlaceMap, PlacePage, type PlaceValues } from './views/place.js';
import type { IconName } from './views/icons.js';
import { type CodeFlash, type Flash, riderStep, TrackingPage } from './views/tracking.js';

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
      codeFlash: CodeFlash;
    },
  ) {
    const page = `/t/${p.token}`;
    // Course finie : pas de carte à charger (ni de script), la ville dessinée suffit.
    const live = Boolean(p.fingerprint);
    return (
      <Layout
        t={p.t}
        nonce={p.nonce}
        reference={p.data.reference}
        fingerprint={p.fingerprint}
        langHref={langHref(c, p.t)}
        refreshHref={p.fingerprint ? `${page}${p.langQuery}` : undefined}
        realMap={live}
        map={
          <>
            <City rider={riderStep(p.data)} youLabel={p.t.trackTo} />
            {live ? (
              <RealMap
                kind="track"
                label={p.t.mapLabel}
                dropoff={p.data.map.dropoff}
                rider={p.data.map.rider}
                youLabel={p.t.trackTo}
              />
            ) : null}
          </>
        }
      >
        <TrackingPage
          data={p.data}
          t={p.t}
          locale={p.locale}
          now={p.now}
          actionHref={`${page}/reponse${p.langQuery}`}
          flash={p.flash}
          codeHref={`${page}/code${p.langQuery}`}
          codeFlash={p.codeFlash}
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
    /** Issue du lien de localisation : même ville que la page « Mon point », message dans la feuille. */
    onMap = false,
  ) {
    return (
      <Layout
        t={t}
        nonce={nonce}
        langHref={langHref(c, t)}
        title={pageTitle}
        map={onMap ? <City rider={null} point /> : undefined}
        brandSub={onMap ? t.place.title : undefined}
      >
        <Message {...m} sheet={onMap} />
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
    const validUntil = formatDayTime(p.link.expiresAt, p.locale);
    return (
      <Layout
        t={p.t}
        nonce={p.nonce}
        langHref={langHref(c, p.t)}
        title={p.t.place.title}
        script={PLACE_SCRIPT}
        realMap
        brandSub={p.t.place.validUntil(formatShortDay(p.link.expiresAt))}
        map={
          <PlaceMap
            link={p.link}
            t={p.t.place}
            located={p.values.latitude !== '' && p.values.longitude !== ''}
            at={
              p.values.latitude !== '' && p.values.longitude !== ''
                ? { latitude: Number(p.values.latitude), longitude: Number(p.values.longitude) }
                : null
            }
          />
        }
      >
        <PlacePage
          link={p.link}
          t={p.t.place}
          actionHref={`/l/${p.token}${p.langQuery}`}
          validUntil={validUntil}
          values={p.values}
          error={p.error}
        />
      </Layout>
    );
  },

  receipt(c: Context, t: Strings, nonce: string, receipt: PublicReceipt | null) {
    return (
      <Layout
        t={t}
        nonce={nonce}
        langHref={langHref(c, t)}
        title={t.receipt.title}
        brandSub={t.receipt.title}
        blobs
      >
        <ReceiptPage receipt={receipt} t={t.receipt} />
      </Layout>
    );
  },
};
