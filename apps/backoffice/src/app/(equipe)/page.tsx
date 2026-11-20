import type { Metadata } from 'next';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { Kpi } from '@/components/kpi';
import { TopBar } from '@/components/top-bar';
import { cx, Note } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { doualaHour, greeting, longDate } from '@/lib/douala';
import { FINANCE_ROLES } from '@/lib/finance';
import { time } from '@/lib/format';
import { alertsOf, countsOf } from '@/lib/live';
import { change, METRICS_ROLES, minutes, pointsChange, rate } from '@/lib/metrics';
import { OPS_ROLES } from '@/lib/navigation';
import type { FinanceOverview, LiveMap, MetricsToday } from '@/lib/schemas';

export const metadata: Metadata = { title: 'Accueil' };

/** Ce que voit le membre : chaque source n'est lue que si son rôle l'y autorise. */
async function load<T>(allowed: boolean, path: string): Promise<T | null> {
  if (!allowed) return null;
  try {
    return await staffApi<T>(path);
  } catch {
    return null;
  }
}

/**
 * Accueil (maquette BO-Accueil) : la journée en six chiffres, commandes par heure en
 * colonnes, quartiers les plus demandés, et ce qui est à traiter maintenant.
 */
export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ acces?: string }>;
}) {
  const session = await requireStaff();
  const { acces } = await searchParams;
  const now = new Date();
  const can = (roles: readonly string[]) => roles.some((role) => session.roles.includes(role));
  const [today, map, finance] = await Promise.all([
    load<MetricsToday>(can(METRICS_ROLES), '/admin/metrics/today'),
    load<LiveMap>(can(OPS_ROLES), '/admin/live-map'),
    load<FinanceOverview>(can(FINANCE_ROLES), '/admin/finance/overview'),
  ]);
  const firstName = session.name?.split(/\s+/)[0];
  const alerts = map ? alertsOf(map, now.getTime()) : [];
  const counts = map ? countsOf(map) : null;
  const todo: Todo[] = [
    ...alerts.slice(0, finance?.payoutsAwaitingApproval ? 3 : 4).map((alert) => ({
      key: alert.key,
      urgent: alert.level === 'critical',
      title: alert.title,
      detail: alert.detail,
      href: alert.orderId ? `/carte?commande=${alert.orderId}` : '/carte',
      action: alert.level === 'critical' ? 'Ouvrir' : 'Voir',
    })),
    ...(finance?.payoutsAwaitingApproval
      ? [
          {
            key: 'payouts',
            urgent: false,
            title: `${finance.payoutsAwaitingApproval} reversement${finance.payoutsAwaitingApproval > 1 ? 's' : ''} à valider`,
            detail: 'Gros montants, en attente de votre accord',
            href: '/finance',
            action: 'Valider',
          },
        ]
      : []),
  ];
  const pending = alerts.length + (finance?.payoutsAwaitingApproval ? 1 : 0);

  return (
    <div className="mx-auto max-w-[1180px] pb-8">
      <TopBar
        title={`${greeting(now)}${firstName ? ` ${firstName}` : ''}`}
        subtitle={`${longDate.format(now)} · ${time(now)} · Douala`}
        alerts={map ? alerts.length : undefined}
      />
      {acces === 'refuse' ? (
        <div className="mb-4">
          <Note tone="warn">Cette page est réservée à d’autres rôles de l’équipe.</Note>
        </div>
      ) : null}
      {today ? (
        <Kpis
          today={today}
          online={counts ? counts.free + counts.onCourse : null}
          onCourse={counts?.onCourse ?? null}
        />
      ) : null}
      <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
        {today ? <Hourly today={today} hour={doualaHour(now)} /> : null}
        <section className="bo-glass flex min-h-[300px] flex-col gap-3 rounded-[22px] px-[18px] py-4">
          <div className="flex items-center justify-between">
            <h2 className="text-[15px] font-bold">À traiter maintenant</h2>
            <span
              className={cx(
                'rounded-full px-2.5 py-1 text-[11px] font-extrabold',
                pending
                  ? 'bg-[rgba(255,107,117,.14)] text-[#E5252F] dark:text-[#FF6B75]'
                  : 'bg-ok-bg text-ok',
              )}
            >
              {pending}
            </span>
          </div>
          {todo.length ? (
            <ul className="flex flex-col gap-2.5">
              {todo.map((item) => (
                <TodoRow key={item.key} item={item} />
              ))}
            </ul>
          ) : (
            <p className="text-[13px] text-muted">
              {map || finance ? 'Rien d’urgent : tout roule.' : 'Rien à signaler pour votre rôle.'}
            </p>
          )}
          {alerts.length > todo.filter((item) => item.key !== 'payouts').length ? (
            <Link
              href="/carte"
              className="mt-auto text-[12px] font-extrabold text-accent underline"
            >
              Toutes les alertes sur la carte
            </Link>
          ) : null}
        </section>
      </div>
    </div>
  );
}

