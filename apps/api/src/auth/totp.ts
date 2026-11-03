import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Codes à usage unique basés sur le temps (TOTP, RFC 6238), compatibles avec Google
 * Authenticator, Microsoft Authenticator, Aegis, etc. : HMAC-SHA1, 6 chiffres, 30 s.
 */

const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
export const TOTP_PERIOD_SECONDS = 30;
export const TOTP_DIGITS = 6;

export function base32Encode(data: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of data) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32.charAt((value >>> (bits - 5)) & 31);
      bits -= 5;
    }
  }
  if (bits > 0) out += BASE32.charAt((value << (5 - bits)) & 31);
  return out;
}

export function base32Decode(text: string): Buffer {
  const clean = text.replace(/=+$/, '').replace(/\s/g, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const char of clean) {
    const index = BASE32.indexOf(char);
    if (index === -1) throw new Error('Secret base32 invalide');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

/** Secret aléatoire de 160 bits, encodé en base32 pour les applications. */
export function generateTotpSecret(): string {
  return base32Encode(randomBytes(20));
}

export function totpStep(at: Date): number {
  return Math.floor(at.getTime() / 1000 / TOTP_PERIOD_SECONDS);
}

export function totpCode(secret: string, step: number, digits = TOTP_DIGITS): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const hmac = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const offset = (hmac.at(-1) ?? 0) & 0x0f;
  const binary = hmac.readUInt32BE(offset) & 0x7fffffff;
  return String(binary % 10 ** digits).padStart(digits, '0');
}

/**
 * Pas de temps du code s'il est valide, sinon null. Tolère un pas d'écart (± 30 s) pour les
 * horloges de téléphone décalées, et refuse tout pas déjà utilisé (`afterStep`) : un code
 * intercepté ne peut pas être rejoué.
 */
export function verifyTotp(
  secret: string,
  code: string,
  at: Date,
  afterStep: number | null = null,
): number | null {
  if (!/^\d{6}$/.test(code)) return null;
  const current = totpStep(at);
  for (const step of [current - 1, current, current + 1]) {
    if (afterStep !== null && step <= afterStep) continue;
    const expected = Buffer.from(totpCode(secret, step));
    if (timingSafeEqual(expected, Buffer.from(code))) return step;
  }
  return null;
}

/** Adresse à afficher en QR code pour l'enrôlement dans une application d'authentification. */
export function otpauthUrl(secret: string, account: string): string {
  const label = encodeURIComponent(`Tara:${account}`);
  return `otpauth://totp/${label}?secret=${secret}&issuer=Tara&algorithm=SHA1&digits=${TOTP_DIGITS}&period=${TOTP_PERIOD_SECONDS}`;
}
