import type { LegalDocumentName } from './legal-sources.js';
import { LEGAL_TEXTS } from './legal-texts.generated.js';

/** Conditions propres à chaque app ; la politique de confidentialité vaut pour toutes. */
export const APP_TERMS = { client: 'expediteurs', rider: 'livreurs' } as const;
export type LegalApp = keyof typeof APP_TERMS;

/** Versions affichées par l'app et acceptées, par document : `{ expediteurs: '2026-11' }`. */
export type AcceptedVersions = Partial<Record<LegalDocumentName, string>>;

/** « expediteurs:2026-11 » : version acceptée telle qu'enregistrée au consentement. */
export function currentVersion(document: LegalDocumentName): string {
  return `${document}:${LEGAL_TEXTS[document].version}`;
}

/**
 * Consentements de l'inscription : les conditions d'une seule app et la politique de
 * confidentialité, toutes deux dans leur version en vigueur. Null si l'app a affiché autre
 * chose (texte périmé, document manquant).
 */
export function signupConsents(
  versions: AcceptedVersions,
): { kind: 'TERMS' | 'PRIVACY'; version: string }[] | null {
  const terms = Object.values(APP_TERMS).filter((name) => versions[name] !== undefined);
  const [document] = terms;
  if (terms.length !== 1 || !document) return null;
  for (const name of [document, 'confidentialite'] as const) {
    if (versions[name] !== LEGAL_TEXTS[name].version) return null;
  }
  return [
    { kind: 'TERMS', version: currentVersion(document) },
    { kind: 'PRIVACY', version: currentVersion('confidentialite') },
  ];
}

/** Versions à avoir acceptées pour utiliser l'app : ses conditions et la confidentialité. */
export function requiredVersions(app: LegalApp): string[] {
  return [currentVersion(APP_TERMS[app]), currentVersion('confidentialite')];
}

/** Vrai si les versions acceptées couvrent celles en vigueur pour l'app. */
export function termsAccepted(app: LegalApp, accepted: readonly string[]): boolean {
  return requiredVersions(app).every((version) => accepted.includes(version));
}