interface Todo {
  key: string;
  urgent: boolean;
  title: string;
  detail: string;
  href: string;
  action: string;
}

function TodoRow({ item }: { item: Todo }) {
  return (
    <li
      className={cx(
        'flex items-center gap-3 rounded-[14px] px-3 py-2.5',
        item.urgent ? 'bg-[rgba(255,107,117,.14)]' : 'bg-[rgba(255,177,92,.16)]',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'size-2.5 shrink-0 rounded-full',
          item.urgent
            ? 'bg-[#FF6B75] shadow-[0_0_10px_#FF6B75]'
            : 'bg-accent shadow-[0_0_10px_var(--accent)]',
        )}
      />
      <span className="min-w-0 flex-1">
        <b className="block text-[13px]">{item.title}</b>
        <span className="block text-[12px] text-muted">{item.detail}</span>
      </span>
      <Link href={item.href} className="text-[12px] font-extrabold text-accent underline">
        {item.action}
      </Link>
    </li>
  );
}

/** Les six chiffres du jour (maquette : carte de verre, chiffre en grand, barre qui coule). */
function Kpis({
  today,
  online,
  onCourse,
}: {
  today: MetricsToday;
  online: number | null;
  onCourse: number | null;
}) {
  const orders = change(today.orders, today.previousOrders);
  const success = pointsChange(today.successRate, today.previousSuccessRate);
  const delay =
    today.deliveryMinutes !== null && today.previousDeliveryMinutes !== null
      ? Math.round(today.deliveryMinutes - today.previousDeliveryMinutes)
      : null;
  const weekday = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', timeZone: 'Africa/Douala' })
    .format(new Date())
    .toLowerCase();
  return (
    <div className="grid grid-cols-2 gap-3.5 md:grid-cols-3 xl:grid-cols-6">
      <Kpi
        label="Commandes du jour"
        value={String(today.orders)}
        note={orders ? `${orders.text} vs ${weekday} dernier` : null}
        tone={orders && !orders.up ? 'down' : 'up'}
        fill={
          today.previousOrders ? Math.min(1, today.orders / (today.previousOrders * 1.5)) : null
        }
      />
      <Kpi
        label="En cours"
        value={String(today.inProgress)}
        note={`${today.searching} en recherche`}
        tone="accent"
      />
      <Kpi
        label="Livreurs en ligne"
        value={online === null ? '—' : `${online} / ${today.approvedRiders}`}
        note={onCourse === null ? null : `${onCourse} en course`}
        tone="accent"
        fill={online === null || !today.approvedRiders ? null : online / today.approvedRiders}
      />
      <Kpi
        label="Taux de réussite"
        value={rate(today.successRate)}
        note={success ? `${success} vs hier` : null}
        tone={success?.startsWith('−') ? 'down' : 'up'}
        fill={today.successRate}
      />
      <Kpi
        label="Délai médian"
        value={minutes(today.deliveryMinutes)}
        note={
          delay === null || delay === 0
            ? null
            : `${delay > 0 ? '+' : '−'}${Math.abs(delay)} min vs hier`
        }
        tone={delay !== null && delay > 0 ? 'down' : 'up'}
      />
      <Kpi
        label="Encaissé aujourd’hui"
        value={short(today.collected)}
        note="pour les boutiques"
        tone="accent"
      />
    </div>
  );
}

