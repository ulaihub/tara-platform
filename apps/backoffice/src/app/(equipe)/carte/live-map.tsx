'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from 'react';
import { Icon, type IconName } from '@/components/icon';
import { cx } from '@/components/ui';
import { ago, distance, duration, firstName, money, time } from '@/lib/format';
import {
  type AlertItem,
  REFRESH_MS,
  RIDER_STATE_LABELS,
  STATUS_LABELS,
  alertsOf,
  delayText,
  countsOf,
  place,
  type Point,
} from '@/lib/live';
import { type Selection, pointsOf, trailPoints, trailRequest } from '@/lib/map-data';
import { displayPhone } from '@/lib/phone';
import type { LiveMap as LiveMapData, LiveOrder, LiveRider, RiderTrail } from '@/lib/schemas';
import { acknowledgeSos } from './actions';
import { MapView } from './map-view';

type Tab = 'alertes' | 'commandes' | 'livreurs';

/** Trois bips courts et aigus : un SOS vient d'arriver. */
function beep(): void {
  try {
    const audio = new AudioContext();
    for (let index = 0; index < 3; index += 1) {
      const start = audio.currentTime + index * 0.28;
      const tone = audio.createOscillator();
      const gain = audio.createGain();
      tone.frequency.value = 880;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.4, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.2);
      tone.connect(gain).connect(audio.destination);
      tone.start(start);
      tone.stop(start + 0.22);
    }
  } catch {
    // Son bloqué par le navigateur tant que la page n'a pas été touchée : l'alerte reste visible.
  }
}

/** Relit la carte toutes les 5 s (en pause quand l'onglet est caché), plus lentement en cas d'échec. */
function useLiveMap(initial: LiveMapData) {
  const [data, setData] = useState(initial);
  const [failing, setFailing] = useState(false);
  const [receivedAt, setReceivedAt] = useState(() => Date.now());
  const refresh = useRef<() => void>(() => undefined);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    let failures = 0;
    let stopped = false;
    const schedule = (delay: number) => {
      clearTimeout(timer);
      if (!stopped) timer = setTimeout(() => void tick(), delay);
    };
    async function tick(): Promise<void> {
      if (document.hidden) return schedule(REFRESH_MS);
      try {
        const response = await fetch('/carte/donnees', { cache: 'no-store' });
        // Session terminée : le serveur renvoie vers la connexion.
        if (response.redirected || response.status === 401) {
          window.location.assign('/connexion?expiree=1');
          return;
        }
        if (!response.ok) throw new Error(String(response.status));
        const next = (await response.json()) as LiveMapData;
        if (stopped) return;
        setData(next);
        setReceivedAt(Date.now());
        setFailing(false);
        failures = 0;
      } catch {
        failures += 1;
        if (!stopped) setFailing(true);
      }
      schedule(failures === 0 ? REFRESH_MS : Math.min(30_000, REFRESH_MS * 2 ** failures));
    }
    refresh.current = () => schedule(0);
    const onVisible = () => {
      if (!document.hidden) schedule(0);
    };
    document.addEventListener('visibilitychange', onVisible);
    schedule(REFRESH_MS);
    return () => {
      stopped = true;
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, []);

  return { data, failing, receivedAt, refresh: () => refresh.current() };
}

/** Tracé de la course choisie, relu toutes les 10 s (chemin parcouru, itinéraire restant). */
const TRAIL_REFRESH_MS = 10_000;

function useTrail(data: LiveMapData, selection: Selection): RiderTrail | null {
  const request = trailRequest(data, selection);
  const key = request ? `${request.riderId}:${request.orderId ?? ''}` : null;
  const [trail, setTrail] = useState<{ key: string; trail: RiderTrail } | null>(null);
  useEffect(() => {
    if (!key) return;
    const [riderId, orderId] = key.split(':');
    const query = new URLSearchParams({ livreur: riderId ?? '' });
    if (orderId) query.set('commande', orderId);
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const load = async () => {
      try {
        const response = await fetch(`/carte/trajet?${query.toString()}`, { cache: 'no-store' });
        if (response.ok && !response.redirected) {
          const next = (await response.json()) as RiderTrail;
          if (!stopped) setTrail({ key, trail: next });
        }
      } catch {
        // Réseau coupé : le trait pointillé reste affiché, nouvel essai au prochain tour.
      }
      if (!stopped) timer = setTimeout(() => void load(), TRAIL_REFRESH_MS);
    };
    void load();
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [key]);
  return trail && trail.key === key ? trail.trail : null;
}

/** Horloge à la seconde, pour « il y a … ». */
function useNow(): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1_000);
    return () => clearInterval(timer);
  }, []);
  return now;
}

