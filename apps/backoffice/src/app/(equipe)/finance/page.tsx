import type { Metadata } from 'next';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { doualaDay, longDate } from '@/lib/douala';
import { dateTime, money } from '@/lib/format';
import { FINANCE_ROLES, lastCheck } from '@/lib/finance';
import type { FinanceOverview, Reconciliation } from '@/lib/schemas';
import { ExportForm } from './finance-actions';
import { FinanceHeader } from './tabs';

export const metadata: Metadata = { title: 'Finance' };

/** Comptes de la plateforme, regroupés pour être lus d'un coup d'œil. */
const GROUPS: { title: string; hint: string; codes: string[] }[] = [
  {
    title: 'Argent détenu par Tara',
    hint: 'Ce qui est sur le compte de l’agrégateur et en espèces au bureau.',
    codes: ['mobile_money', 'office_cash'],
  },
  {
    title: 'Argent dû par Tara',
    hint: 'Livraisons payées d’avance, reversements en route, paiements à affecter.',
    codes: ['orders_prepaid', 'payouts_in_transit', 'unallocated'],
  },
  {
    title: 'Ce que Tara gagne',
    hint: 'Depuis le début : commission, frais d’encaissement, frais Mobile Money facturés.',
    codes: ['revenue:commission', 'revenue:cod_fees', 'revenue:mobile_money_fees'],
  },
  {
    title: 'Ce que Tara dépense',
    hint: 'Depuis le début : frais de l’agrégateur, remises, avoirs commerciaux.',
    codes: ['expense:provider_fees', 'expense:promotions', 'expense:goodwill'],
  },
];

/**
 * Finance (H5) : ce qui demande une action (reversements à valider, écarts du dernier
 * contrôle), les soldes de la plateforme, et l'export comptable du journal.
 */
export default async function FinancePage() {
  await requireStaff(FINANCE_ROLES);
  const [overview, reports] = await Promise.all([
    staffApi<FinanceOverview>('/admin/finance/overview'),
    staffApi<Reconciliation[]>('/admin/finance/reconciliations'),
  ]);
  const check = lastCheck(reports);
  const balances = new Map(overview.accounts.map((account) => [account.code, account]));
  const now = new Date();
  const today = doualaDay(now);

  return (
    <div className="mx-auto max-w-[1280px]">
      <FinanceHeader current="/finance" aside={longDate.format(now)} />

      <div className="mb-5 grid gap-4 md:grid-cols-3">
        <Tile
          href="/finance/reversements"
          icon="wallet"
          label="Reversements à valider"
          value={String(overview.payoutsAwaitingApproval)}
          tone={overview.payoutsAwaitingApproval > 0 ? 'warn' : 'ok'}
          detail={
            overview.payoutsAwaitingApproval > 0
              ? 'Gros montants : un membre de la finance les envoie.'
              : 'Rien à valider.'
          }
        />
        <Tile
          icon="clock"
          label="Paiements en attente"
          value={String(overview.paymentsPending)}
          tone="plain"
          detail="Demandes Mobile Money pas encore validées par les clients."
        />
        <Tile
          href={check.report ? `/finance/controle?jour=${check.report.day}` : '/finance/controle'}
          icon="shieldCheck"
          label="Dernier contrôle des comptes"
          value={
            check.report
              ? check.issues === 0
                ? 'Équilibré'
                : `${check.issues} écart${check.issues > 1 ? 's' : ''}`
              : '—'
          }
          tone={check.report ? (check.issues === 0 ? 'ok' : 'danger') : 'plain'}
          detail={
            check.report
              ? `Journée du ${longDate.format(new Date(`${check.report.day}T12:00:00Z`))}, contrôlée le ${dateTime(check.report.updatedAt)}.`
              : 'Le contrôle tourne chaque nuit pour la veille.'
          }
        />
      </div>

      <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_420px]">
        <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <h2 className="mb-4 font-display text-[17px] font-bold">Comptes de la plateforme</h2>
          <div className="space-y-5">
            {GROUPS.map((group) => (
              <div key={group.title}>
                <p className="text-[14px] font-bold">{group.title}</p>
                <p className="text-[12px] text-faint">{group.hint}</p>
                <dl className="mt-2 divide-y divide-line">
                  {group.codes
                    .map((code) => balances.get(code))
                    .filter((account) => account !== undefined)
                    .map((account) => (
                      <div key={account.code} className="flex items-baseline gap-3 py-2">
                        <dt className="flex-1 text-[14px] text-muted">{account.name}</dt>
                        <dd className="text-[15px] font-bold tabular-nums">
                          {money(account.balance)}
                        </dd>
                      </div>
                    ))}
                </dl>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <h2 className="font-display text-[17px] font-bold">Export comptable</h2>
          <p className="mt-1 mb-4 text-[13px] text-muted">
            Toutes les écritures de la période, une ligne par mouvement, pour le cabinet comptable.
            Chaque export est inscrit au journal d’audit.
          </p>
          <ExportForm from={`${today.slice(0, 8)}01`} to={today} />
        </section>
      </div>
    </div>
  );
}

function Tile({
  href,
  icon,
  label,
  value,
  detail,
  tone,
}: {
  href?: string;
  icon: 'wallet' | 'clock' | 'shieldCheck';
  label: string;
  value: string;
  detail: string;
  tone: 'ok' | 'warn' | 'danger' | 'plain';
}) {
  const body: ReactNode = (
    <>
      <div className="flex items-center gap-2 text-[13px] font-bold text-muted">
        <Icon name={icon} size={16} />
        {label}
      </div>
      <p
        className={cx(
          'mt-2 font-display text-[28px] font-bold tabular-nums',
          tone === 'ok' && 'text-ok',
          tone === 'warn' && 'text-warn',
          tone === 'danger' && 'text-danger',
        )}
      >
        {value}
      </p>
      <p className="mt-1 text-[13px] text-muted">{detail}</p>
    </>
  );
  const className = 'block rounded-3xl border border-line bg-panel p-5 shadow-card';
  return href ? (
    <Link href={href} className={cx(className, 'transition hover:border-accent-line')}>
      {body}
    </Link>
  ) : (
    <div className={className}>{body}</div>
  );
}
