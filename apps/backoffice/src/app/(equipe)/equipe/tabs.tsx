import Link from 'next/link';
import { cx } from '@/components/ui';

const TABS = [
  { href: '/equipe', label: 'Membres' },
  { href: '/equipe/journal', label: 'Journal des actions' },
] as const;

/** En-tête commun des pages « Équipe et audit » (H8). */
export function TeamHeader({
  current,
  aside,
}: {
  current: (typeof TABS)[number]['href'];
  aside?: string;
}) {
  return (
    <header className="mb-6">
      <h1 className="font-display text-[28px] font-bold tracking-tight">Équipe et audit</h1>
      {aside ? <p className="text-muted">{aside}</p> : null}
      <nav aria-label="Équipe et audit" className="mt-4 flex flex-wrap gap-2">
        {TABS.map((tab) => (
          <Link
            key={tab.href}
            href={tab.href}
            aria-current={tab.href === current ? 'page' : undefined}
            className={cx(
              'min-h-10 rounded-xl px-4 py-2.5 text-[14px] font-bold transition',
              tab.href === current
                ? 'bg-accent-bg text-accent'
                : 'bg-panel text-muted hover:text-text',
            )}
          >
            {tab.label}
          </Link>
        ))}
      </nav>
    </header>
  );
}
