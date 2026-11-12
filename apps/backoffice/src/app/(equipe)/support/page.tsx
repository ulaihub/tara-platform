import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime } from '@/lib/format';
import { displayPhone } from '@/lib/phone';
import type { AdminTicketPage, AdminTicketRow, SafetyAlert } from '@/lib/schemas';
import {
  CATEGORY_LABELS,
  PERSON_LABELS,
  PRIORITY_LABELS,
  PRIORITY_TONE,
  STATUS_LABELS,
  STATUS_TONE,
  SUPPORT_ROLES,
  TICKET_VIEWS,
  ticketView,
} from '@/lib/support';

export const metadata: Metadata = { title: 'Support' };

type Search = { q?: string; vue?: string; suite?: string };

function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...current, ...changes })) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `/support?${query}` : '/support';
}

/**
 * Service client (H6) : file des demandes, les plus urgentes et les plus anciennes d'abord ;
 * recherche par numéro SUP-…, commande, téléphone ou sujet. Les alertes SOS en cours sont
 * rappelées en tête : elles se traitent sur la carte en direct.
 */
export default async function SupportPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(SUPPORT_ROLES);
  const search = await searchParams;
  const view = ticketView(search.vue);
  const q = search.q?.trim() ?? '';
  const [page, alerts] = await Promise.all([
    staffApi<AdminTicketPage>('/admin/support/tickets', {
      query: { view, q: q.length >= 2 ? q : undefined, cursor: search.suite, limit: 30 },
    }),
    staffApi<SafetyAlert[]>('/admin/safety-alerts', { query: { status: 'open' } }),
  ]);
  const current: Search = { q, vue: view === 'TO_HANDLE' ? undefined : view.toLowerCase() };

  return (
    <div className="mx-auto max-w-[1280px]">
      <header className="mb-6 flex flex-wrap items-end gap-4">
        <div className="flex-1">
          <h1 className="font-display text-[28px] font-bold tracking-tight">Support</h1>
          <p className="text-muted">
            {page.counts.TO_HANDLE} demande{page.counts.TO_HANDLE > 1 ? 's' : ''} à traiter ·{' '}
            {page.counts.MINE} suivie{page.counts.MINE > 1 ? 's' : ''} par vous
          </p>
        </div>
        <form action="/support" className="flex w-full max-w-[460px] gap-2">
          {current.vue ? <input type="hidden" name="vue" value={current.vue} /> : null}
          <label className="flex min-h-11 flex-1 items-center gap-2 rounded-2xl border border-line bg-panel px-3 focus-within:border-accent-line">
            <Icon name="search" size={18} className="text-faint" />
            <span className="sr-only">Chercher une demande</span>
            <input
              name="q"
              defaultValue={q}
              placeholder="SUP-…, commande, numéro ou sujet"
              className="w-full bg-transparent text-[15px] focus:outline-none"
            />
          </label>
          <button
            type="submit"
            className="min-h-11 rounded-2xl border border-line bg-panel px-4 text-[14px] font-extrabold"
          >
            Chercher
          </button>
        </form>
        <Link
          href="/support/nouvelle"
          className="inline-flex min-h-11 items-center gap-2 rounded-2xl bg-brand px-4 text-[14px] font-extrabold text-on-brand"
        >
          <Icon name="phone" size={18} />
          Nouvelle demande (appel)
        </Link>
      </header>

      {alerts.length > 0 ? (
        <Link
          href="/carte"
          className="mb-4 flex items-center gap-3 rounded-2xl bg-danger-bg px-4 py-3 text-[14px] font-bold text-danger"
        >
          <Icon name="alertCircle" size={20} />
          <span className="flex-1">
            {alerts.length} alerte{alerts.length > 1 ? 's' : ''} SOS en cours :{' '}
            {alerts
              .slice(0, 3)
              .map((alert) => alert.riderName ?? displayPhone(alert.riderPhone))
              .join(', ')}
            {alerts.length > 3 ? '…' : ''}
          </span>
          <span className="inline-flex items-center gap-1">
            Ouvrir la carte <Icon name="chevronRight" size={16} />
          </span>
        </Link>
      ) : null}

      <nav aria-label="Vues" className="mb-3 flex flex-wrap items-center gap-2">
        {TICKET_VIEWS.map((item) => {
          const active = view === item.value;
          const count = page.counts[item.value];
          return (
            <Link
              key={item.value}
              href={hrefWith(current, {
                vue: item.value === 'TO_HANDLE' ? undefined : item.value.toLowerCase(),
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
                    : item.value === 'URGENT' && count > 0
                      ? 'bg-danger-bg text-danger'
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
            {view === 'TO_HANDLE' && !q ? 'Aucune demande en attente' : 'Aucune demande'}
          </p>
          <p className="mt-1 text-muted">
            {view === 'TO_HANDLE' && !q
              ? 'Toutes les demandes ont été traitées.'
              : 'Changez la recherche ou la vue.'}
          </p>
        </div>
      ) : (
        <div className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          <table className="w-full text-left text-[14px]">
            <thead className="border-b border-line text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="px-4 py-3">Demande</th>
                <th className="px-4 py-3">Personne</th>
                <th className="px-4 py-3">Commande</th>
                <th className="px-4 py-3">Priorité</th>
                <th className="px-4 py-3">Statut</th>
                <th className="px-4 py-3">Suivie par</th>
                <th className="px-4 py-3">Dernier échange</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((ticket) => (
                <TicketRow key={ticket.id} ticket={ticket} />
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
              Demandes suivantes →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function TicketRow({ ticket }: { ticket: AdminTicketRow }) {
  return (
    <tr className="relative border-b border-line last:border-0 hover:bg-panel-soft">
      <td className="max-w-[340px] px-4 py-3">
        <Link
          href={`/support/${ticket.id}`}
          className="block truncate font-bold after:absolute after:inset-0 after:content-['']"
        >
          {ticket.subject}
        </Link>
        <span className="block text-[12px] text-muted">
          {ticket.reference} · {CATEGORY_LABELS[ticket.category]}
          {ticket.fromApp ? ' · depuis l’app' : ' · appel'}
        </span>
      </td>
      <td className="px-4 py-3">
        <span className="block font-semibold whitespace-nowrap">
          {ticket.requester.name ?? displayPhone(ticket.requester.phone)}
        </span>
        <span className="block text-[12px] text-muted">{PERSON_LABELS[ticket.requester.kind]}</span>
      </td>
      <td className="px-4 py-3 whitespace-nowrap text-muted">{ticket.order?.reference ?? '—'}</td>
      <td className="px-4 py-3">
        <span
          className={cx(
            'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
            PRIORITY_TONE[ticket.priority],
          )}
        >
          {PRIORITY_LABELS[ticket.priority]}
        </span>
      </td>
      <td className="px-4 py-3">
        <span
          className={cx(
            'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
            STATUS_TONE[ticket.status],
          )}
        >
          {STATUS_LABELS[ticket.status]}
        </span>
        {ticket.awaitingReply && (ticket.status === 'OPEN' || ticket.status === 'IN_PROGRESS') ? (
          <span className="mt-1 block text-[12px] font-extrabold whitespace-nowrap text-danger">
            Attend une réponse
          </span>
        ) : null}
      </td>
      <td className="px-4 py-3 text-muted">{ticket.assignee?.name ?? 'Personne'}</td>
      <td className="px-4 py-3 whitespace-nowrap text-muted">{dateTime(ticket.lastMessageAt)}</td>
    </tr>
  );
}
