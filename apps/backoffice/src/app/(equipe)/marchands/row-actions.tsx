'use client';

import { useActionState } from 'react';
import { cx } from '@/components/ui';
import { type ActionState, createPromo, togglePromo, toggleZone } from './actions';

const IDLE: ActionState = { error: null, done: false };

const INPUT =
  'block w-full rounded-xl border border-line bg-panel px-3 py-2 text-[14px] focus:border-accent-line focus:outline-none';

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

/** Interrupteur actif / coupé d'un code promo ou d'une zone. */
function Toggle({
  action,
  name,
  id,
  active,
  labels,
}: {
  action: (state: ActionState, form: FormData) => Promise<ActionState>;
  name: string;
  id: string;
  active: boolean;
  labels: [string, string];
}) {
  const [state, run, pending] = useActionState(action, IDLE);
  return (
    <form action={run} className="flex flex-col items-end">
      <input type="hidden" name={name} value={id} />
      <input type="hidden" name="active" value={active ? 'false' : 'true'} />
      <button
        type="submit"
        disabled={pending}
        aria-pressed={active}
        className={cx(
          'min-h-9 min-w-[96px] rounded-xl px-3 text-[13px] font-extrabold disabled:opacity-60',
          active ? 'bg-ok-bg text-ok' : 'bg-track text-muted',
        )}
      >
        {active ? labels[0] : labels[1]}
      </button>
      <Feedback state={state} />
    </form>
  );
}

export function PromoToggle({ id, active }: { id: string; active: boolean }) {
  return (
    <Toggle
      action={togglePromo}
      name="promoId"
      id={id}
      active={active}
      labels={['Actif', 'En pause']}
    />
  );
}

export function ZoneToggle({ id, active }: { id: string; active: boolean }) {
  return (
    <Toggle
      action={toggleZone}
      name="zoneId"
      id={id}
      active={active}
      labels={['Active', 'Coupée']}
    />
  );
}

/** Nouveau code promo : code, type, valeur, durée, nombre d'utilisations. */
export function PromoForm() {
  const [state, action, pending] = useActionState(createPromo, IDLE);
  return (
    <form action={action} className="grid gap-3 md:grid-cols-[1fr_1fr_120px_120px_140px]">
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Code</span>
        <input
          name="code"
          required
          placeholder="BIENVENUE"
          className={cx(INPUT, 'mt-1 uppercase')}
        />
      </label>
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Remise</span>
        <select name="kind" defaultValue="FIXED_AMOUNT" className={cx(INPUT, 'mt-1')}>
          <option value="FIXED_AMOUNT">Montant déduit (F)</option>
          <option value="PERCENT">Pourcentage (%)</option>
          <option value="FIXED_PRICE">Prix fixe de la course (F)</option>
        </select>
      </label>
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Valeur</span>
        <input
          name="value"
          required
          inputMode="decimal"
          placeholder="500"
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Durée (jours)</span>
        <input name="days" inputMode="numeric" placeholder="30" className={cx(INPUT, 'mt-1')} />
      </label>
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Utilisations max.</span>
        <input
          name="maxRedemptions"
          inputMode="numeric"
          placeholder="Illimité"
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <label className="flex items-center gap-2 text-[14px] md:col-span-3">
        <input
          type="checkbox"
          name="newCustomersOnly"
          className="size-4 accent-[var(--color-accent)]"
        />
        Réservé aux nouveaux clients (première commande)
      </label>
      <div className="flex items-center justify-end md:col-span-2">
        <button
          type="submit"
          disabled={pending}
          className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
        >
          {pending ? 'Création…' : 'Créer le code'}
        </button>
      </div>
      <div className="md:col-span-5">
        <Feedback state={state} done="Code créé : utilisable tout de suite dans l’app." />
      </div>
    </form>
  );
}
