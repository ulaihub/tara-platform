import { raw } from 'hono/html';
import type { Child, FC } from 'hono/jsx';
import type { Strings } from '../i18n.js';
import { CSS } from '../styles.js';

/** Squelette : marque, référence, contenu, pied de page avec le choix de langue. */
export const Layout: FC<{
  t: Strings;
  nonce: string;
  reference?: string;
  /** Empreinte de l'état : la page se recharge quand elle change. */
  fingerprint?: string;
  langHref: string;
  refreshHref?: string;
  children: Child;
}> = ({ t, nonce, reference, fingerprint, langHref, refreshHref, children }) => (
  <>
    {raw('<!doctype html>')}
    <html lang={t.lang}>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <meta name="theme-color" content="#F6F2EC" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#0A0A0F" media="(prefers-color-scheme: dark)" />
        <title>{reference ? `${t.title} · ${reference}` : t.title}</title>
        <link rel="icon" href="/static/marque-clair.svg" type="image/svg+xml" />
        <style nonce={nonce} dangerouslySetInnerHTML={{ __html: CSS }} />
      </head>
      <body data-v={fingerprint}>
        <div class="wrap">
          <header>
            <span class="brand">
              <picture>
                <source srcset="/static/marque-sombre.svg" media="(prefers-color-scheme: dark)" />
                <img src="/static/marque-clair.svg" alt="" width="34" height="24" />
              </picture>
              Tara
            </span>
            {reference ? <span class="ref">{reference}</span> : null}
          </header>
          <main>{children}</main>
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
        </div>
        {fingerprint ? (
          <script nonce={nonce} dangerouslySetInnerHTML={{ __html: LIVE_SCRIPT }} />
        ) : null}
      </body>
    </html>
  </>
);

/**
 * Seul JavaScript de la page (moins de 1 Ko) : toutes les 20 s, l'empreinte de l'état est
 * relue ; si elle a changé, la page se recharge, sauf pendant une saisie.
 */
const LIVE_SCRIPT = `(function(){var v=document.body.getAttribute("data-v"),u=location.pathname.replace(/\\/$/,"")+"/etat";setInterval(function(){var a=document.activeElement;if(document.hidden||(a&&/^(INPUT|TEXTAREA)$/.test(a.tagName)))return;fetch(u,{cache:"no-store"}).then(function(r){return r.ok?r.json():null}).then(function(j){if(j&&j.v!==v)location.reload()}).catch(function(){})},20000)})();`;
