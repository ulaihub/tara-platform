import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, duration, money } from '@/lib/format';
import { displayPhone } from '@/lib/phone';
import {
  DOCUMENT_LABELS,
  DOCUMENT_STATUS_LABELS,
  DOCUMENT_STATUS_TONE,
  EXPIRING_TYPES,
  HISTORY_LABELS,
  HISTORY_TONE,
  RIDER_ROLES,
  RIDER_STATUS_LABELS,
  RIDER_STATUS_TONE,
  VEHICLE_LABELS,
  approvalBlockers,
  calendarDate,
  canSetFreePayout,
  documentLines,
  rates,
  ratingText,
  reactivationBlockers,
} from '@/lib/riders';
import type { AdminRider, FreePayout, RiderReliability } from '@/lib/schemas';
import {
  CloseAccountButton,
  DecisionButton,
  DocumentReview,
  FreePayoutForm,
} from './rider-actions';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  return { title: `Livreur ${(await params).id.slice(0, 8)}` };
}

async function load(id: string): Promise<AdminRider> {
  if (!UUID.test(id)) notFound();
  try {
    return await staffApi<AdminRider>(`/admin/riders/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
}

/**
 * Fiche d'un livreur (H3) : pièces à examiner (ouvertes dans un onglet, validées ou
 * refusées avec motif), décision (valider, refuser, suspendre,
 * réactiver), fiabilité sur 30 jours et depuis l'inscription, historique des décisions.
 */
export default async function RiderPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await requireStaff(RIDER_ROLES);
  const { id } = await params;
  const rider = await load(id);
  const reliability = await staffApi<RiderReliability>(`/admin/riders/${id}/reliability`);
  const payout = canSetFreePayout(session.roles)
    ? await staffApi<FreePayout>(`/admin/finance/riders/${id}/free-payout`)
    : null;
  const name = rider.user.closed
    ? 'Ancien livreur'
    : (rider.user.fullName ?? displayPhone(rider.user.phone));
  const lines = documentLines(rider.documents);
  // Pièces validées qui expirent dans les 30 jours (le livreur a été prévenu, A5).
  const expiring = new Set(
    rider.documents
      .filter((doc) =>
        rider.expiringSoon.some(
          (soon) => soon.type === doc.type && soon.expiresOn === doc.expiresOn,
        ),
      )
      .map((doc) => doc.id),
  );

  return (
    <div className="mx-auto max-w-[1280px]">
      <Link
        href="/livreurs"
        className="inline-flex items-center gap-1 text-[14px] font-bold text-muted hover:text-text"
      >
        <Icon name="chevronLeft" size={16} />
        Livreurs
      </Link>
      <header className="mt-2 mb-6 flex flex-wrap items-center gap-3">
        <h1 className="font-display text-[28px] font-bold tracking-tight">{name}</h1>
        <span
          className={cx(
            'rounded-full px-3 py-1 text-[13px] font-bold',
            RIDER_STATUS_TONE[rider.status],
          )}
        >
          {RIDER_STATUS_LABELS[rider.status]}
        </span>
        {rider.user.closed ? (
          <span className="rounded-full bg-danger-bg px-3 py-1 text-[13px] font-bold text-danger">
            Compte fermé
          </span>
        ) : null}
        <span className="text-[14px] text-muted">
          {VEHICLE_LABELS[rider.vehicleType]}
          {rider.plateNumber ? ` · ${rider.plateNumber}` : ''} · inscrit le{' '}
          {dateTime(rider.createdAt)}
        </span>
        <span className="ml-auto" />
        {rider.user.closed ? null : (
          <a
            href={`tel:${rider.user.phone}`}
            className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-accent-bg px-3 text-[13px] font-bold text-accent"
          >
            <Icon name="phone" size={16} />
            {displayPhone(rider.user.phone)}
          </a>
        )}
      </header>

      {rider.status === 'SUSPENDED' && rider.suspendedReason ? (
        <p className="mb-5 rounded-2xl bg-danger-bg px-4 py-3 text-[14px] font-bold text-danger">
          Suspendu : {rider.suspendedReason}
        </p>
      ) : null}

      <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-5">
          <Section
            title="Pièces"
            aside={
              rider.pendingDocuments > 0
                ? `${rider.pendingDocuments} à examiner`
                : `${lines.filter((line) => line.required && line.document?.status === 'APPROVED').length} sur ${lines.filter((line) => line.required).length} validées`
            }
          >
            <ul className="divide-y divide-line">
              {lines.map((line) => {
                const doc = line.document;
                const status = doc?.status ?? 'MISSING';
                return (
                  <li key={line.label} className="py-3 first:pt-0 last:pb-0">
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                      <p className="min-w-[180px] flex-1 text-[15px] font-bold">
                        {doc ? DOCUMENT_LABELS[doc.type] : line.label}
                        {line.required ? null : (
                          <span className="ml-2 text-[12px] font-normal text-faint">
                            facultative
                          </span>
                        )}
                      </p>
                      <span
                        className={cx(
                          'rounded-full px-2 py-0.5 text-[12px] font-bold',
                          DOCUMENT_STATUS_TONE[status],
                        )}
                      >
                        {DOCUMENT_STATUS_LABELS[status]}
                      </span>
                      {doc ? (
                        <a
                          href={`/livreurs/pieces/${doc.id}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex min-h-9 items-center gap-1.5 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
                        >
                          <Icon name="idCard" size={15} />
                          Voir la pièce
                        </a>
                      ) : null}
                    </div>
                    {doc ? (
                      <p className="mt-1 text-[13px] text-muted">
                        Envoyée le {dateTime(doc.createdAt)}
                        {doc.expiresOn && expiring.has(doc.id) ? (
                          <strong className="text-warn">
                            {' '}
                            · expire bientôt, le {calendarDate(doc.expiresOn)}
                          </strong>
                        ) : doc.expiresOn ? (
                          ` · expire le ${calendarDate(doc.expiresOn)}`
                        ) : (
                          ''
                        )}
                        {doc.reviewedAt && doc.status !== 'PENDING'
                          ? ` · examinée le ${dateTime(doc.reviewedAt)}`
                          : ''}
                      </p>
                    ) : (
                      <p className="mt-1 text-[13px] text-muted">
                        Le livreur l’envoie depuis son profil dans l’app.
                      </p>
                    )}
                    {doc?.status === 'REJECTED' && doc.rejectionReason ? (
                      <p className="mt-1 text-[13px] font-bold text-danger">
                        Motif : {doc.rejectionReason}
                      </p>
                    ) : null}
                    {doc?.status === 'PENDING' ? (
                      <DocumentReview
                        riderId={rider.id}
                        documentId={doc.id}
                        asksExpiry={EXPIRING_TYPES.includes(doc.type)}
                        expiresOn={doc.expiresOn}
                      />
                    ) : null}
                  </li>
                );
              })}
            </ul>
            <p className="mt-4 text-[12px] text-faint">
              Chaque ouverture d’une pièce est inscrite au journal d’audit.
            </p>
          </Section>

          <Reliability reliability={reliability} />

          <Section title="Historique">
            {reliability.history.length === 0 ? (
              <p className="text-[14px] text-muted">Aucun événement.</p>
            ) : (
              <ol className="relative space-y-4 border-l-2 border-line pl-5">
                {reliability.history.map((item, index) => (
                  <li key={`${item.at}-${index}`} className="relative">
                    <span
                      className={cx(
                        'absolute top-1.5 -left-[27px] size-3 rounded-full ring-4 ring-panel',
                        HISTORY_TONE[item.action],
                      )}
                      aria-hidden="true"
                    />
                    <p className="text-[14px] font-bold">
                      {HISTORY_LABELS[item.action]}
                      {item.documentType ? ` · ${DOCUMENT_LABELS[item.documentType]}` : ''}
                    </p>
                    <p className="text-[13px] text-muted">
                      {dateTime(item.at)}
                      {item.by
                        ? ` · ${item.by}`
                        : item.action === 'APPLIED'
                          ? ''
                          : ' · automatique'}
                    </p>
                    {item.note ? (
                      <p className="mt-0.5 text-[13px]">
                        {item.action === 'FREE_PAYOUT_SET'
                          ? `Nouveau seuil : ${money(Number(item.note))}`
                          : item.note}
                      </p>
                    ) : item.action === 'FREE_PAYOUT_SET' ? (
                      <p className="mt-0.5 text-[13px]">Retour au seuil général</p>
                    ) : null}
                  </li>
                ))}
              </ol>
            )}
          </Section>
        </div>

        <div className="space-y-5">
          <Decision rider={rider} />

          <Section title="Contacts">
            <Facts
              rows={[
                ['Garant', rider.guarantorName],
                ['Tél. garant', rider.guarantorPhone ? displayPhone(rider.guarantorPhone) : null],
                [
                  'Contact d’urgence',
                  rider.emergencyContact
                    ? `${rider.emergencyContact.name} · ${displayPhone(rider.emergencyContact.phone)}`
                    : null,
                ],
              ]}
              empty="Aucun garant ni contact d’urgence (facultatifs)."
            />
          </Section>

          {payout && (rider.status === 'ACTIVE' || rider.status === 'SUSPENDED') ? (
            <Section title="Retraits">
              <p className="text-[14px]">
                Gratuit à partir de <strong>{money(payout.freeFrom)}</strong>
                {payout.custom === null ? ' (seuil général)' : ''}.
                {payout.feeBps > 0
                  ? ` En dessous, frais Mobile Money de ${(payout.feeBps / 100).toLocaleString('fr-FR')} % : ${payout.feeSharePercent} % payés par le livreur, le reste par Tara.`
                  : ' Aucun frais de retrait réglé pour l’instant.'}
              </p>
              <p className="mt-1 text-[13px] text-muted">
                Retraits moyens : {money(payout.averageMonthlyPayouts)} par mois (90 derniers
                jours).
              </p>
              <FreePayoutForm riderId={rider.id} custom={payout.custom} fallback={payout.default} />
            </Section>
          ) : null}

          {session.roles.includes('ADMIN') && !rider.user.closed ? (
            <Section title="Fermer le compte">
              <p className="text-[14px] text-muted">
                À la demande du livreur. Possible seulement sans course en cours, sans argent dû
                dans un sens ou dans l’autre ni retrait en cours. Pièces d’identité, garant et
                contact d’urgence sont effacés ; ses courses restent, anonymes.
              </p>
              <div className="mt-3">
                <CloseAccountButton riderId={rider.id} />
              </div>
            </Section>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/** Décision selon le statut, avec ce qui manque encore pour valider ou réactiver. */
function Decision({ rider }: { rider: AdminRider }) {
  if (rider.status === 'REJECTED') {
    return (
      <Section title="Décision">
        <p className="text-[14px] text-muted">Candidature refusée : aucune action possible.</p>
      </Section>
    );
  }
  if (rider.status === 'PENDING') {
    const blockers = approvalBlockers(rider);
    return (
      <Section title="Décision">
        <Checklist items={[['Toutes les pièces validées', blockers.length === 0]]} />
        {blockers.length > 0 ? (
          <p className="mt-3 text-[13px] font-bold text-warn">{blockers.join(' · ')}</p>
        ) : null}
        <div className="mt-4 space-y-2">
          <DecisionButton riderId={rider.id} decision="APPROVE" disabled={blockers.length > 0} />
          <DecisionButton riderId={rider.id} decision="REJECT" />
        </div>
      </Section>
    );
  }
  if (rider.status === 'SUSPENDED') {
    const blockers = reactivationBlockers(rider);
    return (
      <Section title="Décision">
        {rider.cashSuspendedAt ? (
          <p className="mb-3 text-[13px] font-bold text-danger">
            Suspendu le {dateTime(rider.cashSuspendedAt)} faute d’avoir déposé ses espèces : la
            finance réactive une fois la somme réglée.
          </p>
        ) : null}
        {blockers.length > 0 ? (
          <p className="mb-3 text-[13px] font-bold text-warn">{blockers.join(' · ')}</p>
        ) : null}
        <DecisionButton
          riderId={rider.id}
          decision="REACTIVATE"
          disabled={blockers.length > 0 || rider.cashSuspendedAt !== null}
        />
      </Section>
    );
  }
  return (
    <Section title="Décision">
      <p className="mb-3 text-[14px] text-muted">
        Actif depuis le {rider.approvedAt ? dateTime(rider.approvedAt) : '—'}. Une suspension
        l’empêche de recevoir des courses ; le motif est gardé dans l’historique.
      </p>
      <DecisionButton riderId={rider.id} decision="SUSPEND" />
    </Section>
  );
}

function Checklist({ items }: { items: [string, boolean][] }) {
  return (
    <ul className="space-y-2">
      {items.map(([label, ok]) => (
        <li key={label} className="flex items-center gap-2 text-[14px] font-bold">
          <span
            className={cx(
              'grid size-6 place-items-center rounded-full',
              ok ? 'bg-ok text-white' : 'bg-track text-faint',
            )}
          >
            {ok ? <Icon name="check" size={14} /> : null}
          </span>
          <span className={ok ? undefined : 'text-muted'}>{label}</span>
        </li>
      ))}
    </ul>
  );
}

/** Fiabilité : 30 derniers jours et depuis l'inscription, côte à côte. */
function Reliability({ reliability }: { reliability: RiderReliability }) {
  const windows = [reliability.last30Days, reliability.allTime] as const;
  const [recent, all] = windows.map(rates) as [ReturnType<typeof rates>, ReturnType<typeof rates>];
  const pct = (value: number | null) => (value === null ? '—' : `${value} %`);
  const rows: [string, string, string, string?][] = [
    [
      'Propositions acceptées',
      pct(recent.acceptance),
      pct(all.acceptance),
      'Acceptées sur les propositions reçues (refusées ou laissées sans réponse comptent contre).',
    ],
    [
      'Livraisons réussies',
      pct(recent.success),
      pct(all.success),
      'Livrées sur livrées + échecs déclarés.',
    ],
    ['Livrées à l’heure', pct(recent.onTime), pct(all.onTime)],
    [
      'Courses livrées',
      String(reliability.last30Days.deliveries.delivered),
      String(reliability.allTime.deliveries.delivered),
    ],
    [
      'Échecs de livraison',
      String(reliability.last30Days.deliveries.failed),
      String(reliability.allTime.deliveries.failed),
    ],
    [
      'Colis refusés à l’enlèvement',
      String(reliability.last30Days.deliveries.parcelsRefused),
      String(reliability.allTime.deliveries.parcelsRefused),
    ],
    [
      'Note des expéditeurs',
      ratingCell(reliability.last30Days.rating),
      ratingCell(reliability.allTime.rating),
    ],
    [
      'Temps en ligne',
      duration(reliability.last30Days.onlineMinutes),
      duration(reliability.allTime.onlineMinutes),
    ],
    [
      'Alertes de course',
      String(reliability.last30Days.courseAlerts),
      String(reliability.allTime.courseAlerts),
      'Action validée loin de l’adresse, long arrêt avec le colis, position simulée, coupure.',
    ],
    [
      'Alertes SOS',
      String(reliability.last30Days.sosAlerts),
      String(reliability.allTime.sosAlerts),
    ],
  ];
  return (
    <Section title="Fiabilité">
      <div className="relative overflow-x-auto">
        <table className="w-full text-[14px]">
          <thead className="text-[12px] font-bold text-faint uppercase">
            <tr>
              <th className="pb-2 text-left font-bold">
                <span className="sr-only">Indicateur</span>
              </th>
              <th className="w-[140px] pb-2 text-right">30 derniers jours</th>
              <th className="w-[140px] pb-2 text-right">Depuis l’inscription</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(([label, last30, total, hint]) => (
              <tr key={label} className="border-t border-line">
                <th scope="row" className="py-2 text-left font-semibold">
                  {label}
                  {hint ? (
                    <span className="block text-[12px] font-normal text-faint">{hint}</span>
                  ) : null}
                </th>
                <td className="py-2 text-right font-bold tabular-nums">{last30}</td>
                <td className="py-2 text-right tabular-nums text-muted">{total}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Section>
  );
}

function ratingCell(rating: { average: number | null; count: number }): string {
  const text = ratingText(rating.average);
  return text ? `★ ${text} (${rating.count})` : '—';
}

function Section({
  title,
  aside,
  children,
}: {
  title: string;
  aside?: string;
  children: ReactNode;
}) {
  return (
    <section className="bo-glass rounded-[22px] p-5 shadow-card">
      <div className="mb-4 flex items-baseline justify-between gap-3">
        <h2 className="font-display text-[17px] font-bold">{title}</h2>
        {aside ? <span className="text-[13px] font-bold text-muted">{aside}</span> : null}
      </div>
      {children}
    </section>
  );
}

function Facts({ rows, empty }: { rows: [string, string | null][]; empty: string }) {
  const shown = rows.filter((row): row is [string, string] => Boolean(row[1]));
  if (shown.length === 0) return <p className="text-[14px] text-muted">{empty}</p>;
  return (
    <dl className="space-y-1.5 text-[14px]">
      {shown.map(([label, value]) => (
        <div key={label} className="flex gap-3">
          <dt className="w-[130px] shrink-0 text-muted">{label}</dt>
          <dd className="min-w-0 flex-1 font-semibold">{value}</dd>
        </div>
      ))}
    </dl>
  );
}
