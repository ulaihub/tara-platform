'use client';

import { Icon } from '@/components/icon';

/** Écran de l'équipe en erreur (API injoignable, réponse inattendue) : on peut réessayer. */
export default function TeamError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="mx-auto mt-16 max-w-md text-center">
      <span className="mx-auto mb-4 grid size-14 place-items-center rounded-2xl bg-danger-bg text-danger">
        <Icon name="alertCircle" size={28} />
      </span>
      <h1 className="font-display text-[24px] font-bold">Cet écran ne répond pas</h1>
      <p className="mt-2 text-muted">
        Le serveur Tara n’a pas pu fournir les données. Réessayez dans un instant ; si cela dure,
        prévenez l’équipe technique.
      </p>
      <button
        type="button"
        onClick={reset}
        className="mt-6 inline-flex min-h-11 items-center gap-2 rounded-2xl bg-brand px-5 font-bold text-on-brand"
      >
        <Icon name="refresh" size={18} />
        Réessayer
      </button>
    </div>
  );
}
