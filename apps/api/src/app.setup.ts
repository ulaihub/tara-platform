import { randomUUID } from 'node:crypto';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { ENV } from './config/config.module.js';
import type { Env } from './config/env.js';
import { RedisIoAdapter } from './realtime/redis-io.adapter.js';

/** Valeur Express de « trust proxy » à partir de TRUST_PROXY. */
export function parseTrustProxy(value: string): boolean | number | string[] {
  const trimmed = value.trim();
  if (trimmed === 'true') return true;
  if (trimmed === 'false') return false;
  if (/^\d+$/.test(trimmed)) return Number(trimmed);
  return trimmed
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
}

const REQUEST_ID = /^[A-Za-z0-9-]{8,64}$/;

/**
 * Identifiant de requête : repris de l'en-tête X-Request-Id s'il est sûr, sinon généré.
 * Renvoyé dans la réponse et dans les erreurs, pour retrouver une requête dans les journaux.
 */
function requestId(request: Request, response: Response, next: NextFunction): void {
  const incoming = request.headers['x-request-id'];
  const id = typeof incoming === 'string' && REQUEST_ID.test(incoming) ? incoming : randomUUID();
  (request as Request & { id?: string }).id = id;
  response.setHeader('X-Request-Id', id);
  next();
}

/** Les réponses de l'API contiennent des données personnelles : aucun cache intermédiaire. */
function noStore(_request: Request, response: Response, next: NextFunction): void {
  response.setHeader('Cache-Control', 'no-store');
  next();
}

/** Réglages communs à l'exécution, aux tests et à la génération de l'OpenAPI. */
export function configureApp(app: NestExpressApplication): void {
  const env = app.get<Env>(ENV);

  // Adresse IP réelle du client derrière l'hébergeur (limitation de débit, journaux).
  app.set('trust proxy', parseTrustProxy(env.TRUST_PROXY));
  app.disable('x-powered-by');
  app.use(requestId);

  // En-têtes de sécurité. La politique de contenu stricte est réservée à la production :
  // l'interface Swagger de développement a besoin de scripts.
  app.use(
    helmet({
      contentSecurityPolicy:
        env.NODE_ENV === 'production'
          ? {
              useDefaults: false,
              directives: { 'default-src': ["'none'"], 'frame-ancestors': ["'none'"] },
            }
          : false,
      crossOriginResourcePolicy: { policy: 'same-site' },
    }),
  );

  // Les apps mobiles n'ont pas besoin de CORS ; seules les origines web déclarées sont admises.
  const origins = env.CORS_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (origins.length > 0) {
    app.enableCors({
      origin: origins,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      allowedHeaders: [
        'Authorization',
        'Content-Type',
        'Accept-Language',
        'Idempotency-Key',
        'X-Request-Id',
      ],
      exposedHeaders: ['X-Request-Id'],
      maxAge: 600,
    });
  }

  app.use('/v1', noStore);
  app.setGlobalPrefix('v1', { exclude: ['health'] });

  // Temps réel : les événements circulent entre les instances de l'API par Redis.
  app.useWebSocketAdapter(new RedisIoAdapter(app, env.REDIS_URL, env.QUEUE_PREFIX));
}
