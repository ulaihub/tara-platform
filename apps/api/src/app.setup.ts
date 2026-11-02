import type { INestApplication } from '@nestjs/common';

/** Réglages communs à l'exécution, aux tests et à la génération de l'OpenAPI. */
export function configureApp(app: INestApplication): void {
  app.setGlobalPrefix('v1', { exclude: ['health'] });
}
