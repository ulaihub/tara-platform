import { ConsoleLogger } from '@nestjs/common';

/**
 * Masquage des données sensibles avant écriture dans les journaux : les journaux partent
 * chez l'hébergeur et dans les outils de supervision, ils ne doivent contenir ni numéro de
 * téléphone complet, ni jeton de session, ni lien secret (suivi, localisation).
 */
const RULES: [RegExp, string | ((match: string, ...groups: string[]) => string)][] = [
  // Numéros camerounais : +237 6XX XX XX XX, 237…, avec ou sans séparateurs.
  [
    /\+?237[\s.-]?6(?:[\s.-]?\d){8}/g,
    (match) => {
      const digits = match.replace(/\D/g, '');
      return `+2376•••••${digits.slice(-2)}`;
    },
  ],
  // Jetons JWT et en-têtes d'autorisation.
  [/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, '[jeton]'],
  [/(Bearer\s+)[\w.~+/=-]+/gi, '$1[jeton]'],
  // Jetons des liens publics, présents dans les URL journalisées.
  [/(\/public\/(?:tracking|location-links)\/)[A-Za-z0-9_-]+/g, '$1[jeton]'],
  [/(\/(?:t|l)\/)[A-Za-z0-9_-]{16,}/g, '$1[jeton]'],
];

export function redact(text: string): string {
  return RULES.reduce(
    (out, [pattern, replacement]) =>
      out.replace(pattern, replacement as (substring: string, ...args: string[]) => string),
    text,
  );
}

function clean(value: unknown): unknown {
  if (typeof value === 'string') return redact(value);
  if (value instanceof Error) {
    const copy = new Error(redact(value.message));
    copy.name = value.name;
    copy.stack = value.stack ? redact(value.stack) : undefined;
    return copy;
  }
  return value;
}

/** Journal de l'API : texte en développement, JSON en production, données sensibles masquées. */
export class RedactingLogger extends ConsoleLogger {
  override log(message: unknown, ...optionalParams: unknown[]): void {
    super.log(clean(message), ...optionalParams.map(clean));
  }
  override error(message: unknown, ...optionalParams: unknown[]): void {
    super.error(clean(message), ...optionalParams.map(clean));
  }
  override warn(message: unknown, ...optionalParams: unknown[]): void {
    super.warn(clean(message), ...optionalParams.map(clean));
  }
  override debug(message: unknown, ...optionalParams: unknown[]): void {
    super.debug(clean(message), ...optionalParams.map(clean));
  }
  override verbose(message: unknown, ...optionalParams: unknown[]): void {
    super.verbose(clean(message), ...optionalParams.map(clean));
  }
  override fatal(message: unknown, ...optionalParams: unknown[]): void {
    super.fatal(clean(message), ...optionalParams.map(clean));
  }
}
