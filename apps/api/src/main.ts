import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { configureApp } from './app.setup.js';
import { RedactingLogger } from './common/logging/redacting-logger.js';
import { ENV } from './config/config.module.js';
import type { Env } from './config/env.js';
import { setupOpenApiUi } from './openapi/openapi.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // Journaux JSON en production (collecte), lisibles en développement ; données masquées.
    logger: new RedactingLogger({ json: process.env['NODE_ENV'] === 'production' }),
  });
  app.enableShutdownHooks();
  configureApp(app);

  const env = app.get<Env>(ENV);
  if (env.NODE_ENV !== 'production') setupOpenApiUi(app);

  await app.listen(env.PORT);
  new Logger('Bootstrap').log(`API Tara démarrée sur le port ${env.PORT} (${env.NODE_ENV})`);
}

await bootstrap();
