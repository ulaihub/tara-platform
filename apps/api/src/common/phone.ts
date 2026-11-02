import { z } from 'zod';

/**
 * Normalise un numéro de mobile camerounais au format international E.164.
 * Accepte les écritures courantes : « 690 00 00 00 », « 690-000-000 », « 237690000000 »,
 * « +237 6 90 00 00 00 », « 00237690000000 ». Les mobiles camerounais ont 9 chiffres et
 * commencent par 6. Renvoie null si le numéro n'est pas reconnu.
 */
export function normalizeCameroonMobile(input: string): string | null {
  const compact = input.replace(/[\s.\-()]/g, '');
  let local: string;
  if (compact.startsWith('+237')) local = compact.slice(4);
  else if (compact.startsWith('00237')) local = compact.slice(5);
  else if (compact.startsWith('237') && compact.length === 12) local = compact.slice(3);
  else local = compact;
  return /^6\d{8}$/.test(local) ? `+237${local}` : null;
}

/** Numéro de mobile camerounais, normalisé en E.164 à la validation. */
export const CameroonMobile = z
  .string()
  .max(32)
  .transform((value, ctx) => {
    const normalized = normalizeCameroonMobile(value);
    if (!normalized) {
      ctx.issues.push({ code: 'custom', message: 'INVALID_PHONE', input: value });
      return z.NEVER;
    }
    return normalized;
  })
  .meta({
    description: 'Mobile camerounais ; toutes les écritures courantes sont acceptées',
    example: '+237690000000',
  });

/** Masque un numéro pour les journaux et les écrans publics : +237 6•• •• •• 12. */
export function maskPhone(phone: string): string {
  return phone.length < 6 ? '••••' : `${phone.slice(0, 6)}•••••${phone.slice(-2)}`;
}
