'use client';

import { type MouseEvent, type ReactNode, useEffect, useState } from 'react';
import { Icon } from './icon';
import { Logo } from './ui';

/**
 * Téléphone et tablette : barre du haut (logo, bouton menu) et menu en tiroir, qui reprend
 * les sections et le membre connecté. Sur grand écran, le menu latéral prend le relais.
 */
export function MobileNav({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = overflow;
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  // Un lien touché dans le tiroir ouvre sa page : le tiroir se referme.
  const closeOnLink = (event: MouseEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest('a')) setOpen(false);
  };

  return (
    <>
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-line bg-panel-soft/95 px-4 py-2.5 backdrop-blur lg:hidden">
        <Logo className="h-[34px]" />
        <button
          type="button"
          aria-label="Ouvrir le menu"
          aria-expanded={open}
          aria-controls="menu-equipe"
          onClick={() => setOpen(true)}
          className="flex size-11 items-center justify-center rounded-2xl border border-line bg-panel text-text"
        >
          <Icon name="menu" size={20} />
        </button>
      </header>
      {open ? (
        <div
          className="fixed inset-0 z-40 lg:hidden"
          role="dialog"
          aria-modal="true"
          aria-label="Menu"
        >
          <button
            type="button"
            aria-label="Fermer le menu"
            className="absolute inset-0 bg-black/45"
            onClick={() => setOpen(false)}
          />
          <div
            id="menu-equipe"
            className="absolute inset-y-0 left-0 flex w-[min(300px,85vw)] flex-col overflow-y-auto bg-panel-soft px-4 py-4 shadow-xl"
            onClick={closeOnLink}
          >
            <div className="mb-5 flex items-center justify-between pl-2">
              <Logo className="h-[36px]" />
              <button
                type="button"
                aria-label="Fermer le menu"
                onClick={() => setOpen(false)}
                className="flex size-11 items-center justify-center rounded-2xl text-muted hover:text-text"
              >
                <Icon name="close" size={20} />
              </button>
            </div>
            {children}
          </div>
        </div>
      ) : null}
    </>
  );
}