/** « 2 400 000 » → « 2,4 M F » ; « 85 000 » → « 85 000 F ». */
function short(value: number): string {
  if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(1).replace('.', ',').replace(',0', '')} M F`;
  }
  return `${new Intl.NumberFormat('fr-FR').format(value)} F`;
}

/** Commandes par heure, en colonnes en relief ; l'heure en cours en orange. */
function Hourly({ today, hour }: { today: MetricsToday; hour: number }) {
  return (
    <section className="bo-glass flex flex-col gap-3 rounded-[22px] px-[18px] py-4">
      <div className="flex items-center justify-between">
        <h2 className="text-[15px] font-bold">Commandes par heure</h2>
        <span className="rounded-full bg-[rgba(255,177,92,.16)] px-2.5 py-1 text-[11px] font-extrabold text-accent">
          Aujourd’hui
        </span>
      </div>
      <Columns today={today} hour={hour} />
      {today.neighborhoods.length ? (
        <div className="grid grid-cols-3 gap-2.5">
          {today.neighborhoods.map((place) => (
            <Tile key={place.name} label={place.name}>
              {place.orders} commande{place.orders > 1 ? 's' : ''}
            </Tile>
          ))}
        </div>
      ) : null}
    </section>
  );
}

/** Colonnes en relief (face, côté, dessus), dessinées en SVG ; l'heure en cours en orange. */
function Columns({ today, hour }: { today: MetricsToday; hour: number }) {
  const max = Math.max(1, ...today.hourly.map((slot) => slot.orders));
  const slot = 44;
  const front = 31;
  const base = 290;
  return (
    <figure className="m-0">
      <svg
        viewBox={`0 0 ${today.hourly.length * slot} 300`}
        preserveAspectRatio="none"
        className="block h-[300px] w-full"
        role="img"
        aria-label={today.hourly.map((s) => `${s.hour} h : ${s.orders}`).join(', ')}
      >
        {today.hourly.map((s, i) => {
          const h = Math.max(4, Math.round((s.orders / max) * 270));
          const x = i * slot;
          const top = base - h;
          return (
            <g key={s.hour} className={cx('bo-col', s.hour === hour && 'now')}>
              <title>{`${s.hour} h : ${s.orders} commande${s.orders > 1 ? 's' : ''}`}</title>
              <rect className="face" x={x} y={top} width={front} height={h} />
              <polygon
                className="side"
                points={`${x + front},${top} ${x + front + 9},${top - 7.5} ${x + front + 9},${base - 7.5} ${x + front},${base}`}
              />
              <polygon
                className="cap"
                points={`${x},${top} ${x + front},${top} ${x + front + 9},${top - 7.5} ${x + 9},${top - 7.5}`}
              />
            </g>
          );
        })}
      </svg>
      <figcaption className="mt-1.5 flex" aria-hidden="true">
        {today.hourly.map((s) => (
          <span
            key={s.hour}
            className="h-4 flex-1 pr-2 text-center text-[11px] font-extrabold text-faint"
          >
            {s.hour % 2 === 0 ? `${s.hour} h` : ''}
          </span>
        ))}
      </figcaption>
    </figure>
  );
}

function Tile({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="rounded-2xl bg-track p-3">
      <span className="text-[12px] text-muted">{label}</span>
      <b className="block font-display text-[20px]">{children}</b>
    </div>
  );
}
