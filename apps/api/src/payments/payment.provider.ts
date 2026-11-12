import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import type { Redis } from 'ioredis';

export const PAYMENT_PROVIDER = Symbol('PAYMENT_PROVIDER');

export type ProviderStatus = 'PENDING' | 'SUCCEEDED' | 'FAILED';
export type OperationKind = 'COLLECT' | 'DISBURSE';
export type MobileMoneyOperator = 'MTN' | 'ORANGE';

export interface CollectRequest {
  /** Notre référence (identifiant du paiement), renvoyée par le prestataire. */
  reference: string;
  amount: number;
  /** Payeur, +2376XXXXXXXX : il reçoit une demande de validation sur son téléphone. */
  phone: string;
  /** Opérateur choisi par le payeur ; sinon déduit du numéro par le prestataire. */
  operator?: MobileMoneyOperator;
  description: string;
}

export interface DisburseRequest {
  /** Notre référence (identifiant du reversement) : le prestataire la garde. */
  reference: string;
  amount: number;
  phone: string;
  operator?: MobileMoneyOperator;
  /** Nom du bénéficiaire (exigé par certains prestataires). */
  recipientName?: string;
  description: string;
}

export interface ProviderOperation {
  providerReference: string;
  status: ProviderStatus;
  /** Montant réellement traité, quand le prestataire le donne (contrôlé à la confirmation). */
  amount?: number;
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
  /**
   * Revérifie une notification auprès du prestataire (statut et montant lus par son API)
   * quand la signature n'engage pas le contenu de la notification.
   */
  confirmEvent?(event: ProviderEvent): Promise<ProviderEvent>;
  /**
   * Relevé du prestataire sur une période (rapprochement). Absent chez un prestataire qui
   * n'en donne pas : chaque opération est alors relue une à une (`lookup`).
   */
  transactions?(from: Date, to: Date): Promise<ProviderTransaction[]>;
  /** Relit une opération par notre référence ; null si le prestataire ne la connaît pas. */
  lookup?(kind: OperationKind, reference: string): Promise<ProviderTransaction | null>;
}

// --- Prestataire factice --------------------------------------------------------------------

interface FakeOperation extends ProviderTransaction {
  phone: string;
  failureReason?: string;
}

const FAKE_SECRET = 'tara-fake-payment-webhook';
const STORE_KEY = 'fake-payment-provider:operations';

/**
 * Prestataire factice pour le développement, les tests et le simulateur. Il garde ses
 * propres opérations (son « relevé ») et sait simuler les incidents réels : refus du payeur,
 * coupure réseau APRÈS exécution d'un envoi, notifications répétées.
 */
export class FakePaymentProvider implements PaymentProvider {
  readonly name = 'fake';
  /**
   * Relevé du prestataire factice, gardé aussi dans Redis quand il est fourni : comme chez un
   * vrai prestataire, il survit au redémarrage de l'API (rapprochement, simulateur).
   */
  constructor(private readonly store: Redis | null = null) {}

  readonly operations = new Map<string, FakeOperation>();
  /** Payeurs qui refusent ou n'ont pas assez d'argent. */
  readonly decliningPhones = new Set<string>();
  /** Numéros que l'opérateur refuse comme destinataires (numéro inconnu, compte bloqué). */
  readonly refusingPhones = new Set<string>();
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

  private async persist(operation: FakeOperation): Promise<void> {
    await this.store?.hset(STORE_KEY, operation.providerReference, JSON.stringify(operation));
  }

  private async load(providerReference: string): Promise<FakeOperation | undefined> {
    const local = this.operations.get(providerReference);
    if (local || !this.store) return local;
    const raw = await this.store.hget(STORE_KEY, providerReference);
    if (!raw) return undefined;
    const parsed = JSON.parse(raw) as FakeOperation;
    const operation: FakeOperation = { ...parsed, at: new Date(parsed.at) };
    this.operations.set(providerReference, operation);
    return operation;
  }

  private async all(): Promise<FakeOperation[]> {
    const merged = new Map<string, FakeOperation>();
    for (const raw of this.store ? await this.store.hvals(STORE_KEY) : []) {
      const parsed = JSON.parse(raw) as FakeOperation;
      merged.set(parsed.providerReference, { ...parsed, at: new Date(parsed.at) });
    }
    for (const operation of this.operations.values())
      merged.set(operation.providerReference, operation);
    return [...merged.values()];
  }

  async collect(request: CollectRequest): Promise<ProviderOperation> {
    const operation = this.record('COLLECT', request.reference, request.amount, request.phone);
    if (this.decliningPhones.has(request.phone)) {
      operation.status = 'FAILED';
      operation.failureReason = 'Solde insuffisant';
    }
    await this.persist(operation);
    return this.view(operation);
  }

  async disburse(request: DisburseRequest): Promise<ProviderOperation> {
    const operation = this.record('DISBURSE', request.reference, request.amount, request.phone);
    operation.status = 'SUCCEEDED';
    if (this.refusingPhones.has(request.phone)) {
      operation.status = 'FAILED';
      operation.failureReason = 'Numéro Mobile Money inconnu de l’opérateur';
    }
    await this.persist(operation);
    if (this.loseResponseOnce.delete(request.reference)) {
      throw new ProviderUnavailableError('Délai dépassé (réponse perdue)');
    }
    return this.view(operation);
  }

  async collectStatus(providerReference: string): Promise<ProviderOperation> {
    const operation = await this.load(providerReference);
    if (!operation) throw new Error('Opération inconnue');
    return this.view(operation);
  }

  async disburseStatus(reference: string): Promise<ProviderOperation | null> {
    const operation = (await this.all()).find(
      (candidate) => candidate.kind === 'DISBURSE' && candidate.reference === reference,
    );
    return operation ? this.view(operation) : null;
  }

  /** Le payeur valide (ou refuse) sur son téléphone : renvoie la notification signée. */
  async settle(
    providerReference: string,
    status: 'SUCCEEDED' | 'FAILED',
  ): Promise<{ body: string; signature: string }> {
    const operation = await this.load(providerReference);
    if (!operation) throw new Error(`Opération inconnue : ${providerReference}`);
    operation.status = status;
    await this.persist(operation);
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

  async transactions(from: Date, to: Date): Promise<ProviderTransaction[]> {
    return (await this.all())
      .filter((operation) => operation.at >= from && operation.at < to)
      .map(({ phone: _phone, failureReason: _reason, ...transaction }) => ({ ...transaction }));
  }

  async lookup(kind: OperationKind, reference: string): Promise<ProviderTransaction | null> {
    const found = (await this.all()).find(
      (operation) =>
        operation.kind === kind &&
        (operation.reference === reference || operation.providerReference === reference),
    );
    if (!found) return null;
    const { phone: _phone, failureReason: _reason, ...transaction } = found;
    return { ...transaction };
  }

  private view(operation: FakeOperation): ProviderOperation {
    return {
      providerReference: operation.providerReference,
      status: operation.status,
      amount: operation.amount,
      fee: operation.fee,
      ...(operation.failureReason ? { failureReason: operation.failureReason } : {}),
    };
  }
}
