import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { requireStaff } from '@/lib/dal';
import { CATEGORY_LABELS, PRIORITY_LABELS, SUPPORT_ROLES } from '@/lib/support';
import { NewTicketForm } from '../ticket-actions';

export const metadata: Metadata = { title: 'Nouvelle demande' };

/** Demande ouverte pendant ou après un appel ; la fiche s'ouvre une fois enregistrée. */
export default async function NewTicketPage({
  searchParams,
}: {
  searchParams: Promise<{ telephone?: string; commande?: string }>;
}) {
  await requireStaff(SUPPORT_ROLES);
  const { telephone, commande } = await searchParams;
  return (
    <div className="mx-auto max-w-[760px]">
      <Link
        href="/support"
        className="inline-flex items-center gap-1 text-[14px] font-bold text-muted hover:text-text"
      >
        <Icon name="chevronLeft" size={16} />
        Support
      </Link>
      <h1 className="mt-2 mb-1 font-display text-[28px] font-bold tracking-tight">
        Nouvelle demande
      </h1>
      <p className="mb-6 text-muted">
        Notez l’appel pendant que la personne est au téléphone. La demande vous est confiée.
      </p>
      <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
        <NewTicketForm
          categories={Object.entries(CATEGORY_LABELS).map(([value, label]) => ({ value, label }))}
          priorities={Object.entries(PRIORITY_LABELS).map(([value, label]) => ({ value, label }))}
          phone={telephone}
          orderReference={commande}
        />
      </section>
    </div>
  );
}
