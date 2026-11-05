import type { FC } from 'hono/jsx';
import type { PublicLocationLink } from '../api.js';
import type { PlaceStrings } from '../i18n.js';
import { Icon } from './icons.js';

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
 * Page du lien de localisation (B3) : le destinataire partage sa position (bouton), écrit
 * un repère et, s'il le veut, un autre numéro. Un formulaire classique l'envoie ; le seul
 * script lit la position du téléphone.
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
  };
  return (
    <form id="place" method="post" action={actionHref} data-m={JSON.stringify(messages)}>
      <section class="card">
        <div class="hero">
          <span class="badge">
            <Icon name="pin" size={24} />
          </span>
          <div class="grow">
            <p class="from">{link.senderName ? t.from(link.senderName) : t.fromUnknown}</p>
            <h1>{t.heading}</h1>
            <p class="sub">{t.intro}</p>
          </div>
        </div>
      </section>

      {error ? (
        <p class="note error" role="alert">
          {error}
        </p>
      ) : null}

      <section class="card" aria-labelledby="step1">
        <div class="row">
          <span class="num">1</span>
          <h2 id="step1">{t.step1}</h2>
        </div>
        <p class="small step">{t.step1Body}</p>
        <button type="button" id="locate" class="btn primary block" hidden>
          <Icon name="pin" />
          {located ? t.again : t.locate}
        </button>
        <noscript>
          <p class="note">{t.noscript}</p>
        </noscript>
        <p id="pos" class={`status${located ? ' ok' : ''}`} role="status" aria-live="polite">
          {located && values.accuracy ? t.found.replace('{m}', values.accuracy) : ''}
        </p>
        <input type="hidden" name="latitude" value={values.latitude} />
        <input type="hidden" name="longitude" value={values.longitude} />
        <input type="hidden" name="accuracy" value={values.accuracy} />
      </section>

      <section class="card" aria-labelledby="step2">
        <div class="row">
          <span class="num">2</span>
          <h2 id="step2">{t.step2}</h2>
        </div>
        <label class="field" for="landmark">
          {t.landmarkLabel}
        </label>
        <textarea
          id="landmark"
          name="landmark"
          required
          minlength={3}
          maxlength={300}
          placeholder={t.landmarkPlaceholder}
        >
          {values.landmark}
        </textarea>
      </section>

      <section class="card" aria-labelledby="step3">
        <div class="row">
          <span class="num">3</span>
          <h2 id="step3">{t.step3}</h2>
        </div>
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
      </section>

      <p>
        <button id="send" type="submit" class="btn primary block" disabled={!located}>
          {t.send}
        </button>
      </p>
      <p class="small center">
        {t.validUntil(validUntil)} {t.privacy}
      </p>
    </form>
  );
};

/**
 * Seul script de la page : lit la position du téléphone (bouton), la met dans le formulaire
 * et dit sa précision. Sans position, l'envoi reste désactivé.
 */
export const PLACE_SCRIPT = `(function(){var f=document.getElementById("place"),b=document.getElementById("locate"),s=document.getElementById("pos"),go=document.getElementById("send");if(!f||!b)return;var m=JSON.parse(f.getAttribute("data-m"));b.hidden=false;function say(t,k){s.textContent=t;s.className="status"+(k?" "+k:"")}b.addEventListener("click",function(){if(!navigator.geolocation){say(m.unsupported,"err");return}say(m.searching);b.disabled=true;navigator.geolocation.getCurrentPosition(function(p){var c=p.coords,a=Math.max(1,Math.round(c.accuracy));f.latitude.value=c.latitude.toFixed(6);f.longitude.value=c.longitude.toFixed(6);f.accuracy.value=a;say((a>100?m.rough:m.found).replace("{m}",a),a>100?"warn":"ok");b.disabled=false;b.lastChild.textContent=m.again;go.disabled=false},function(e){say(e.code===1?m.denied:m.failed,"err");b.disabled=false},{enableHighAccuracy:true,timeout:20000,maximumAge:0})})})();`;
