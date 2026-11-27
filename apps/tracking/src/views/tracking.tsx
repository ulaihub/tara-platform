import type { FC } from 'hono/jsx';
import type { OrderStatus, PublicTracking } from '../api.js';
import { dayOf, formatAmount, formatClock } from '../format.js';
import type { Locale, Strings } from '../i18n.js';
import { routeStep } from './city.js';
import { Icon } from './icons.js';

/** Réponse au formulaire de disponibilité, affichée après la redirection. */
export type Flash = 'yes' | 'no' | 'already' | null;

/** Issue de « Je n'ai pas reçu le code », affichée après la redirection. */
export type CodeFlash = 'sent' | 'soon' | 'limit' | 'closed' | null;

type Props = {
  data: PublicTracking;
  t: Strings;
  locale: Locale;
  now: Date;
  actionHref: string;
  flash: Flash;
  /** Formulaire « Je n'ai pas reçu le code ». */
  codeHref: string;
  codeFlash: CodeFlash;
};

const FINAL: readonly OrderStatus[] = [
  'DELIVERED',
  'RETURNED',
  'CANCELLED',
  'HELD_AT_OFFICE',
  'UNCLAIMED',
];
const COMING: readonly OrderStatus[] = ['PICKED_UP', 'IN_DELIVERY'];

const reached = (data: PublicTracking, status: OrderStatus) =>
  data.timeline.find((step) => step.status === status)?.at ?? null;

/** Cran de la moto sur le trajet de la carte (null : pas de livreur en route). */
export function riderStep(data: PublicTracking): number | null {
  if (data.status === 'ASSIGNED') return 0;
  if (!COMING.includes(data.status)) return null;
  return routeStep(data.eta?.progress ?? (data.status === 'PICKED_UP' ? 0.1 : 0.5));
}

/**
 * Feuille de la maquette Web-Suivi : colis de qui, titre et minutes restantes, barre
 * d'étapes, rappel du code, somme à payer, adresse, réponse, puis « Appeler » et « Mon point ».
 * Le code de livraison n'est jamais affiché ici : il arrive par SMS.
 */
export const TrackingPage: FC<Props> = (props) => {
  const { data, t } = props;
  const settled = FINAL.includes(data.status);
  const failedHere =
    data.status === 'DELIVERY_FAILED' &&
    data.failureDecision !== 'RETURN' &&
    data.failureDecision !== 'OFFICE';
  const phone = data.rider && !settled ? data.rider.phone : null;
  return (
    <>
      <Lead {...props} />
      {data.deliveryCode ? (
        <DeliveryCode {...props} code={data.deliveryCode} />
      ) : COMING.includes(data.status) || failedHere ? (
        <p class="card note-card" role="note">
          {t.codeHint}
        </p>
      ) : null}
      {settled ? null : <Payment data={data} t={t} />}
      <section class="card row" id="point" aria-label={t.address}>
        <span class="tile">
          <Icon name="pin" />
        </span>
        <div class="grow">
          <p class="label">{t.address}</p>
          <p class="name">
            {[data.dropoffNeighborhood, data.dropoffLandmark].filter(Boolean).join(' · ')}
          </p>
        </div>
      </section>
      <Availability {...props} />
      {settled ? null : (
        <div class={phone ? 'actions' : 'actions one'}>
          {phone && data.rider ? (
            <a class="btn call" href={`tel:${phone}`} aria-label={t.callLabel(data.rider.name)}>
              <Icon name="phone" size={18} />
              {t.callName(firstName(data.rider.name))}
            </a>
          ) : null}
          <a class="btn glass" href="#point">
            <Icon name="pin" size={18} />
            {t.myPoint}
          </a>
        </div>
      )}
    </>
  );
};

/**
 * Code de livraison : jamais montré (le lien peut circuler), seulement où et quand il est
 * parti ; « Je n'ai pas reçu le code » en renvoie un nouveau au même numéro.
 */
