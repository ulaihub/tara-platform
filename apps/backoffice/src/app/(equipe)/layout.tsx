import type { ReactNode } from 'react';
import { Icon } from '@/components/icon';
import { MobileNav } from '@/components/mobile-nav';
import { NavLinks } from '@/components/nav-links';
import { Logo } from '@/components/ui';
import { logout } from '@/app/connexion/actions';
import { requireStaff } from '@/lib/dal';
import { ROLE_LABELS, sectionsFor } from '@/lib/navigation';
import { displayPhone } from '@/lib/phone';
import { staffRoles } from '@/lib/session';

/**
 * Cadre du back-office : logo et menu à gauche, membre connecté et déconnexion en bas ; sur
 * téléphone, barre du haut et menu en tiroir.
 */
export default async function TeamLayout({ children }: { children: ReactNode }) {
  const session = await requireStaff();
  const sections = sectionsFor(session.roles).map(({ href, label, icon, ready }) => ({
    href,
    label,
    icon,
    ready,
  }));
  const roles = staffRoles(session.roles).map((role) => ROLE_LABELS[role]);
  const member = (
    <div className="mt-4 rounded-2xl border border-line bg-panel p-3">
      <p className="truncate text-[14px] font-extrabold">
        {session.name ?? displayPhone(session.phone)}
      </p>
      <p className="truncate text-[12px] text-faint">{roles.join(' · ')}</p>
      <form action={logout} className="mt-2">
        <button
          type="submit"
          className="flex min-h-9 items-center gap-2 text-[13px] font-bold text-muted hover:text-danger"
        >
          <Icon name="logout" size={16} />
          Se déconnecter
        </button>
      </form>
    </div>
  );
  return (
    <div className="min-h-screen lg:flex">
      <MobileNav>
        <nav aria-label="Sections du back-office" className="flex-1">
          <NavLinks sections={sections} />
        </nav>
        {member}
      </MobileNav>
      <aside className="sticky top-0 hidden h-screen w-[280px] shrink-0 flex-col border-r border-line bg-panel-soft px-4 py-6 lg:flex">
        <div className="mb-8 px-2">
          <Logo className="h-[42px]" />
        </div>
        <nav aria-label="Sections du back-office" className="flex-1 overflow-y-auto">
          <NavLinks sections={sections} />
        </nav>
        {member}
      </aside>
      <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-10 lg:py-8">{children}</main>
    </div>
  );
}