/**
 * Carte en direct (H1) : la ville à gauche, ce qui demande l'attention à droite. Un SOS
 * arrive avec un son et passe en tête ; un clic sur un élément le montre sur la carte.
 */
export function LiveMap({
  initial,
  focusOrder = null,
}: {
  initial: LiveMapData;
  focusOrder?: string | null;
}) {
  const { data, failing, receivedAt, refresh } = useLiveMap(initial);
  const now = useNow();
  const [tab, setTab] = useState<Tab>('alertes');
  const [selection, setSelection] = useState<Selection>(null);
  const [focus, setFocus] = useState<{ points: Point[] } | null>(null);
  const alerts = useMemo(() => alertsOf(data, now), [data, now]);
  const counts = useMemo(() => countsOf(data), [data]);
  const trail = useTrail(data, selection);

  // Premier tracé reçu pour la course choisie : la carte la montre entière.
  const framed = useRef<string | null>(null);
  useEffect(() => {
    if (!trail?.order) return;
    const key = `${trail.riderId}:${trail.order.id}`;
    if (framed.current === key) return;
    framed.current = key;
    const points = trailPoints(trail);
    if (points.length > 1) setFocus({ points });
  }, [trail]);

  // Nouveau SOS : son et titre de l'onglet, même si l'agent regarde ailleurs.
  const seenSos = useRef(new Set(initial.safetyAlerts.map((alert) => alert.id)));
  useEffect(() => {
    const fresh = data.safetyAlerts.filter((alert) => !seenSos.current.has(alert.id));
    for (const alert of fresh) seenSos.current.add(alert.id);
    if (fresh.length > 0) {
      beep();
      setTab('alertes');
    }
    const open = data.safetyAlerts.filter((alert) => !alert.acknowledgedAt).length;
    document.title =
      open > 0 ? `(${open}) SOS · Carte en direct` : 'Carte en direct · Back-office Tara';
  }, [data.safetyAlerts]);

  const choose = useCallback(
    (next: Selection) => {
      setSelection(next);
      framed.current = null;
      const points = pointsOf(data, next);
      if (points.length > 0) setFocus({ points });
    },
    [data],
  );

  // Arrivée depuis une fiche commande : elle est choisie et montrée sur la carte.
  const opened = useRef(false);
  useEffect(() => {
    if (opened.current || !focusOrder) return;
    opened.current = true;
    setTab('commandes');
    choose({ type: 'order', id: focusOrder });
  }, [focusOrder, choose]);

  return (
    <div className="flex flex-col gap-4 lg:h-[calc(100vh-128px)] lg:flex-row">
      <section
        className="bo-glass relative h-[58vh] min-h-[320px] overflow-hidden rounded-[22px] lg:h-auto lg:min-w-0 lg:flex-1"
        aria-label="Carte de Douala"
      >
        <MapView
          data={data}
          selection={selection}
          trail={trail}
          focus={focus}
          onSelect={setSelection}
        />
        {/* Téléphone : une seule ligne qui défile ; grand écran : sur plusieurs lignes. */}
        <div className="absolute inset-x-0 top-0 flex items-start gap-2 overflow-x-auto px-3 pt-3 lg:pointer-events-none lg:inset-x-4 lg:top-4 lg:flex-wrap lg:overflow-visible lg:p-0">
          <Counter tone="free" label="Libres" value={counts.free} />
          <Counter tone="course" label="En course" value={counts.onCourse} />
          <Counter tone="offline" label="Hors ligne" value={counts.offline} />
          <Counter tone="neutral" label="Commandes" value={counts.orders} />
          <Counter
            tone={counts.late > 0 ? 'late' : 'neutral'}
            label="En retard"
            value={counts.late}
          />
          <span className="ml-auto hidden lg:block" />
          <p
            role="status"
            className={cx(
              'pointer-events-auto shrink-0 rounded-xl px-3 py-2 text-[12px] font-extrabold whitespace-nowrap',
              failing ? 'bg-danger-bg text-danger' : 'bo-glass text-muted',
            )}
          >
            {failing
              ? 'Connexion perdue · nouvel essai…'
              : `À jour · ${ago(new Date(receivedAt).toISOString(), now)}`}
          </p>
        </div>
        <Legend className="bo-glass absolute bottom-4 left-4 hidden space-y-1 rounded-2xl px-3 py-2.5 lg:block" />
      </section>

      <aside className="bo-glass flex w-full flex-col overflow-hidden rounded-[22px] lg:w-[360px] lg:shrink-0">
        <Legend className="flex flex-wrap gap-x-4 gap-y-1 border-b border-line px-4 py-2.5 lg:hidden" />
        <div
          role="tablist"
          aria-label="Contenu du panneau"
          className="m-3 mb-0 flex gap-1 rounded-[14px] bg-track p-1"
        >
          <TabButton
            current={tab}
            value="alertes"
            onSelect={setTab}
            count={alerts.length}
            urgent={alerts.some((alert) => alert.level === 'critical')}
          >
            Alertes
          </TabButton>
          <TabButton current={tab} value="commandes" onSelect={setTab} count={data.orders.length}>
            Commandes
          </TabButton>
          <TabButton current={tab} value="livreurs" onSelect={setTab} count={data.riders.length}>
            Livreurs
          </TabButton>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto p-3">
          {tab === 'alertes' ? (
            <AlertList
              alerts={alerts}
              selection={selection}
              onChoose={choose}
              onAcknowledged={refresh}
            />
          ) : tab === 'commandes' ? (
            <OrderList
              rules={data.rules}
              orders={data.orders}
              riders={data.riders}
              now={now}
              selection={selection}
              onChoose={choose}
            />
          ) : (
            <RiderList riders={data.riders} now={now} selection={selection} onChoose={choose} />
          )}
        </div>
        <Details
          data={data}
          selection={selection}
          trail={trail}
          now={now}
          onClose={() => setSelection(null)}
          onChoose={choose}
        />
      </aside>
    </div>
  );
}

