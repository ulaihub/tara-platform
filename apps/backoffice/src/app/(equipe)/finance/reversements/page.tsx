import type { Metadata } from 'next';
import Link from 'next/link';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, money } from '@/lib/format';
import {
  BENEFICIARY_LABELS,
  FINANCE_ROLES,
  PAYOUT_STATUS_LABELS,
  PAYOUT_STATUS_TONE,
  PAYOUT_VIEWS,
  ownerHref,
  payoutView,
} from '@/lib/finance';
import { displayPhone } from '@/lib/phone';
import type { AdminPayout, AdminPayoutPage } from '@/lib/schemas';
import { PayoutDecision } from '../finance-actions';
import { FinanceHeader } from '../tabs';

export const metadata: Metadata = { title: 'Reversements' };

type Search = { vue?: string; suite?: string };

function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...current, ...changes })) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `/finance/reversements?${query}` : '/finance/reversements';
}

/**
 * Reversements (H5) : les gros montants attendent la validation d'un membre de la finance ;
 * les autres partent seuls. Échoués, versés, avec le bénéficiaire et ce qu'il reçoit.
 */
export default async function PayoutsPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(FINANCE_ROLES);
  const search = await searchParams;
  const view = payoutView(search.vue);
  const page = await staffApi<AdminPayoutPage>('/admin/finance/payouts', {
    query: { view, cursor: search.suite, limit: 30 },
  });
  const current: Search = { vue: view === 'TO_APPROVE' ? undefined : view.toLowerCase() };

  return (
    <div className="mx-auto max-w-[1280px]">
      <FinanceHeader
        current="/finance/reversements"
        aside={`${page.counts.TO_APPROVE} reversement${page.counts.TO_APPROVE > 1 ? 's' : ''} à valider`}
      />

      <nav aria-label="Vues" className="mb-3 flex flex-wrap items-center gap-2">
        {PAYOUT_VIEWS.map((item) => {
          const active = view === item.value;
          const count = page.counts[item.value];
          return (
            <Link
              key={item.value}
              href={hrefWith(current, {
                vue: item.value === 'TO_APPROVE' ? undefined : item.value.toLowerCase(),
                suite: undefined,
              })}
              aria-current={active ? 'page' : undefined}
              className={cx(
                'inline-flex min-h-[34px] items-center gap-2 rounded-xl px-3 py-2 text-[13px] font-extrabold transition',
                active
                  ? 'bg-brand text-on-brand shadow-[0_8px_18px_rgba(255,90,0,.22)]'
                  : 'bo-glass text-text hover:brightness-105',
              )}
            >
              {item.label}
              <span
                className={cx(
                  'rounded-full px-1.5 text-[12px] tabular-nums',
                  active
                    ? 'bg-bg/20'
                    : (item.value === 'TO_APPROVE' || item.value === 'FAILED') && count > 0
                      ? item.value === 'FAILED'
                        ? 'bg-danger-bg text-danger'
                        : 'bg-warn-bg text-warn'
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
        <div className="bo-glass rounded-[22px] px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">
            {view === 'TO_APPROVE' ? 'Rien à valider' : 'Aucun reversement'}
          </p>
          <p className="mt-1 text-muted">
            {view === 'TO_APPROVE'
              ? 'Les gros reversements attendant une validation apparaîtront ici.'
              : 'Changez de vue.'}
          </p>
        </div>
      ) : (
        <div className="relative overflow-x-auto bo-glass rounded-[22px] px-2 pb-1 sm:px-3">
          <table className="w-full min-w-[720px] border-separate border-spacing-y-1.5 text-left text-[13px]">
            <thead className="text-[11px] font-extrabold tracking-[.06em] text-faint uppercase">
              <tr>
                <th className="px-3 pb-1">Bénéficiaire</th>
                <th className="px-3 pb-1">Envoyé au</th>
                <th className="px-3 pb-1 text-right">Montant</th>
                <th className="px-3 pb-1 text-right">Reçu</th>
                <th className="px-3 pb-1">Demandé</th>
                <th className="px-3 pb-1">Statut</th>
                <th className="px-3 pb-1 text-right">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((payout) => (
                <PayoutRow key={payout.id} payout={payout} />
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
              Reversements plus anciens →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function PayoutRow({ payout }: { payout: AdminPayout }) {
  const owner = payout.owner;
  const href = ownerHref(payout);
  const name = owner ? (owner.shopName ?? owner.name ?? displayPhone(owner.phone)) : '—';
  return (
    <tr className="border-b border-line align-top last:border-0">
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]">
        {href ? (
          <Link href={href} className="font-bold text-accent hover:underline">
            {name}
          </Link>
        ) : (
          <span className="font-bold">{name}</span>
        )}
        <span className="block text-[12px] text-muted">
          {BENEFICIARY_LABELS[payout.beneficiary]}
          {owner?.shopName && owner.name ? ` · ${owner.name}` : ''}
        </span>
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] whitespace-nowrap text-muted">
        {displayPhone(payout.phone)}
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] text-right font-bold whitespace-nowrap tabular-nums">
        {money(payout.amount)}
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] text-right whitespace-nowrap tabular-nums">
        {money(payout.received)}
        {payout.withdrawalFee > 0 ? (
          <span className="block text-[12px] text-faint">frais {money(payout.withdrawalFee)}</span>
        ) : null}
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] whitespace-nowrap text-muted">
        {dateTime(payout.requestedAt)}
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]">
        <span
          className={cx(
            'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
            PAYOUT_STATUS_TONE[payout.status],
          )}
        >
          {PAYOUT_STATUS_LABELS[payout.status]}
        </span>
        {payout.approvedBy ? (
          <span className="mt-1 block text-[12px] text-muted">validé par {payout.approvedBy}</span>
        ) : null}
        {payout.failureReason ? (
          <span className="mt-1 block max-w-[220px] text-[12px] text-danger">
            {payout.failureReason}
          </span>
        ) : null}
      </td>
      <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]">
        {payout.status === 'AWAITING_APPROVAL' ? (
          <PayoutDecision payoutId={payout.id} amount={money(payout.received)} />
        ) : null}
      </td>
    </tr>
  );
}
