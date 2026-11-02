import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

export const PAYMENT_PROVIDER = Symbol('PAYMENT_PROVIDER');

export type ProviderStatus = 'PENDING' | 'SUCCEEDED' | 'FAILED';
export type OperationKind = 'COLLECT' | 'DISBURSE';

export interface CollectRequest {
  /** Notre référence (identifiant du paiement), renvoyée par le prestataire. */
  reference: string;
  amount: number;
  /** Payeur, +2376XXXXXXXX : il reçoit une demande de validation sur son téléphone. */
  phone: string;
  description: string;
}

export interface DisburseRequest {
  /** Notre référence (identifiant du reversement) : le prestataire la garde. */
  reference: string;
  amount: number;
  phone: string;
  description: string;
}

export interface ProviderOperation {
  providerReference: string;
  status: ProviderStatus;
  /** Frais retenus par le prestataire, s'il les communique. */
  fee?: number;
  failureReason?: string;
}

export interface ProviderEvent {
  /** Identifiant unique de la notification (dédoublonnage). */
  eventId: string;
  reference: string | null;
  providerReference: string;
  status: ProviderStatus;
  amount: number | null;
  fee?: number;
  failureReason?: string;
}

export interface ProviderTransaction {
  providerReference: string;
  reference: string | null;
  kind: OperationKind;
  amount: number;
  fee: number;
  status: ProviderStatus;
  at: Date;
}

export interface WebhookInput {
  rawBody: Buffer | undefined;
  headers: Record<string, string | string[] | undefined>;
  query: Record<string, unknown>;
  body: unknown;
}

/** Le prestataire n'a pas répondu (coupure, délai) : l'issue de l'opération est inconnue. */
export class ProviderUnavailableError extends Error {}
export class InvalidWebhookError extends Error {}

/**
 * Agrégateur Mobile Money (MTN MoMo et Orange Money derrière une seule API). Toute la
 * logique financière passe par cette interface : changer d'agrégateur ne touche qu'une
 * implémentation.
 */
export interface PaymentProvider {
  readonly name: string;
  /** Demande de paiement envoyée au téléphone du payeur (validation par code secret). */
  collect(request: CollectRequest): Promise<ProviderOperation>;
  /** Envoi d'argent vers un compte Mobile Money. */
  disburse(request: DisburseRequest): Promise<ProviderOperation>;
  collectStatus(providerReference: string): Promise<ProviderOperation>;
  /**
   * Statut d'un envoi retrouvé par NOTRE référence ; null si le prestataire ne l'a jamais
   * reçu (on peut alors renvoyer sans risque de doublon).
   */
  disburseStatus(reference: string): Promise<ProviderOperation | null>;
  /** Vérifie la signature d'une notification et en extrait l'événement. */
  parseWebhook(input: WebhookInput): Promise<ProviderEvent>;
  /** Relevé du prestataire sur une période (rapprochement). */
  transactions(from: Date, to: Date): Promise<ProviderTransaction[]>;
}

// --- Prestataire factice --------------------------------------------------------------------

interface FakeOperation extends ProviderTransaction {
  phone: string;
  failureReason?: string;
}

const FAKE_SECRET = 'tara-fake-payment-webhook';

/**
 * Prestataire factice pour le développement, les tests et le simulateur. Il garde ses
 * propres opérations (son « relevé ») et sait simuler les incidents réels : refus du payeur,
 * coupure réseau APRÈS exécution d'un envoi, notifications répétées.
 */
export class FakePaymentProvider implements PaymentProvider {
  readonly name = 'fake';
  readonly operations = new Map<string, FakeOperation>();
  /** Payeurs qui refusent ou n'ont pas assez d'argent. */
  readonly decliningPhones = new Set<string>();
  /** Références d'envoi pour lesquelles la réponse se perd, une fois, après exécution. */
  readonly loseResponseOnce = new Set<string>();
  /** Frais retenus, en points de base. */
  collectFeeBps = 0;
  disburseFeeBps = 0;

