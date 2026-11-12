import { describe, expect, it } from 'vitest';
import { actionLabel, entityLabel, preview } from '../src/lib/team';

describe('Équipe et audit (H8)', () => {
  it('dit les actions du journal en mots simples, sinon garde le code', () => {
    expect(actionLabel('payout.approved')).toBe('Reversement validé');
    expect(actionLabel('nouvelle.action')).toBe('nouvelle.action');
    expect(entityLabel('order')).toBe('Commandes');
  });

  it('résume le détail avant / après', () => {
    expect(preview(null)).toBe('—');
    expect(preview({ roles: ['SUPPORT'] })).toBe('{ "roles": [ "SUPPORT" ] }');
    expect(preview({ text: 'x'.repeat(600) }).endsWith('…')).toBe(true);
  });
});
