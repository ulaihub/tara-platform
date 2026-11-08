import type { IconName } from '@/components/icon';
import type { StaffRole } from './session';

export interface Section {
  href: string;
  label: string;
  icon: IconName;
  /** Exigence du cahier des charges. */
  requirement: string;
  description: string;
  roles: readonly StaffRole[];
  /** Écran disponible ; sinon annoncé « bientôt ». */
  ready: boolean;
}

const ALL: readonly StaffRole[] = ['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'];

/** Pilotage (carte en direct, commandes) : dispatch, support et administrateurs, comme l’API. */
export const OPS_ROLES: readonly StaffRole[] = ['ADMIN', 'DISPATCHER', 'SUPPORT'];

/** Sections du back-office, dans l'ordre du menu, avec les rôles qui y ont accès. */
export const SECTIONS: readonly Section[] = [
  {
    href: '/carte',
    label: 'Carte en direct',
    icon: 'map',
    requirement: 'H1',
    description:
      'Livreurs libres, en course ou hors ligne, commandes en cours, retards et alertes.',
    roles: OPS_ROLES,
    ready: true,
  },
  {
    href: '/commandes',
    label: 'Commandes',
    icon: 'package',
    requirement: 'H2',
    description: 'Recherche, détail et historique, réattribution, annulation, notes internes.',
    roles: OPS_ROLES,
    ready: true,
  },
  {
    href: '/livreurs',
    label: 'Livreurs',
    icon: 'moto',
    requirement: 'H3',
    description: 'Validation des pièces et entretien, suspension, historique de fiabilité.',
    roles: ['ADMIN', 'DISPATCHER'],
    ready: false,
  },
  {
    href: '/support',
    label: 'Support',
    icon: 'headset',
    requirement: 'H6',
    description: 'Tickets liés aux commandes, litiges avec preuves, alertes SOS.',
    roles: ['ADMIN', 'SUPPORT'],
    ready: false,
  },
  {
    href: '/finance',
    label: 'Finance',
    icon: 'wallet',
    requirement: 'H5',
    description: 'Rapprochement du jour, reversements à valider, export comptable.',
    roles: ['ADMIN', 'FINANCE'],
    ready: false,
  },
  {
    href: '/marchands',
    label: 'Marchands et tarifs',
    icon: 'store',
    requirement: 'H4',
    description: 'Boutiques, grille tarifaire et suppléments, zones, codes promo.',
    roles: ['ADMIN'],
    ready: false,
  },
  {
    href: '/indicateurs',
    label: 'Indicateurs',
    icon: 'chart',
    requirement: 'H7',
    description: 'Livraisons par jour, réussite, délais, reversements, notes des livreurs.',
    roles: ALL,
    ready: false,
  },
  {
    href: '/equipe',
    label: 'Équipe et audit',
    icon: 'users',
    requirement: 'H8',
    description: 'Membres de l’équipe et leurs rôles, journal des actions sensibles.',
    roles: ['ADMIN'],
    ready: false,
  },
];

export function sectionsFor(roles: readonly string[]): Section[] {
  return SECTIONS.filter((section) => section.roles.some((role) => roles.includes(role)));
}

export const ROLE_LABELS: Record<StaffRole, string> = {
  ADMIN: 'Administrateur',
  DISPATCHER: 'Dispatch',
  SUPPORT: 'Support',
  FINANCE: 'Finance',
};
