import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  type CollectRequest,
  type DisburseRequest,
  InvalidWebhookError,
  type MobileMoneyOperator,
  type OperationKind,
  type PaymentProvider,
  type ProviderEvent,
  type ProviderOperation,
  type ProviderStatus,
  type ProviderTransaction,
  ProviderUnavailableError,
  type WebhookInput,
} from './payment.provider.js';

export interface SebpayConfig {
  /**
   * https://api.sandbox.sebpay.bj/api/v1 (bac à sable, clés pk_test_/sk_test_) ou
   * https://newapi.sebpay.bj/api/v1 (réel, clés pk_live_/sk_live_, KYC approuvé).
   */
  baseUrl: string;
  /** Clé publique (X-Public-Key). */
  publicKey: string;
  /** Clé secrète (X-Secret-Key) : elle signe aussi les notifications reçues. */
  secretKey: string;
  /** Adresse publique où Sebpay envoie ses notifications (https, adresse publique). */
  callbackUrl: string;
  fetch?: typeof fetch;
}

/** Collecte ou payout tel que Sebpay le renvoie (dans `data`). */
interface SebpayTransaction {
  transaction_id?: string;
  external_reference?: string;
  status?: string;
  amount?: number | string;
  currency?: string;
  fee_amount?: number | string;
  created_at?: string;
}

interface SebpayEnvelope<T> {
  success?: boolean;
  data?: T;
  message?: string;
  errors?: { code?: string; [field: string]: unknown };
}

/** Refus explicite de Sebpay, avec son code stable (errors.code). */
export class SebpayError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | null,
    message: string,
  ) {
    super(message);
  }
}

function mapStatus(status: string | undefined): ProviderStatus {
  switch ((status ?? '').toLowerCase()) {
    case 'approved':
      return 'SUCCEEDED';
    case 'rejected':
      return 'FAILED';
    default:
      return 'PENDING';
  }
}

/** Numéro au format attendu par Sebpay : indicatif compris, sans « + » (2376XXXXXXXX). */
const msisdn = (phone: string): string => phone.replace(/^\+/, '');

/** Code de l'opérateur camerounais chez Sebpay (GET /operators : mtn-cm, orange-cm). */
const OPERATOR_CODES: Record<MobileMoneyOperator, string> = { MTN: 'mtn', ORANGE: 'orange' };

/**
 * Opérateur d'un numéro camerounais, d'après ses premiers chiffres (plan de numérotation
 * national). Null si le numéro n'est ni MTN ni Orange.
 */
export function cameroonOperator(phone: string): MobileMoneyOperator | null {
  const national = phone.replace(/^\+?237/, '');
  if (!/^6\d{8}$/.test(national)) return null;
  const head = Number(national.slice(0, 3));
  if ((head >= 670 && head <= 679) || (head >= 650 && head <= 654) || (head >= 680 && head <= 684))
    return 'MTN';
  if ((head >= 690 && head <= 699) || (head >= 655 && head <= 659) || (head >= 685 && head <= 689))
    return 'ORANGE';
  return null;
}

const amountOf = (value: number | string | undefined): number | null =>
  value === undefined || value === null ? null : Math.round(Number(value));

/**
 * Adaptateur Sebpay (agrégateur MTN Money et Orange Money au Cameroun, en XAF) : collecte
 * par demande de validation sur le téléphone, payout, statut, notifications signées par
 * HMAC-SHA256 du corps brut avec la clé secrète. Toutes les créations portent notre
 * référence (`external_reference`) : une requête renvoyée après une coupure ne crée rien
 * deux fois. Sebpay ne donne pas de relevé par période : le rapprochement relit chacune de
 * nos opérations (`lookup`). À valider sur le bac à sable avant la mise en production.
 */
export class SebpayPaymentProvider implements PaymentProvider {
  readonly name = 'sebpay';
  private readonly http: typeof fetch;

  constructor(private readonly config: SebpayConfig) {
    this.http = config.fetch ?? fetch;
  }

