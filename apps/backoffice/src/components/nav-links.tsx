'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { Section } from '@/lib/navigation';
import { Icon } from './icon';
import { cx } from './ui';

/** Menu latéral : section en cours mise en avant, sections à venir signalées. */
export function NavLinks({
  sections,
}: {
  sections: Pick<Section, 'href' | 'label' | 'icon' | 'ready'>[];
}) {
  const path = usePathname();
  const items = [{ href: '/', label: 'Accueil', icon: 'home' as const, ready: true }, ...sections];
  return (
    <ul className="space-y-1">
      {items.map((item) => {
        const active = item.href === '/' ? path === '/' : path.startsWith(item.href);
        return (
          <li key={item.href}>
            <Link
              href={item.href}
              aria-current={active ? 'page' : undefined}
              className={cx(
                'flex min-h-[42px] items-center gap-3 rounded-[13px] px-3 text-[14px] transition',
                active
                  ? 'bg-brand font-extrabold text-on-brand shadow-[0_8px_18px_rgba(255,90,0,.28)]'
                  : 'font-semibold text-muted hover:bg-glass hover:text-text',
              )}
            >
              <Icon name={item.icon} size={19} />
              <span className="flex-1">{item.label}</span>
              {item.ready ? null : (
                <span
                  className={cx(
                    'text-[11px] font-extrabold',
                    active ? 'text-on-brand/70' : 'text-faint',
                  )}
                >
                  bientôt
                </span>
              )}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