const DeliveryCode: FC<Props & { code: NonNullable<PublicTracking['deliveryCode']> }> = ({
  t,
  code,
  codeHref,
  codeFlash,
}) => (
  <section class="card code-card" id="code" aria-labelledby="code-title">
    <div class="row">
      <span class="tile">
        <Icon name="lock" />
      </span>
      <div class="grow">
        <h2 id="code-title" class="name">
          {t.codeTitle}
        </h2>
        <p class="small">{t.codeSent(code.phone, formatClock(code.sentAt))}</p>
      </div>
    </div>
    <p class="small">{t.codeHint}</p>
    {codeFlash ? (
      <p class={`note${codeFlash === 'sent' ? ' ok' : ''}`} role="status">
        {t.codeFlash[codeFlash]}
      </p>
    ) : null}
    {code.resendsLeft > 0 && codeFlash !== 'limit' ? (
      <form method="post" action={codeHref}>
        <button type="submit" class="btn glass block">
          {t.codeResend}
        </button>
        <p class="small center">{t.codeResendsLeft(String(code.resendsLeft))}</p>
      </form>
    ) : null}
  </section>
);

const firstName = (name: string) => name.trim().split(/\s+/)[0] ?? name;

/** Colis de qui, titre et minutes, détail, livreur, barre des étapes. */
const Lead: FC<Props> = ({ data, t, now }) => {
  const scheduled =
    data.scheduledFor &&
    ['CREATED', 'SEARCHING_RIDER'].includes(data.status) &&
    new Date(data.scheduledFor) > now
      ? data.scheduledFor
      : null;
  const eta = data.eta;
  const title = scheduled
    ? t.scheduledFor(when(t, scheduled, now))
    : data.status === 'DELIVERY_FAILED' && data.failureDecision === 'RETRY'
      ? t.retrying
      : data.status === 'DELIVERY_FAILED' && data.failureDecision === 'RETURN'
        ? t.returning
        : data.status === 'DELIVERY_FAILED' && data.failureDecision === 'OFFICE'
          ? t.toOffice
          : data.status === 'IN_DELIVERY' && data.rider
            ? t.riderComing(data.rider.name)
            : t.status[data.status];
  const sub = eta ? null : subtitle(data, t, Boolean(scheduled));
  const rider = data.rider && !FINAL.includes(data.status) ? data.rider : null;
  return (
    <section class="lead" aria-live="polite">
      <p class="kicker">{data.senderName ? t.parcelOf(data.senderName) : t.yourParcel}</p>
      <div class="headline">
        <h1>{title}</h1>
        {eta ? <span class="chip">{t.minutes(Math.max(1, Math.round(eta.minutes)))}</span> : null}
      </div>
      {sub ? <p class="sub">{sub}</p> : null}
      {rider ? (
        <p class="small">
          {[t.vehicle[rider.vehicleType], rider.plateNumber].filter(Boolean).join(' · ')}
        </p>
      ) : null}
      {data.status === 'CANCELLED' ? null : <Progress data={data} t={t} />}
    </section>
  );
};

function when(t: Strings, iso: string, now: Date): string {
  const day = dayOf(iso, now);
  const label = day === 'today' ? t.today : day === 'tomorrow' ? t.tomorrow : t.on(day);
  return t.at(label, formatClock(iso));
}

function subtitle(data: PublicTracking, t: Strings, scheduled: boolean): string | null {
  if (scheduled) return null;
  switch (data.status) {
    case 'CREATED':
    case 'SEARCHING_RIDER':
      return t.searchingBody;
    case 'ASSIGNED':
      return t.assignedBody;
    case 'PICKED_UP':
    case 'IN_DELIVERY':
      return t.etaPending;
    case 'DELIVERY_FAILED':
      return data.failureDecision ? null : t.failedBody;
    case 'DELIVERED': {
      const at = reached(data, 'DELIVERED');
      return at ? t.deliveredAt(formatClock(at)) : null;
    }
    case 'RETURNED':
      return t.returnedBody;
    case 'HELD_AT_OFFICE':
    case 'UNCLAIMED':
      return t.officeBody;
    case 'CANCELLED':
      return t.cancelledBody;
  }
}

