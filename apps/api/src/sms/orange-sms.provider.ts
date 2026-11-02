import type { SmsProvider, SmsSendResult } from './sms.provider.js';

const BASE_URL = 'https://api.orange.com';

export interface OrangeSmsConfig {
  clientId: string;
  clientSecret: string;
  /** Numéro du compte émetteur, +2376XXXXXXXX. */
  senderPhone: string;
  /** Nom d'expéditeur validé par Orange Cameroun. */
  senderName?: string | undefined;
  /** Remplaçable pour les tests. */
  fetch?: typeof fetch;
}

/**
 * API SMS d'Orange (« SMS Cameroon », tous opérateurs) : jeton OAuth 2 par identifiants
 * client, réutilisé jusqu'à quelques minutes de son expiration, puis envoi au format
 * « smsmessaging/v1 ». Un jeton refusé (401) est renouvelé une fois.
 */
export class OrangeSmsProvider implements SmsProvider {
  readonly name = 'orange';
  private token: { value: string; expiresAt: number } | null = null;
  private readonly http: typeof fetch;

  constructor(private readonly config: OrangeSmsConfig) {
    this.http = config.fetch ?? fetch;
  }

  private async accessToken(force = false): Promise<string> {
    if (!force && this.token && this.token.expiresAt > Date.now() + 300_000)
      return this.token.value;
    const basic = Buffer.from(`${this.config.clientId}:${this.config.clientSecret}`).toString(
      'base64',
    );
    const response = await this.http(`${BASE_URL}/oauth/v3/token`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: 'grant_type=client_credentials',
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error(`Jeton Orange refusé (${response.status})`);
    const body = (await response.json()) as { access_token: string; expires_in: number };
    this.token = { value: body.access_token, expiresAt: Date.now() + body.expires_in * 1000 };
    return body.access_token;
  }

  async send(to: string, text: string): Promise<SmsSendResult> {
    const sender = `tel:${this.config.senderPhone}`;
    const url = `${BASE_URL}/smsmessaging/v1/outbound/${encodeURIComponent(sender)}/requests`;
    const payload = JSON.stringify({
      outboundSMSMessageRequest: {
        address: `tel:${to}`,
        senderAddress: sender,
        ...(this.config.senderName ? { senderName: this.config.senderName } : {}),
        outboundSMSTextMessage: { message: text },
      },
    });
    const post = async (token: string): Promise<Response> =>
      this.http(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: payload,
        signal: AbortSignal.timeout(10_000),
      });

    let response = await post(await this.accessToken());
    if (response.status === 401) response = await post(await this.accessToken(true));
    if (!response.ok) {
      // Le corps peut citer le numéro : seuls le statut et le code d'erreur sont gardés.
      const body = (await response.json().catch(() => ({}))) as {
        requestError?: {
          serviceException?: { messageId?: string };
          policyException?: { messageId?: string };
        };
      };
      const code =
        body.requestError?.serviceException?.messageId ??
        body.requestError?.policyException?.messageId ??
        '';
      throw new Error(`Envoi Orange refusé (${response.status}${code ? ` ${code}` : ''})`);
    }
    const body = (await response.json()) as {
      outboundSMSMessageRequest?: { resourceURL?: string };
    };
    const resource = body.outboundSMSMessageRequest?.resourceURL ?? '';
    return { providerReference: resource.split('/').at(-1) ?? '', provider: this.name };
  }
}
