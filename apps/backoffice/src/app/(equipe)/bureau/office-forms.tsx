'use client';

import { useActionState, useState } from 'react';
import { cx } from '@/components/ui';
import { handOver, markUnclaimed, type OfficeActionState } from './actions';

const IDLE: OfficeActionState = { error: null, done: false };

function Feedback({ state, done }: { state: OfficeActionState; done: string }) {
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

/**
 * « Remis à l'expéditeur » : avec le code de retrait s'il a payé dans l'app, sinon contre
 * les frais en espèces (case à cocher, montant rappelé).
 */
export function HandOverForm({
  orderId,
  paid,
  due,
}: {
  orderId: string;
  paid: boolean;
  due: string;
}) {
  const [state, action, pending] = useActionState(handOver, IDLE);
  return (
    <form action={action} className="flex flex-col gap-2">
      <input type="hidden" name="orderId" value={orderId} />
      {paid ? (
        <label className="flex items-center gap-2 text-[13px] font-bold">
          Code de retrait
          <input
            name="code"
            inputMode="numeric"
            pattern="\d{4}"
            maxLength={4}
            required
            autoComplete="off"
            className="h-10 w-24 rounded-xl border border-line bg-panel-soft px-3 text-center text-[15px] tracking-[.3em] focus:border-accent-line focus:outline-none"
          />
        </label>
      ) : (
        <label className="flex items-center gap-2 text-[13px] font-bold">
          <input type="checkbox" name="cash" required className="size-4 accent-[var(--accent)]" />
          {`Frais reçus en espèces : ${due}`}
        </label>
      )}
      <button
        type="submit"
        disabled={pending}
        className="min-h-10 rounded-xl bg-text px-4 text-[13px] font-extrabold text-bg disabled:opacity-60"
      >
        {pending ? 'Enregistrement…' : 'Remis à l’expéditeur'}
      </button>
      <Feedback state={state} done="Colis rendu." />
    </form>
  );
}

/** Garde finie : la note dit ce que Tara a fait du colis (don, destruction…). */
export function UnclaimedForm({ orderId, over }: { orderId: string; over: boolean }) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(markUnclaimed, IDLE);
  if (!over) return null;
  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="min-h-10 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg"
      >
        Délai fini : colis non réclamé
      </button>
    );
  }
  return (
    <form action={action} className="rounded-2xl border border-danger/30 bg-danger-bg p-3">
      <input type="hidden" name="orderId" value={orderId} />
      <label className="block text-[13px] font-bold">
        Ce que Tara a fait du colis
        <input
          name="note"
          required
          minLength={3}
          maxLength={300}
          placeholder="Ex. : donné à l’association …, le 6 janvier"
          className={cx(
            'mt-1 block h-10 w-full rounded-xl border border-line bg-panel px-3 text-[14px] font-normal',
            'focus:border-accent-line focus:outline-none',
          )}
        />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="mt-2 min-h-10 rounded-xl bg-danger px-4 text-[13px] font-extrabold text-white disabled:opacity-60"
      >
        {pending ? 'Enregistrement…' : 'Confirmer : non réclamé'}
      </button>
      <Feedback state={state} done="Noté : plus rien n’est dû." />
    </form>
  );
}
