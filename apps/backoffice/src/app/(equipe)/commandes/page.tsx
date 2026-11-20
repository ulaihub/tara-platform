import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { TopBar } from '@/components/top-bar';
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
    <div className="mx-auto max-w-[1280px] pb-8">
      <TopBar
        title="Commandes"
        subtitle={`Liste, détail, preuves et actions · ${page.total} commande${page.total > 1 ? 's' : ''}`}
      />

      <nav aria-label="Vues" className="mb-2.5 flex flex-wrap items-center gap-2">
        {ORDER_VIEWS.map((item) => {
          const active = view === item.value;
          return (
            <Link
              key={item.value}
              href={hrefWith(current, {
                vue: item.value === 'all' ? undefined : item.value,
                suite: undefined,
              })}
              aria-current={active ? 'page' : undefined}
              className={cx(
                'flex min-h-[34px] items-center rounded-xl px-3 text-[13px] font-extrabold transition',
                active
                  ? 'bg-brand text-on-brand shadow-[0_8px_18px_rgba(255,90,0,.22)]'
                  : 'bo-glass text-text hover:brightness-105',
              )}
            >
              {item.label}
              {active ? ` · ${page.total}` : ''}
            </Link>
          );
        })}
      </nav>
      <nav aria-label="Période" className="mb-4 flex flex-wrap items-center gap-1.5">
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
                'min-h-8 rounded-lg px-2.5 py-1.5 text-[12px] font-bold transition',
                active ? 'bg-accent-bg text-accent' : 'text-muted hover:text-text',
              )}
            >
              {item.label}
            </Link>
          );
        })}
        {q ? (
          <Link
            href={hrefWith(current, { q: undefined, suite: undefined })}
            className="ml-auto flex min-h-8 items-center gap-1.5 rounded-lg bg-track px-2.5 text-[12px] font-bold"
          >
            « {q} »
            <Icon name="close" size={14} />
            <span className="sr-only">Effacer la recherche</span>
          </Link>
        ) : null}
      </nav>

      <section className="bo-glass rounded-[22px] p-3 sm:px-[18px] sm:py-4">
        <h2 className="mb-2 px-1 text-[15px] font-bold">Commandes</h2>
        {page.items.length === 0 ? (
          <div className="px-6 py-14 text-center">
            <p className="font-display text-[18px] font-bold">Aucune commande</p>
            <p className="mt-1 text-muted">Changez la recherche, la vue ou la période.</p>
          </div>
        ) : (
          <>
            {/* Téléphone : une carte par commande. */}
            <ul className="flex flex-col gap-2 md:hidden">
              {page.items.map((order) => (
                <OrderCard key={order.id} order={order} />
              ))}
            </ul>
            {/* Tablette et ordinateur : tableau aux lignes arrondies (maquette BO-Commandes). */}
            <div className="hidden overflow-x-auto md:block">
              <table className="w-full min-w-[820px] border-separate border-spacing-y-1.5 text-left text-[13px]">
                <thead className="text-[11px] font-extrabold tracking-[.06em] text-faint uppercase">
                  <tr>
                    <th className="px-3 pb-1">N°</th>
                    <th className="px-3 pb-1">Créée</th>
                    <th className="px-3 pb-1">Statut</th>
                    <th className="px-3 pb-1">Trajet</th>
                    <th className="px-3 pb-1">Expéditeur</th>
                    <th className="px-3 pb-1">Livreur</th>
                    <th className="px-3 pb-1 text-right">Prix</th>
                  </tr>
                </thead>
                <tbody>
                  {page.items.map((order) => (
                    <OrderRow key={order.id} order={order} />
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

      {page.nextCursor || search.suite ? (
        <div className="mt-4 flex justify-between gap-3">
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

/** Pastille du statut et retard éventuel. */
function Status({ order }: { order: AdminOrderRow }) {
  return (
    <>
      <span
        className={cx(
          'rounded-md px-2 py-0.5 text-[11px] font-extrabold whitespace-nowrap',
          STATUS_TONE[order.status],
        )}
      >
        {statusLabel(order.status, order.scheduledFor)}
        {order.delay ? ` · +${duration(order.delay.minutes)}` : ''}
      </span>
    </>
  );
}

function Tags({ order }: { order: AdminOrderRow }) {
  return (
    <>
      {order.isExpress ? (
        <span className="ml-2 rounded-full bg-accent-bg px-2 text-[11px] font-extrabold text-accent">
          Express
        </span>
      ) : null}
      {order.isBulky ? (
        <span className="ml-2 rounded-full bg-warn-bg px-2 text-[11px] font-extrabold text-warn">
          Gros objet
        </span>
      ) : null}
    </>
  );
}

function OrderCard({ order }: { order: AdminOrderRow }) {
  return (
    <li className="relative rounded-[14px] bg-track px-3 py-2.5">
      <div className="flex items-center gap-2">
        <Link
          href={`/commandes/${order.id}`}
          className="font-display text-[14px] font-bold after:absolute after:inset-0 after:content-['']"
        >
          {order.reference}
        </Link>
        <Tags order={order} />
        <span className="ml-auto font-bold whitespace-nowrap">{money(order.totalPrice)}</span>
      </div>
      <p className="mt-1 truncate text-[12px] text-muted">
        {order.senderName ?? order.senderPhone} · {order.pickupNeighborhood ?? '—'} →{' '}
        {order.dropoffNeighborhood ?? '—'}
      </p>
      <div className="mt-1.5 flex items-center justify-between gap-2 text-[12px] text-muted">
        <Status order={order} />
        <span className="truncate">
          {order.rider?.name ?? (order.rider ? order.rider.phone : '')}
        </span>
      </div>
    </li>
  );
}

function OrderRow({ order }: { order: AdminOrderRow }) {
  const cell = 'bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]';
  return (
    <tr className="relative transition hover:brightness-95">
      <td className={cx(cell, 'whitespace-nowrap')}>
        <Link
          href={`/commandes/${order.id}`}
          className="font-display font-bold after:absolute after:inset-0 after:content-['']"
        >
          {order.reference}
        </Link>
        <Tags order={order} />
      </td>
      <td className={cx(cell, 'whitespace-nowrap text-muted')}>{dateTime(order.createdAt)}</td>
      <td className={cell}>
        <Status order={order} />
      </td>
      <td className={cx(cell, 'text-muted')}>
        {order.pickupNeighborhood ?? '—'} → {order.dropoffNeighborhood ?? '—'}
      </td>
      <td className={cx(cell, 'max-w-[200px] truncate')}>
        {order.senderName ?? order.senderPhone}
      </td>
      <td className={cx(cell, 'text-muted')}>
        {order.rider?.name ?? (order.rider ? order.rider.phone : '—')}
      </td>
      <td className={cx(cell, 'text-right whitespace-nowrap')}>
        <span className="font-extrabold">{money(order.totalPrice)}</span>
        {order.codAmount > 0 ? (
          <span className="block text-[11px] text-faint">à encaisser {money(order.codAmount)}</span>
        ) : null}
      </td>
    </tr>
  );
}
