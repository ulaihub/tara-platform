import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { Kpi } from '@/components/kpi';
import { Pills, ROW_CELL, ROW_HEAD, ROW_TABLE } from '@/components/pills';
import { TopBar } from '@/components/top-bar';
import { cx } from '@/components/ui';
import { alertsOf, countsOf } from '@/lib/live';
import type { LiveMap } from '@/lib/schemas';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime } from '@/lib/format';
import { displayPhone } from '@/lib/phone';
import {
  RIDER_ROLES,
  RIDER_STATUS_LABELS,
  RIDER_STATUS_TONE,
  RIDER_VIEWS,
  VEHICLE_LABELS,
  documentSummary,
  ratingText,
  riderView,
} from '@/lib/riders';
import type { AdminRider, AdminRiderPage } from '@/lib/schemas';

export const metadata: Metadata = { title: 'Livreurs' };

type Search = { q?: string; vue?: string; suite?: string };

/** Adresse de la liste avec ces critères (les autres sont gardés). */
function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...current, ...changes })) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `/livreurs?${query}` : '/livreurs';
}

/**
 * Livreurs (H3) : candidatures et pièces à examiner d'abord, puis par statut ; recherche
 * par nom, numéro ou plaque. Un clic ouvre la fiche (pièces, décision, fiabilité).
 */
