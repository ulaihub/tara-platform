import type { FC } from 'hono/jsx';
import type { PublicLocationLink } from '../api.js';
import type { PlaceStrings } from '../i18n.js';
import { City } from './city.js';
import { RealMap } from './realmap.js';

/** Saisie gardée quand la page revient avec une erreur. */
export interface PlaceValues {
  latitude: string;
  longitude: string;
  accuracy: string;
  landmark: string;
  name: string;
  phone: string;
}

export const EMPTY_PLACE: PlaceValues = {
  latitude: '',
  longitude: '',
  accuracy: '',
  landmark: '',
  name: '',
  phone: '',
};

/**
 * Haut de la page (maquette Web-Point) : épingle qui rebondit au centre de la ville, bulle
 * d'accueil et bouton « Ma position » posés sur la carte.
 */
export const PlaceMap: FC<{
  link: PublicLocationLink;
  t: PlaceStrings;
  located: boolean;
  /** Point déjà choisi (page revenue avec une erreur) : la carte s'y ouvre. */
  at?: { latitude: number; longitude: number } | null;
}> = ({ link, t, located, at }) => (
  <>
    <City rider={null} point />
    <RealMap kind="place" label={t.dragHint} dropoff={at ?? null} />
    <span class="drop" aria-hidden="true">
      <span class="head">
        <i />
      </span>
      <span class="pole" />
    </span>
    <p class="bubble">
      <b>{link.senderName ? `${t.from(link.senderName)}.` : `${t.fromUnknown}.`}</b> {t.bubble}
    </p>
    <button type="button" id="locate" class="locate" hidden>
      <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="12" cy="12" r="3" />
        <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
      </svg>
      <span>{located ? t.again : t.locate}</span>
    </button>
  </>
);

/**
 * Feuille du bas : point placé (ou à placer), repère pour le livreur, contact facultatif et
 * « Valider mon point ». Un formulaire classique l'envoie ; le seul script lit la position.
 */
export const PlacePage: FC<{
  link: PublicLocationLink;
  t: PlaceStrings;
  actionHref: string;
  validUntil: string;
  values: PlaceValues;
  error: string | null;
}> = ({ link, t, actionHref, validUntil, values, error }) => {
  const located = values.latitude !== '' && values.longitude !== '';
  const messages = {
    searching: t.searching,
    found: t.found,
    rough: t.rough,
    denied: t.denied,
    failed: t.failed,
    unsupported: t.unsupported,
    again: t.again,
    placed: t.pointPlaced,
    manual: t.manual,
  };
  return (
    <form id="place" method="post" action={actionHref} data-m={JSON.stringify(messages)}>
      {error ? (
        <p class="note error" role="alert">
          {error}
        </p>
      ) : null}
      <h1 id="pt" class="pt">
        {located ? t.pointPlaced : t.pointTitle}
      </h1>
      <p id="pos" class={`status${located ? ' ok' : ''}`} role="status" aria-live="polite">
        {located && values.accuracy ? t.found.replace('{m}', values.accuracy) : t.step1Body}
      </p>
      <noscript>
        <p class="note">{t.noscript}</p>
      </noscript>
      <input type="hidden" name="latitude" value={values.latitude} />
      <input type="hidden" name="longitude" value={values.longitude} />
      <input type="hidden" name="accuracy" value={values.accuracy} />

      <label class="boxed" for="landmark">
        <span>{t.landmarkLabel}</span>
        <textarea
          id="landmark"
          name="landmark"
          required
          minlength={3}
          maxlength={300}
          rows={2}
          placeholder={t.landmarkPlaceholder}
        >
          {values.landmark}
        </textarea>
      </label>

      <details class="more" open={Boolean(values.phone) || undefined}>
        <summary>{t.step3}</summary>
        <label class="field" for="name">
          {t.nameLabel}
        </label>
        <input
          id="name"
          name="name"
          type="text"
          maxlength={80}
          autocomplete="name"
          value={values.name || link.recipientName || ''}
        />
        <label class="field" for="phone">
          {t.phoneLabel}
        </label>
        <input
          id="phone"
          name="phone"
          type="tel"
          inputmode="tel"
          maxlength={20}
          autocomplete="tel"
          placeholder={t.phonePlaceholder}
          value={values.phone}
        />
      </details>

      <button id="send" type="submit" class="btn primary block big" disabled={!located}>
        {t.send}
      </button>
      <p class="small center">
        {t.validUntil(validUntil)}. {t.privacy}
      </p>
    </form>
  );
};

/**
 * Script du formulaire : lit la position du téléphone (bouton), la met dans le formulaire,
 * dit sa précision et recentre la carte ; un point placé à la main sur la carte compte aussi.
 * Sans point, l'envoi reste désactivé.
 */
export const PLACE_SCRIPT = `(function(){var f=document.getElementById("place"),b=document.getElementById("locate"),s=document.getElementById("pos"),go=document.getElementById("send");if(!f||!b)return;var m=JSON.parse(f.getAttribute("data-m"));b.hidden=false;function say(t,k){s.textContent=t;s.className="status"+(k?" "+k:"")}b.addEventListener("click",function(){if(!navigator.geolocation){say(m.unsupported,"err");return}say(m.searching);b.disabled=true;navigator.geolocation.getCurrentPosition(function(p){var c=p.coords,a=Math.max(1,Math.round(c.accuracy));f.latitude.value=c.latitude.toFixed(6);f.longitude.value=c.longitude.toFixed(6);f.accuracy.value=a;say((a>100?m.rough:m.found).replace("{m}",a),a>100?"warn":"ok");b.disabled=false;b.lastChild.textContent=m.again;var h=document.getElementById("pt");if(h)h.textContent=m.placed;go.disabled=false;document.dispatchEvent(new CustomEvent("tara:position",{detail:{lat:c.latitude,lng:c.longitude}}))},function(e){say(e.code===1?m.denied:m.failed,"err");b.disabled=false},{enableHighAccuracy:true,timeout:20000,maximumAge:0})});document.addEventListener("tara:manual",function(){say(m.manual,"ok");var h=document.getElementById("pt");if(h)h.textContent=m.placed;go.disabled=false})})();`;
