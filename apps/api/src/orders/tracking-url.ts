import type { Env } from '../config/env.js';

/** Lien de la page de suivi publique (F2) envoyé au destinataire. */
export function trackingUrl(env: Pick<Env, 'PUBLIC_WEB_URL'>, trackingToken: string): string {
  return `${env.PUBLIC_WEB_URL.replace(/\/$/, '')}/t/${trackingToken}`;
}