export default async function RidersPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(RIDER_ROLES);
  const search = await searchParams;
  const view = riderView(search.vue);
  const q = search.q?.trim() ?? '';
  const page = await staffApi<AdminRiderPage>('/admin/riders', {
    query: {
      view,
      q: q.length >= 2 ? q : undefined,
      cursor: search.suite,
      limit: 30,
    },
  });
  const current: Search = { q, vue: view === 'TO_REVIEW' ? undefined : view.toLowerCase() };
  // Livreurs en ligne : la carte en direct (mêmes rôles que cette page).
  const map = await staffApi<LiveMap>('/admin/live-map').catch(() => null);

  const online = map ? countsOf(map) : null;
  return (
    <div className="mx-auto max-w-[1280px] pb-8">
      <TopBar
        title="Livreurs"
        subtitle="Dossiers, fiabilité, suspensions"
        alerts={map ? alertsOf(map, Date.now()).length : undefined}
      />
      <div className="mb-4 grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <Kpi
          label="Livreurs validés"
          value={String(page.counts.ACTIVE)}
          note={`${page.counts.TO_REVIEW} dossier${page.counts.TO_REVIEW > 1 ? 's' : ''} à vérifier`}
          tone={page.counts.TO_REVIEW > 0 ? 'down' : 'up'}
        />
        <Kpi
          label="En ligne"
          value={online ? String(online.free + online.onCourse) : '—'}
          note={online ? `${online.onCourse} en course` : null}
          tone="accent"
          fill={
            online && page.counts.ACTIVE
              ? (online.free + online.onCourse) / page.counts.ACTIVE
              : null
          }
        />
        <Kpi
          label="Candidatures"
          value={String(page.counts.PENDING)}
          note="en attente de pièces"
          tone="accent"
        />
        <Kpi
          label="Suspendus"
          value={String(page.counts.SUSPENDED)}
          note={page.counts.SUSPENDED ? 'à suivre' : 'aucun'}
          tone={page.counts.SUSPENDED ? 'down' : 'up'}
        />
      </div>

      <Pills
        label="Vues"
        items={RIDER_VIEWS.map((item) => ({
          href: hrefWith(current, {
            vue: item.value === 'TO_REVIEW' ? undefined : item.value.toLowerCase(),
            suite: undefined,
          }),
          label: item.label,
          active: view === item.value,
          count: page.counts[item.value],
          alert: item.value === 'TO_REVIEW',
        }))}
      />
      <form action="/livreurs" role="search" className="mb-4 flex max-w-[420px] gap-2">
        {current.vue ? <input type="hidden" name="vue" value={current.vue} /> : null}
        <label className="bo-glass flex h-10 flex-1 items-center gap-2 rounded-xl px-3">
          <Icon name="search" size={16} className="text-faint" />
          <span className="sr-only">Chercher un livreur</span>
          <input
            name="q"
            defaultValue={q}
            placeholder="Nom, numéro ou plaque"
            className="w-full bg-transparent text-[13px] focus:outline-none"
          />
        </label>
      </form>

      <section className="bo-glass rounded-[22px] p-3 sm:px-[18px] sm:py-4">
        <h2 className="mb-2 px-1 text-[15px] font-bold">Livreurs</h2>
        {page.items.length === 0 ? (
          <div className="px-6 py-14 text-center">
            <p className="font-display text-[18px] font-bold">
              {view === 'TO_REVIEW' && !q ? 'Rien à examiner' : 'Aucun livreur'}
            </p>
            <p className="mt-1 text-muted">
              {view === 'TO_REVIEW' && !q
                ? 'Toutes les candidatures et pièces envoyées ont été traitées.'
                : 'Changez la recherche ou la vue.'}
            </p>
          </div>
        ) : (
          <>
            <ul className="flex flex-col gap-2 md:hidden">
              {page.items.map((rider) => (
                <RiderCard key={rider.id} rider={rider} />
              ))}
            </ul>
            <div className="hidden overflow-x-auto md:block">
              <table className={cx(ROW_TABLE, 'min-w-[760px]')}>
                <thead className={ROW_HEAD}>
                  <tr>
                    <th className="px-3 pb-1">Livreur</th>
                    <th className="px-3 pb-1">Véhicule</th>
                    <th className="px-3 pb-1">Dossier</th>
                    <th className="px-3 pb-1">Pièces</th>
                    <th className="px-3 pb-1">Note</th>
                    <th className="px-3 pb-1">30 jours</th>
                    <th className="px-3 pb-1">Inscrit</th>
                  </tr>
                </thead>
                <tbody>
                  {page.items.map((rider) => (
                    <RiderRow key={rider.id} rider={rider} />
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

      {page.nextCursor || search.suite ? (
        <div className="mt-4 flex justify-between">
          {search.suite ? (
            <Link
              href={hrefWith(current, { suite: undefined })}
              className="text-[14px] font-bold text-accent hover:underline"
            >
              ← Revenir au début
            </Link>
          ) : (
            <span />
          )}
          {page.nextCursor ? (
            <Link
              href={hrefWith(current, { suite: page.nextCursor })}
              className="text-[14px] font-bold text-accent hover:underline"
            >
              Livreurs suivants →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function Name({ rider }: { rider: AdminRider }) {
  return (
    <Link
      href={`/livreurs/${rider.id}`}
      className="font-display font-bold after:absolute after:inset-0 after:content-['']"
    >
      {rider.user.closed ? 'Ancien livreur' : (rider.user.fullName ?? 'Sans nom')}
    </Link>
  );
}

function StatusPill({ rider }: { rider: AdminRider }) {
  return (
    <span
      className={cx(
        'rounded-md px-2 py-0.5 text-[11px] font-extrabold whitespace-nowrap',
        RIDER_STATUS_TONE[rider.status],
      )}
    >
      {RIDER_STATUS_LABELS[rider.status]}
    </span>
  );
}

function RiderCard({ rider }: { rider: AdminRider }) {
  const documents = documentSummary(rider);
  const rating = ratingText(rider.rating.average);
  return (
    <li className="relative rounded-[14px] bg-track px-3 py-2.5">
      <div className="flex items-center gap-2">
        <Name rider={rider} />
        <span className="ml-auto">
          <StatusPill rider={rider} />
        </span>
      </div>
      <p className="mt-1 text-[12px] text-muted">
        {VEHICLE_LABELS[rider.vehicleType]}
        {rider.plateNumber ? ` · ${rider.plateNumber}` : ''}
        {rating ? ` · ★ ${rating}` : ''} · {rider.deliveredLast30Days} course
        {rider.deliveredLast30Days > 1 ? 's' : ''} en 30 j
      </p>
      <p className={cx('mt-0.5 text-[12px] font-bold', documents.tone)}>{documents.text}</p>
    </li>
  );
}

function RiderRow({ rider }: { rider: AdminRider }) {
  const documents = documentSummary(rider);
  const rating = ratingText(rider.rating.average);
  return (
    <tr className="relative transition hover:brightness-95">
      <td className={ROW_CELL}>
        <Name rider={rider} />
        <span className="block text-[12px] text-muted">
          {rider.user.closed ? 'Compte fermé' : displayPhone(rider.user.phone)}
        </span>
      </td>
      <td className={cx(ROW_CELL, 'whitespace-nowrap')}>
        {VEHICLE_LABELS[rider.vehicleType]}
        {rider.plateNumber ? (
          <span className="block text-[12px] text-muted">{rider.plateNumber}</span>
        ) : null}
      </td>
      <td className={ROW_CELL}>
        <StatusPill rider={rider} />
      </td>
      <td className={cx(ROW_CELL, 'font-bold', documents.tone)}>{documents.text}</td>
      <td className={cx(ROW_CELL, 'whitespace-nowrap')}>
        {rating ? (
          <>
            {rating} ★ <span className="text-faint">({rider.rating.count})</span>
          </>
        ) : (
          <span className="text-faint">—</span>
        )}
      </td>
      <td className={cx(ROW_CELL, 'whitespace-nowrap font-bold')}>
        {rider.status === 'ACTIVE' || rider.deliveredLast30Days > 0
          ? `${rider.deliveredLast30Days} course${rider.deliveredLast30Days > 1 ? 's' : ''}`
          : '—'}
      </td>
      <td className={cx(ROW_CELL, 'whitespace-nowrap text-muted')}>{dateTime(rider.createdAt)}</td>
    </tr>
  );
}
