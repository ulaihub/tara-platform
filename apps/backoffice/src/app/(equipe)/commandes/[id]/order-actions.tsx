'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { type ActionState, addNote, assignRider, cancelOrder, validateDelivery } from '../actions';

const IDLE: ActionState = { error: null, done: false };

function Feedback({ state, done }: { state: ActionState; done: string }) {
  if (state.error) {
    return (
      <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
        {state.error}
      </p>
    );
  }
  return state.done ? (
    <p role="status" className="mt-2 text-[13px] font-bold text-ok">
      {done}
    </p>
  ) : null;
}

/** Ajout d'une note interne ; le champ se vide une fois la note enregistrée. */
export function NoteForm({ orderId }: { orderId: string }) {
  const [state, action, pending] = useActionState(addNote, IDLE);
  const form = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (state.done) form.current?.reset();
  }, [state]);
  return (
    <form ref={form} action={action}>
      <input type="hidden" name="orderId" value={orderId} />
      <label className="block">
        <span className="sr-only">Nouvelle note interne</span>
        <textarea
          name="body"
          required
          minLength={2}
          maxLength={1000}
          rows={3}
          placeholder="Ex. : le client préfère être appelé après 14 h. Visible de l’équipe seulement."
          className="block w-full rounded-2xl border border-line bg-panel-soft px-4 py-3 text-[14px] focus:border-accent-line focus:outline-none"
        />
      </label>
      <div className="mt-2 flex items-center justify-end">
        <button
          type="submit"
          disabled={pending}
          className="min-h-10 rounded-xl bg-text px-4 text-[13px] font-extrabold text-bg disabled:opacity-60"
        >
          {pending ? 'Enregistrement…' : 'Ajouter la note'}
        </button>
      </div>
      <Feedback state={state} done="Note ajoutée." />
    </form>
  );
}

/** Annulation en deux temps : le bouton ouvre la raison à donner, puis confirme. */
export function CancelForm({ orderId }: { orderId: string }) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(cancelOrder, IDLE);
  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex min-h-10 w-full items-center justify-center gap-2 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg"
      >
        <Icon name="close" size={16} />
        Annuler la commande
      </button>
    );
  }
  return (
    <form action={action} className="rounded-2xl border border-danger/30 bg-danger-bg p-3">
      <input type="hidden" name="orderId" value={orderId} />
      <label className="block">
        <span className="text-[13px] font-bold text-danger">Raison (envoyée à l’expéditeur)</span>
        <input
          name="reason"
          required
          minLength={3}
          maxLength={300}
          autoFocus
          placeholder="Ex. : commande en double"
          className="mt-1 block min-h-10 w-full rounded-xl border border-line bg-panel px-3 text-[14px] focus:outline-none"
        />
      </label>
      <div className="mt-2 flex gap-2">
        <button
          type="submit"
          disabled={pending}
          className="min-h-10 flex-1 rounded-xl bg-danger px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
        >
          {pending ? 'Annulation…' : 'Confirmer l’annulation'}
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="min-h-10 rounded-xl px-3 text-[13px] font-bold text-muted"
        >
          Garder
        </button>
      </div>
      <Feedback state={state} done="Commande annulée, l’expéditeur est prévenu." />
    </form>
  );
}

/** Bouton « Confier » d'un livreur proposé pour la course. */
export function AssignButton({
  orderId,
  riderId,
  name,
  blocked,
}: {
  orderId: string;
  riderId: string;
  name: string;
  /** Pièce manquante ou conditions non acceptées : impossible de lui confier la course. */
  blocked: boolean;
}) {
  const [state, action, pending] = useActionState(assignRider, IDLE);
  return (
    <form action={action}>
      <input type="hidden" name="orderId" value={orderId} />
      <input type="hidden" name="riderId" value={riderId} />
      <input type="hidden" name="note" value="Attribution manuelle depuis le back-office" />
      <button
        type="submit"
        disabled={pending || blocked || state.done}
        aria-label={`Confier la course à ${name}`}
        className={cx(
          'min-h-9 rounded-xl px-3 text-[13px] font-extrabold',
          blocked ? 'bg-track text-faint' : 'bg-brand text-on-brand',
          'disabled:opacity-60',
        )}
      >
        {state.done ? 'Confiée' : pending ? '…' : 'Confier'}
      </button>
      {state.error ? (
        <p role="alert" className="mt-1 max-w-[180px] text-[12px] font-bold text-danger">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}

/** Validation d'une remise sans code après l'appel au destinataire. */
export function ValidateDeliveryForm({ orderId }: { orderId: string }) {
  const [state, action, pending] = useActionState(validateDelivery, IDLE);
  if (state.done) {
    return (
      <p role="status" className="text-[14px] font-extrabold text-ok">
        Remise validée : la commande est livrée et le livreur est prévenu.
      </p>
    );
  }
  return (
    <form action={action} className="flex flex-col gap-2 sm:flex-row sm:items-start">
      <input type="hidden" name="orderId" value={orderId} />
      <label className="flex-1">
        <span className="sr-only">Comment le destinataire a confirmé</span>
        <input
          name="note"
          required
          minLength={3}
          maxLength={300}
          placeholder="Ex. : appelé à 12 h 20, la cliente confirme avoir reçu le colis."
          className="block min-h-11 w-full rounded-xl border border-line bg-panel-soft px-3 text-[14px] focus:border-accent-line focus:outline-none"
        />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="min-h-11 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
      >
        {pending ? 'Validation…' : 'Valider la remise'}
      </button>
      <Feedback state={state} done="" />
    </form>
  );
}