const COUNTER_DOT = {
  free: 'bg-[#12805a]',
  course: 'bg-[#ff6a00]',
  offline: 'bg-[#9a9187]',
  late: 'bg-[#d93025]',
  neutral: 'bg-faint',
} as const;

function Counter({
  tone,
  label,
  value,
}: {
  tone: keyof typeof COUNTER_DOT;
  label: string;
  value: number;
}) {
  return (
    <p
      className={cx(
        'bo-glass pointer-events-auto flex shrink-0 items-center gap-2 rounded-xl px-3 py-1.5 whitespace-nowrap',
        tone === 'late' && 'text-danger',
      )}
    >
      <span aria-hidden="true" className={cx('size-2.5 rounded-full', COUNTER_DOT[tone])} />
      <span className="text-[13px] font-extrabold tabular-nums">{value}</span>
      <span className="text-[12px] font-extrabold">{label}</span>
    </p>
  );
}

function Legend({ className }: { className: string }) {
  const items: [string, string][] = [
    ['bg-[#12805a]', 'Livreur libre'],
    ['bg-[#ff6a00]', 'Livreur en course'],
    ['bg-[#9a9187]', 'Hors ligne (dernière position)'],
    ['bg-[#16120e] ring-2 ring-[#ff6a00]', 'Vendeur à servir'],
    ['bg-white ring-[3px] ring-[#ff6a00]', 'Client à livrer'],
    ['bg-[#d93025]', 'En retard'],
  ];
  return (
    <ul aria-label="Légende" className={cx('text-[12px] font-bold text-muted', className)}>
      {items.map(([dot, label]) => (
        <li key={label} className="flex items-center gap-2">
          <span aria-hidden="true" className={cx('size-2.5 rounded-full', dot)} />
          {label}
        </li>
      ))}
    </ul>
  );
}

