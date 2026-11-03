import { Logger } from '@nestjs/common';
import { importPKCS8, SignJWT } from 'jose';

export const PUSH_PROVIDER = Symbol('PUSH_PROVIDER');

export interface PushMessage {
  title: string;
  body: string;
  /** Données lues par l'app (identifiants, type d'événement). Valeurs texte uniquement. */
  data: Record<string, string>;
  /**
   * Proposition de course (E1) : priorité haute et canal sonore, pour réveiller le
   * téléphone même écran verrouillé. Durée de vie courte : inutile de la livrer en retard.
   */
  urgent?: boolean;
  ttlSeconds?: number;
}

/** Jeton d'appareil refusé définitivement (app désinstallée) : à effacer. */
export class PushTokenInvalidError extends Error {}

export interface PushProvider {
  readonly name: string;
  send(token: string, message: PushMessage): Promise<{ providerReference: string }>;
}

/** Fournisseur factice (développement, tests) : garde les messages en mémoire. */
export class FakePushProvider implements PushProvider {
  readonly name = 'fake';
  readonly outbox: { token: string; message: PushMessage; at: Date }[] = [];
  /** Jetons à traiter comme invalides (tests). */
  readonly invalidTokens = new Set<string>();
  private readonly logger = new Logger('FakePush');
  private counter = 0;

  send(token: string, message: PushMessage): Promise<{ providerReference: string }> {
    if (this.invalidTokens.has(token)) return Promise.reject(new PushTokenInvalidError(token));
    this.outbox.push({ token, message, at: new Date() });
    if (this.outbox.length > 500) this.outbox.shift();
    this.logger.debug(`→ ${token.slice(0, 8)}… : ${message.title}`);
    this.counter += 1;
    return Promise.resolve({ providerReference: `fake-push-${this.counter}` });
  }

  lastTo(token: string): PushMessage | undefined {
    return this.outbox.filter((entry) => entry.token === token).at(-1)?.message;
  }
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const DEFAULT_TOKEN_URI = 'https://oauth2.googleapis.com/token';

/**
 * Firebase Cloud Messaging, API HTTP v1. Le jeton OAuth est obtenu avec le compte de
 * service (assertion JWT signée RS256) et réutilisé jusqu'à quelques minutes de son
 * expiration. Aucun SDK : moins de dépendances, et l'API v1 est stable.
 */
export class FcmPushProvider implements PushProvider {
  readonly name = 'fcm';
  private readonly account: ServiceAccount;
  private accessToken: { value: string; expiresAt: number } | null = null;

  constructor(serviceAccountBase64: string) {
    const parsed = JSON.parse(
      Buffer.from(serviceAccountBase64, 'base64').toString('utf8'),
    ) as Partial<ServiceAccount>;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error('Compte de service Firebase incomplet');
    }
    this.account = parsed as ServiceAccount;
  }

  private async token(): Promise<string> {
    if (this.accessToken && this.accessToken.expiresAt > Date.now() + 300_000) {
      return this.accessToken.value;
    }
    const tokenUri = this.account.token_uri ?? DEFAULT_TOKEN_URI;
    const key = await importPKCS8(this.account.private_key, 'RS256');
    const assertion = await new SignJWT({ scope: FCM_SCOPE })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(this.account.client_email)
      .setAudience(tokenUri)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(key);
    const response = await fetch(tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error(`Jeton FCM refusé (${response.status})`);
    const body = (await response.json()) as { access_token: string; expires_in: number };
    this.accessToken = {
      value: body.access_token,
      expiresAt: Date.now() + body.expires_in * 1000,
    };
    return body.access_token;
  }

  async send(token: string, message: PushMessage): Promise<{ providerReference: string }> {
    const ttl = `${message.ttlSeconds ?? 3600}s`;
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.account.project_id)}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${await this.token()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              priority: message.urgent ? 'HIGH' : 'NORMAL',
              ttl,
              notification: {
                channel_id: message.urgent ? 'offers' : 'orders',
                sound: 'default',
              },
            },
            apns: {
              headers: { 'apns-priority': message.urgent ? '10' : '5' },
              payload: { aps: { sound: 'default' } },
            },
          },
        }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (response.ok) {
      const body = (await response.json()) as { name?: string };
      return { providerReference: body.name ?? '' };
    }
    const text = await response.text();
    if (response.status === 404 || text.includes('UNREGISTERED')) {
      throw new PushTokenInvalidError('Jeton d’appareil inconnu de FCM');
    }
    throw new Error(`Envoi FCM refusé (${response.status}) : ${text.slice(0, 200)}`);
  }
}
