import { jwtVerify } from 'jose';
import {
  type CollectRequest,
  type DisburseRequest,
  InvalidWebhookError,
  type PaymentProvider,
  type ProviderEvent,
  type ProviderOperation,
  type ProviderStatus,
  type ProviderTransaction,
  ProviderUnavailableError,
  type WebhookInput,
} from './payment.provider.js';

export interface CamPayConfig {
  /** https://demo.campay.net/api (bac à sable) ou https://www.campay.net/api. */
  baseUrl: string;
  username: string;
  password: string;
  /** Clé de signature des notifications (« Webhook key » du tableau de bord). */
  webhookKey: string;
  fetch?: typeof fetch;
}

interface CamPayTransaction {
  reference?: string;
  external_reference?: string | null;
  status?: string;
  amount?: number | string;
  app_amount?: number | string;
  operation?: string;
  created_at?: string;
}

function mapStatus(status: string | undefined): ProviderStatus {
  switch ((status ?? '').toUpperCase()) {
    case 'SUCCESSFUL':
    case 'SUCCESS':
      return 'SUCCEEDED';
    case 'FAILED':
    case 'CANCELLED':
    case 'EXPIRED':
      return 'FAILED';
    default:
      return 'PENDING';
  }
}

/** Numéro au format attendu par CamPay : 2376XXXXXXXX, sans « + ». */
const msisdn = (phone: string): string => phone.replace(/^\+/, '');

/**
 * Adaptateur CamPay (agrégateur camerounais MTN MoMo + Orange Money) : jeton d'API,
 * collecte par invite sur le téléphone, retrait, statut, historique ; notifications
 * signées par un JWT. À valider sur le bac à sable avant la mise en production (les
 * champs de l'historique en particulier).
 */
export class CamPayPaymentProvider implements PaymentProvider {
  readonly name = 'campay';
  private token: { value: string; expiresAt: number } | null = null;
  private readonly http: typeof fetch;

  constructor(private readonly config: CamPayConfig) {
    this.http = config.fetch ?? fetch;
  }

  private async call<T>(
    method: 'GET' | 'POST',
    path: string,
    body?: object,
    auth = true,
  ): Promise<T> {
    let response: Response;
    try {
      response = await this.http(`${this.config.baseUrl.replace(/\/$/, '')}${path}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(auth ? { Authorization: `Token ${await this.accessToken()}` } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(15_000),
      });
    } catch (error) {
      throw new ProviderUnavailableError(`CamPay injoignable : ${String(error)}`);
    }
    if (response.status >= 500)
      throw new ProviderUnavailableError(`CamPay indisponible (${response.status})`);
    const payload = (await response.json().catch(() => ({}))) as T & { message?: string };
    if (!response.ok)
      throw new Error(`CamPay a refusé ${path} (${response.status}) : ${payload.message ?? ''}`);
    return payload;
  }

  private async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt > Date.now() + 300_000) return this.token.value;
    const body = await this.call<{ token: string; expires_in?: number }>(
      'POST',
      '/token/',
      { username: this.config.username, password: this.config.password },
      false,
    );
    this.token = { value: body.token, expiresAt: Date.now() + (body.expires_in ?? 3600) * 1000 };
    return body.token;
  }

  async collect(request: CollectRequest): Promise<ProviderOperation> {
    const body = await this.call<{ reference: string }>('POST', '/collect/', {
      amount: String(request.amount),
      currency: 'XAF',
      from: msisdn(request.phone),
      description: request.description.slice(0, 100),
      external_reference: request.reference,
    });
    return { providerReference: body.reference, status: 'PENDING' };
  }

  async disburse(request: DisburseRequest): Promise<ProviderOperation> {
    const body = await this.call<{ reference: string; status?: string }>('POST', '/withdraw/', {
      amount: String(request.amount),
      currency: 'XAF',
      to: msisdn(request.phone),
      description: request.description.slice(0, 100),
      external_reference: request.reference,
    });
    return { providerReference: body.reference, status: mapStatus(body.status) };
  }

  async collectStatus(providerReference: string): Promise<ProviderOperation> {
    const body = await this.call<CamPayTransaction>(
      'GET',
      `/transaction/${encodeURIComponent(providerReference)}/`,
    );
    return {
      providerReference,
      status: mapStatus(body.status),
      ...(body.amount !== undefined ? { amount: Number(body.amount) } : {}),
    };
  }

  async disburseStatus(reference: string): Promise<ProviderOperation | null> {
    const to = new Date();
    const from = new Date(to.getTime() - 7 * 86_400_000);
    const found = (await this.history(from, to)).find(
      (item) => item.external_reference === reference,
    );
    if (!found?.reference) return null;
    return this.collectStatus(found.reference);
  }

  async parseWebhook(input: WebhookInput): Promise<ProviderEvent> {
    // CamPay transmet les champs dans l'URL ; le corps est accepté par précaution.
    const fields = { ...(input.body as Record<string, unknown> | undefined), ...input.query };
    const signature = typeof fields['signature'] === 'string' ? fields['signature'] : '';
    try {
      await jwtVerify(signature, new TextEncoder().encode(this.config.webhookKey), {
        algorithms: ['HS256'],
      });
    } catch {
      throw new InvalidWebhookError('Signature CamPay invalide');
    }
    const text = (value: unknown): string => (typeof value === 'string' ? value : '');
    const providerReference = text(fields['reference']);
    const status = mapStatus(text(fields['status']));
    return {
      eventId: `${providerReference}:${status}`,
      reference:
        typeof fields['external_reference'] === 'string' ? fields['external_reference'] : null,
      providerReference,
      status,
      amount: fields['amount'] === undefined ? null : Number(fields['amount']),
    };
  }

  /**
   * La signature CamPay authentifie l'appel mais ne couvre pas forcément chaque champ :
   * statut et montant sont relus par l'API avant d'être crus.
   */
  async confirmEvent(event: ProviderEvent): Promise<ProviderEvent> {
    const body = await this.call<CamPayTransaction>(
      'GET',
      `/transaction/${encodeURIComponent(event.providerReference)}/`,
    );
    return {
      ...event,
      status: mapStatus(body.status),
      amount: body.amount === undefined ? null : Number(body.amount),
      reference: body.external_reference ?? event.reference,
    };
  }

  private async history(from: Date, to: Date): Promise<CamPayTransaction[]> {
    const day = (date: Date): string => date.toISOString().slice(0, 10);
    const body = await this.call<CamPayTransaction[] | { data?: CamPayTransaction[] }>(
      'POST',
      '/history/',
      {
        start_date: day(from),
        end_date: day(to),
      },
    );
    return Array.isArray(body) ? body : (body.data ?? []);
  }

  async transactions(from: Date, to: Date): Promise<ProviderTransaction[]> {
    return (await this.history(from, to)).flatMap((item) => {
      const at = item.created_at ? new Date(item.created_at) : null;
      if (!item.reference || !at || at < from || at >= to) return [];
      const amount = Number(item.amount ?? 0);
      return [
        {
          providerReference: item.reference,
          reference: item.external_reference ?? null,
          kind: (item.operation ?? '').toUpperCase().startsWith('WITHDRAW')
            ? 'DISBURSE'
            : 'COLLECT',
          amount,
          fee: Math.max(0, amount - Number(item.app_amount ?? amount)),
          status: mapStatus(item.status),
          at,
        } satisfies ProviderTransaction,
      ];
    });
  }
}
