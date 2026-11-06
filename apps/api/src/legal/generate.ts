import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { readLegalSources } from './legal-sources.js';

/**
 * Copie les textes de docs/juridique dans l'API (`pnpm --filter @tara/api legal`) : l'API
 * déployée les sert sans dépendre du dossier docs. Un test vérifie qu'ils sont à jour.
 */
const repo = resolve(import.meta.dirname, '../../../..');
const texts = readLegalSources(repo);
const body = `// Généré par \`pnpm --filter @tara/api legal\` depuis docs/juridique : ne pas modifier.
import type { LegalDocumentName, LegalText } from './legal-sources.js';

export const LEGAL_TEXTS: Record<LegalDocumentName, LegalText> = ${JSON.stringify(texts, null, 2)};
`;
writeFileSync(resolve(import.meta.dirname, 'legal-texts.generated.ts'), body);
process.stdout.write(
  `Textes juridiques copiés : ${Object.entries(texts)
    .map(([name, text]) => `${name} ${text.version}`)
    .join(', ')}\n`,
);
