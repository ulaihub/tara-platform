import { SectionHeader } from '@/components/section-header';

const TABS = [
  {
    href: '/equipe',
    label: 'Membres',
    title: 'Équipe et journal',
    subtitle: 'Rôles, sécurité, traçabilité',
  },
  {
    href: '/equipe/journal',
    label: 'Journal des actions',
    title: 'Journal des actions',
    subtitle: 'Chaque action de l’équipe : qui, quoi, quand',
  },
] as const;

/** En-tête commun des pages « Équipe et journal » (H8, maquette BO-Equipe). */
export function TeamHeader({
  current,
  aside,
}: {
  current: (typeof TABS)[number]['href'];
  aside?: string;
}) {
  return <SectionHeader tabs={TABS} current={current} label="Équipe et journal" aside={aside} />;
}
