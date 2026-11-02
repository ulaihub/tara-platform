import {
  base32Decode,
  base32Encode,
  generateTotpSecret,
  otpauthUrl,
  totpCode,
  totpStep,
  verifyTotp,
} from './totp.js';

/** Secret des vecteurs de test officiels de la RFC 6238 (annexe B), en base32. */
const RFC_SECRET = base32Encode(Buffer.from('12345678901234567890'));

describe('TOTP (RFC 6238)', () => {
  it('encode et décode le base32 sans perte', () => {
    expect(RFC_SECRET).toBe('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(base32Decode(RFC_SECRET).toString()).toBe('12345678901234567890');
    const secret = generateTotpSecret();
    expect(secret).toMatch(/^[A-Z2-7]{32}$/);
    expect(base32Encode(base32Decode(secret))).toBe(secret);
  });

  it.each([
    [59, '94287082'],
    [1_111_111_109, '07081804'],
    [1_111_111_111, '14050471'],
    [1_234_567_890, '89005924'],
    [2_000_000_000, '69279037'],
    [20_000_000_000, '65353130'],
  ])('vecteur officiel à %i s → %s', (seconds, expected) => {
    const step = totpStep(new Date(seconds * 1000));
    expect(totpCode(RFC_SECRET, step, 8)).toBe(expected);
    expect(totpCode(RFC_SECRET, step)).toBe(expected.slice(2));
  });

  it('accepte un pas d’écart pour une horloge décalée, pas davantage', () => {
    const now = new Date(1_234_567_890_000);
    const step = totpStep(now);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step - 1), now)).toBe(step - 1);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step + 1), now)).toBe(step + 1);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step - 2), now)).toBeNull();
  });

  it('refuse de rejouer un code déjà utilisé', () => {
    const now = new Date(1_234_567_890_000);
    const step = totpStep(now);
    const code = totpCode(RFC_SECRET, step);
    expect(verifyTotp(RFC_SECRET, code, now, step - 1)).toBe(step);
    expect(verifyTotp(RFC_SECRET, code, now, step)).toBeNull();
  });

  it('refuse un code mal formé', () => {
    expect(verifyTotp(RFC_SECRET, '12345', new Date())).toBeNull();
    expect(verifyTotp(RFC_SECRET, 'abcdef', new Date())).toBeNull();
  });

  it('produit une adresse otpauth lisible par les applications', () => {
    expect(otpauthUrl('ABC', '+237690000000')).toBe(
      'otpauth://totp/Tara%3A%2B237690000000?secret=ABC&issuer=Tara&algorithm=SHA1&digits=6&period=30',
    );
  });
});
