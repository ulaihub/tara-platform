import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

/**
 * Le contrat versionné (régénéré et comparé en CI) doit être utilisable par un client :
 * chaque schéma nommé décrit ses champs, et chaque référence pointe vers un schéma existant.
 */
describe('contrat OpenAPI', () => {
  const document = JSON.parse(
    readFileSync(new URL('../../openapi.json', import.meta.url), 'utf8'),
  ) as {
    components: { schemas: Record<string, Record<string, unknown>> };
  };
  const schemas = document.components.schemas;

  it('aucun schéma ne se réduit à une référence vers lui-même', () => {
    const circular = Object.entries(schemas)
      .filter(([name, schema]) => schema['$ref'] === `#/components/schemas/${name}`)
      .map(([name]) => name);
    expect(circular).toEqual([]);
  });

  it('toutes les références pointent vers un schéma défini', () => {
    const missing = new Set<string>();
    const walk = (node: unknown): void => {
      if (Array.isArray(node)) node.forEach(walk);
      else if (node && typeof node === 'object') {
        for (const [key, value] of Object.entries(node)) {
          if (key === '$ref' && typeof value === 'string') {
            const name = value.split('/').at(-1) ?? '';
            if (!(name in schemas)) missing.add(name);
          } else walk(value);
        }
      }
    };
    walk(document);
    expect([...missing]).toEqual([]);
  });
});
