import { describe, expect, it } from 'vitest';
import { seal, unseal } from '@/lib/seal';
import { type Session, needsRefresh, openSession, sealSession, staffRoles } from '@/lib/session';

const SECRET = 'un-secret-de-test-assez-long-pour-aes-256';
const OTHER = 'un-autre-secret-de-test-assez-long-aussi';

describe('cookie scellé', () => {
  it('se relit avec la même clé', () => {
    const token = seal({ phone: '+237677123456', n: 1 }, SECRET, 60);
    expect(unseal(token, SECRET)).toEqual({ phone: '+237677123456', n: 1 });
  });

  it('ne laisse rien lire en clair', () => {
    const token = seal({ phone: '+237677123456' }, SECRET, 60);
    expect(Buffer.from(token, 'base64url').toString('latin1')).not.toContain('677123456');
  });

  it('est ignoré avec une autre clé, abîmé ou vide', () => {
    const token = seal({ ok: true }, SECRET, 60);
    expect(unseal(token, OTHER)).toBeNull();
    const raw = Buffer.from(token, 'base64url');
    raw[raw.length - 1] = (raw[raw.length - 1] ?? 0) ^ 1;
    expect(unseal(raw.toString('base64url'), SECRET)).toBeNull();
    expect(unseal('court', SECRET)).toBeNull();
    expect(unseal(undefined, SECRET)).toBeNull();
  });

  it('expire à la date prévue', () => {
    const now = Date.UTC(2026, 10, 6, 9);
    const token = seal({ ok: true }, SECRET, 600, now);
    expect(unseal(token, SECRET, now + 599_000)).toEqual({ ok: true });
    expect(unseal(token, SECRET, now + 600_000)).toBeNull();
  });

  it('refuse une clé trop courte', () => {
    expect(() => seal({}, 'court', 60)).toThrow(/32 caractères/);
  });
});

describe('session de l’équipe', () => {
  const session: Session = {
    accessToken: 'a',
    refreshToken: 'r',
    accessExpiresAt: Date.UTC(2026, 10, 6, 9, 15),
    userId: 'u1',
    phone: '+237690000777',
    name: 'Awa',
    roles: ['CUSTOMER', 'ADMIN', 'SUPPORT'],
    mfaVerified: true,
  };

  it('se scelle et se relit', () => {
    expect(openSession(sealSession(session, SECRET), SECRET)).toEqual(session);
  });

  it('renouvelle le jeton d’accès une minute avant son échéance', () => {
    expect(needsRefresh(session, Date.UTC(2026, 10, 6, 9, 13, 59))).toBe(false);
    expect(needsRefresh(session, Date.UTC(2026, 10, 6, 9, 14, 1))).toBe(true);
  });

  it('ne garde que les rôles de l’équipe, dans l’ordre', () => {
    expect(staffRoles(session.roles)).toEqual(['SUPPORT', 'ADMIN']);
    expect(staffRoles(['CUSTOMER', 'RIDER'])).toEqual([]);
  });
});