function TabButton({
  current,
  value,
  count,
  urgent = false,
  onSelect,
  children,
}: {
  current: Tab;
  value: Tab;
  count: number;
  urgent?: boolean;
  onSelect: (tab: Tab) => void;
  children: string;
}) {
  const active = current === value;
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={() => onSelect(value)}
      className={cx(
        'flex min-h-9 flex-1 items-center justify-center gap-1.5 rounded-[11px] text-[13px] font-extrabold transition',
        active
          ? 'bg-brand text-on-brand shadow-[0_6px_14px_rgba(255,90,0,.25)]'
          : 'text-muted hover:text-text',
      )}
    >
      {children}
      <span
        className={cx(
          'min-w-6 rounded-full px-1.5 text-[12px] font-extrabold tabular-nums',
          urgent ? 'bg-danger text-white' : 'bg-track text-muted',
        )}
      >
        {count}
      </span>
    </button>
  );
}

/** Cartes d'alerte teintées (maquette BO-Carte) : rouge pour un SOS, orange sinon. */
const LEVEL_STYLE = {
  critical: 'border-transparent bg-[rgba(255,107,117,.14)]',
  high: 'border-transparent bg-[rgba(255,177,92,.16)]',
  normal: 'border-transparent bg-track',
} as const;

const LEVEL_ICON: Record<AlertItem['level'], IconName> = {
  critical: 'alertCircle',
  high: 'clock',
  normal: 'bell',
};

