'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { cx } from '@/components/ui';
import { type ActionState, createTicket, sendMessage, updateTicket } from './actions';

const IDLE: ActionState = { error: null, done: false };

const INPUT =
  'block w-full rounded-2xl border border-line bg-panel px-3 py-2.5 text-[14px] focus:border-accent-line focus:outline-none';

function Feedback({ state, done }: { state: ActionState; done?: string }) {
  if (state.error) {
    return (
      <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
        {state.error}
      </p>
    );
  }
  return state.done && done ? (
    <p role="status" className="mt-2 text-[13px] font-bold text-ok">
      {done}
    </p>
  ) : null;
}

/**
 * Réponse au client (il la reçoit : notification dans l'app, sinon SMS) ou note interne
 * (équipe seulement). Le choix est visible avant d'envoyer.
 */
export function ReplyForm({ ticketId, canReply }: { ticketId: string; canReply: boolean }) {
  const [internal, setInternal] = useState(!canReply);
  const [state, action, pending] = useActionState(sendMessage, IDLE);
  const form = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (state.done) form.current?.reset();
  }, [state]);
  return (
    <form
      ref={form}
      action={action}
      className={cx(
        'rounded-2xl border p-3',
        internal ? 'border-warn/40 bg-warn-bg' : 'border-line bg-panel-soft',
      )}
    >
      <input type="hidden" name="ticketId" value={ticketId} />
      <input type="hidden" name="internal" value={internal ? 'true' : 'false'} />
      <div role="radiogroup" aria-label="Type de message" className="mb-2 flex gap-2">
        {[
          { value: false, label: 'Réponse au client', disabled: !canReply },
          { value: true, label: 'Note interne', disabled: false },
        ].map((option) => (
          <button
            key={option.label}
            type="button"
            role="radio"
            aria-checked={internal === option.value}
            disabled={option.disabled}
            onClick={() => setInternal(option.value)}
            className={cx(
              'min-h-9 rounded-xl px-3 text-[13px] font-bold disabled:opacity-40',
              internal === option.value ? 'bg-text text-bg' : 'text-muted hover:text-text',
            )}
          >
            {option.label}
          </button>
        ))}
      </div>
      <label className="block">
        <span className="sr-only">{internal ? 'Note interne' : 'Réponse au client'}</span>
        <textarea
          name="body"
          required
          minLength={2}
          maxLength={2000}
          rows={4}
          placeholder={
            internal
              ? 'Visible de l’équipe seulement. Ex. : vérifier le trajet du livreur avant de rappeler.'
              : 'Ex. : Bonjour, nous avons vérifié la livraison…'
          }
          className={INPUT}
        />
      </label>
      <div className="mt-2 flex items-center gap-3">
        <p className="flex-1 text-[12px] text-muted">
          {internal
            ? 'Le client ne voit pas cette note.'
            : 'Le client la reçoit dans l’app, ou par SMS s’il ne l’a pas.'}
        </p>
        <button
          type="submit"
          disabled={pending}
          className={cx(
            'min-h-10 rounded-xl px-4 text-[13px] font-extrabold disabled:opacity-60',
            internal ? 'bg-text text-bg' : 'bg-brand text-on-brand',
          )}
        >
          {pending ? 'Envoi…' : internal ? 'Ajouter la note' : 'Envoyer la réponse'}
        </button>
      </div>
      <Feedback state={state} done={internal ? 'Note ajoutée.' : 'Réponse envoyée.'} />
    </form>
  );
}

