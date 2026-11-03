import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';

/** Code numérique aléatoire de `length` chiffres (zéros initiaux conservés). */
export function randomDigits(length: number): string {
  return String(randomInt(0, 10 ** length)).padStart(length, '0');
}

/** Jeton aléatoire encodé en base64url (32 octets → 43 caractères). */
export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString('base64url');
}

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/** Identifiant lisible sans caractères ambigus (pas de I, L, O, U). */
export function randomReadableId(length: number): string {
  let out = '';
  for (let i = 0; i < length; i += 1) out += CROCKFORD.charAt(randomInt(0, CROCKFORD.length));
  return out;
}

export function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/**
 * Hachage d'un code court (SMS, enlèvement, livraison). Le secret empêche de retrouver
 * un code par force brute à partir d'une copie de la base ; le contexte (`purpose`)
 * empêche de réutiliser un hachage d'un usage à l'autre.
 */
export function hashCode(secret: string, purpose: string, code: string): string {
  return createHmac('sha256', secret).update(`${purpose}:${code}`).digest('hex');
}

export function verifyCode(secret: string, purpose: string, code: string, hash: string): boolean {
  const expected = Buffer.from(hashCode(secret, purpose, code), 'hex');
  const actual = Buffer.from(hash, 'hex');
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

const IV_LENGTH = 12;
const TAG_LENGTH = 16;

/** Chiffrement authentifié AES-256-GCM : [iv 12 o][tag 16 o][données chiffrées]. */
export function encrypt(key: Buffer, plaintext: Buffer): Buffer {
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
}

export function decrypt(key: Buffer, payload: Buffer): Buffer {
  const iv = payload.subarray(0, IV_LENGTH);
  const tag = payload.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([
    decipher.update(payload.subarray(IV_LENGTH + TAG_LENGTH)),
    decipher.final(),
  ]);
}

/**
 * UUID version 7 (horodaté, RFC 9562), pour les insertions en SQL brut.
 * Prisma génère les mêmes identifiants pour les insertions qu'il gère lui-même.
 */
export function uuidv7(now = Date.now()): string {
  const bytes = randomBytes(16);
  let timestamp = BigInt(now);
  for (let i = 5; i >= 0; i -= 1) {
    bytes[i] = Number(timestamp & 0xffn);
    timestamp >>= 8n;
  }
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x70;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
