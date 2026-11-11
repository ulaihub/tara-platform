import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, distance, duration, money, time } from '@/lib/format';
import { COURSE_ALERT_LABELS } from '@/lib/live';
import { OPS_ROLES } from '@/lib/navigation';
import {
  ACTOR_LABELS,
  EVENT_LABELS,
  CONTENTS_LABELS,
  FAILURE_LABELS,
  INELIGIBLE_LABELS,
  PAYMENT_LABELS,
  PROOF_LABELS,
  SIZE_LABELS,
  STATUS_TONE,
  orderPermissions,
  statusLabel,
} from '@/lib/orders';
import { displayPhone } from '@/lib/phone';
import type { AdminOrder, DispatchCandidate } from '@/lib/schemas';
import { AssignButton, CancelForm, NoteForm } from './order-actions';

const VEHICLE_LABELS: Record<NonNullable<AdminOrder['rider']>['vehicleType'], string> = {
  MOTORBIKE: 'Moto',
  TRICYCLE: 'Tricycle',
  CAR: 'Voiture',
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ACTIVE = new Set([
  'CREATED',
  'SEARCHING_RIDER',
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
]);

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  return { title: `Commande ${(await params).id.slice(0, 8)}` };
}

async function load(id: string): Promise<AdminOrder> {
  if (!UUID.test(id)) notFound();
  try {
    return await staffApi<AdminOrder>(`/admin/orders/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
}

/**
 * Fiche d'une commande (H2) : qui, quoi, où, combien, l'historique complet des statuts et
 * des preuves, les notes internes, et pour le dispatch : réattribuer ou annuler.
 */
export default async function OrderPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ reattribuer?: string }>;
}) {
  const session = await requireStaff(OPS_ROLES);
  const { id } = await params;
  const { reattribuer } = await searchParams;
  const order = await load(id);
  const can = orderPermissions(session.roles, order);
  const candidates =
    can.reassign && reattribuer === '1'
      ? await staffApi<DispatchCandidate[]>(`/admin/orders/${id}/candidates`)
      : null;

  return (
    <div className="mx-auto max-w-[1280px]">
      <Link
        href="/commandes"
        className="inline-flex items-center gap-1 text-[14px] font-bold text-muted hover:text-text"
      >
        <Icon name="chevronLeft" size={16} />
        Commandes
      </Link>
      <header className="mt-2 mb-6 flex flex-wrap items-center gap-3">
        <h1 className="font-display text-[28px] font-bold tracking-tight">{order.reference}</h1>
        <span
          className={cx('rounded-full px-3 py-1 text-[13px] font-bold', STATUS_TONE[order.status])}
        >
          {statusLabel(order.status, order.scheduledFor)}
        </span>
        {order.isExpress ? (
          <span className="rounded-full bg-accent-bg px-3 py-1 text-[13px] font-extrabold text-accent">
            Express
          </span>
        ) : null}
        {order.parcel.size === 'BULKY' ? (
          <span className="rounded-full bg-warn-bg px-3 py-1 text-[13px] font-extrabold text-warn">
            Gros objet{order.parcel.loadingHelp ? ' · à deux' : ''}
          </span>
        ) : null}
        {order.delay ? (
          <span className="rounded-full bg-danger-bg px-3 py-1 text-[13px] font-extrabold text-danger">
            En retard de {duration(order.delay.minutes)}
          </span>
        ) : null}
        <span className="ml-auto" />
        {ACTIVE.has(order.status) ? (
          <Link
            href={`/carte?commande=${order.id}`}
            className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-line bg-panel px-3 text-[13px] font-bold hover:border-accent-line"
          >
            <Icon name="map" size={16} />
            Voir sur la carte
          </Link>
        ) : null}
      </header>

      <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-5">
          <Section title="Trajet" aside={distance(order.price.distanceMeters)}>
            <div className="grid gap-4 md:grid-cols-2">
              <Stop title="Enlèvement" stop={order.pickup} />
              <Stop title="Livraison" stop={order.dropoff} />
            </div>
          </Section>

          <Section title="Historique">
            <ol className="relative space-y-4 border-l-2 border-line pl-5">
              {order.timeline.map((event) => (
                <li key={event.id} className="relative">
                  <span
                    aria-hidden="true"
                    className="absolute top-1.5 -left-[27px] size-3 rounded-full border-2 border-panel bg-accent"
                  />
                  <p className="text-[14px] font-bold">
                    {EVENT_LABELS[event.to]}
                    <span className="ml-2 text-[12px] font-normal text-faint">
                      {dateTime(event.at)}
                    </span>
                  </p>
                  <p className="text-[13px] text-muted">
                    {ACTOR_LABELS[event.actorRole] ?? event.actorRole}
                    {event.actorName ? ` · ${event.actorName}` : ''}
                    {event.failureReason
                      ? ` · ${FAILURE_LABELS[event.failureReason] ?? event.failureReason}`
                      : ''}
                  </p>
                  {event.note ? (
                    <p className="mt-0.5 text-[13px] italic text-muted">« {event.note} »</p>
                  ) : null}
                </li>
              ))}
            </ol>
            {order.proofs.length > 0 ? (
              <div className="mt-5 border-t border-line pt-4">
                <h3 className="mb-2 text-[13px] font-bold text-faint uppercase">Preuves</h3>
                <ul className="space-y-1 text-[13px]">
                  {order.proofs.map((proof) => (
                    <li key={proof.id} className="flex flex-wrap gap-x-2">
                      <span className="font-bold">{PROOF_LABELS[proof.kind] ?? proof.kind}</span>
                      <span className="text-faint">{time(proof.at)}</span>
                      <span className="text-muted">
                        {[
                          proof.hasPhoto ? 'photo' : null,
                          proof.codeVerified
                            ? 'code vérifié'
                            : proof.kind === 'DELIVERY'
                              ? 'sans code'
                              : null,
                          proof.receivedBy ? `reçu par ${proof.receivedBy}` : null,
                          proof.validatedBySupport ? 'validée par le support' : null,
                        ]
                          .filter(Boolean)
                          .join(' · ')}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </Section>

          <Section title="Notes internes" aside="Visibles de l’équipe seulement">
            <NoteForm orderId={order.id} />
            {order.notes.length > 0 ? (
              <ul className="mt-4 space-y-3">
                {order.notes.map((note) => (
                  <li key={note.id} className="rounded-2xl bg-panel-soft px-4 py-3">
                    <p className="text-[14px] whitespace-pre-line">{note.body}</p>
                    <p className="mt-1 text-[12px] text-faint">
                      {note.authorName ?? displayPhone(note.authorPhone)} ·{' '}
                      {dateTime(note.createdAt)}
                    </p>
                  </li>
                ))}
              </ul>
            ) : null}
          </Section>
        </div>

        <div className="space-y-5">
          {can.cancel || can.reassign ? (
            <Section title="Actions">
              <div className="space-y-2">
                {can.reassign ? (
                  reattribuer === '1' ? (
                    <Link
                      href={`/commandes/${order.id}`}
                      className="flex min-h-10 items-center justify-center rounded-xl border border-line px-3 text-[13px] font-bold"
                    >
                      Fermer la liste des livreurs
                    </Link>
                  ) : (
                    <Link
                      href={`/commandes/${order.id}?reattribuer=1`}
                      className="flex min-h-10 items-center justify-center gap-2 rounded-xl bg-brand px-3 text-[13px] font-extrabold text-on-brand"
                    >
                      <Icon name="moto" size={16} />
                      {order.rider ? 'Confier à un autre livreur' : 'Choisir un livreur'}
                    </Link>
                  )
                ) : null}
                {can.cancel ? <CancelForm orderId={order.id} /> : null}
              </div>
              {candidates ? (
                <Candidates
                  orderId={order.id}
                  candidates={candidates}
                  current={order.rider?.id ?? null}
                />
              ) : null}
            </Section>
          ) : null}

          <Section title="Personnes">
            <Person
              role="Expéditeur"
              name={order.sender.shopName ?? order.sender.name}
              extra={order.sender.shopName ? order.sender.name : null}
              phone={order.sender.phone}
            />
            <Person
              role="Destinataire"
              name={order.recipient.name}
              extra={
                order.recipient.confirmedAt
                  ? `${order.recipient.available === false ? 'Indisponible' : 'A confirmé'} à ${time(order.recipient.confirmedAt)}${order.recipient.note ? ` · « ${order.recipient.note} »` : ''}`
                  : 'Pas encore de réponse au message de confirmation'
              }
              phone={order.recipient.phone}
            />
            {order.rider ? (
              <Person
                role="Livreur"
                name={order.rider.name ?? displayPhone(order.rider.phone)}
                extra={[VEHICLE_LABELS[order.rider.vehicleType], order.rider.plateNumber]
                  .filter(Boolean)
                  .join(' · ')}
                phone={order.rider.phone}
              />
            ) : (
              <p className="text-[13px] text-muted">Aucun livreur pour l’instant.</p>
            )}
          </Section>

          <Section title="Colis">
            <Facts
              rows={[
                ['Taille', SIZE_LABELS[order.parcel.size]],
                ['Contenu', order.parcel.contents ? CONTENTS_LABELS[order.parcel.contents] : null],
                ['Précision', order.parcel.description],
                ['Fragile', order.parcel.fragile ? 'Oui' : null],
                ['Chargement', order.parcel.loadingHelp ? 'À deux (manutention)' : null],
                [
                  'Valeur déclarée',
                  order.parcel.declaredValue ? money(order.parcel.declaredValue) : null,
                ],
                ['Instructions', order.parcel.instructions],
                ['Programmée', order.scheduledFor ? dateTime(order.scheduledFor) : null],
              ]}
            />
          </Section>

          <Section title="Paiement" aside={money(order.price.totalPrice)}>
            <Facts
              rows={[
                ['Prix de base', money(order.price.basePrice)],
                [
                  'Suppléments',
                  order.price.surchargesTotal > 0 ? money(order.price.surchargesTotal) : null,
                ],
                [
                  'Remise',
                  order.price.discountTotal > 0 ? `− ${money(order.price.discountTotal)}` : null,
                ],
                [
                  'Payé par',
                  order.price.feePayer === 'SENDER' ? 'L’expéditeur' : 'Le destinataire',
                ],
                ['Moyen', PAYMENT_LABELS[order.price.feePaymentMethod]],
                ['Réglé', order.price.feePaidAt ? dateTime(order.price.feePaidAt) : 'Pas encore'],
                ['Part du livreur', money(order.price.riderEarning)],
                ['Part Tara', money(order.price.platformFee)],
                ['À encaisser', order.cod ? money(order.cod.amount) : null],
                [
                  'Encaissé',
                  order.cod?.collectedAt
                    ? `${money(order.cod.collectedAmount ?? 0)} · ${order.cod.method ? PAYMENT_LABELS[order.cod.method] : ''} · ${time(order.cod.collectedAt)}`
                    : null,
                ],
                [
                  'Si échec',
                  `nouvelle tentative ${money(order.price.retryFee)} · retour ${money(order.price.returnFee)}`,
                ],
              ]}
            />
          </Section>

          {order.failure || order.cancelReason ? (
            <Section title={order.cancelReason ? 'Annulation' : 'Échec de livraison'}>
              <Facts
                rows={[
                  [
                    'Raison',
                    order.cancelReason ??
                      (order.failure?.reason
                        ? (FAILURE_LABELS[order.failure.reason] ?? null)
                        : null),
                  ],
                  ['Le', order.failure?.at ? dateTime(order.failure.at) : null],
                  [
                    'Décision',
                    order.failure?.decision === 'RETRY'
                      ? 'Nouvelle tentative'
                      : order.failure?.decision === 'RETURN'
                        ? 'Retour à l’expéditeur'
                        : order.failure
                          ? 'En attente de l’expéditeur'
                          : null,
                  ],
                  ['Tentatives', order.attempts > 0 ? String(order.attempts) : null],
                  // Colis non conforme refusé par le livreur : l'expéditeur paie le déplacement.
                  [
                    'Déplacement facturé',
                    order.proofs.some((proof) => proof.kind === 'PICKUP_REFUSED')
                      ? `${money(order.price.retryFee)} à l’expéditeur`
                      : null,
                  ],
                ]}
              />
            </Section>
          ) : null}

          {order.courseAlerts.length > 0 ? (
            <Section title="Alertes de trajet">
              <ul className="space-y-2 text-[13px]">
                {order.courseAlerts.map((alert) => (
                  <li key={alert.id}>
                    <span className="font-bold">{COURSE_ALERT_LABELS[alert.kind]}</span>
                    <span className="text-faint"> · {dateTime(alert.createdAt)}</span>
                    {alert.acknowledgedAt ? <span className="text-ok"> · vue</span> : null}
                  </li>
                ))}
              </ul>
            </Section>
          ) : null}
        </div>
      </div>
    </div>
  );
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
    <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
      <div className="mb-4 flex items-baseline justify-between gap-3">
        <h2 className="font-display text-[17px] font-bold">{title}</h2>
        {aside ? <span className="text-[13px] font-bold text-muted">{aside}</span> : null}
      </div>
      {children}
    </section>
  );
}

function Stop({ title, stop }: { title: string; stop: AdminOrder['pickup'] }) {
  return (
    <div>
      <p className="text-[12px] font-bold text-faint uppercase">{title}</p>
      <p className="mt-1 text-[15px] font-bold">
        {stop.neighborhood ?? 'Quartier inconnu'}
        {stop.label ? <span className="font-normal text-muted"> · {stop.label}</span> : null}
      </p>
      <p className="text-[14px] text-muted">{stop.landmark}</p>
      {stop.contactName || stop.contactPhone ? (
        <p className="mt-1 text-[13px]">
          {stop.contactName}
          {stop.contactPhone ? (
            <a href={`tel:${stop.contactPhone}`} className="ml-2 font-bold text-accent">
              {displayPhone(stop.contactPhone)}
            </a>
          ) : null}
        </p>
      ) : null}
      {stop.hasPhoto || stop.hasVoiceNote ? (
        <p className="mt-1 text-[12px] text-faint">
          {[stop.hasPhoto ? 'Photo de la façade' : null, stop.hasVoiceNote ? 'Note vocale' : null]
            .filter(Boolean)
            .join(' · ')}
        </p>
      ) : null}
    </div>
  );
}

function Person({
  role,
  name,
  extra,
  phone,
}: {
  role: string;
  name: string | null;
  extra: string | null;
  phone: string;
}) {
  return (
    <div className="mb-3 flex items-start gap-3 last:mb-0">
      <div className="min-w-0 flex-1">
        <p className="text-[12px] font-bold text-faint uppercase">{role}</p>
        <p className="truncate text-[15px] font-bold">{name ?? displayPhone(phone)}</p>
        {extra ? <p className="text-[13px] text-muted">{extra}</p> : null}
      </div>
      <a
        href={`tel:${phone}`}
        aria-label={`Appeler ${name ?? displayPhone(phone)}`}
        className="mt-3 inline-flex min-h-9 items-center gap-1.5 rounded-xl bg-accent-bg px-3 text-[13px] font-bold text-accent"
      >
        <Icon name="phone" size={14} />
        {displayPhone(phone)}
      </a>
    </div>
  );
}

function Facts({ rows }: { rows: [string, string | null][] }) {
  return (
    <dl className="space-y-1.5 text-[14px]">
      {rows
        .filter((row): row is [string, string] => Boolean(row[1]))
        .map(([label, value]) => (
          <div key={label} className="flex gap-3">
            <dt className="w-[120px] shrink-0 text-muted">{label}</dt>
            <dd className="min-w-0 flex-1 font-semibold">{value}</dd>
          </div>
        ))}
    </dl>
  );
}

/** Livreurs proches, du mieux placé au moins bien placé, avec ce qui les empêche de rouler. */
function Candidates({
  orderId,
  candidates,
  current,
}: {
  orderId: string;
  candidates: DispatchCandidate[];
  current: string | null;
}) {
  const shown = candidates.filter((candidate) => candidate.riderId !== current).slice(0, 10);
  if (shown.length === 0) {
    return <p className="mt-4 text-[13px] text-muted">Aucun livreur en ligne près du vendeur.</p>;
  }
  return (
    <ul className="mt-4 space-y-2">
      {shown.map((candidate) => {
        // Ce que l'API refuserait de toute façon : pièces, conditions, véhicule, SOS ouvert.
        const blocked = candidate.ineligibleBecause.some((reason) =>
          ['DOCUMENTS', 'TERMS', 'VEHICLE', 'SAFETY_ALERT'].includes(reason),
        );
        const name = candidate.name ?? displayPhone(candidate.phone);
        return (
          <li
            key={candidate.riderId}
            className="flex items-start gap-3 rounded-2xl bg-panel-soft p-3"
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-[14px] font-bold">{name}</p>
              <p className="text-[12px] text-muted">
                à {distance(candidate.distanceMeters)} du vendeur
                {candidate.activeOrders > 0
                  ? ` · ${candidate.activeOrders} course${candidate.activeOrders > 1 ? 's' : ''} en cours`
                  : ''}
                {candidate.rating !== null ? ` · ★ ${candidate.rating.toFixed(1)}` : ''}
              </p>
              {candidate.ineligibleBecause.length > 0 ? (
                <p className="text-[12px] font-bold text-warn">
                  {candidate.ineligibleBecause
                    .map((reason) => INELIGIBLE_LABELS[reason])
                    .join(', ')}
                </p>
              ) : null}
            </div>
            <AssignButton
              orderId={orderId}
              riderId={candidate.riderId}
              name={name}
              blocked={blocked}
            />
          </li>
        );
      })}
    </ul>
  );
}
