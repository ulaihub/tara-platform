import { SectionHeader } from '@/components/section-header';

const TABS = [
  {
    href: '/finance',
    label: 'Vue d’ensemble',
    title: 'Finance',
    subtitle: 'Vue d’ensemble et reversements',
  },
  {
    href: '/finance/reversements',
    label: 'Reversements',
    title: 'Reversements',
    subtitle: 'À valider, envoyés, en échec',
  },
  {
    href: '/finance/controle',
    label: 'Contrôle des comptes',
    title: 'Contrôle des comptes',
    subtitle: 'Grand livre, prestataire, espèces, écarts',
  },
] as const;

/** En-tête commun des pages de la finance (H5, maquettes BO-Finance et BO-Controle). */
export function FinanceHeader({
  current,
  aside,
}: {
  current: (typeof TABS)[number]['href'];
  aside?: string;
}) {
  return <SectionHeader tabs={TABS} current={current} label="Finance" aside={aside} />;
}
