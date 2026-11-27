import type { Metadata } from 'next';
import Link from 'next/link';
import { TopBar } from '@/components/top-bar';
import { cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, money } from '@/lib/format';
import { OPS_ROLES } from '@/lib/navigation';
import type { OfficeReturn } from '@/lib/schemas';
import { HandOverForm, UnclaimedForm } from './office-forms';

export const metadata: Metadata = { title: 'Bureau Tara' };

/** « 12 jours », « 1 jour », « délai fini ». */
function daysLabel(days: number): string {
  if (days <= 0) return 'Délai fini';
  return days === 1 ? '1 jour' : `${days} jours`;
}

/**
 * Colis gardés au bureau Tara (retour non payé à temps) : la fin de garde la plus proche
 * d'abord, le montant dû, puis « Remis à l'expéditeur » (code de retrait ou espèces) ou,
 * la garde finie, « non réclamé » avec ce que Tara a fait du colis.
 */
export default async function OfficePage() {
  await requireStaff(OPS_ROLES);
  const rows = await staffApi<OfficeReturn[]>('/admin/office-returns');
  const unpaid = rows.filter((row) => !row.paidAt);
  const total = unpaid.reduce((sum, row) => sum + row.due, 0);

  return (
    <div className="mx-auto max-w-[1280px] pb-8">
      <TopBar
        title="Bureau Tara"
        subtitle={`${rows.length} colis gardé${rows.length > 1 ? 's' : ''} · ${money(total)} à recevoir`}
      />
      <section className="bo-glass rounded-[22px] p-3 sm:px-[18px] sm:py-4">
        <h2 className="mb-1 px-1 text-[15px] font-bold">Colis au bureau</h2>
        <p className="mb-3 px-1 text-[13px] text-muted">
          Retours non payés à temps. L’expéditeur paie dans l’app (il reçoit un code de retrait par
          SMS) ou en espèces ici. Garde gratuite, rappels envoyés automatiquement.
        </p>
        {rows.length === 0 ? (
          <div className="px-6 py-14 text-center">
            <p className="font-display text-[18px] font-bold">Aucun colis au bureau</p>
            <p className="mt-1 text-muted">Les retours non payés apparaîtront ici.</p>
          </div>
        ) : (
          <ul className="flex flex-col gap-2">
            {rows.map((row) => (
              <OfficeRow key={row.orderId} row={row} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function OfficeRow({ row }: { row: OfficeReturn }) {
  const over = row.daysLeft <= 0;
  return (
    <li className="grid gap-3 rounded-2xl bg-panel-soft p-3 md:grid-cols-[1.2fr_1fr_1fr_1.3fr] md:items-center">
      <div>
        <Link href={`/commandes/${row.orderId}`} className="font-extrabold hover:underline">
          {row.reference}
        </Link>
        <p className="text-[13px]">{row.senderName ?? 'Expéditeur'}</p>
        <p className="text-[12px] text-muted">{row.senderPhone}</p>
      </div>
      <div className="text-[13px]">
        <p className="text-muted">Déposé le {dateTime(row.heldSince)}</p>
        <p>
          <span
            className={cx(
              'rounded-md px-2 py-0.5 text-[11px] font-extrabold',
              over
                ? 'bg-danger-bg text-danger'
                : row.daysLeft <= 5
                  ? 'bg-warn-bg text-warn'
                  : 'bg-track text-muted',
            )}
          >
            {daysLabel(row.daysLeft)}
          </span>{' '}
          <span className="text-muted">
            · {row.reminders} rappel{row.reminders > 1 ? 's' : ''}
          </span>
        </p>
      </div>
      <div className="text-[13px]">
        {row.paidAt ? (
          <p className="font-extrabold text-ok">Payé le {dateTime(row.paidAt)}</p>
        ) : (
          <p>
            <span className="font-extrabold">{money(row.due)}</span>
            <span className="text-muted"> à payer</span>
          </p>
        )}
      </div>
      <div className="flex flex-col gap-2">
        <HandOverForm orderId={row.orderId} paid={Boolean(row.paidAt)} due={money(row.due)} />
        {row.paidAt ? null : <UnclaimedForm orderId={row.orderId} over={over} />}
      </div>
    </li>
  );
}