  private record(
    kind: OperationKind,
    reference: string,
    amount: number,
    phone: string,
  ): FakeOperation {
    const operation: FakeOperation = {
      // Unique d'une exécution à l'autre, comme chez un vrai prestataire.
      providerReference: `fake-${kind.toLowerCase()}-${randomUUID()}`,
      reference,
      kind,
      amount,
      fee: Math.round(
        (amount * (kind === 'COLLECT' ? this.collectFeeBps : this.disburseFeeBps)) / 10_000,
      ),
      status: 'PENDING',
      at: new Date(),
      phone,
    };
    this.operations.set(operation.providerReference, operation);
    return operation;
  }

  collect(request: CollectRequest): Promise<ProviderOperation> {
    const operation = this.record('COLLECT', request.reference, request.amount, request.phone);
    if (this.decliningPhones.has(request.phone)) {
      operation.status = 'FAILED';
      operation.failureReason = 'Solde insuffisant';
    }
    return Promise.resolve(this.view(operation));
  }

  disburse(request: DisburseRequest): Promise<ProviderOperation> {
    const operation = this.record('DISBURSE', request.reference, request.amount, request.phone);
    operation.status = 'SUCCEEDED';
    if (this.loseResponseOnce.delete(request.reference)) {
      return Promise.reject(new ProviderUnavailableError('Délai dépassé (réponse perdue)'));
    }
    return Promise.resolve(this.view(operation));
  }

  collectStatus(providerReference: string): Promise<ProviderOperation> {
    const operation = this.operations.get(providerReference);
    if (!operation) return Promise.reject(new Error('Opération inconnue'));
    return Promise.resolve(this.view(operation));
  }

  disburseStatus(reference: string): Promise<ProviderOperation | null> {
    const operation = [...this.operations.values()].find(
      (candidate) => candidate.kind === 'DISBURSE' && candidate.reference === reference,
    );
    return Promise.resolve(operation ? this.view(operation) : null);
  }

  /** Le payeur valide (ou refuse) sur son téléphone : renvoie la notification signée. */
  settle(
    providerReference: string,
    status: 'SUCCEEDED' | 'FAILED',
  ): { body: string; signature: string } {
    const operation = this.operations.get(providerReference);
    if (!operation) throw new Error(`Opération inconnue : ${providerReference}`);
    operation.status = status;
    return this.webhookFor(operation);
  }

  webhookFor(operation: FakeOperation): { body: string; signature: string } {
    const body = JSON.stringify({
      eventId: `${operation.providerReference}:${operation.status}`,
      reference: operation.reference,
      providerReference: operation.providerReference,
      status: operation.status,
      amount: operation.amount,
      fee: operation.fee,
    });
    return { body, signature: createHmac('sha256', FAKE_SECRET).update(body).digest('hex') };
  }

  /** Nombre d'envois réellement exécutés pour une référence (détection des doublons). */
  disbursementsFor(reference: string): number {
    return [...this.operations.values()].filter(
      (operation) => operation.kind === 'DISBURSE' && operation.reference === reference,
    ).length;
  }

  parseWebhook(input: WebhookInput): Promise<ProviderEvent> {
    const raw = input.rawBody?.toString('utf8') ?? '';
    const header = input.headers['x-fake-signature'];
    const expected = createHmac('sha256', FAKE_SECRET).update(raw).digest('hex');
    if (
      typeof header !== 'string' ||
      header.length !== expected.length ||
      !timingSafeEqual(Buffer.from(header), Buffer.from(expected))
    ) {
      return Promise.reject(new InvalidWebhookError('Signature invalide'));
    }
    return Promise.resolve(JSON.parse(raw) as ProviderEvent);
  }

  transactions(from: Date, to: Date): Promise<ProviderTransaction[]> {
    return Promise.resolve(
      [...this.operations.values()]
        .filter((operation) => operation.at >= from && operation.at < to)
        .map(({ phone: _phone, failureReason: _reason, ...transaction }) => ({ ...transaction })),
    );
  }

  private view(operation: FakeOperation): ProviderOperation {
    return {
      providerReference: operation.providerReference,
      status: operation.status,
      fee: operation.fee,
      ...(operation.failureReason ? { failureReason: operation.failureReason } : {}),
    };
  }
}
