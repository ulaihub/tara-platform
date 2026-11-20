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
  const name = session.name ?? displayPhone(session.phone);
  const member = (
    <div className="bo-glass mt-auto flex items-center gap-2.5 rounded-2xl p-2.5">
      <span
        aria-hidden="true"
        className="grid size-9 shrink-0 place-items-center rounded-full bg-brand font-display text-[13px] font-extrabold text-on-brand"
      >
        {initials(name)}
      </span>
      <span className="min-w-0 flex-1">
        <b className="block truncate text-[13px]">{name}</b>
        <span className="block truncate text-[11px] text-muted">{roles.join(' · ')} · 2FA ✓</span>
      </span>
      <form action={logout}>
        <button
          type="submit"
          aria-label="Se déconnecter"
          title="Se déconnecter"
          className="grid size-9 place-items-center rounded-xl text-muted hover:bg-danger-bg hover:text-danger"
        >
          <Icon name="logout" size={16} />
        </button>
      </form>
    </div>
  );
  return (
    <div className="relative min-h-screen lg:flex">
      <div className="bo-blobs" aria-hidden="true">
        <i />
        <i />
      </div>
      <MobileNav>
        <nav aria-label="Sections du back-office" className="flex-1">
          <NavLinks sections={sections} />
        </nav>
        {member}
      </MobileNav>
      <aside className="bo-side sticky top-0 z-10 hidden h-screen w-[248px] shrink-0 flex-col gap-1 border-r border-line px-3.5 py-5 lg:flex">
        <div className="flex items-center gap-2.5 px-1.5 pb-[18px]">
          <span className="flex rounded-xl bg-[#16120E] px-2 py-1.5">
            <Logo className="h-7 w-10 object-contain" dark />
          </span>
          <span>
            <b className="block text-[15px]">Tara</b>
            <span className="block text-[11px] text-muted">Espace équipe</span>
          </span>
        </div>
        <nav aria-label="Sections du back-office" className="flex-1 overflow-y-auto">
          <NavLinks sections={sections} />
        </nav>
        {member}
      </aside>
      <main className="relative z-[1] min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-7 lg:py-8">
        {children}
      </main>
    </div>
  );
}

/** « Awa Mbappé » → « AM ». */
function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  return ((parts[0]?.[0] ?? '') + (parts[1]?.[0] ?? '')).toUpperCase() || 'T';
}
