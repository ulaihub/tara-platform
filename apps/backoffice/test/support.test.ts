import { describe, expect, it } from 'vitest';
import { callDuration, mapLink, statusActions, ticketView } from '@/lib/support';

describe('service client au back-office', () => {
  it('ouvre « à traiter » par défaut et lit la vue dans l’adresse', () => {
    expect(ticketView(undefined)).toBe('TO_HANDLE');
    expect(ticketView('mine')).toBe('MINE');
    expect(ticketView('to-handle')).toBe('TO_HANDLE');
    expect(ticketView('nimporte')).toBe('TO_HANDLE');
  });

  it('dit si le destinataire a décroché, et combien de temps', () => {
    expect(callDuration(0)).toBe('pas de réponse');
    expect(callDuration(42)).toBe('42 s');
    expect(callDuration(125)).toBe('2 min 05');
  });

  it('propose les bons changements de statut', () => {
    expect(statusActions('IN_PROGRESS').map((a) => a.status)).toEqual(['RESOLVED', 'CLOSED']);
    expect(statusActions('RESOLVED').map((a) => a.status)).toEqual(['CLOSED', 'IN_PROGRESS']);
    expect(statusActions('CLOSED').map((a) => a.status)).toEqual(['IN_PROGRESS']);
  });

  it('pointe la position d’une preuve sur la carte', () => {
    expect(mapLink(4.05, 9.7)).toBe(
      'https://www.openstreetmap.org/?mlat=4.05&mlon=9.7#map=18/4.05/9.7',
    );
  });
});
