import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
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

  return (
    <div className="mx-auto max-w-[1280px]">
      <header className="mb-6 flex flex-wrap items-end gap-4">
        <div className="flex-1">
          <h1 className="font-display text-[28px] font-bold tracking-tight">Livreurs</h1>
          <p className="text-muted">
            {page.counts.ACTIVE} actif{page.counts.ACTIVE > 1 ? 's' : ''} · {page.counts.TO_REVIEW}{' '}
            dossier{page.counts.TO_REVIEW > 1 ? 's' : ''} à examiner
          </p>
        </div>
        <form action="/livreurs" className="flex w-full max-w-[520px] gap-2">
          {current.vue ? <input type="hidden" name="vue" value={current.vue} /> : null}
          <label className="flex min-h-11 flex-1 items-center gap-2 rounded-2xl border border-line bg-panel px-3 focus-within:border-accent-line">
            <Icon name="search" size={18} className="text-faint" />
            <span className="sr-only">Chercher un livreur</span>
            <input
              name="q"
              defaultValue={q}
              placeholder="Nom, numéro ou plaque"
              className="w-full bg-transparent text-[15px] focus:outline-none"
            />
          </label>
          <button
            type="submit"
            className="min-h-11 rounded-2xl bg-brand px-4 text-[14px] font-extrabold text-on-brand"
          >
            Chercher
          </button>
        </form>
      </header>

      <nav aria-label="Vues" className="mb-3 flex flex-wrap items-center gap-2">
        {RIDER_VIEWS.map((item) => {
          const active = view === item.value;
          const count = page.counts[item.value];
          return (
            <Link
              key={item.value}
              href={hrefWith(current, {
                vue: item.value === 'TO_REVIEW' ? undefined : item.value.toLowerCase(),
                suite: undefined,
              })}
              aria-current={active ? 'page' : undefined}
              className={cx(
                'inline-flex min-h-9 items-center gap-2 rounded-xl px-3 py-2 text-[13px] font-bold transition',
                active ? 'bg-text text-bg' : 'bg-panel text-muted hover:text-text',
              )}
            >
              {item.label}
              <span
                className={cx(
                  'rounded-full px-1.5 text-[12px] tabular-nums',
                  active
                    ? 'bg-bg/20'
                    : item.value === 'TO_REVIEW' && count > 0
                      ? 'bg-warn-bg text-warn'
                      : 'bg-track',
                )}
              >
                {count}
              </span>
            </Link>
          );
        })}
      </nav>

      {page.items.length === 0 ? (
        <div className="rounded-3xl border border-line bg-panel px-6 py-16 text-center">
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
        <div className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          <table className="w-full text-left text-[14px]">
            <thead className="border-b border-line text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="px-4 py-3">Livreur</th>
                <th className="px-4 py-3">Véhicule</th>
                <th className="px-4 py-3">Statut</th>
                <th className="px-4 py-3">Pièces</th>
                <th className="px-4 py-3">30 derniers jours</th>
                <th className="px-4 py-3">Inscrit</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((rider) => (
                <RiderRow key={rider.id} rider={rider} />
              ))}
            </tbody>
          </table>
        </div>
      )}

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

function RiderRow({ rider }: { rider: AdminRider }) {
  const documents = documentSummary(rider);
  const rating = ratingText(rider.rating.average);
  return (
    <tr className="relative border-b border-line last:border-0 hover:bg-panel-soft">
      <td className="px-4 py-3">
        <Link
          href={`/livreurs/${rider.id}`}
          className="font-display font-bold after:absolute after:inset-0 after:content-['']"
        >
          {rider.user.fullName ?? 'Sans nom'}
        </Link>
        <span className="block text-[12px] text-muted">{displayPhone(rider.user.phone)}</span>
      </td>
      <td className="px-4 py-3 whitespace-nowrap">
        {VEHICLE_LABELS[rider.vehicleType]}
        {rider.plateNumber ? (
          <span className="block text-[12px] text-muted">{rider.plateNumber}</span>
        ) : null}
      </td>
      <td className="px-4 py-3">
        <span
          className={cx(
            'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
            RIDER_STATUS_TONE[rider.status],
          )}
        >
          {RIDER_STATUS_LABELS[rider.status]}
        </span>
      </td>
      <td className={cx('px-4 py-3 font-bold', documents.tone)}>{documents.text}</td>
      <td className="px-4 py-3 whitespace-nowrap">
        {rider.status === 'ACTIVE' || rider.deliveredLast30Days > 0 ? (
          <>
            <span className="font-bold">
              {rider.deliveredLast30Days} course{rider.deliveredLast30Days > 1 ? 's' : ''}
            </span>
            {rating ? (
              <span className="ml-2 text-muted">
                ★ {rating} <span className="text-faint">({rider.rating.count})</span>
              </span>
            ) : null}
          </>
        ) : (
          <span className="text-faint">—</span>
        )}
      </td>
      <td className="px-4 py-3 whitespace-nowrap text-muted">{dateTime(rider.createdAt)}</td>
    </tr>
  );
}
