'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import {
  type ActionState,
  decideRider,
  recordInterview,
  reviewDocument,
  setFreePayout,
} from '../actions';

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

/** Compte rendu de l'entretien au bureau ; le champ se vide une fois enregistré. */
export function InterviewForm({ riderId, again }: { riderId: string; again: boolean }) {
  const [open, setOpen] = useState(!again);
  const [state, action, pending] = useActionState(recordInterview, IDLE);
  const form = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (state.done) {
      form.current?.reset();
      setOpen(false);
    }
  }, [state]);
  if (!open) {
    return (
      <>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="mt-3 min-h-10 w-full rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
        >
          Enregistrer un nouvel entretien
        </button>
        <Feedback state={state} done="Entretien enregistré." />
      </>
    );
  }
  return (
    <form ref={form} action={action} className="mt-3 space-y-3">
      <input type="hidden" name="riderId" value={riderId} />
      <fieldset className="flex gap-2">
        <legend className="mb-1 text-[13px] font-bold">Résultat</legend>
        {[
          { value: 'passed', label: 'Réussi', tone: 'peer-checked:bg-ok peer-checked:text-white' },
          {
            value: 'failed',
            label: 'Échoué',
            tone: 'peer-checked:bg-danger peer-checked:text-white',
          },
        ].map((option) => (
          <label key={option.value} className="flex-1">
            <input
              type="radio"
              name="result"
              value={option.value}
              required
              className="peer sr-only"
            />
            <span
              className={cx(
                'flex min-h-10 cursor-pointer items-center justify-center rounded-xl border border-line text-[13px] font-extrabold peer-focus-visible:ring-2',
                option.tone,
              )}
            >
              {option.label}
            </span>
          </label>
        ))}
      </fieldset>
      <label className="block">
        <span className="text-[13px] font-bold">Compte rendu</span>
        <textarea
          name="note"
          required
          minLength={3}
          maxLength={500}
          rows={3}
          placeholder="Ex. : connaît bien Douala, moto en bon état, comprend les règles d’encaissement."
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="min-h-10 w-full rounded-xl bg-text px-4 text-[13px] font-extrabold text-bg disabled:opacity-60"
      >
        {pending ? 'Enregistrement…' : 'Enregistrer l’entretien'}
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
