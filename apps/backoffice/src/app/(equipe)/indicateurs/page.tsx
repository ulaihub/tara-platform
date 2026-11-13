import type { Metadata } from 'next';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { longDate } from '@/lib/douala';
import {
  change,
  METRICS_ROLES,
  minutes,
  PERIODS,
  periodOf,
  pointsChange,
  rate,
} from '@/lib/metrics';
import type { Metrics } from '@/lib/schemas';
import { DailyChart } from './daily-chart';

export const metadata: Metadata = { title: 'Indicateurs' };

const day = (value: string) => longDate.format(new Date(`${value}T12:00:00Z`));

/**
 * Indicateurs (H7) : livraisons et réussite, délais, reversements le jour même, livreurs,
 * boutiques, qualité. Période au choix (7, 30, 90 jours), comparée à la précédente.
 */
export default async function MetricsPage({
  searchParams,
}: {
  searchParams: Promise<{ jours?: string }>;
}) {
  await requireStaff(METRICS_ROLES);
  const { jours } = await searchParams;
  const days = periodOf(jours);
  const m = await staffApi<Metrics>('/admin/metrics', { query: { days } });
  const delivered = change(m.deliveries.delivered, m.deliveries.previousDelivered);
  const success = pointsChange(m.deliveries.successRate, m.deliveries.previousSuccessRate);

  return (
    <div className="mx-auto max-w-[1280px]">
      <header className="mb-6 flex flex-wrap items-end gap-3">
        <div className="flex-1">
          <h1 className="font-display text-[28px] font-bold tracking-tight">Indicateurs</h1>
          <p className="text-muted">
            Du {day(m.period.from)} au {day(m.period.to)}, comparé aux {days} jours d’avant.
          </p>
        </div>
        <nav aria-label="Période" className="flex gap-2">
          {PERIODS.map((value) => (
            <Link
              key={value}
              href={value === 30 ? '/indicateurs' : `/indicateurs?jours=${value}`}
              aria-current={value === days ? 'page' : undefined}
              className={cx(
                'min-h-10 rounded-xl px-4 py-2.5 text-[14px] font-bold transition',
                value === days ? 'bg-accent-bg text-accent' : 'bg-panel text-muted hover:text-text',
              )}
            >
              {value} jours
            </Link>
          ))}
        </nav>
      </header>

      <div className="mb-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <Tile
          label="Livraisons réussies"
          value={String(m.deliveries.delivered)}
          detail={
            delivered ? (
              <span className={delivered.up ? 'text-ok' : 'text-danger'}>
                {delivered.text} vs période précédente
              </span>
            ) : (
              'Pas de période précédente à comparer.'
            )
          }
        />
        <Tile
          label="Taux de réussite"
          value={rate(m.deliveries.successRate)}
          detail={`${rate(m.deliveries.firstAttemptRate)} dès le premier passage${success ? ` · ${success}` : ''}`}
        />
        <Tile
          label="Délai, commande → remise"
          value={minutes(m.delays.total.median)}
          detail={`9 livraisons sur 10 en moins de ${minutes(m.delays.total.p90)}`}
        />
        <Tile
          label="Reversements le jour même"
          value={rate(m.payouts.sameDayRate)}
          detail={`${m.payouts.sameDay} sur ${m.payouts.merchantPayouts} reversements aux boutiques`}
        />
      </div>

      <section className="mb-5 rounded-3xl border border-line bg-panel p-5 shadow-card">
        <div className="mb-3 flex flex-wrap items-baseline gap-3">
          <h2 className="flex-1 font-display text-[17px] font-bold">
            Livraisons réussies par jour
          </h2>
          <p className="text-[13px] text-muted">
            {m.deliveries.created} commandes passées · {m.deliveries.returned} retours ·{' '}
            {m.deliveries.cancelled} annulées
          </p>
        </div>
        <DailyChart days={m.daily} />
        <details className="mt-2 text-[13px]">
          <summary className="cursor-pointer font-bold text-accent">Voir le tableau</summary>
          <table className="mt-2 w-full text-left">
            <thead className="text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="py-1">Jour</th>
                <th className="py-1 text-right">Livrées</th>
                <th className="py-1 text-right">Échecs</th>
                <th className="py-1 text-right">Retours</th>
                <th className="py-1 text-right">Annulées</th>
              </tr>
            </thead>
            <tbody>
              {[...m.daily].reverse().map((row) => (
                <tr key={row.day} className="border-t border-line">
                  <td className="py-1">{day(row.day)}</td>
                  <td className="py-1 text-right tabular-nums">{row.delivered}</td>
                  <td className="py-1 text-right tabular-nums">{row.failed}</td>
                  <td className="py-1 text-right tabular-nums">{row.returned}</td>
                  <td className="py-1 text-right tabular-nums">{row.cancelled}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      </section>

      <div className="grid items-start gap-5 lg:grid-cols-3">
        <Panel title="Délais">
          <Line
            label="Trouver un livreur"
            value={minutes(m.delays.assign.median)}
            hint={`9 sur 10 : ${minutes(m.delays.assign.p90)}`}
          />
          <Line
            label="Trajet, enlèvement → remise"
            value={minutes(m.delays.delivery.median)}
            hint={`9 sur 10 : ${minutes(m.delays.delivery.p90)}`}
          />
          <Line
            label="Total, commande → remise"
            value={minutes(m.delays.total.median)}
            hint={`9 sur 10 : ${minutes(m.delays.total.p90)}`}
          />
          <p className="mt-3 text-[12px] text-faint">
            Valeurs médianes : la moitié des livraisons fait mieux. Hors courses programmées.
          </p>
        </Panel>

        <Panel title="Livreurs">
          <Line
            label="Livreurs actifs"
            value={String(m.riders.active)}
            hint="au moins une livraison"
          />
          <Line
            label="Courses par livreur et par jour"
            value={
              m.riders.perRiderDay === null ? '—' : String(m.riders.perRiderDay).replace('.', ',')
            }
            hint="les jours où il a livré"
          />
          <Line
            label="Note moyenne reçue"
            value={
              m.ratings.average === null ? '—' : `${String(m.ratings.average).replace('.', ',')}/5`
            }
            hint={`${m.ratings.count} note${m.ratings.count > 1 ? 's' : ''} · ${m.ratings.lowRated} livreur${m.ratings.lowRated > 1 ? 's' : ''} sous 4/5`}
          />
          {m.riders.top.length > 0 ? (
            <ol className="mt-3 space-y-1.5 text-[13px]">
              {m.riders.top.map((rider, index) => (
                <li key={rider.riderId} className="flex items-baseline gap-2">
                  <span className="w-4 text-faint tabular-nums">{index + 1}</span>
                  <Link
                    href={`/livreurs/${rider.riderId}`}
                    className="flex-1 truncate font-semibold text-accent hover:underline"
                  >
                    {rider.name ?? 'Livreur'}
                  </Link>
                  <span className="font-bold tabular-nums">{rider.delivered}</span>
                  <span className="w-12 text-right text-muted tabular-nums">
                    {rider.rating === null ? '—' : `${String(rider.rating).replace('.', ',')}/5`}
                  </span>
                </li>
              ))}
            </ol>
          ) : null}
        </Panel>

        <Panel title="Boutiques et comptes">
          <Line
            label="Boutiques actives"
            value={String(m.merchants.active)}
            hint={`${m.merchants.new} nouvelle${m.merchants.new > 1 ? 's' : ''} sur la période`}
          />
          <Line
            label="Fidélité des boutiques"
            value={rate(m.merchants.retentionRate)}
            hint={`${m.merchants.retained} sur ${m.merchants.previousActive} actives la période d’avant`}
          />
          <Line
            label="Contrôle des comptes"
            value={
              m.reconciliation.daysChecked === 0
                ? '—'
                : m.reconciliation.daysWithIssues === 0
                  ? 'Équilibré'
                  : `${m.reconciliation.daysWithIssues} jour${m.reconciliation.daysWithIssues > 1 ? 's' : ''}`
            }
            hint={
              m.reconciliation.daysChecked === 0
                ? 'aucune journée contrôlée'
                : `avec écarts sur ${m.reconciliation.daysChecked} contrôlés · ${m.reconciliation.issues} écart${m.reconciliation.issues > 1 ? 's' : ''}`
            }
            tone={m.reconciliation.daysWithIssues > 0 ? 'danger' : 'plain'}
          />
        </Panel>
      </div>
    </div>
  );
}

function Tile({ label, value, detail }: { label: string; value: string; detail: ReactNode }) {
  return (
    <div className="rounded-3xl border border-line bg-panel p-5 shadow-card">
      <p className="text-[13px] font-bold text-muted">{label}</p>
      <p className="mt-2 font-display text-[30px] font-bold tabular-nums">{value}</p>
      <p className="mt-1 text-[13px] text-muted">{detail}</p>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
      <h2 className="mb-2 font-display text-[17px] font-bold">{title}</h2>
      <div className="divide-y divide-line">{children}</div>
    </section>
  );
}

function Line({
  label,
  value,
  hint,
  tone = 'plain',
}: {
  label: string;
  value: string;
  hint: string;
  tone?: 'plain' | 'danger';
}) {
  return (
    <div className="flex items-baseline gap-3 py-2.5">
      <div className="flex-1">
        <p className="text-[14px]">{label}</p>
        <p className="text-[12px] text-muted">{hint}</p>
      </div>
      <p className={cx('text-[17px] font-bold tabular-nums', tone === 'danger' && 'text-danger')}>
        {value}
      </p>
    </div>
  );
}
