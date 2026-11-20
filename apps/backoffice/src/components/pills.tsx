import Link from 'next/link';
import { cx } from './ui';

export interface Pill {
  href: string;
  label: string;
  active: boolean;
  /** Nombre affiché après le libellé ; `alert` le met en avant (à traiter). */
  count?: number;
  alert?: boolean;
}

/** Vues d'une liste (maquettes BO) : pastilles de verre, la vue ouverte en dégradé. */
export function Pills({ label, items }: { label: string; items: Pill[] }) {
  return (
    <nav aria-label={label} className="mb-3 flex flex-wrap items-center gap-2">
      {items.map((item) => (
        <Link
          key={item.href + item.label}
          href={item.href}
          aria-current={item.active ? 'page' : undefined}
          className={cx(
            'flex min-h-[34px] items-center gap-1.5 rounded-xl px-3 text-[13px] font-extrabold transition',
            item.active
              ? 'bg-brand text-on-brand shadow-[0_8px_18px_rgba(255,90,0,.22)]'
              : 'bo-glass text-text hover:brightness-105',
          )}
        >
          {item.label}
          {item.count === undefined ? null : (
            <span
              className={cx(
                'tabular-nums',
                !item.active &&
                  item.alert &&
                  item.count > 0 &&
                  'rounded-md bg-warn-bg px-1.5 text-warn',
              )}
            >
              · {item.count}
            </span>
          )}
        </Link>
      ))}
    </nav>
  );
}

/** Cellule des tableaux aux lignes arrondies (maquettes BO-Commandes, BO-Livreurs…). */
export const ROW_CELL = 'bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]';
export const ROW_TABLE = 'w-full border-separate border-spacing-y-1.5 text-left text-[13px]';
export const ROW_HEAD = 'text-[11px] font-extrabold tracking-[.06em] text-faint uppercase';