function AlertList({
  alerts,
  selection,
  onChoose,
  onAcknowledged,
}: {
  alerts: AlertItem[];
  selection: Selection;
  onChoose: (selection: Selection) => void;
  onAcknowledged: () => void;
}) {
  if (alerts.length === 0) {
    return (
      <div className="grid place-items-center px-6 py-16 text-center">
        <span className="mb-3 grid size-12 place-items-center rounded-2xl bg-ok-bg text-ok">
          <Icon name="check" size={24} />
        </span>
        <p className="font-display text-[17px] font-bold">Tout roule</p>
        <p className="mt-1 text-[14px] text-muted">Aucun SOS, aucun retard, rien à valider.</p>
      </div>
    );
  }
  return (
    <ul className="space-y-2">
      {alerts.map((alert) => {
        const target: Selection = alert.safety
          ? { type: 'sos', id: alert.safety.id }
          : alert.orderId
            ? { type: 'order', id: alert.orderId }
            : alert.riderId
              ? { type: 'rider', id: alert.riderId }
              : null;
        const active =
          target !== null && selection?.type === target.type && selection.id === target.id;
        return (
          <li
            key={alert.key}
            className={cx(
              'rounded-[16px] border p-3',
              LEVEL_STYLE[alert.level],
              active && 'ring-2 ring-accent-line',
            )}
          >
            <button
              type="button"
              className="flex w-full items-start gap-3 text-left"
              onClick={() => onChoose(target)}
            >
              <span
                className={cx(
                  'mt-0.5 grid size-8 shrink-0 place-items-center rounded-xl',
                  alert.level === 'critical'
                    ? 'bg-danger text-white'
                    : alert.level === 'high'
                      ? 'bg-warn-bg text-warn'
                      : 'bg-accent-bg text-accent',
                )}
              >
                <Icon name={LEVEL_ICON[alert.level]} size={17} />
              </span>
              <span className="min-w-0 flex-1">
                <span
                  className={cx(
                    'block text-[14px] font-extrabold',
                    alert.level === 'critical' && 'text-danger',
                  )}
                >
                  {alert.title}
                </span>
                <span className="block text-[13px] text-muted">{alert.detail}</span>
              </span>
            </button>
            {alert.safety && !alert.safety.acknowledged ? (
              <AcknowledgeButton id={alert.safety.id} onDone={onAcknowledged} />
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

function AcknowledgeButton({ id, onDone }: { id: string; onDone: () => void }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <div className="mt-2 pl-11">
      <button
        type="button"
        disabled={pending}
        onClick={() =>
          start(async () => {
            const result = await acknowledgeSos(id);
            setError(result.error);
            if (!result.error) onDone();
          })
        }
        className="min-h-9 rounded-xl bg-danger px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
      >
        {pending ? 'Un instant…' : 'Je m’en occupe'}
      </button>
      {error ? (
        <p role="alert" className="mt-1 text-[13px] font-bold text-danger">
          {error}
        </p>
      ) : null}
    </div>
  );
}

const STATUS_TONE: Partial<Record<LiveOrder['status'], string>> = {
  SEARCHING_RIDER: 'bg-warn-bg text-warn',
  DELIVERY_FAILED: 'bg-danger-bg text-danger',
  CREATED: 'bg-track text-muted',
};

function OrderList({
  rules,
  orders,
  riders,
  now,
  selection,
  onChoose,
}: {
  rules: LiveMapData['rules'];
  orders: LiveOrder[];
  riders: LiveRider[];
  now: number;
  selection: Selection;
  onChoose: (selection: Selection) => void;
}) {
  const byId = new Map(riders.map((rider) => [rider.id, rider]));
  if (orders.length === 0) {
    return (
      <p className="px-3 py-16 text-center text-[14px] text-muted">Aucune commande en cours.</p>
    );
  }
  // Les retards d'abord, puis les plus anciennes.
  const sorted = orders.toSorted(
    (a, b) =>
      Number(b.delay !== null) - Number(a.delay !== null) || a.createdAt.localeCompare(b.createdAt),
  );
  return (
    <ul className="space-y-2">
      {sorted.map((order) => {
        const rider = order.riderId ? byId.get(order.riderId) : undefined;
        const active = selection?.type === 'order' && selection.id === order.id;
        return (
          <li key={order.id}>
            <button
              type="button"
              onClick={() => onChoose({ type: 'order', id: order.id })}
              className={cx(
                'w-full rounded-2xl border bg-panel p-3 text-left transition hover:border-accent-line',
                active ? 'border-accent-line ring-2 ring-accent-line' : 'border-line',
              )}
            >
              <span className="flex items-center gap-2">
                <span className="font-display text-[14px] font-bold">{order.reference}</span>
                {order.isExpress ? (
                  <span className="rounded-full bg-accent-bg px-2 text-[11px] font-extrabold text-accent">
                    Express
                  </span>
                ) : null}
                <span className="ml-auto text-[12px] text-faint">{ago(order.createdAt, now)}</span>
              </span>
              <span className="mt-1 flex items-center gap-2">
                <span
                  className={cx(
                    'rounded-full px-2 py-0.5 text-[12px] font-bold',
                    STATUS_TONE[order.status] ?? 'bg-accent-bg text-accent',
                  )}
                >
                  {STATUS_LABELS[order.status]}
                </span>
                {order.delay ? (
                  <span className="text-[12px] font-extrabold text-danger">
                    {delayText(order, rules)}
                  </span>
                ) : null}
              </span>
              <span className="mt-1.5 block truncate text-[13px] text-muted">
                {order.pickup.neighborhood ?? order.pickup.landmark} →{' '}
                {order.dropoff.neighborhood ?? order.dropoff.landmark}
              </span>
              <span className="block truncate text-[12px] text-faint">
                {order.senderName ?? 'Expéditeur'} ·{' '}
                {rider ? firstName(rider.name, rider.phone) : 'sans livreur'}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

const STATE_ORDER: Record<LiveRider['state'], number> = { ON_COURSE: 0, FREE: 1, OFFLINE: 2 };
const STATE_DOT: Record<LiveRider['state'], string> = {
  FREE: 'bg-[#12805a]',
  ON_COURSE: 'bg-[#ff6a00]',
  OFFLINE: 'bg-[#9a9187]',
};

function RiderList({
  riders,
  now,
  selection,
  onChoose,
}: {
  riders: LiveRider[];
  now: number;
  selection: Selection;
  onChoose: (selection: Selection) => void;
}) {
  const [query, setQuery] = useState('');
  const needle = query.trim().toLowerCase();
  const digits = needle.replace(/\D/g, '');
  const shown = riders
    .filter(
      (rider) =>
        !needle ||
        (rider.name ?? '').toLowerCase().includes(needle) ||
        (digits.length >= 3 && rider.phone.includes(digits)),
    )
    .toSorted(
      (a, b) =>
        STATE_ORDER[a.state] - STATE_ORDER[b.state] || (a.name ?? '').localeCompare(b.name ?? ''),
    );
  return (
    <div>
      <label className="mb-3 flex min-h-10 items-center gap-2 rounded-xl border border-line bg-panel px-3">
        <Icon name="search" size={16} className="text-faint" />
        <span className="sr-only">Chercher un livreur</span>
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Nom ou numéro"
          className="w-full bg-transparent text-[14px] focus:outline-none"
        />
      </label>
      <ul className="space-y-1.5">
        {shown.map((rider) => {
          const active = selection?.type === 'rider' && selection.id === rider.id;
          return (
            <li key={rider.id}>
              <button
                type="button"
                onClick={() => onChoose({ type: 'rider', id: rider.id })}
                className={cx(
                  'flex w-full items-center gap-3 rounded-2xl border bg-panel px-3 py-2.5 text-left transition hover:border-accent-line',
                  active ? 'border-accent-line ring-2 ring-accent-line' : 'border-line',
                )}
              >
                <span
                  aria-hidden="true"
                  className={cx(
                    'size-2.5 shrink-0 rounded-full',
                    STATE_DOT[rider.state],
                    rider.signalLost && 'opacity-40',
                  )}
                />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[14px] font-bold">
                    {rider.name ?? displayPhone(rider.phone)}
                  </span>
                  <span className="block truncate text-[12px] text-faint">
                    {RIDER_STATE_LABELS[rider.state]}
                    {rider.signalLost ? ' · sans signal' : ''}
                    {rider.position ? ` · ${ago(rider.position.at, now)}` : ' · position inconnue'}
                  </span>
                </span>
                {rider.rating !== null ? (
                  <span className="text-[12px] font-bold text-muted">
                    ★ {rider.rating.toFixed(1)}
                  </span>
                ) : null}
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

/** Fiche de l'élément choisi, en bas du panneau. */
/** « Reste 2,4 km · environ 9 min » jusqu'au prochain arrêt, d'après l'itinéraire. */
function remainingLine(trail: RiderTrail | null, orderId: string | undefined): string | null {
  const remaining = trail?.order?.id === orderId ? trail?.remaining : null;
  if (!remaining) return null;
  const where = trail?.order?.target === 'pickup' ? 'jusqu’au vendeur' : 'jusqu’au client';
  const minutes =
    remaining.seconds !== null
      ? ` · environ ${duration(Math.max(1, Math.round(remaining.seconds / 60)))}`
      : '';
  return `Reste ${distance(remaining.meters)} ${where}${minutes}${remaining.onRoads ? '' : ' (estimation à vol d’oiseau)'}`;
}

function Details({
  data,
  selection,
  trail,
  now,
  onClose,
  onChoose,
}: {
  data: LiveMapData;
  selection: Selection;
  trail: RiderTrail | null;
  now: number;
  onClose: () => void;
  onChoose: (selection: Selection) => void;
}) {
  if (!selection) return null;
  let title = '';
  let lines: (string | null)[] = [];
  let phone: string | null = null;
  let link: { label: string; target: Selection } | null = null;
  let sheet: string | null = null;
  if (selection.type === 'rider') {
    const rider = data.riders.find((item) => item.id === selection.id);
    if (!rider) return null;
    title = rider.name ?? displayPhone(rider.phone);
    phone = rider.phone;
    lines = [
      `${RIDER_STATE_LABELS[rider.state]}${rider.signalLost ? ' · sans signal' : ''}`,
      rider.position ? `Dernière position ${ago(rider.position.at, now)}` : 'Position inconnue',
      [rider.plateNumber, rider.rating !== null ? `★ ${rider.rating.toFixed(1)}` : null]
        .filter(Boolean)
        .join(' · ') || null,
      remainingLine(trail, trail?.riderId === rider.id ? trail.order?.id : undefined),
    ];
    const orderId = rider.orderIds[0];
    if (orderId) {
      const order = data.orders.find((item) => item.id === orderId);
      link = {
        label: `Voir sa course ${order?.reference ?? ''}`.trim(),
        target: { type: 'order', id: orderId },
      };
    }
  } else if (selection.type === 'order') {
    const order = data.orders.find((item) => item.id === selection.id);
    if (!order) return null;
    const rider = data.riders.find((item) => item.id === order.riderId);
    title = `${order.reference} · ${STATUS_LABELS[order.status]}`;
    lines = [
      `Vendeur : ${order.senderName ?? 'expéditeur'} · ${place(order.pickup)}`,
      `Client : ${place(order.dropoff)}`,
      `Créée à ${time(order.createdAt)}${order.assignedAt ? ` · attribuée à ${time(order.assignedAt)}` : ''}${order.pickedUpAt ? ` · récupérée à ${time(order.pickedUpAt)}` : ''}`,
      order.codAmount > 0 ? `À encaisser : ${money(order.codAmount)}` : null,
      order.delay ? `En retard de ${duration(order.delay.minutes)}` : null,
      remainingLine(trail, order.id),
    ];
    sheet = `/commandes/${order.id}`;
    if (rider) {
      phone = rider.phone;
      link = {
        label: `Livreur : ${rider.name ?? displayPhone(rider.phone)}`,
        target: { type: 'rider', id: rider.id },
      };
    }
  } else {
    const alert = data.safetyAlerts.find((item) => item.id === selection.id);
    if (!alert) return null;
    title = `SOS · ${alert.riderName ?? displayPhone(alert.riderPhone)}`;
    phone = alert.riderPhone;
    lines = [
      `${alert.neighborhood ?? 'Quartier inconnu'} · déclenché à ${time(alert.createdAt)}`,
      alert.riderPlate ? `Moto ${alert.riderPlate}` : null,
      alert.note ? `Note : ${alert.note}` : null,
      alert.acknowledgedAt
        ? `Pris en charge à ${time(alert.acknowledgedAt)}`
        : 'Personne ne l’a encore pris en charge',
    ];
  }
  return (
    <section aria-label="Fiche" className="border-t border-line bg-panel p-4">
      <div className="flex items-start gap-2">
        <h2 className="flex-1 font-display text-[16px] font-bold">{title}</h2>
        <button
          type="button"
          onClick={onClose}
          aria-label="Fermer la fiche"
          className="grid size-8 place-items-center rounded-xl text-muted hover:bg-track"
        >
          <Icon name="close" size={16} />
        </button>
      </div>
      <ul className="mt-1 space-y-0.5 text-[13px] text-muted">
        {lines
          .filter((line): line is string => Boolean(line))
          .map((line) => (
            <li key={line}>{line}</li>
          ))}
      </ul>
      <div className="mt-3 flex flex-wrap gap-2">
        {phone ? (
          <a
            href={`tel:${phone}`}
            className="inline-flex min-h-9 items-center gap-2 rounded-xl bg-brand px-3 text-[13px] font-extrabold text-on-brand"
          >
            <Icon name="phone" size={15} />
            Appeler {displayPhone(phone)}
          </a>
        ) : null}
        {sheet ? (
          <Link
            href={sheet}
            className="inline-flex min-h-9 items-center rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
          >
            Ouvrir la fiche
          </Link>
        ) : null}
        {link ? (
          <button
            type="button"
            onClick={() => onChoose(link.target)}
            className="min-h-9 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
          >
            {link.label}
          </button>
        ) : null}
      </div>
    </section>
  );
}