  private async call<T>(method: 'GET' | 'POST', path: string, body?: object): Promise<T> {
    let response: Response;
    try {
      response = await this.http(`${this.config.baseUrl.replace(/\/$/, '')}${path}`, {
        method,
        headers: {
          'X-Public-Key': this.config.publicKey,
          'X-Secret-Key': this.config.secretKey,
          Accept: 'application/json',
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(20_000),
      });
    } catch (error) {
      throw new ProviderUnavailableError(`Sebpay injoignable : ${String(error)}`);
    }
    const payload = (await response.json().catch(() => ({}))) as SebpayEnvelope<T>;
    const code = typeof payload.errors?.code === 'string' ? payload.errors.code : null;
    // Issue inconnue ou à réessayer plus tard avec la même référence : rien n'est conclu.
    if (
      response.status >= 500 ||
      response.status === 429 ||
      (response.status === 409 && code === 'REQUEST_IN_PROGRESS')
    ) {
      throw new ProviderUnavailableError(
        `Sebpay indisponible (${response.status}${code ? ` ${code}` : ''})`,
      );
    }
    if (!response.ok) {
      throw new SebpayError(
        response.status,
        code,
        `Sebpay a refusé ${method} ${path} (${response.status}${code ? ` ${code}` : ''}) : ${payload.message ?? ''}`,
      );
    }
    return (payload.data ?? (payload as unknown)) as T;
  }

  private operatorCode(phone: string, operator: MobileMoneyOperator | undefined): string {
    const resolved = operator ?? cameroonOperator(phone);
    if (!resolved) throw new Error('Numéro ni MTN ni Orange : Mobile Money impossible');
    return OPERATOR_CODES[resolved];
  }

  async collect(request: CollectRequest): Promise<ProviderOperation> {
    const body = await this.call<SebpayTransaction>('POST', '/collections', {
      amount: request.amount,
      currency: 'XAF',
      phone: msisdn(request.phone),
      operator: this.operatorCode(request.phone, request.operator),
      country: 'CM',
      external_reference: request.reference,
      callback_url: this.config.callbackUrl,
    });
    return {
      providerReference: body.transaction_id ?? request.reference,
      status: mapStatus(body.status),
    };
  }

  async disburse(request: DisburseRequest): Promise<ProviderOperation> {
    let body: SebpayTransaction;
    try {
      body = await this.call<SebpayTransaction>('POST', '/payouts', {
        recipient_name: (request.recipientName ?? 'Bénéficiaire Tara').slice(0, 180),
        phone: msisdn(request.phone),
        operator: this.operatorCode(request.phone, request.operator),
        country: 'CM',
        amount: request.amount,
        currency: 'XAF',
        external_reference: request.reference,
        callback_url: this.config.callbackUrl,
        description: request.description.slice(0, 500),
      });
    } catch (error) {
      // Solde Sebpay insuffisant : rien n'est créé, le reversement attend une recharge.
      if (error instanceof SebpayError && error.code === 'INSUFFICIENT_BALANCE')
        throw new ProviderUnavailableError(error.message);
      throw error;
    }
    const fee = amountOf(body.fee_amount);
    return {
      providerReference: body.transaction_id ?? request.reference,
      status: mapStatus(body.status),
      ...(fee !== null ? { fee } : {}),
    };
  }

  async collectStatus(providerReference: string): Promise<ProviderOperation> {
    const body = await this.call<SebpayTransaction>(
      'GET',
      `/collections/${encodeURIComponent(providerReference)}`,
    );
    return this.withCollectionFee(this.operation(body, providerReference));
  }

  async disburseStatus(reference: string): Promise<ProviderOperation | null> {
    try {
      const body = await this.call<SebpayTransaction>(
        'GET',
        `/payouts/${encodeURIComponent(reference)}`,
      );
      return this.operation(body, reference);
    } catch (error) {
      // Jamais reçu par Sebpay : on peut renvoyer sans risque de doublon.
      if (error instanceof SebpayError && error.status === 404) return null;
      throw error;
    }
  }

  private operation(body: SebpayTransaction, fallback: string): ProviderOperation {
    const amount = amountOf(body.amount);
    const fee = amountOf(body.fee_amount);
    return {
      providerReference: body.transaction_id ?? fallback,
      status: mapStatus(body.status),
      ...(amount !== null ? { amount } : {}),
      ...(fee !== null ? { fee } : {}),
    };
  }

  /**
   * Sebpay retient ses frais sur l'encaissement sans les donner dans la collecte : ils sont
   * lus au tarif du compte (GET /c/calculate-fee) une fois le paiement réussi.
   */
  private async withCollectionFee(operation: ProviderOperation): Promise<ProviderOperation> {
    if (operation.status !== 'SUCCEEDED' || operation.amount === undefined) return operation;
    if (operation.fee !== undefined) return operation;
    const query = new URLSearchParams({
      amount: String(operation.amount),
      source_country: 'cm',
      transaction_type: 'collection',
    });
    const fee = await this.call<{ fee_amount?: number | string }>(
      'GET',
      `/c/calculate-fee?${query.toString()}`,
    );
    const value = amountOf(fee.fee_amount);
    return value === null ? operation : { ...operation, fee: value };
  }

  /** Signature : HMAC-SHA256 hexadécimal du corps brut, avec la clé secrète. */
  parseWebhook(input: WebhookInput): Promise<ProviderEvent> {
    const header = input.headers['x-sebpay-signature'];
    const signature = (Array.isArray(header) ? header[0] : header) ?? '';
    const raw = input.rawBody;
    if (!raw || !/^[0-9a-f]{64}$/i.test(signature)) {
      return Promise.reject(new InvalidWebhookError('Signature Sebpay absente'));
    }
    const expected = createHmac('sha256', this.config.secretKey).update(raw).digest();
    const received = Buffer.from(signature, 'hex');
    if (received.length !== expected.length || !timingSafeEqual(received, expected)) {
      return Promise.reject(new InvalidWebhookError('Signature Sebpay invalide'));
    }
    let body: SebpayTransaction;
    try {
      body = JSON.parse(raw.toString('utf8')) as SebpayTransaction;
    } catch {
      return Promise.reject(new InvalidWebhookError('Notification Sebpay illisible'));
    }
    const providerReference = body.transaction_id ?? '';
    if (!providerReference) {
      return Promise.reject(new InvalidWebhookError('Notification Sebpay sans transaction'));
    }
    const status = mapStatus(body.status);
    return Promise.resolve({
      eventId: `${providerReference}:${status}`,
      reference: body.external_reference ?? null,
      providerReference,
      status,
      amount: amountOf(body.amount),
    });
  }

  /**
   * Sebpay recommande de relire la transaction avant de livrer : la lecture revérifie auprès
   * de l'opérateur et donne les frais. La notification ne dit pas s'il s'agit d'une collecte
   * ou d'un payout : la collecte est lue d'abord.
   */
  async confirmEvent(event: ProviderEvent): Promise<ProviderEvent> {
    const found =
      (await this.find('COLLECT', event.providerReference)) ??
      (await this.find('DISBURSE', event.providerReference));
    if (!found) return { ...event, status: 'PENDING' };
    return {
      ...event,
      status: found.status,
      amount: found.amount,
      ...(found.fee ? { fee: found.fee } : {}),
      reference: found.reference ?? event.reference,
    };
  }

  /** Relit une collecte ou un payout par notre référence ou celle de Sebpay ; null s'il est inconnu. */
  async lookup(kind: OperationKind, reference: string): Promise<ProviderTransaction | null> {
    return this.find(kind, reference);
  }

  private async find(kind: OperationKind, reference: string): Promise<ProviderTransaction | null> {
    const path = kind === 'COLLECT' ? '/collections/' : '/payouts/';
    let body: SebpayTransaction;
    try {
      body = await this.call<SebpayTransaction>('GET', `${path}${encodeURIComponent(reference)}`);
    } catch (error) {
      if (error instanceof SebpayError && error.status === 404) return null;
      throw error;
    }
    const operation =
      kind === 'COLLECT'
        ? await this.withCollectionFee(this.operation(body, reference))
        : this.operation(body, reference);
    return {
      providerReference: operation.providerReference,
      reference: body.external_reference ?? null,
      kind,
      amount: operation.amount ?? 0,
      fee: operation.fee ?? 0,
      status: operation.status,
      at: body.created_at ? new Date(body.created_at) : new Date(),
    };
  }
}
