'use client';

import { useActionState, useState } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { exportRange } from '@/lib/finance';
import { type ActionState, approvePayout, rejectPayout, rerunCheck } from './actions';

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
 * Validation d'un gros reversement, en deux temps : le bouton demande confirmation avec le
 * montant ; refuser demande le motif (l'argent reste sur le solde du bénéficiaire).
 */
export function PayoutDecision({ payoutId, amount }: { payoutId: string; amount: string }) {
  const [mode, setMode] = useState<'idle' | 'approve' | 'reject'>('idle');
  const [approveState, approve, approving] = useActionState(approvePayout, IDLE);
  const [rejectState, reject, rejecting] = useActionState(rejectPayout, IDLE);
  if (mode === 'approve') {
    return (
      <form action={approve} className="flex flex-wrap items-center justify-end gap-2">
        <input type="hidden" name="payoutId" value={payoutId} />
        <span className="text-[13px] font-bold">Envoyer {amount} ?</span>
        <button
          type="submit"
          disabled={approving}
          className="min-h-9 rounded-xl bg-ok px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
        >
          {approving ? 'Envoi…' : 'Confirmer'}
        </button>
        <button
          type="button"
          onClick={() => setMode('idle')}
          className="min-h-9 rounded-xl px-2 text-[13px] font-bold text-muted hover:text-text"
        >
          Retour
        </button>
        <Feedback state={approveState} />
      </form>
    );
  }
  if (mode === 'reject') {
    return (
      <form action={reject} className="flex flex-wrap items-center justify-end gap-2">
        <input type="hidden" name="payoutId" value={payoutId} />
        <label className="min-w-[200px] flex-1">
          <span className="sr-only">Motif du refus</span>
          <input
            name="reason"
            required
            minLength={3}
            maxLength={300}
            autoFocus
            placeholder="Motif du refus"
            className={cx(INPUT, 'py-2')}
          />
        </label>
        <button
          type="submit"
          disabled={rejecting}
          className="min-h-9 rounded-xl bg-danger px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
        >
          {rejecting ? 'Envoi…' : 'Refuser'}
        </button>
        <button
          type="button"
          onClick={() => setMode('idle')}
          className="min-h-9 rounded-xl px-2 text-[13px] font-bold text-muted hover:text-text"
        >
          Retour
        </button>
        <Feedback state={rejectState} />
      </form>
    );
  }
  return (
    <div className="flex justify-end gap-2">
      <button
        type="button"
        onClick={() => setMode('approve')}
        className="inline-flex min-h-9 items-center gap-1.5 rounded-xl bg-ok px-3 text-[13px] font-extrabold text-white"
      >
        <Icon name="check" size={15} />
        Valider
      </button>
      <button
        type="button"
        onClick={() => setMode('reject')}
        className="min-h-9 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg"
      >
        Refuser
      </button>
    </div>
  );
}

/** Relance le contrôle d'une journée. */
export function RerunButton({ day }: { day: string }) {
  const [state, action, pending] = useActionState(rerunCheck, IDLE);
  return (
    <form action={action}>
      <input type="hidden" name="day" value={day} />
      <button
        type="submit"
        disabled={pending}
        className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line disabled:opacity-60"
      >
        <Icon name="refresh" size={16} />
        {pending ? 'Contrôle en cours…' : 'Relancer le contrôle'}
      </button>
      <Feedback state={state} done="Contrôle relancé." />
    </form>
  );
}

/** Export comptable : période, puis téléchargement du fichier CSV. */
export function ExportForm({ from, to }: { from: string; to: string }) {
  const [range, setRange] = useState({ from, to });
  const invalid = exportRange(range.from, range.to);
  return (
    <div className="flex flex-wrap items-end gap-3">
      <label className="block">
        <span className="text-[13px] font-bold">Du</span>
        <input
          type="date"
          value={range.from}
          onChange={(event) => setRange({ ...range, from: event.target.value })}
          className={cx(INPUT, 'mt-1 w-[170px]')}
        />
      </label>
      <label className="block">
        <span className="text-[13px] font-bold">Au</span>
        <input
          type="date"
          value={range.to}
          onChange={(event) => setRange({ ...range, to: event.target.value })}
          className={cx(INPUT, 'mt-1 w-[170px]')}
        />
      </label>
      <a
        href={invalid ? undefined : `/finance/export?du=${range.from}&au=${range.to}`}
        aria-disabled={invalid !== null}
        className={cx(
          'inline-flex min-h-11 items-center gap-2 rounded-2xl px-4 text-[14px] font-extrabold',
          invalid ? 'pointer-events-none bg-track text-faint' : 'bg-brand text-on-brand',
        )}
      >
        <Icon name="download" size={18} />
        Télécharger le journal (CSV)
      </a>
      {invalid ? <p className="w-full text-[13px] font-bold text-warn">{invalid}</p> : null}
    </div>
  );
}
