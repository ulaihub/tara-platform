import { describe, expect, it } from 'vitest';
import { orderPermissions, orderView, statusLabel } from '@/lib/orders';

describe('commandes au back-office', () => {
  it('ne laisse annuler ou réattribuer que le dispatch et les administrateurs', () => {
    const open = { can: { cancel: true, reassign: true } };
    expect(orderPermissions(['SUPPORT'], open)).toEqual({ cancel: false, reassign: false });
    expect(orderPermissions(['DISPATCHER'], open)).toEqual({ cancel: true, reassign: true });
    expect(orderPermissions(['ADMIN'], { can: { cancel: false, reassign: false } })).toEqual({
      cancel: false,
      reassign: false,
    });
  });

  it('distingue une commande programmée d’une commande en attente', () => {
    expect(statusLabel('CREATED', '2026-11-09T08:00:00Z')).toBe('Programmée');
    expect(statusLabel('CREATED', null)).toBe('En attente de départ');
    expect(statusLabel('DELIVERED', null)).toBe('Livrée');
  });

  it('revient à « toutes » pour une vue inconnue', () => {
    expect(orderView('problems')).toBe('problems');
    expect(orderView('nimporte')).toBe('all');
    expect(orderView(undefined)).toBe('all');
  });
});
