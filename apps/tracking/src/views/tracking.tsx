import type { FC } from 'hono/jsx';
import type { OrderStatus, PublicTracking } from '../api.js';
import { dayOf, formatAmount, formatClock, formatDistance, initials } from '../format.js';
import type { Locale, Strings } from '../i18n.js';
import { Icon, type IconName } from './icons.js';

/** Réponse au formulaire de disponibilité, affichée après la redirection. */
export type Flash = 'yes' | 'no' | 'already' | null;

type Props = {
  data: PublicTracking;
  t: Strings;
  locale: Locale;
  now: Date;
  actionHref: string;
  flash: Flash;
};

const FINAL: readonly OrderStatus[] = ['DELIVERED', 'RETURNED', 'CANCELLED'];
const COMING: readonly OrderStatus[] = ['PICKED_UP', 'IN_DELIVERY'];

const reached = (data: PublicTracking, status: OrderStatus) =>
  data.timeline.find((step) => step.status === status)?.at ?? null;

/** Contenu de la page : statut, trajet, étapes, livreur, somme à payer, adresse, réponse. */
export const TrackingPage: FC<Props> = (props) => {
  const { data, t } = props;
  const settled = FINAL.includes(data.status);
  const failedHere = data.status === 'DELIVERY_FAILED' && data.failureDecision !== 'RETURN';
  return (
    <>
      <Hero {...props} />
      {data.status === 'CANCELLED' ? null : <Steps data={data} t={t} />}
      {data.rider && !settled ? <Rider rider={data.rider} t={t} /> : null}
      {settled ? null : <Payment data={data} t={t} />}
      {COMING.includes(data.status) || failedHere ? (
        <p class="note" role="note">
          {t.codeHint}
        </p>
      ) : null}
      <section class="card row" aria-label={t.address}>
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
    </>
  );
};

const Hero: FC<Props> = ({ data, t, locale, now }) => {
  const scheduled =
    data.scheduledFor &&
    ['CREATED', 'SEARCHING_RIDER'].includes(data.status) &&
    new Date(data.scheduledFor) > now
      ? data.scheduledFor
      : null;
  const title = scheduled
    ? t.scheduledFor(when(t, scheduled, now))
    : data.status === 'DELIVERY_FAILED' && data.failureDecision === 'RETRY'
      ? t.retrying
      : data.status === 'DELIVERY_FAILED' && data.failureDecision === 'RETURN'
        ? t.returning
        : t.status[data.status];
  const [icon, tone] = badge(data, Boolean(scheduled));
  const eta = data.eta;
  const sub = subtitle(data, t, Boolean(scheduled));
  return (
    <section class="card" aria-live="polite">
      <div class="hero">
        <span class={`badge ${tone}`}>
          <Icon name={icon} size={24} />
        </span>
        <div class="grow">
          <p class="from">{data.senderName ? t.from(data.senderName) : t.fromUnknown}</p>
          <h1>{title}</h1>
          {eta ? (
            <p class="eta">
              {t.etaAt(
                formatClock(new Date(now.getTime() + eta.minutes * 60_000)),
                formatDistance(eta.distanceMeters, locale),
              )}
            </p>
          ) : sub ? (
            <p class="sub">{sub}</p>
          ) : null}
        </div>
      </div>
      {eta ? <Trip progress={eta.progress} t={t} /> : null}
    </section>
  );
};

function when(t: Strings, iso: string, now: Date): string {
  const day = dayOf(iso, now);
  const label = day === 'today' ? t.today : day === 'tomorrow' ? t.tomorrow : t.on(day);
  return t.at(label, formatClock(iso));
}

function badge(data: PublicTracking, scheduled: boolean): [IconName, string] {
  if (scheduled) return ['clock', ''];
  switch (data.status) {
    case 'DELIVERED':
      return ['check', 'ok'];
    case 'DELIVERY_FAILED':
      return data.failureDecision === 'RETRY'
        ? ['moto', '']
        : data.failureDecision === 'RETURN'
          ? ['back', 'muted']
          : ['alert', 'danger'];
    case 'RETURNED':
      return ['back', 'muted'];
    case 'CANCELLED':
      return ['close', 'muted'];
    case 'PICKED_UP':
    case 'IN_DELIVERY':
      return ['moto', ''];
    case 'ASSIGNED':
      return ['package', ''];
    default:
      return ['timer', ''];
  }
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
    case 'CANCELLED':
      return t.cancelledBody;
  }
}

