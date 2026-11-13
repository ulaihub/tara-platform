import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Icon } from '@/components/icon';
import { Badge, Card } from '@/components/ui';
import { requireStaff } from '@/lib/dal';
import { SECTIONS } from '@/lib/navigation';

const find = (slug: string) => SECTIONS.find((section) => section.href === `/${slug}`);

export async function generateMetadata({
  params,
}: {
  params: Promise<{ section: string }>;
}): Promise<Metadata> {
  return { title: find((await params).section)?.label ?? 'Page introuvable' };
}

/**
 * Section annoncée mais pas encore construite. Chaque écran livré a sa propre page, qui
 * passe avant celle-ci ; le rôle est vérifié comme sur un vrai écran.
 */
export default async function UpcomingSection({
  params,
}: {
  params: Promise<{ section: string }>;
}) {
  const section = find((await params).section);
  if (!section) notFound();
  await requireStaff(section.roles);
  return (
    <div className="mx-auto max-w-[760px]">
      <header className="mb-6 flex items-center gap-4">
        <span className="grid size-12 place-items-center rounded-2xl bg-accent-bg text-accent">
          <Icon name={section.icon} size={24} />
        </span>
        <div>
          <h1 className="font-display text-[28px] font-bold tracking-tight">{section.label}</h1>
          <p className="text-muted">{section.description}</p>
        </div>
      </header>
      <Card>
        <Badge>Bientôt · {section.requirement}</Badge>
        <p className="mt-3 text-[15px]">
          Cet écran est en préparation. Il apparaîtra ici dès qu’il sera prêt.
        </p>
        <Link
          href="/"
          className="mt-4 inline-flex min-h-10 items-center gap-2 text-[14px] font-bold text-accent hover:underline"
        >
          <Icon name="chevronLeft" size={16} />
          Retour à l’accueil
        </Link>
      </Card>
    </div>
  );
}
