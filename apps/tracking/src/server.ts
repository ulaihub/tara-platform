import { serve } from '@hono/node-server';
import { getConnInfo } from '@hono/node-server/conninfo';
import { httpApi } from './api.js';
import { createApp } from './app.js';

const port = Number(process.env['PORT'] ?? 3001);
const apiUrl = process.env['API_URL'] ?? 'http://localhost:3000';
/** Derrière un relais (hébergeur), l'adresse du visiteur arrive dans X-Forwarded-For. */
const behindProxy = process.env['TRUST_PROXY'] === 'true';

const app = createApp({
  api: httpApi(apiUrl),
  clientIp: (c) =>
    behindProxy
      ? c.req.header('x-forwarded-for')?.split(',')[0]?.trim()
      : getConnInfo(c).remote.address,
});

serve({ fetch: app.fetch, port }, (info) => {
  process.stdout.write(`Page de suivi sur http://localhost:${info.port} (API : ${apiUrl})\n`);
});