/** Un bouton qui modifie la demande (prendre en charge, statut…). */
export function UpdateButton({
  ticketId,
  name,
  value,
  label,
  tone = 'plain',
}: {
  ticketId: string;
  name: 'status' | 'assign';
  value: string;
  label: string;
  tone?: 'plain' | 'brand' | 'ok';
}) {
  const [state, action, pending] = useActionState(updateTicket, IDLE);
  return (
    <form action={action}>
      <input type="hidden" name="ticketId" value={ticketId} />
      <input type="hidden" name={name} value={value} />
      <button
        type="submit"
        disabled={pending}
        className={cx(
          'flex min-h-10 w-full items-center justify-center rounded-xl px-3 text-[13px] font-extrabold disabled:opacity-60',
          tone === 'brand' && 'bg-brand text-on-brand',
          tone === 'ok' && 'bg-ok text-white',
          tone === 'plain' && 'border border-line hover:border-accent-line',
        )}
      >
        {pending ? '…' : label}
      </button>
      <Feedback state={state} />
    </form>
  );
}

/** Priorité modifiable d'un clic. */
export function PriorityForm({
  ticketId,
  priority,
  options,
}: {
  ticketId: string;
  priority: string;
  options: { value: string; label: string }[];
}) {
  const [state, action, pending] = useActionState(updateTicket, IDLE);
  return (
    <form action={action} className="flex gap-2">
      <input type="hidden" name="ticketId" value={ticketId} />
      <label className="flex-1">
        <span className="sr-only">Priorité</span>
        <select name="priority" defaultValue={priority} className={INPUT}>
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>
      <button
        type="submit"
        disabled={pending}
        className="min-h-10 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line disabled:opacity-60"
      >
        {pending ? '…' : 'Changer'}
      </button>
      <Feedback state={state} />
    </form>
  );
}

/** Nouvelle demande après un appel : qui appelle, pourquoi, résumé. */
export function NewTicketForm({
  categories,
  priorities,
  phone,
  orderReference,
}: {
  categories: { value: string; label: string }[];
  priorities: { value: string; label: string }[];
  phone?: string;
  orderReference?: string;
}) {
  const [state, action, pending] = useActionState(createTicket, IDLE);
  return (
    <form action={action} className="space-y-4">
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block">
          <span className="text-[13px] font-bold">Numéro de la personne</span>
          <input
            name="phone"
            inputMode="tel"
            defaultValue={phone}
            placeholder="6 90 00 00 00"
            className={cx(INPUT, 'mt-1')}
          />
        </label>
        <label className="block">
          <span className="text-[13px] font-bold">Commande concernée</span>
          <input
            name="orderReference"
            defaultValue={orderReference}
            placeholder="TR-7K3P9Q"
            className={cx(INPUT, 'mt-1 uppercase')}
          />
        </label>
      </div>
      <p className="-mt-2 text-[12px] text-muted">
        L’un des deux suffit. Avec la commande seule, la demande est rattachée à l’expéditeur. Un
        destinataire sans compte est rappelé à son numéro.
      </p>
      <div className="grid gap-4 md:grid-cols-[1fr_200px]">
        <label className="block">
          <span className="text-[13px] font-bold">Motif</span>
          <select name="category" required defaultValue="" className={cx(INPUT, 'mt-1')}>
            <option value="" disabled>
              Choisir…
            </option>
            {categories.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="text-[13px] font-bold">Priorité</span>
          <select name="priority" defaultValue="NORMAL" className={cx(INPUT, 'mt-1')}>
            {priorities.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="block">
        <span className="text-[13px] font-bold">Titre</span>
        <input
          name="subject"
          required
          minLength={3}
          maxLength={120}
          placeholder="Ex. : colis non reçu par la destinataire"
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <label className="block">
        <span className="text-[13px] font-bold">Résumé de l’appel</span>
        <textarea
          name="message"
          required
          minLength={2}
          maxLength={2000}
          rows={5}
          placeholder="Ce que dit la personne et ce qu’elle demande."
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <div className="flex justify-end">
        <button
          type="submit"
          disabled={pending}
          className="min-h-11 rounded-2xl bg-brand px-5 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
        >
          {pending ? 'Enregistrement…' : 'Ouvrir la demande'}
        </button>
      </div>
      <Feedback state={state} />
    </form>
  );
}
