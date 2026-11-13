import { describe, expect, it } from 'vitest';
import { SECTIONS, sectionsFor } from '@/lib/navigation';

const hrefs = (roles: string[]) => sectionsFor(roles).map((section) => section.href);

describe('menu selon le rôle', () => {
  it('ouvre tout à l’administrateur', () => {
    expect(hrefs(['ADMIN'])).toEqual(SECTIONS.map((section) => section.href));
  });

  it('limite chaque rôle à son travail', () => {
    expect(hrefs(['DISPATCHER'])).toEqual(['/carte', '/commandes', '/livreurs', '/indicateurs']);
    expect(hrefs(['SUPPORT'])).toEqual(['/carte', '/commandes', '/support', '/indicateurs']);
    expect(hrefs(['FINANCE'])).toEqual(['/finance', '/indicateurs']);
  });

  it('cumule les rôles sans doublon', () => {
    expect(hrefs(['FINANCE', 'SUPPORT'])).toEqual([
      '/carte',
      '/commandes',
      '/support',
      '/finance',
      '/indicateurs',
    ]);
  });

  it('n’ouvre rien hors de l’équipe', () => {
    expect(hrefs(['CUSTOMER', 'RIDER'])).toEqual([]);
  });

  it('suit les exigences H1 à H8 une fois chacune', () => {
    expect(SECTIONS.map((section) => section.requirement).toSorted()).toEqual([
      'H1',
      'H2',
      'H3',
      'H4',
      'H5',
      'H6',
      'H7',
      'H8',
    ]);
  });
});
