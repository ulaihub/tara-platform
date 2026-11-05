import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/** Documents juridiques publiés par l'API, et leur fichier source dans docs/juridique. */
export const LEGAL_SOURCES = {
  expediteurs: 'conditions-expediteurs.md',
  livreurs: 'conditions-livreurs.md',
  destinataires: 'conditions-destinataires.md',
  confidentialite: 'politique-confidentialite.md',
} as const;

export type LegalDocumentName = keyof typeof LEGAL_SOURCES;

export interface LegalText {
  title: string;
  version: string;
  markdown: string;
}

/** Titre (première ligne « # ») et version (« Version 2026-11 ») d'un texte. */
export function parseLegal(markdown: string): LegalText {
  const title = /^# (.+)$/m.exec(markdown)?.[1]?.trim();
  const version = /^Version (\d{4}-\d{2}(?:\.\d+)?)/m.exec(markdown)?.[1];
  if (!title || !version)
    throw new Error('Texte juridique sans titre « # » ni « Version AAAA-MM »');
  return { title, version, markdown };
}

/** Lit les textes depuis docs/juridique (répertoire racine du dépôt). */
export function readLegalSources(root: string): Record<LegalDocumentName, LegalText> {
  const entries = Object.entries(LEGAL_SOURCES).map(([name, file]) => [
    name,
    parseLegal(readFileSync(resolve(root, 'docs/juridique', file), 'utf8')),
  ]);
  return Object.fromEntries(entries) as Record<LegalDocumentName, LegalText>;
}
