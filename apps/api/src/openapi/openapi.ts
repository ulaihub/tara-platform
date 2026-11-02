import type { INestApplication } from '@nestjs/common';
import { DocumentBuilder, type OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { z } from 'zod';
import { ERROR_MESSAGES } from '../common/errors/error-codes.js';
import { openApiComponents, toOpenApiSchema } from '../common/validation/zod.js';

const ErrorBody = z
  .object({
    error: z.object({
      code: z.enum(Object.keys(ERROR_MESSAGES) as [string, ...string[]]),
      message: z
        .string()
        .meta({ description: 'Message prêt à afficher, en français ou en anglais' }),
      details: z.unknown().optional(),
      requestId: z
        .string()
        .optional()
        .meta({ description: 'À communiquer au support : retrouve la requête dans les journaux' }),
    }),
  })
  .meta({ id: 'ErrorBody', description: 'Format unique des erreurs de l’API' });

/** Document OpenAPI 3 de l'API, source du client généré pour les applications. */
export function buildOpenApiDocument(app: INestApplication): OpenAPIObject {
  toOpenApiSchema(ErrorBody);
  const config = new DocumentBuilder()
    .setTitle('API Tara')
    .setDescription(
      'Plateforme de livraison urbaine. Les erreurs suivent le schéma ErrorBody ; ' +
        'la langue des messages suit Accept-Language (fr par défaut).',
    )
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config, {
    operationIdFactory: (controllerKey, methodKey) =>
      `${controllerKey.replace(/Controller$/, '')}_${methodKey}`,
  });

  const schemas = Object.fromEntries(
    [...openApiComponents.entries()].sort(([a], [b]) => a.localeCompare(b)),
  );
  document.components = {
    ...document.components,
    schemas: { ...document.components?.schemas, ...schemas },
  };
  return document;
}

export function setupOpenApiUi(app: INestApplication): void {
  SwaggerModule.setup('docs', app, buildOpenApiDocument(app));
}
