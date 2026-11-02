import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { configureApp } from './app.setup.js';
import { ENV } from './config/config.module.js';
import type { Env } from './config/env.js';
import { setupOpenApiUi } from './openapi/openapi.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  configureApp(app);

  const env = app.get<Env>(ENV);
  if (env.NODE_ENV !== 'production') setupOpenApiUi(app);

  await app.listen(env.PORT);
  new Logger('Bootstrap').log(`API Tara démarrée sur le port ${env.PORT} (${env.NODE_ENV})`);
}

await bootstrap();
