import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

/**
 * Chiffrement des cookies (AES-256-GCM) : contenu illisible et infalsifiable dans le
 * navigateur. Clé dérivée de SESSION_SECRET ; un cookie scellé avec une autre clé, abîmé
 * ou périmé est ignoré.
 */
function key(secret: string): Buffer {
  if (secret.length < 32) throw new Error('SESSION_SECRET : 32 caractères au moins');
  return createHash('sha256').update(secret).digest();
}

export function seal(
  value: unknown,
  secret: string,
  maxAgeSeconds: number,
  now = Date.now(),
): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key(secret), iv);
  const payload = JSON.stringify({ v: value, e: now + maxAgeSeconds * 1000 });
  const body = Buffer.concat([cipher.update(payload, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString('base64url');
}

export function unseal<T>(token: string | undefined, secret: string, now = Date.now()): T | null {
  if (!token) return null;
  try {
    const raw = Buffer.from(token, 'base64url');
    if (raw.length < 29) return null;
    const decipher = createDecipheriv('aes-256-gcm', key(secret), raw.subarray(0, 12));
    decipher.setAuthTag(raw.subarray(12, 28));
    const payload = Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString(
      'utf8',
    );
    const parsed = JSON.parse(payload) as { v: T; e: number };
    return parsed.e > now ? parsed.v : null;
  } catch {
    return null;
  }
}
