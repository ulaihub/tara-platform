import 'reflect-metadata';
import { writeFile } from 'node:fs/promises';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';

/**
 * Écrit le contrat OpenAPI de l'API dans un fichier versionné (apps/api/openapi.json),
 * source du client généré pour les applications Flutter. La CI vérifie qu'il est à jour.
 * Aucune base ni aucun service n'est contacté : seules les routes et les schémas sont lus.
 */
const PLACEHOLDERS: Record<string, string> = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://openapi:openapi@localhost:5432/openapi',
  JWT_SECRET: 'openapi-generation-only-0000000000000000',
  CODE_HASH_SECRET: 'openapi-generation-only-0000000000000000',
  STORAGE_ENCRYPTION_KEY: Buffer.alloc(32).toString('base64'),
  JOBS_ENABLED: 'false',
  REDIS_URL: 'redis://localhost:6379',
};
for (const [key, value] of Object.entries(PLACEHOLDERS)) process.env[key] ??= value;

const { AppModule } = await import('../app.module.js');
const { configureApp } = await import('../app.setup.js');
const { buildOpenApiDocument } = await import('./openapi.js');

const app = await NestFactory.create<NestExpressApplication>(AppModule, { logger: false });
configureApp(app);
const document = buildOpenApiDocument(app);
const target = process.argv[2] ?? 'openapi.json';
await writeFile(target, `${JSON.stringify(document, null, 2)}\n`);
await app.close();
process.stdout.write(`Contrat OpenAPI écrit dans ${target}\n`);
