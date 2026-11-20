import Link from 'next/link';
import { Icon } from './icon';

/**
 * Barre du haut des pages (maquettes BO) : titre et sous-titre à gauche, recherche d'une
 * commande (téléphone, référence, livreur) et cloche des alertes à droite.
 */
export function TopBar({
  title,
  subtitle,
  alerts,
}: {
  title: string;
  subtitle: string;
  /** Alertes en cours sur la carte ; absent : pas de pastille. */
  alerts?: number;
}) {
  return (
    <header className="-mx-4 -mt-5 mb-5 flex min-h-[76px] flex-wrap items-center gap-4 border-b border-line px-4 py-3 sm:-mx-6 sm:px-6 lg:-mx-7 lg:-mt-8 lg:px-7">
      <div className="min-w-0 flex-1">
        <h1 className="font-display text-[22px] font-bold tracking-[-0.01em]">{title}</h1>
        <p className="text-[12px] text-muted first-letter:uppercase">{subtitle}</p>
      </div>
      <div className="flex w-full items-center gap-2.5 sm:w-auto">
        <form
          action="/commandes"
          role="search"
          className="min-w-0 flex-1 sm:w-[320px] sm:flex-none"
        >
          <label className="flex h-[42px] items-center gap-2 rounded-[14px] border border-glass-line bg-glass px-3.5 text-[13px] text-faint shadow-glass">
            <Icon name="search" size={16} />
            <span className="sr-only">Rechercher une commande</span>
            <input
              name="q"
              type="search"
              placeholder="Commande, téléphone, livreur…"
              className="min-w-0 flex-1 bg-transparent text-text outline-none placeholder:text-faint"
            />
          </label>
        </form>
        <Link
          href="/carte"
          aria-label={alerts ? `Alertes : ${alerts}` : 'Alertes de la carte'}
          className="relative grid size-[42px] shrink-0 place-items-center rounded-[14px] border border-glass-line bg-glass shadow-glass"
        >
          <Icon name="bell" size={18} />
          {alerts ? (
            <span className="absolute -top-1 -right-1 grid h-[18px] min-w-[18px] place-items-center rounded-full bg-[#F01E2C] px-1 text-[10px] font-extrabold text-white">
              {alerts}
            </span>
          ) : null}
        </Link>
      </div>
    </header>
  );
}
