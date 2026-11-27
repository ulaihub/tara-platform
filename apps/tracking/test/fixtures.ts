import type {
  LocationSubmit,
  OrderStatus,
  PublicLocationLink,
  PublicReceipt,
  PublicTracking,
  ResendResult,
  RespondResult,
  SubmitResult,
  TrackingApi,
} from '../src/api.js';

export const TOKEN = 'k3Jx9Qm2Lp7Vw4Rz8Ty1';

/** 4 novembre 2026, 10:20 à Douala (09:20 UTC). */
export const NOW = new Date('2026-11-04T09:20:00Z');

const at = (time: string) => `2026-11-04T${time}:00.000Z`;

/** Commande d'Awa Fashion pour Marie, à l'étape [status]. */
export function tracking(status: OrderStatus, patch: Partial<PublicTracking> = {}): PublicTracking {
  const order: OrderStatus[] = [
    'CREATED',
    'SEARCHING_RIDER',
    'ASSIGNED',
    'PICKED_UP',
    'IN_DELIVERY',
  ];
  const reachedIndex = order.indexOf(status);
  const times: Record<string, string> = {
    CREATED: at('09:02'),
    SEARCHING_RIDER: at('09:02'),
    ASSIGNED: at('09:04'),
    PICKED_UP: at('09:12'),
    IN_DELIVERY: at('09:13'),
  };
  const timeline = order
    .filter((s, i) => reachedIndex === -1 || i <= reachedIndex)
    .map((s) => ({ status: s, at: times[s] ?? at('09:02') }));
  if (status === 'DELIVERY_FAILED') timeline.push({ status, at: at('09:18') });
  if (status === 'DELIVERED') timeline.push({ status, at: at('09:35') });
  if (status === 'RETURNED' || status === 'HELD_AT_OFFICE' || status === 'UNCLAIMED')
    timeline.push({ status: 'DELIVERY_FAILED', at: at('09:18') }, { status, at: at('09:50') });
  const withRider = !['CREATED', 'SEARCHING_RIDER', 'CANCELLED'].includes(status);
  const coming = ['PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'].includes(status);
  return {
    reference: 'TR-48301',
    status,
    senderName: 'Awa Fashion',
    recipientName: 'Marie Ngo',
    dropoffLandmark: 'Face pharmacie du Rond-point',
    dropoffNeighborhood: 'Bonapriso',
    scheduledFor: null,
    recipientConfirmedAt: null,
    recipientAvailable: null,
    canRespond: ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'].includes(status),
    timeline,
    rider: withRider
      ? {
          name: 'Jean M.',
          vehicleType: 'MOTORBIKE',
          plateNumber: 'LT 482 KQ',
          phone: coming ? '+237677445566' : null,
        }
      : null,
    eta: status === 'IN_DELIVERY' ? { minutes: 8, distanceMeters: 2350, progress: 0.62 } : null,
    due: { fee: 1500, cod: 12500, total: 14000 },
    mobileMoneyFee: 0,
    paymentPending: null,
    failureDecision: null,
    deliveryCode: ['PICKED_UP', 'IN_DELIVERY'].includes(status)
      ? { phone: '+237 6•• •• 22 33', sentAt: at('09:12'), resendsLeft: 3 }
      : null,
    map: {
      dropoff: { latitude: 4.0318, longitude: 9.6905 },
      rider: status === 'IN_DELIVERY' ? { latitude: 4.0405, longitude: 9.695 } : null,
    },
    ...patch,
  };
}

/** Lien de localisation d'Awa Fashion pour Marie, valable jusqu'au 6 novembre 18:00 (Douala). */
export function locationLink(patch: Partial<PublicLocationLink> = {}): PublicLocationLink {
  return {
    senderName: 'Awa Fashion',
    recipientName: 'Marie Ngo',
    expiresAt: '2026-11-06T17:00:00.000Z',
    status: 'PENDING',
    ...patch,
  };
}

/** Reçu authentique : course livrée, payée, encaissement pour l'expéditeur. */
export function receipt(patch: Partial<PublicReceipt> = {}): PublicReceipt {
  return {
    reference: 'TR-48301K',
    status: 'DELIVERED',
    issuedAt: '2026-11-19T13:32:00.000Z',
    senderName: 'Awa Fashion',
    recipientName: 'Marie N.',
    dropoffNeighborhood: 'Bonapriso',
    fee: 1200,
    feePaid: true,
    deliveredAt: '2026-11-19T14:24:00.000Z',
    collectedForSender: 15000,
    ...patch,
  };
}

export const RECEIPT_CODE = 'TR-48301K-4F8M2XQA';

/** API sans réseau : renvoie [data], garde les réponses du destinataire. */
export class FakeApi implements TrackingApi {
  constructor(public data: PublicTracking | null = tracking('IN_DELIVERY')) {}
  down = false;
  link: PublicLocationLink | null = locationLink();
  submitResult: SubmitResult = 'ok';
  submissions: { token: string; body: LocationSubmit; ip?: string }[] = [];
  respondResult: RespondResult = 'ok';
  responses: { token: string; body: { available: boolean; note?: string }; ip?: string }[] = [];
  views: { token: string; ip?: string }[] = [];

  async view(token: string, ip?: string): Promise<PublicTracking | null> {
    this.views.push({ token, ...(ip ? { ip } : {}) });
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    return this.data;
  }

  async respond(
    token: string,
    body: { available: boolean; note?: string },
    ip?: string,
  ): Promise<RespondResult> {
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    this.responses.push({ token, body, ...(ip ? { ip } : {}) });
    return this.respondResult;
  }

  async locationLink(token: string, ip?: string): Promise<PublicLocationLink | null> {
    this.views.push({ token, ...(ip ? { ip } : {}) });
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    return this.link;
  }

  receiptData: PublicReceipt | null = receipt();
  receiptCodes: string[] = [];

  async receipt(code: string): Promise<PublicReceipt | null> {
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    this.receiptCodes.push(code);
    return this.receiptData;
  }

  resendResult: ResendResult = 'sent';
  resends: string[] = [];

  async resendCode(token: string): Promise<ResendResult> {
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    this.resends.push(token);
    return this.resendResult;
  }

  async submitLocation(token: string, body: LocationSubmit, ip?: string): Promise<SubmitResult> {
    if (this.down) throw new (await import('../src/api.js')).ApiUnavailableError('panne');
    this.submissions.push({ token, body, ...(ip ? { ip } : {}) });
    if (this.submitResult === 'ok' && this.link) this.link = { ...this.link, status: 'SUBMITTED' };
    return this.submitResult;
  }
}
