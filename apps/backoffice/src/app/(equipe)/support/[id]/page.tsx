import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, money, time } from '@/lib/format';
import { STATUS_TONE as ORDER_TONE, statusLabel } from '@/lib/orders';
import { displayPhone } from '@/lib/phone';
import type { AdminOrder, AdminTicket, OrderEvidence } from '@/lib/schemas';
import {
  CATEGORY_LABELS,
  PERSON_LABELS,
  PRIORITY_LABELS,
  PRIORITY_TONE,
  PROOF_KIND_LABELS,
  STATUS_LABELS,
  STATUS_TONE,
  SUPPORT_ROLES,
  callDuration,
  mapLink,
  statusActions,
} from '@/lib/support';
import { PriorityForm, ReplyForm, UpdateButton } from '../ticket-actions';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  return { title: `Demande ${(await params).id.slice(0, 8)}` };
}

async function load(id: string): Promise<AdminTicket> {
  if (!UUID.test(id)) notFound();
  try {
    return await staffApi<AdminTicket>(`/admin/support/tickets/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
}

/**
 * Fiche d'une demande (H6) : échanges avec le client et notes internes, réponse, prise en
 * charge et statut ; pour une commande, les preuves qui permettent de trancher (photos,
 * positions, appels du livreur, codes, notes) et le lien vers sa fiche complète.
 */
export default async function TicketPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await requireStaff(SUPPORT_ROLES);
  const { id } = await params;
  const ticket = await load(id);
  const [order, evidence] = ticket.order
    ? await Promise.all([
        staffApi<AdminOrder>(`/admin/orders/${ticket.order.id}`),
        staffApi<OrderEvidence>(`/admin/support/orders/${ticket.order.id}/evidence`),
      ])
    : [null, null];
  const person = ticket.requester.name ?? displayPhone(ticket.requester.phone);
  const active = ticket.status === 'OPEN' || ticket.status === 'IN_PROGRESS';
  const mine = ticket.assignee?.id === session.userId;

  return (
    <div className="mx-auto max-w-[1280px]">
      <Link
        href="/support"
        className="inline-flex items-center gap-1 text-[14px] font-bold text-muted hover:text-text"
      >
        <Icon name="chevronLeft" size={16} />
        Support
      </Link>
      <header className="mt-2 mb-6 flex flex-wrap items-center gap-3">
        <h1 className="font-display text-[26px] font-bold tracking-tight">{ticket.subject}</h1>
        <span
          className={cx('rounded-full px-3 py-1 text-[13px] font-bold', STATUS_TONE[ticket.status])}
        >
          {STATUS_LABELS[ticket.status]}
        </span>
        <span
          className={cx(
            'rounded-full px-3 py-1 text-[13px] font-bold',
            PRIORITY_TONE[ticket.priority],
          )}
        >
          Priorité {PRIORITY_LABELS[ticket.priority].toLowerCase()}
        </span>
        <span className="text-[14px] text-muted">
          {ticket.reference} · {CATEGORY_LABELS[ticket.category]} · ouverte le{' '}
          {dateTime(ticket.createdAt)} {ticket.fromApp ? 'depuis l’app' : 'après un appel'}
        </span>
      </header>

      <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-5">
          <Section title="Échanges">
            <ol className="space-y-3">
              {ticket.messages.map((message, index) => (
                <li
                  key={message.id}
                  className={cx(
                    'max-w-[85%] rounded-2xl px-4 py-3',
                    message.internal
                      ? 'mx-auto max-w-full border border-dashed border-warn/50 bg-warn-bg'
                      : message.fromTara
                        ? 'ml-auto bg-accent-bg'
                        : 'bg-panel-soft',
                  )}
                >
                  <p className="text-[12px] font-bold text-muted">
                    {message.internal
                      ? `Note interne · ${message.authorName ?? 'Équipe Tara'}`
                      : index === 0 && !ticket.fromApp
                        ? `Résumé de l’appel · ${message.authorName ?? 'Équipe Tara'}`
                        : message.fromTara
                          ? `Tara · ${message.authorName ?? 'Équipe'}`
                          : person}
                    {' · '}
                    {dateTime(message.at)}
                  </p>
                  <p className="mt-1 text-[14px] whitespace-pre-line">{message.body}</p>
                </li>
              ))}
            </ol>
            <div className="mt-4">
              {!ticket.requesterHasApp && ticket.status !== 'CLOSED' ? (
                <div className="mb-3 flex flex-wrap items-center gap-3 rounded-2xl bg-warn-bg px-4 py-3">
                  <Icon name="phone" size={18} className="text-warn" />
                  <p className="min-w-[220px] flex-1 text-[13px] font-bold text-warn">
                    {ticket.requester.id
                      ? 'Cette personne n’a pas l’app Tara'
                      : 'Personne sans compte Tara'}{' '}
                    : appelez-la pour lui donner la réponse. Elle la reçoit aussi par SMS.
                  </p>
                  <a
                    href={`tel:${ticket.requester.phone}`}
                    className="inline-flex min-h-9 items-center gap-1.5 rounded-xl bg-panel px-3 text-[13px] font-extrabold text-accent"
                  >
                    <Icon name="phone" size={14} />
                    {displayPhone(ticket.requester.phone)}
                  </a>
                </div>
              ) : null}
              <ReplyForm ticketId={ticket.id} canReply={ticket.status !== 'CLOSED'} />
            </div>
          </Section>

          {order && evidence ? <Evidence order={order} evidence={evidence} /> : null}
        </div>

        <div className="space-y-5">
          <Section title="Suivi">
            <p className="text-[14px]">
              {ticket.assignee ? (
                <>
                  Suivie par <strong>{mine ? 'vous' : ticket.assignee.name}</strong>
                </>
              ) : (
                <span className="text-muted">Personne ne suit encore cette demande.</span>
              )}
            </p>
            <div className="mt-3 space-y-2">
              {active && !mine ? (
                <UpdateButton
                  ticketId={ticket.id}
                  name="assign"
                  value="me"
                  label="Prendre en charge"
                  tone="brand"
                />
              ) : null}
              {active && mine ? (
                <UpdateButton
                  ticketId={ticket.id}
                  name="assign"
                  value="none"
                  label="Ne plus suivre"
                />
              ) : null}
              {statusActions(ticket.status).map((action) => (
                <UpdateButton
                  key={action.status}
                  ticketId={ticket.id}
                  name="status"
                  value={action.status}
                  label={action.label}
                  tone={action.status === 'RESOLVED' ? 'ok' : 'plain'}
                />
              ))}
            </div>
            {ticket.resolvedAt ? (
              <p className="mt-3 text-[13px] text-ok">Résolue le {dateTime(ticket.resolvedAt)}</p>
            ) : null}
            <div className="mt-4">
              <p className="mb-1 text-[13px] font-bold">Priorité</p>
              <PriorityForm
                ticketId={ticket.id}
                priority={ticket.priority}
                options={Object.entries(PRIORITY_LABELS).map(([value, label]) => ({
                  value,
                  label,
                }))}
              />
            </div>
          </Section>

          <Section title="Personne">
            <p className="text-[15px] font-bold">{person}</p>
            <p className="text-[13px] text-muted">{PERSON_LABELS[ticket.requester.kind]}</p>
            <a
              href={`tel:${ticket.requester.phone}`}
              className="mt-3 inline-flex min-h-10 items-center gap-2 rounded-xl bg-accent-bg px-3 text-[13px] font-bold text-accent"
            >
              <Icon name="phone" size={16} />
              Rappeler · {displayPhone(ticket.requester.phone)}
            </a>
            {ticket.otherTickets.length > 0 ? (
              <div className="mt-4">
                <p className="mb-1 text-[13px] font-bold">Autres demandes</p>
                <ul className="space-y-1">
                  {ticket.otherTickets.map((other) => (
                    <li key={other.id} className="text-[13px]">
                      <Link
                        href={`/support/${other.id}`}
                        className="font-bold text-accent hover:underline"
                      >
                        {other.reference}
                      </Link>{' '}
                      {other.subject}{' '}
                      <span className="text-muted">
                        · {STATUS_LABELS[other.status].toLowerCase()}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </Section>

          {order ? (
            <Section title="Commande">
              <div className="flex items-center gap-2">
                <Link
                  href={`/commandes/${order.id}`}
                  className="font-display text-[16px] font-bold text-accent hover:underline"
                >
                  {order.reference}
                </Link>
                <span
                  className={cx(
                    'rounded-full px-2 py-0.5 text-[12px] font-bold',
                    ORDER_TONE[order.status],
                  )}
                >
                  {statusLabel(order.status, order.scheduledFor)}
                </span>
              </div>
              <Facts
                rows={[
                  [
                    'Expéditeur',
                    order.sender.shopName ?? order.sender.name ?? displayPhone(order.sender.phone),
                  ],
                  [
                    'Destinataire',
                    `${order.recipient.name} · ${displayPhone(order.recipient.phone)}`,
                  ],
                  [
                    'Livreur',
                    order.rider
                      ? `${order.rider.name ?? displayPhone(order.rider.phone)}${order.rider.plateNumber ? ` · ${order.rider.plateNumber}` : ''}`
                      : null,
                  ],
                  ['Prix', money(order.price.totalPrice)],
                  ['À encaisser', order.cod ? money(order.cod.amount) : null],
                  ['Créée le', dateTime(order.createdAt)],
                ]}
              />
              <Link
                href={`/commandes/${order.id}`}
                className="mt-3 inline-flex items-center gap-1 text-[13px] font-bold text-accent hover:underline"
              >
                Historique complet de la commande <Icon name="chevronRight" size={14} />
              </Link>
            </Section>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/** Ce qui permet de trancher : preuves (photo, position, code, appels), notes, trajet. */
function Evidence({ order, evidence }: { order: AdminOrder; evidence: OrderEvidence }) {
  return (
    <Section title="Preuves de la commande" aside={order.reference}>
      {evidence.proofs.length === 0 ? (
        <p className="text-[14px] text-muted">
          Aucune preuve encore : le livreur n’a pas récupéré le colis.
        </p>
      ) : (
        <ol className="space-y-4">
          {evidence.proofs.map((proof) => (
            <li key={proof.id} className="rounded-2xl bg-panel-soft p-4">
              <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                <p className="flex-1 text-[15px] font-bold">
                  {PROOF_KIND_LABELS[proof.kind] ?? proof.kind}
                  <span className="ml-2 text-[13px] font-normal text-muted">
                    {dateTime(proof.at)}
                  </span>
                </p>
                {proof.hasPhoto ? (
                  <a
                    href={`/support/photos/preuve/${proof.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex min-h-9 items-center gap-1.5 rounded-xl border border-line bg-panel px-3 text-[13px] font-bold hover:border-accent-line"
                  >
                    <Icon name="camera" size={15} />
                    Voir la photo
                  </a>
                ) : null}
                <a
                  href={mapLink(proof.latitude, proof.longitude)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex min-h-9 items-center gap-1.5 rounded-xl border border-line bg-panel px-3 text-[13px] font-bold hover:border-accent-line"
                >
                  <Icon name="mapPin" size={15} />
                  Position
                </a>
              </div>
              <p className="mt-1 text-[13px] text-muted">{codeLine(proof)}</p>
              {proof.calls.length > 0 ? (
                <div className="mt-2">
                  <p className="text-[13px] font-bold">Appels du livreur</p>
                  <ul className="mt-1 space-y-0.5 text-[13px]">
                    {proof.calls.map((call, index) => (
                      <li key={`${call.at}-${index}`}>
                        {time(call.at)} · {call.to === 'RECIPIENT' ? 'destinataire' : 'expéditeur'}{' '}
                        ·{' '}
                        <span className={call.durationSeconds === 0 ? 'font-bold text-danger' : ''}>
                          {callDuration(call.durationSeconds)}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
            </li>
          ))}
        </ol>
      )}

      <div className="mt-4 grid gap-3 md:grid-cols-2">
        <div className="rounded-2xl border border-line p-3">
          <p className="text-[13px] font-bold">Colis à la commande</p>
          {evidence.hasParcelPhoto ? (
            <a
              href={`/support/photos/colis/${order.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-1 inline-flex items-center gap-1 text-[13px] font-bold text-accent hover:underline"
            >
              Voir la photo de l’expéditeur <Icon name="chevronRight" size={14} />
            </a>
          ) : (
            <p className="mt-1 text-[13px] text-muted">Pas de photo jointe.</p>
          )}
          {order.parcel.declaredValue ? (
            <p className="mt-1 text-[13px]">
              Valeur déclarée : {money(order.parcel.declaredValue)}
            </p>
          ) : null}
        </div>
        <div className="rounded-2xl border border-line p-3">
          <p className="text-[13px] font-bold">Trajet enregistré</p>
          <p className="mt-1 text-[13px] text-muted">
            {evidence.trackPoints > 0
              ? `${evidence.trackPoints} positions gardées 90 jours.`
              : 'Aucune position enregistrée.'}
          </p>
        </div>
      </div>

      {evidence.ratings.length > 0 ? (
        <div className="mt-4">
          <p className="text-[13px] font-bold">Notes après la course</p>
          <ul className="mt-1 space-y-1 text-[13px]">
            {evidence.ratings.map((rating, index) => (
              <li key={`${rating.at}-${index}`}>
                <span className="font-bold">
                  {rating.by === 'SENDER' ? 'Expéditeur → livreur' : 'Livreur → expéditeur'}
                </span>{' '}
                · {'★'.repeat(rating.score)}
                <span className="text-faint">{'★'.repeat(5 - rating.score)}</span>
                {rating.comment ? ` · « ${rating.comment} »` : ''}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
      <p className="mt-4 text-[12px] text-faint">
        Chaque ouverture d’une photo est inscrite au journal d’audit.
      </p>
    </Section>
  );
}

/** Ce que dit le code à chaque étape : qui l'a donné, ou remise sans code. */
function codeLine(proof: OrderEvidence['proofs'][number]): string {
  if (proof.kind === 'DELIVERY') {
    return proof.codeVerified
      ? 'Code de livraison donné par le destinataire : vérifié.'
      : `Remise sans code${proof.receivedBy ? `, reçue par ${proof.receivedBy}` : ''} (validée par le support).`;
  }
  if (proof.codeVerified) {
    return proof.kind === 'RETURN'
      ? 'Code donné par l’expéditeur au retour du colis : vérifié.'
      : 'Code d’enlèvement donné par l’expéditeur : vérifié.';
  }
  return 'Pas de code à cette étape.';
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

function Facts({ rows }: { rows: [string, string | null][] }) {
  return (
    <dl className="mt-3 space-y-1.5 text-[14px]">
      {rows
        .filter((row): row is [string, string] => Boolean(row[1]))
        .map(([label, value]) => (
          <div key={label} className="flex gap-3">
            <dt className="w-[110px] shrink-0 text-muted">{label}</dt>
            <dd className="min-w-0 flex-1 font-semibold">{value}</dd>
          </div>
        ))}
    </dl>
  );
}