/** Trajet de l'expéditeur au destinataire, la moto à la part déjà parcourue. */
const Trip: FC<{ progress: number; t: Strings }> = ({ progress, t }) => {
  const start = 10;
  const end = 290;
  const x = Math.round(start + (end - start) * progress);
  return (
    <>
      <svg
        class="bar"
        viewBox="0 0 300 40"
        role="img"
        aria-label={`${Math.round(progress * 100)} %`}
      >
        <defs>
          <linearGradient id="g" x1="0" x2="1">
            <stop offset="0" stop-color="#FFB000" />
            <stop offset=".55" stop-color="#FF6A00" />
            <stop offset="1" stop-color="#FF3D00" />
          </linearGradient>
        </defs>
        <rect
          x={start}
          y="25"
          width={end - start}
          height="4"
          rx="2"
          fill="currentColor"
          opacity=".12"
        />
        <rect x={start} y="25" width={x - start} height="4" rx="2" fill="url(#g)" />
        <circle cx={start} cy="27" r="5" fill="#FF6A00" />
        <circle cx={end} cy="27" r="6" fill="none" stroke="#FF6A00" stroke-width="3" />
        <g transform={`translate(${x - 15} 0)`}>
          <circle cx="15" cy="15" r="15" fill="url(#g)" />
          <g
            transform="translate(5 4) scale(.85)"
            fill="none"
            stroke="#140800"
            stroke-width="2.2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="5.5" cy="16.5" r="3" />
            <circle cx="18.5" cy="16.5" r="3" />
            <path d="M8.5 16.5h5l3.5-7M17 9.5l-1.6-4H18M3.5 11.5h6.5l1.5 2.5" />
          </g>
        </g>
      </svg>
      <div class="ends" aria-hidden="true">
        <span>{t.trackFrom}</span>
        <span>{t.trackTo}</span>
      </div>
    </>
  );
};

/** Commande, prise en charge, en route, livré (ou échec, ou rendu), avec leur heure. */
const Steps: FC<{ data: PublicTracking; t: Strings }> = ({ data, t }) => {
  const last =
    data.status === 'DELIVERY_FAILED'
      ? { label: t.stepFailed, at: reached(data, 'DELIVERY_FAILED'), fail: true }
      : data.status === 'RETURNED'
        ? { label: t.stepReturned, at: reached(data, 'RETURNED'), fail: false }
        : { label: t.steps[3], at: reached(data, 'DELIVERED'), fail: false };
  const steps = [
    {
      label: t.steps[0],
      at: reached(data, 'CREATED') ?? data.timeline[0]?.at ?? null,
      fail: false,
    },
    { label: t.steps[1], at: reached(data, 'PICKED_UP'), fail: false },
    { label: t.steps[2], at: reached(data, 'IN_DELIVERY'), fail: false },
    last,
  ];
  return (
    <section class="card">
      <ol class="steps">
        {steps.map((step) => (
          <li class={step.fail && step.at ? 'fail' : step.at ? 'done' : ''}>
            <span class="dot" />
            {step.label}
            <time>{step.at ? formatClock(step.at) : ' '}</time>
          </li>
        ))}
      </ol>
    </section>
  );
};

const Rider: FC<{ rider: NonNullable<PublicTracking['rider']>; t: Strings }> = ({ rider, t }) => (
  <section class="card row">
    <span class="avatar" aria-hidden="true">
      {initials(rider.name)}
    </span>
    <div class="grow">
      <p class="name">{rider.name}</p>
      <p class="small">
        {[t.vehicle[rider.vehicleType], rider.plateNumber].filter(Boolean).join(' · ')}
      </p>
    </div>
    {rider.phone ? (
      <a class="btn primary" href={`tel:${rider.phone}`} aria-label={t.callLabel(rider.name)}>
        <Icon name="phone" size={20} />
        {t.call}
      </a>
    ) : null}
  </section>
);

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
    <section class="card" aria-label={t.toPay}>
      <p class="label">{t.toPay}</p>
      <p class="amount">{formatAmount(due.total)}</p>
      {due.cod > 0 && due.fee > 0 ? (
        <>
          <div class="line">
            <span>{t.parcel}</span>
            <span>{formatAmount(due.cod)}</span>
          </div>
          <div class="line">
            <span>{t.delivery}</span>
            <span>{formatAmount(due.fee)}</span>
          </div>
        </>
      ) : null}
      <p class="small">{t.payHow}</p>
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
