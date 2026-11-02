import { applyDecorators, Body, HttpStatus, type PipeTransform, Query } from '@nestjs/common';
import { ApiBody, ApiQuery, ApiResponse } from '@nestjs/swagger';
import { z, type ZodType } from 'zod';
import { AppError } from '../errors/app-error.js';

/**
 * Zod est la seule source de vérité des contrats d'API : il valide les entrées à l'exécution
 * et produit les schémas OpenAPI dont on génère le client des applications Flutter.
 */

type JsonSchema = Record<string, unknown>;

/** Schémas nommés (`.meta({ id })`), regroupés dans `components.schemas` du document OpenAPI. */
export const openApiComponents = new Map<string, JsonSchema>();

const SAFE_INT_LIMIT = Number.MAX_SAFE_INTEGER;

/** Nettoie le JSON Schema produit par Zod pour les générateurs de clients. */
function clean(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(clean);
  if (node === null || typeof node !== 'object') return node;
  const out: JsonSchema = {};
  for (const [key, value] of Object.entries(node as JsonSchema)) {
    if (key === 'definitions') continue;
    if (key === '$ref' && typeof value === 'string') {
      out[key] = value.replace('#/definitions/', '#/components/schemas/');
      continue;
    }
    out[key] = clean(value);
  }
  // Les motifs regex des formats uuid et date-time encombrent les clients générés.
  if (out['format'] === 'uuid' || out['format'] === 'date-time' || out['format'] === 'date') {
    delete out['pattern'];
  }
  if (out['minimum'] === -SAFE_INT_LIMIT) delete out['minimum'];
  if (out['maximum'] === SAFE_INT_LIMIT) delete out['maximum'];
  return out;
}

export function toOpenApiSchema(schema: ZodType, io: 'input' | 'output' = 'output'): JsonSchema {
  const raw = z.toJSONSchema(schema, { target: 'openapi-3.0', io, unrepresentable: 'any' });
  const definitions = (raw as { definitions?: Record<string, unknown> }).definitions ?? {};
  for (const [id, definition] of Object.entries(definitions)) {
    openApiComponents.set(id, clean(definition) as JsonSchema);
  }
  const cleaned = clean(raw) as JsonSchema;
  // Un schéma racine nommé devient lui-même une référence.
  const rootId = (z.globalRegistry.get(schema) as { id?: string } | undefined)?.id;
  if (rootId) {
    openApiComponents.set(rootId, cleaned);
    return { $ref: `#/components/schemas/${rootId}` };
  }
  return cleaned;
}

export class ZodValidationPipe<T extends ZodType> implements PipeTransform {
  constructor(private readonly schema: T) {}

  transform(value: unknown): z.output<T> {
    const result = this.schema.safeParse(value);
    if (!result.success) {
      throw AppError.badRequest(
        'VALIDATION_FAILED',
        {},
        result.error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      );
    }
    return result.data;
  }
}

/** Corps de requête validé : `@ValidBody(Schema) body: z.output<typeof Schema>`. */
export function ValidBody(schema: ZodType): ParameterDecorator {
  return Body(new ZodValidationPipe(schema));
}

/** Paramètres de requête validés. */
export function ValidQuery(schema: ZodType): ParameterDecorator {
  return Query(new ZodValidationPipe(schema));
}

/** Documente le corps attendu. */
export function ApiZodBody(schema: ZodType): MethodDecorator {
  return ApiBody({ schema: toOpenApiSchema(schema, 'input') });
}

/** Documente chaque paramètre de requête d'un objet Zod. */
export function ApiZodQuery(schema: z.ZodObject): MethodDecorator {
  const json = toOpenApiSchema(schema, 'input') as {
    properties?: Record<string, JsonSchema>;
    required?: string[];
  };
  const required = new Set(json.required ?? []);
  return applyDecorators(
    ...Object.entries(json.properties ?? {}).map(([name, property]) =>
      ApiQuery({ name, required: required.has(name), schema: property }),
    ),
  );
}

/** Documente une réponse. */
export function ApiZodResponse(
  schema: ZodType,
  status: HttpStatus = HttpStatus.OK,
  description = 'Succès',
): MethodDecorator {
  return ApiResponse({ status, description, schema: toOpenApiSchema(schema, 'output') });
}
