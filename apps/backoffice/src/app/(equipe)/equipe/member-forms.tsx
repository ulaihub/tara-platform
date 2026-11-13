'use client';

import { useActionState, useState } from 'react';
import { cx } from '@/components/ui';
import { ROLE_LABELS } from '@/lib/navigation';
import { ROLE_HINTS } from '@/lib/team';
import { type ActionState, addMember, removeMember, resetMfa, saveRoles } from './actions';

const IDLE: ActionState = { error: null, done: false };
const ROLES = ['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'] as const;
const INPUT =
  'block h-10 w-full rounded-xl border border-line bg-panel px-3 text-[14px] focus:border-accent-line focus:outline-none';

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

function RoleChoices({ selected }: { selected: readonly string[] }) {
  return (
    <div className="grid gap-2 sm:grid-cols-2">
      {ROLES.map((role) => (
        <label
          key={role}
          className="flex cursor-pointer items-start gap-2 rounded-xl border border-line px-3 py-2 has-[:checked]:border-accent-line has-[:checked]:bg-accent-bg"
        >
          <input
            type="checkbox"
            name="roles"
            value={role}
            defaultChecked={selected.includes(role)}
            className="mt-1 size-4"
          />
          <span>
            <span className="block text-[14px] font-bold">{ROLE_LABELS[role]}</span>
            <span className="block text-[12px] text-muted">{ROLE_HINTS[role]}</span>
          </span>
        </label>
      ))}
    </div>
  );
}

/** Ajouter un membre : numéro, nom, rôles. Il se connecte ensuite avec son numéro. */
export function AddMemberForm() {
  const [state, action, pending] = useActionState(addMember, IDLE);
  return (
    <form action={action} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block">
          <span className="text-[12px] font-bold text-muted">Nom</span>
          <input
            name="fullName"
            required
            placeholder="Nadège Ekwalla"
            className={cx(INPUT, 'mt-1')}
          />
        </label>
        <label className="block">
          <span className="text-[12px] font-bold text-muted">Téléphone</span>
          <input
            name="phone"
            required
            inputMode="tel"
            placeholder="6XX XX XX XX"
            className={cx(INPUT, 'mt-1')}
          />
        </label>
      </div>
      <RoleChoices selected={['SUPPORT']} />
      <button
        type="submit"
        disabled={pending}
        className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
      >
        {pending ? 'Ajout…' : 'Ajouter à l’équipe'}
      </button>
      <Feedback
        state={state}
        done="Ajouté : la personne se connecte avec son numéro et configure sa double authentification."
      />
    </form>
  );
}

/** Rôles d'un membre, retrait de l'accès, remise à zéro de la double authentification. */
export function MemberActions({
  userId,
  roles,
  self,
}: {
  userId: string;
  roles: readonly string[];
  self: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [confirming, setConfirming] = useState<'remove' | 'mfa' | null>(null);
  const [rolesState, save, saving] = useActionState(saveRoles, IDLE);
  const [removeState, remove, removing] = useActionState(removeMember, IDLE);
  const [mfaState, reset, resetting] = useActionState(resetMfa, IDLE);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="min-h-9 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
      >
        Gérer
      </button>
    );
  }
  return (
    <div className="mt-3 w-full space-y-3 rounded-2xl border border-accent-line bg-panel-soft p-4">
      <form action={save} className="space-y-3">
        <input type="hidden" name="userId" value={userId} />
        <RoleChoices selected={roles} />
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="submit"
            disabled={saving}
            className="min-h-9 rounded-xl bg-brand px-3 text-[13px] font-extrabold text-on-brand disabled:opacity-60"
          >
            {saving ? 'Enregistrement…' : 'Enregistrer les rôles'}
          </button>
          <button
            type="button"
            onClick={() => setOpen(false)}
            className="min-h-9 rounded-xl px-2 text-[13px] font-bold text-muted hover:text-text"
          >
            Fermer
          </button>
        </div>
        <Feedback state={rolesState} done="Rôles enregistrés ; ses sessions sont fermées." />
      </form>
      <div className="flex flex-wrap items-center gap-2 border-t border-line pt-3">
        {confirming === 'mfa' ? (
          <form action={reset} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="userId" value={userId} />
            <span className="text-[13px] font-bold">
              Remettre à zéro sa double authentification ?
            </span>
            <button
              type="submit"
              disabled={resetting}
              className="min-h-9 rounded-xl bg-warn px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
            >
              Confirmer
            </button>
          </form>
        ) : (
          <button
            type="button"
            onClick={() => setConfirming('mfa')}
            className="min-h-9 rounded-xl border border-line px-3 text-[13px] font-bold hover:border-accent-line"
          >
            Téléphone perdu : refaire la double authentification
          </button>
        )}
        {self ? null : confirming === 'remove' ? (
          <form action={remove} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="userId" value={userId} />
            <span className="text-[13px] font-bold">Retirer son accès au back-office ?</span>
            <button
              type="submit"
              disabled={removing}
              className="min-h-9 rounded-xl bg-danger px-3 text-[13px] font-extrabold text-white disabled:opacity-60"
            >
              Retirer
            </button>
          </form>
        ) : (
          <button
            type="button"
            onClick={() => setConfirming('remove')}
            className="min-h-9 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg"
          >
            Retirer l’accès
          </button>
        )}
      </div>
      <Feedback
        state={mfaState}
        done="Fait : à sa prochaine connexion, il configure un nouveau téléphone."
      />
      <Feedback state={removeState} done="Accès retiré." />
    </div>
  );
}