/** Barre des étapes : Commande, Livreur, Récupéré, Livré (ou Échec, ou Rendu). */
const Progress: FC<{ data: PublicTracking; t: Strings }> = ({ data, t }) => {
  const failed = data.status === 'DELIVERY_FAILED';
  const k = STEP_OF[data.status];
  const labels = [
    t.steps[0],
    t.steps[1],
    t.steps[2],
    failed
      ? t.stepFailed
      : data.status === 'RETURNED'
        ? t.stepReturned
        : data.status === 'HELD_AT_OFFICE' || data.status === 'UNCLAIMED'
          ? t.stepOffice
          : t.steps[3],
  ];
  return (
    <div class={failed ? 'progress fail' : 'progress'}>
      <span class="rail">
        <span class={`flow k${k}`} />
      </span>
      <ol>
        {labels.map((label, i) => (
          <li class={i <= k ? 'on' : ''} aria-current={i === k ? 'step' : undefined}>
            {label}
          </li>
        ))}
      </ol>
    </div>
  );
};

const STEP_OF: Record<OrderStatus, number> = {
  CREATED: 0,
  SEARCHING_RIDER: 0,
  ASSIGNED: 1,
  PICKED_UP: 2,
  IN_DELIVERY: 2,
  DELIVERY_FAILED: 3,
  DELIVERED: 3,
  RETURNED: 3,
  CANCELLED: 0,
  HELD_AT_OFFICE: 3,
  UNCLAIMED: 3,
};

/** Somme à payer à la porte, et demande Mobile Money envoyée par le livreur. */
const Payment: FC<{ data: PublicTracking; t: Strings }> = ({ data, t }) => {
  const { due } = data;
  if (due.total === 0) {
    return (
      <section class="card row">
        <span class="tile">
          <Icon name="cash" />
        </span>
        <p class="grow sub">{t.nothingToPay}</p>
      </section>
    );
  }
  return (
    <section class="card pay" aria-label={t.toPay}>
      <div class="row">
        <div class="grow">
          <p class="name">{t.toPay}</p>
          <p class="small">{t.payShort}</p>
        </div>
        <img class="op" src="/static/orange-money.png" alt="Orange Money" width="26" height="26" />
        <img class="op" src="/static/mtn-momo.png" alt="MTN MoMo" width="26" height="26" />
        <b class="amount">{formatAmount(due.total)}</b>
      </div>
      {due.cod > 0 && due.fee > 0 ? (
        <div class="split">
          <div class="line">
            <span>{t.parcel}</span>
            <span>{formatAmount(due.cod)}</span>
          </div>
          <div class="line">
            <span>{t.delivery}</span>
            <span>{formatAmount(due.fee)}</span>
          </div>
        </div>
      ) : null}
      {data.mobileMoneyFee > 0 ? (
        <p class="small fee">{t.mobileMoneyFee(formatAmount(data.mobileMoneyFee))}</p>
      ) : null}
      {data.paymentPending ? (
        <p class="note" role="status">
          {t.paymentPending(formatAmount(data.paymentPending.amount))}
        </p>
      ) : null}
    </section>
  );
};

/** « Serez-vous là ? » avant l'enlèvement (C5) ; ensuite, le merci. */
const Availability: FC<Props> = ({ data, t, actionHref, flash }) => {
  if (flash === 'already') return <p class="note">{t.alreadyAnswered}</p>;
  if (
    flash === 'yes' ||
    flash === 'no' ||
    (data.recipientConfirmedAt && !FINAL.includes(data.status))
  ) {
    const available = flash ? flash === 'yes' : data.recipientAvailable !== false;
    return (
      <p class="note ok" role="status">
        {available ? t.thanksAvailable : t.thanksUnavailable}
      </p>
    );
  }
  if (!data.canRespond) return null;
  return (
    <section class="card">
      <form method="post" action={actionHref}>
        <h2>{t.available}</h2>
        <textarea
          name="note"
          maxlength={300}
          placeholder={t.notePlaceholder}
          aria-label={t.notePlaceholder}
        />
        <div class="choices">
          <button class="btn primary block" name="available" value="yes">
            {t.yes}
          </button>
          <button class="btn ghost block" name="available" value="no">
            {t.no}
          </button>
        </div>
      </form>
    </section>
  );
};
