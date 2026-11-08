import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { PERIODS, periodRange } from '@/lib/douala';
import { dateTime, duration, money } from '@/lib/format';
import { OPS_ROLES } from '@/lib/navigation';
import { ORDER_VIEWS, STATUS_TONE, orderView, statusLabel } from '@/lib/orders';
import type { AdminOrderPage, AdminOrderRow } from '@/lib/schemas';

export const metadata: Metadata = { title: 'Commandes' };

type Search = { q?: string; vue?: string; periode?: string; suite?: string };

/** Adresse de la liste avec ces critères (les autres sont gardés). */
function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  const merged = { ...current, ...changes };
  for (const [key, value] of Object.entries(merged)) if (value) params.set(key, value);
  const query = params.toString();
  return query ? `/commandes?${query}` : '/commandes';
}

/**
 * Commandes (H2) : recherche par référence, numéro ou nom, vues (en cours, à traiter…),
 * période ; un clic ouvre la fiche. Tout est fait sur le serveur, liens et formulaire simples.
 */
export default async function OrdersPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(OPS_ROLES);
  const search = await searchParams;
  const view = orderView(search.vue);
  const q = search.q?.trim() ?? '';
  const range = periodRange(search.periode, new Date());
  const page = await staffApi<AdminOrderPage>('/admin/orders', {
    query: {
      view,
      q: q.length >= 2 ? q : undefined,
      from: range.from,
      to: range.to,
      cursor: search.suite,
      limit: 30,
    },
  });
  const current: Search = { q, vue: view === 'all' ? undefined : view, periode: search.periode };

  return (
    <div className="mx-auto max-w-[1280px]">
      <header className="mb-6 flex flex-wrap items-end gap-4">
        <div className="flex-1">
          <h1 className="font-display text-[28px] font-bold tracking-tight">Commandes</h1>
          <p className="text-muted">
            {page.total} commande{page.total > 1 ? 's' : ''}
            {q ? ` pour « ${q} »` : ''}
          </p>
        </div>
        <form action="/commandes" className="flex w-full max-w-[520px] gap-2">
          {view !== 'all' ? <input type="hidden" name="vue" value={view} /> : null}
          {search.periode ? <input type="hidden" name="periode" value={search.periode} /> : null}
          <label className="flex min-h-11 flex-1 items-center gap-2 rounded-2xl border border-line bg-panel px-3 focus-within:border-accent-line">
            <Icon name="search" size={18} className="text-faint" />
            <span className="sr-only">Chercher une commande</span>
            <input
              name="q"
              defaultValue={q}
              placeholder="Référence, numéro ou nom"
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
        {ORDER_VIEWS.map((item) => (
          <Link
            key={item.value}
            href={hrefWith(current, {
              vue: item.value === 'all' ? undefined : item.value,
              suite: undefined,
            })}
            aria-current={view === item.value ? 'page' : undefined}
            className={cx(
              'min-h-9 rounded-xl px-3 py-2 text-[13px] font-bold transition',
              view === item.value ? 'bg-text text-bg' : 'bg-panel text-muted hover:text-text',
            )}
          >
            {item.label}
          </Link>
        ))}
        <span className="mx-1 h-6 w-px bg-line" aria-hidden="true" />
        {PERIODS.map((item) => {
          const active = (search.periode ?? 'tout') === item.value;
          return (
            <Link
              key={item.value}
              href={hrefWith(current, {
                periode: item.value === 'tout' ? undefined : item.value,
                suite: undefined,
              })}
              aria-current={active ? 'page' : undefined}
              className={cx(
                'min-h-9 rounded-xl px-3 py-2 text-[13px] font-bold transition',
                active ? 'bg-accent-bg text-accent' : 'text-muted hover:text-text',
              )}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>

      {page.items.length === 0 ? (
        <div className="rounded-3xl border border-line bg-panel px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">Aucune commande</p>
          <p className="mt-1 text-muted">Changez la recherche, la vue ou la période.</p>
        </div>
      ) : (
        <div className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          <table className="w-full text-left text-[14px]">
            <thead className="border-b border-line text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="px-4 py-3">Référence</th>
                <th className="px-4 py-3">Créée</th>
                <th className="px-4 py-3">Statut</th>
                <th className="px-4 py-3">Trajet</th>
                <th className="px-4 py-3">Expéditeur</th>
                <th className="px-4 py-3">Livreur</th>
                <th className="px-4 py-3 text-right">Montant</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((order) => (
                <OrderRow key={order.id} order={order} />
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
              ← Revenir aux plus récentes
            </Link>
          ) : (
            <span />
          )}
          {page.nextCursor ? (
            <Link
              href={hrefWith(current, { suite: page.nextCursor })}
              className="text-[14px] font-bold text-accent hover:underline"
            >
              Commandes plus anciennes →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function OrderRow({ order }: { order: AdminOrderRow }) {
  return (
    <tr className="relative border-b border-line last:border-0 hover:bg-panel-soft">
      <td className="px-4 py-3">
        <Link
          href={`/commandes/${order.id}`}
          className="font-display font-bold after:absolute after:inset-0 after:content-['']"
        >
          {order.reference}
        </Link>
        {order.isExpress ? (
          <span className="ml-2 rounded-full bg-accent-bg px-2 text-[11px] font-extrabold text-accent">
            Express
          </span>
        ) : null}
      </td>
      <td className="px-4 py-3 whitespace-nowrap text-muted">{dateTime(order.createdAt)}</td>
      <td className="px-4 py-3">
        <span
          className={cx(
            'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
            STATUS_TONE[order.status],
          )}
        >
          {statusLabel(order.status, order.scheduledFor)}
        </span>
        {order.delay ? (
          <span className="ml-2 text-[12px] font-extrabold whitespace-nowrap text-danger">
            +{duration(order.delay.minutes)}
          </span>
        ) : null}
      </td>
      <td className="px-4 py-3 text-muted">
        {order.pickupNeighborhood ?? '—'} → {order.dropoffNeighborhood ?? '—'}
      </td>
      <td className="max-w-[200px] truncate px-4 py-3">{order.senderName ?? order.senderPhone}</td>
      <td className="px-4 py-3 text-muted">
        {order.rider?.name ?? (order.rider ? order.rider.phone : '—')}
      </td>
      <td className="px-4 py-3 text-right whitespace-nowrap">
        <span className="font-bold">{money(order.totalPrice)}</span>
        {order.codAmount > 0 ? (
          <span className="block text-[12px] text-faint">à encaisser {money(order.codAmount)}</span>
        ) : null}
      </td>
    </tr>
  );
}
