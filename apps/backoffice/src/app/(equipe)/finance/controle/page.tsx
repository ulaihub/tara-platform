import type { Metadata } from 'next';
import Link from 'next/link';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { doualaDay, longDate } from '@/lib/douala';
import { dateTime, money } from '@/lib/format';
import { FINANCE_ROLES, TOTAL_LABELS, discrepancyLabel } from '@/lib/finance';
import type { Reconciliation } from '@/lib/schemas';
import { RerunButton } from '../finance-actions';
import { FinanceHeader } from '../tabs';

export const metadata: Metadata = { title: 'Contrôle des comptes' };

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const dayLabel = (day: string) => longDate.format(new Date(`${day}T12:00:00Z`));

/**
 * Contrôle quotidien des comptes (H5, G6) : chaque nuit, l'argent reçu et envoyé chez
 * l'agrégateur est comparé aux comptes de Tara. Les journées, puis le détail d'une journée :
 * ses chiffres et ses écarts ; une journée corrigée peut être contrôlée de nouveau.
 */
export default async function ChecksPage({
  searchParams,
}: {
  searchParams: Promise<{ jour?: string }>;
}) {
  await requireStaff(FINANCE_ROLES);
  const { jour } = await searchParams;
  const reports = await staffApi<Reconciliation[]>('/admin/finance/reconciliations');
  const selected =
    (jour && DAY.test(jour) ? reports.find((report) => report.day === jour) : undefined) ??
    reports[0];
  const yesterday = doualaDay(new Date(), -1);

  return (
    <div className="mx-auto max-w-[1280px]">
      <FinanceHeader
        current="/finance/controle"
        aside="L’argent de l’agrégateur comparé, chaque nuit, aux comptes de Tara."
      />

      {reports.length === 0 ? (
        <div className="rounded-3xl border border-line bg-panel px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">Aucun contrôle pour l’instant</p>
          <p className="mt-1 mb-4 text-muted">
            Le contrôle tourne chaque nuit pour la veille. Vous pouvez le lancer pour hier.
          </p>
          <div className="flex justify-center">
            <RerunButton day={yesterday} />
          </div>
        </div>
      ) : (
        <div className="grid items-start gap-5 lg:grid-cols-[300px_minmax(0,1fr)]">
          <nav
            aria-label="Journées contrôlées"
            className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card"
          >
            <ul className="divide-y divide-line">
              {reports.map((report) => {
                const active = report.day === selected?.day;
                const issues = report.discrepancies.length;
                return (
                  <li key={report.day}>
                    <Link
                      href={`/finance/controle?jour=${report.day}`}
                      aria-current={active ? 'page' : undefined}
                      className={cx(
                        'flex items-center gap-3 px-4 py-3 text-[14px] transition',
                        active ? 'bg-accent-bg' : 'hover:bg-panel-soft',
                      )}
                    >
                      <span className="flex-1 font-semibold">{dayLabel(report.day)}</span>
                      <span
                        className={cx(
                          'rounded-full px-2 py-0.5 text-[12px] font-bold whitespace-nowrap',
                          issues === 0 ? 'bg-ok-bg text-ok' : 'bg-danger-bg text-danger',
                        )}
                      >
                        {issues === 0 ? 'Équilibré' : `${issues} écart${issues > 1 ? 's' : ''}`}
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </nav>

          {selected ? <Day report={selected} /> : null}
        </div>
      )}
    </div>
  );
}

function Day({ report }: { report: Reconciliation }) {
  const issues = report.discrepancies;
  return (
    <div className="space-y-5">
      <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
        <div className="mb-4 flex flex-wrap items-start gap-3">
          <div className="flex-1">
            <h2 className="font-display text-[20px] font-bold">{dayLabel(report.day)}</h2>
            <p className="text-[13px] text-muted">Contrôlée le {dateTime(report.updatedAt)}</p>
          </div>
          <RerunButton day={report.day} />
        </div>
        {issues.length === 0 ? (
          <p className="rounded-2xl bg-ok-bg px-4 py-3 text-[14px] font-bold text-ok">
            Tout concorde : chaque paiement et chaque reversement de l’agrégateur est dans les
            comptes de Tara, au bon montant.
          </p>
        ) : (
          <p className="rounded-2xl bg-danger-bg px-4 py-3 text-[14px] font-bold text-danger">
            {issues.length} écart{issues.length > 1 ? 's' : ''} à vérifier. Une fois corrigé(s),
            relancez le contrôle de la journée.
          </p>
        )}
      </section>

      {issues.length > 0 ? (
        <section className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          <h3 className="px-5 pt-5 font-display text-[17px] font-bold">Écarts</h3>
          <table className="mt-3 w-full text-left text-[14px]">
            <thead className="border-y border-line text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="px-5 py-2">Écart</th>
                <th className="px-5 py-2">Référence</th>
                <th className="px-5 py-2 text-right">Attendu</th>
                <th className="px-5 py-2 text-right">Constaté</th>
              </tr>
            </thead>
            <tbody>
              {issues.map((issue, index) => (
                <tr
                  key={`${issue.reference}-${index}`}
                  className="border-b border-line align-top last:border-0"
                >
                  <td className="px-5 py-3">
                    <span className="font-bold">{discrepancyLabel(issue.type)}</span>
                    <span className="block text-[13px] text-muted">{issue.detail}</span>
                  </td>
                  <td className="px-5 py-3 font-mono text-[12px] break-all text-muted">
                    {issue.reference}
                  </td>
                  <td className="px-5 py-3 text-right whitespace-nowrap tabular-nums">
                    {issue.expected === undefined ? '—' : money(issue.expected)}
                  </td>
                  <td className="px-5 py-3 text-right font-bold whitespace-nowrap tabular-nums">
                    {issue.actual === undefined ? '—' : money(issue.actual)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ) : null}

      <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
        <h3 className="mb-3 font-display text-[17px] font-bold">Chiffres de la journée</h3>
        <dl className="divide-y divide-line">
          {TOTAL_LABELS.filter(([key]) => typeof report.totals[key] === 'number').map(
            ([key, label, kind]) => (
              <div key={key} className="flex items-baseline gap-3 py-2">
                <dt className="flex-1 text-[14px] text-muted">{label}</dt>
                <dd className="text-[15px] font-bold tabular-nums">
                  {kind === 'money'
                    ? money(report.totals[key] as number)
                    : String(report.totals[key])}
                </dd>
              </div>
            ),
          )}
        </dl>
      </section>
    </div>
  );
}
