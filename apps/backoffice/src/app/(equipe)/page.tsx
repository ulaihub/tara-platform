import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { Badge, Note } from '@/components/ui';
import { requireStaff } from '@/lib/dal';
import { greeting, longDate } from '@/lib/douala';
import { sectionsFor } from '@/lib/navigation';

export const metadata: Metadata = { title: 'Accueil' };

/** Accueil : salutation, sections accessibles à ce membre de l'équipe. */
export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ acces?: string }>;
}) {
  const session = await requireStaff();
  const { acces } = await searchParams;
  const now = new Date();
  const firstName = session.name?.split(/\s+/)[0];
  return (
    <div className="mx-auto max-w-[1180px]">
      <header className="mb-8">
        <p className="text-[14px] font-bold text-accent first-letter:uppercase">
          {longDate.format(now)}
        </p>
        <h1 className="mt-1 font-display text-[32px] font-bold tracking-tight">
          {greeting(now)}
          {firstName ? ` ${firstName}` : ''} 👋
        </h1>
        <p className="mt-1 text-muted">Voici les outils de l’équipe auxquels vous avez accès.</p>
      </header>
      {acces === 'refuse' ? (
        <div className="mb-6">
          <Note tone="warn">Cette page est réservée à d’autres rôles de l’équipe.</Note>
        </div>
      ) : null}
      <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {sectionsFor(session.roles).map((section) => (
          <li key={section.href}>
            <Link
              href={section.href}
              className="group flex h-full flex-col rounded-3xl border border-line bg-panel p-5 shadow-card transition hover:-translate-y-0.5 hover:border-accent-line"
            >
              <div className="mb-4 flex items-center justify-between">
                <span className="grid size-11 place-items-center rounded-2xl bg-accent-bg text-accent">
                  <Icon name={section.icon} size={22} />
                </span>
                {section.ready ? (
                  <Badge tone="ok">Disponible</Badge>
                ) : (
                  <Badge>Bientôt · {section.requirement}</Badge>
                )}
              </div>
              <h2 className="font-display text-[18px] font-bold">{section.label}</h2>
              <p className="mt-1 text-[14px] text-muted">{section.description}</p>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
