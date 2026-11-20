import { hashCode } from '../common/crypto.js';

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/** « TR-7K3P9Q-4F8M2XQA » : référence et 8 caractères de signature. */
export const RECEIPT_CODE_PATTERN = /^(TR-[0-9A-Z]{4,12})-([0-9A-Z]{8})$/;

function signature(secret: string, reference: string): string {
  const digest = hashCode(secret, 'receipt', reference);
  // 40 bits de l'empreinte, en 8 caractères lisibles (sans I, L, O, U).
  let bits = BigInt(`0x${digest.slice(0, 10)}`);
  let out = '';
  for (let i = 0; i < 8; i += 1) {
    out = CROCKFORD.charAt(Number(bits & 31n)) + out;
    bits >>= 5n;
  }
  return out;
}

/**
 * Code imprimé sous le QR du reçu. Signé : la référence seule (courte, devinable) ne
 * suffit pas pour lire un reçu, il faut le papier ou le lien envoyé à l'expéditeur.
 */
export function receiptCode(secret: string, reference: string): string {
  return `${reference}-${signature(secret, reference)}`;
}

/** Référence du reçu si la signature est la bonne, sinon null. */
export function readReceiptCode(secret: string, code: string): string | null {
  const match = RECEIPT_CODE_PATTERN.exec(code.trim().toUpperCase());
  if (!match) return null;
  const [, reference = '', given = ''] = match;
  const expected = signature(secret, reference);
  let diff = 0;
  for (let i = 0; i < expected.length; i += 1) diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0 ? reference : null;
}

/** Lien de vérification du reçu sur le site public (QR du reçu imprimable). */
export function receiptUrl(publicWebUrl: string, secret: string, reference: string): string {
  return `${publicWebUrl.replace(/\/$/, '')}/r/${receiptCode(secret, reference)}`;
}
