'use client';

import { useActionState, useState } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { type ActionState, decideRider, reviewDocument, setFreePayout } from '../actions';

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
 * Examen d'une pièce : valider (avec la date d'expiration lue sur le document quand elle
 * compte) ou refuser avec le motif, envoyé au livreur pour qu'il la renvoie.
 */
export function DocumentReview({
  riderId,
  documentId,
  asksExpiry,
  expiresOn,
}: {
  riderId: string;
  documentId: string;
  asksExpiry: boolean;
  expiresOn: string | null;
}) {
  const [mode, setMode] = useState<'idle' | 'reject'>('idle');
  const [state, action, pending] = useActionState(reviewDocument, IDLE);
  if (mode === 'reject') {
    return (
      <form action={action} className="mt-3 rounded-2xl border border-danger/30 bg-danger-bg p-3">
        <input type="hidden" name="riderId" value={riderId} />
        <input type="hidden" name="documentId" value={documentId} />
        <input type="hidden" name="decision" value="REJECTED" />
        <label className="block">
          <span className="text-[13px] font-bold">Motif envoyé au livreur</span>
          <input
            name="reason"
            required
            minLength={3}
            maxLength={300}
            autoFocus
            placeholder="Ex. : photo floue, document expiré, visage caché"
            className={cx(INPUT, 'mt-1')}
          />
        </label>
        <div className="mt-2 flex gap-2">
          <button
            type="submit"
            disabled={pending}
            className="min-h-10 rounded-xl bg-danger px-4 text-[13px] font-extrabold text-white disabled:opacity-60"
          >
            {pending ? 'Envoi…' : 'Refuser la pièce'}
          </button>
          <button
            type="button"
            onClick={() => setMode('idle')}
            className="min-h-10 rounded-xl px-3 text-[13px] font-bold text-muted hover:text-text"
          >
            Retour
          </button>
        </div>
        <Feedback state={state} />
      </form>
    );
  }
  return (
    <form action={action} className="mt-3 flex flex-wrap items-end gap-2">
      <input type="hidden" name="riderId" value={riderId} />
      <input type="hidden" name="documentId" value={documentId} />
      <input type="hidden" name="decision" value="APPROVED" />
      {asksExpiry ? (
        <label className="block">
          <span className="text-[12px] font-bold text-muted">Expire le</span>
          <input
            type="date"
            name="expiresOn"
            defaultValue={expiresOn ?? ''}
            className={cx(INPUT, 'mt-1 w-[170px] py-2')}
          />
        </label>
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="inline-flex min-h-10 items-center gap-1.5 rounded-xl bg-ok px-4 text-[13px] font-extrabold text-white disabled:opacity-60"
      >
        <Icon name="check" size={16} />
        {pending ? 'Validation…' : 'Valider'}
      </button>
      <button
        type="button"
        onClick={() => setMode('reject')}
        className="min-h-10 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg"
      >
        Refuser
      </button>
      <Feedback state={state} />
    </form>
  );
}

type Decision = 'APPROVE' | 'REJECT' | 'SUSPEND' | 'REACTIVATE';

const DECISION_COPY: Record<
  Decision,
  { button: string; confirm: string; reason: string | null; danger: boolean; done: string }
> = {
  APPROVE: {
    button: 'Valider le livreur',
    confirm: 'Il pourra passer en ligne et recevoir des courses.',
    reason: null,
    danger: false,
    done: 'Livreur validé.',
  },
  REJECT: {
    button: 'Refuser la candidature',
    confirm: 'Le refus est définitif pour ce compte.',
    reason: 'Motif du refus',
    danger: true,
    done: 'Candidature refusée.',
  },
  SUSPEND: {
    button: 'Suspendre',
    confirm: 'Il ne recevra plus de courses jusqu’à sa réactivation.',
    reason: 'Motif de la suspension',
    danger: true,
    done: 'Livreur suspendu.',
  },
  REACTIVATE: {
    button: 'Réactiver',
    confirm: 'Il pourra de nouveau passer en ligne.',
    reason: null,
    danger: false,
    done: 'Livreur réactivé.',
  },
};

/** Décision en deux temps : le bouton ouvre la confirmation (et le motif s'il est exigé). */
export function DecisionButton({
  riderId,
  decision,
  disabled = false,
}: {
  riderId: string;
  decision: Decision;
  disabled?: boolean;
}) {
  const copy = DECISION_COPY[decision];
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(decideRider, IDLE);
  if (!open) {
    return (
      <>
        <button
          type="button"
          disabled={disabled}
          onClick={() => setOpen(true)}
          className={cx(
            'flex min-h-11 w-full items-center justify-center gap-2 rounded-xl px-3 text-[14px] font-extrabold disabled:cursor-not-allowed disabled:opacity-50',
            copy.danger
              ? 'border border-danger/40 text-danger hover:bg-danger-bg'
              : 'bg-brand text-on-brand',
          )}
        >
          {copy.button}
        </button>
        <Feedback state={state} done={copy.done} />
      </>
    );
  }
  return (
    <form
      action={action}
      className={cx(
        'rounded-2xl border p-3',
        copy.danger ? 'border-danger/30 bg-danger-bg' : 'border-accent-line bg-accent-bg',
      )}
    >
      <input type="hidden" name="riderId" value={riderId} />
      <input type="hidden" name="decision" value={decision} />
      <p className="text-[13px] font-bold">{copy.confirm}</p>
      {copy.reason ? (
        <label className="mt-2 block">
          <span className="text-[13px] font-bold">{copy.reason}</span>
          <textarea
            name="reason"
            required
            minLength={3}
            maxLength={300}
            rows={2}
            autoFocus
            className={cx(INPUT, 'mt-1')}
          />
        </label>
      ) : null}
      <div className="mt-2 flex gap-2">
        <button
          type="submit"
          disabled={pending}
          className={cx(
            'min-h-10 rounded-xl px-4 text-[13px] font-extrabold disabled:opacity-60',
            copy.danger ? 'bg-danger text-white' : 'bg-brand text-on-brand',
          )}
        >
          {pending ? 'Envoi…' : `Confirmer`}
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="min-h-10 rounded-xl px-3 text-[13px] font-bold text-muted hover:text-text"
        >
          Retour
        </button>
      </div>
      <Feedback state={state} />
    </form>
  );
}

/** Seuil de retrait gratuit du livreur ; vide : seuil général. */
export function FreePayoutForm({
  riderId,
  custom,
  fallback,
}: {
  riderId: string;
  custom: number | null;
  fallback: number;
}) {
  const [state, action, pending] = useActionState(setFreePayout, IDLE);
  return (
    <form action={action} className="mt-3">
      <input type="hidden" name="riderId" value={riderId} />
      <label className="block">
        <span className="text-[13px] font-bold">Retrait gratuit à partir de (F)</span>
        <div className="mt-1 flex gap-2">
          <input
            name="freeFrom"
            inputMode="numeric"
            defaultValue={custom ?? ''}
            placeholder={`Seuil général : ${new Intl.NumberFormat('fr-FR').format(fallback)}`}
            className={cx(INPUT, 'flex-1')}
          />
          <button
            type="submit"
            disabled={pending}
            className="min-h-10 rounded-xl bg-text px-4 text-[13px] font-extrabold text-bg disabled:opacity-60"
          >
            {pending ? '…' : 'Enregistrer'}
          </button>
        </div>
      </label>
      <p className="mt-1 text-[12px] text-faint">Laissez vide pour revenir au seuil général.</p>
      <Feedback state={state} done="Seuil enregistré." />
    </form>
  );
}
