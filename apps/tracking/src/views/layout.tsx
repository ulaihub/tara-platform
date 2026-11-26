import { raw } from 'hono/html';
import type { Child, FC } from 'hono/jsx';
import type { Strings } from '../i18n.js';
import { CSS } from '../styles.js';
import { MAP_SCRIPT, MAP_VERSION } from './realmap.js';

/** Squelette : marque, référence, contenu, pied de page avec le choix de langue. */
export const Layout: FC<{
  t: Strings;
  nonce: string;
  reference?: string;
  /** Empreinte de l'état : la page se recharge quand elle change. */
  fingerprint?: string;
  langHref: string;
  refreshHref?: string;
  /** Titre de l'onglet (par défaut : suivi du colis). */
  title?: string;
  /** Script propre à la page (lien de localisation). */
  script?: string;
  /** Carte du haut (maquette Web-Suivi) : l'en-tête passe par-dessus, le contenu dans la feuille. */
  map?: Child;
  /** Sous-titre de l'en-tête sur la carte (par défaut : lien envoyé par SMS). */
  brandSub?: string;
  /** Fond de taches de couleur, sans carte (maquette Web-Verifier-Recu). */
  blobs?: boolean;
  /** Vraie carte dans le haut de page : feuille de style et script de MapLibre. */
  realMap?: boolean;
  children: Child;
}> = ({
  t,
  nonce,
  reference,
  fingerprint,
  langHref,
  refreshHref,
  title,
  script,
  map,
  brandSub,
  blobs,
  realMap,
  children,
}) => (
  <>
    {raw('<!doctype html>')}
    <html lang={t.lang}>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <meta name="theme-color" content="#F6F2EC" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#0A0A0F" media="(prefers-color-scheme: dark)" />
        <title>{title ?? (reference ? `${t.title} · ${reference}` : t.title)}</title>
        <link rel="icon" href="/static/marque-clair.svg" type="image/svg+xml" />
        <style nonce={nonce} dangerouslySetInnerHTML={{ __html: CSS }} />
        {realMap ? (
          <link rel="stylesheet" href={`/carte/maplibre-gl.css?v=${MAP_VERSION}`} nonce={nonce} />
        ) : null}
      </head>
      <body data-v={fingerprint}>
        {blobs ? (
          <div class="wrap aura">
            <div class="blobs" aria-hidden="true">
              <i />
              <i />
              <i />
            </div>
            <BrandHeader t={t} sub={brandSub ?? t.brandSub} />
            <main>{children}</main>
            <Footer t={t} langHref={langHref} />
          </div>
        ) : map ? (
          <div class="wrap map">
            <div class="top">
              {map}
              <BrandHeader t={t} sub={brandSub ?? t.brandSub} />
            </div>
            <div class="sheet">
              <main>{children}</main>
              <Footer
                t={t}
                fingerprint={fingerprint}
                langHref={langHref}
                refreshHref={refreshHref}
              />
            </div>
          </div>
        ) : (
          <div class="wrap">
            <header>
              <span class="brand">
                <picture>
                  <source srcset="/static/logo-sombre.svg" media="(prefers-color-scheme: dark)" />
                  <img src="/static/logo-clair.svg" alt={t.logoAlt} width="128" height="48" />
                </picture>
              </span>
              {reference ? <span class="ref">{reference}</span> : null}
            </header>
            <main>{children}</main>
            <Footer t={t} fingerprint={fingerprint} langHref={langHref} refreshHref={refreshHref} />
          </div>
        )}
        {fingerprint ? (
          <script nonce={nonce} dangerouslySetInnerHTML={{ __html: LIVE_SCRIPT }} />
        ) : null}
        {script ? <script nonce={nonce} dangerouslySetInnerHTML={{ __html: script }} /> : null}
        {realMap ? <script nonce={nonce} dangerouslySetInnerHTML={{ __html: MAP_SCRIPT }} /> : null}
      </body>
    </html>
  </>
);

/** En-tête des pages de la refonte : logo sur tuile sombre, marque, sous-titre, « tara.cm ». */
const BrandHeader: FC<{ t: Strings; sub: string }> = ({ t, sub }) => (
  <header class="over">
    <span class="tile-logo">
      <img src="/static/logo-sombre.svg" alt={t.logoAlt} width="40" height="28" />
    </span>
    <span class="grow brandline">
      <b>{t.brandLine}</b>
      <span>{sub}</span>
    </span>
    <span class="secure">
      <svg width="13" height="13" viewBox="0 0 24 24" aria-hidden="true">
        <rect x="5" y="11" width="14" height="9" rx="2" />
        <path d="M8 11V8a4 4 0 0 1 8 0v3" />
      </svg>
      tara.cm
    </span>
  </header>
);

const Footer: FC<{ t: Strings; fingerprint?: string; langHref: string; refreshHref?: string }> = ({
  t,
  fingerprint,
  langHref,
  refreshHref,
}) => (
  <footer>
    {refreshHref ? (
      <p>
        {fingerprint ? `${t.liveHint} ` : null}
        <a href={refreshHref}>{t.refresh}</a>
      </p>
    ) : null}
    <p>
      {t.footer} · <a href={langHref}>{t.switchLang}</a>
    </p>
  </footer>
);

/**
 * Seul JavaScript de la page (moins de 1 Ko) : toutes les 20 s, l'empreinte de l'état est
 * relue (la carte y lit la position du livreur) ; si elle a changé, la page se recharge, sauf
 * pendant une saisie.
 */
const LIVE_SCRIPT = `(function(){var v=document.body.getAttribute("data-v"),u=location.pathname.replace(/\\/$/,"")+"/etat";setInterval(function(){var a=document.activeElement;if(document.hidden||(a&&/^(INPUT|TEXTAREA)$/.test(a.tagName)))return;fetch(u,{cache:"no-store"}).then(function(r){return r.ok?r.json():null}).then(function(j){if(!j)return;document.dispatchEvent(new CustomEvent("tara:etat",{detail:j}));if(j.v!==v)location.reload()}).catch(function(){})},20000)})();`;
