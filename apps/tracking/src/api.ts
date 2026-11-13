/** Ce que l'API renvoie à la page de suivi (schéma `PublicTracking` de apps/api/openapi.json). */
export interface PublicTracking {
  reference: string;
  status: OrderStatus;
  senderName: string | null;
  recipientName: string;
  dropoffLandmark: string;
  dropoffNeighborhood: string | null;
  scheduledFor: string | null;
  recipientConfirmedAt: string | null;
  recipientAvailable: boolean | null;
  canRespond: boolean;
  timeline: { status: OrderStatus; at: string }[];
  rider: {
    name: string;
    vehicleType: 'MOTORBIKE' | 'TRICYCLE' | 'CAR';
    plateNumber: string | null;
    phone: string | null;
  } | null;
  eta: { minutes: number; distanceMeters: number; progress: number } | null;
  due: { fee: number; cod: number; total: number };
  /** Frais ajoutés si le destinataire paie par Mobile Money. */
  mobileMoneyFee: number;
  paymentPending: { amount: number } | null;
  failureDecision: 'RETRY' | 'RETURN' | null;
}

export type OrderStatus =
  | 'CREATED'
  | 'SEARCHING_RIDER'
  | 'ASSIGNED'
  | 'PICKED_UP'
  | 'IN_DELIVERY'
  | 'DELIVERY_FAILED'
  | 'DELIVERED'
  | 'RETURNED'
  | 'CANCELLED';

/** Champs lus par la page (vérifiés contre le contrat de l'API par les tests). */
export const PUBLIC_TRACKING_FIELDS: (keyof PublicTracking)[] = [
  'reference',
  'status',
  'senderName',
  'recipientName',
  'dropoffLandmark',
  'dropoffNeighborhood',
  'scheduledFor',
  'recipientConfirmedAt',
  'recipientAvailable',
  'canRespond',
  'timeline',
  'rider',
  'eta',
  'due',
  'mobileMoneyFee',
  'paymentPending',
  'failureDecision',
];

export type RespondResult = 'ok' | 'already' | 'not-found';

/** Lien de localisation vu par le destinataire (schéma `PublicLocationLink`). */
export interface PublicLocationLink {
  senderName: string | null;
  recipientName: string | null;
  expiresAt: string;
  status: 'PENDING' | 'SUBMITTED' | 'EXPIRED';
}

export const PUBLIC_LOCATION_LINK_FIELDS: (keyof PublicLocationLink)[] = [
  'senderName',
  'recipientName',
  'expiresAt',
  'status',
];

/** Point placé par le destinataire (schéma `PublicLocationSubmitBody`). */
export interface LocationSubmit {
  latitude: number;
  longitude: number;
  landmark: string;
  contactName?: string;
  contactPhone?: string;
}

export type SubmitResult = 'ok' | 'already' | 'expired' | 'not-found' | 'out-of-area' | 'invalid';

/** Accès à l'API ; `clientIp` est transmis pour que la limite de débit vise le visiteur. */
export interface TrackingApi {
  /** null : lien inconnu. Lève une erreur si l'API ne répond pas. */
  view(token: string, clientIp?: string): Promise<PublicTracking | null>;
  respond(
    token: string,
    body: { available: boolean; note?: string },
    clientIp?: string,
  ): Promise<RespondResult>;
  /** null : lien de localisation inconnu. */
  locationLink(token: string, clientIp?: string): Promise<PublicLocationLink | null>;
  submitLocation(token: string, body: LocationSubmit, clientIp?: string): Promise<SubmitResult>;
}

export class ApiUnavailableError extends Error {}

/** Le jeton du lien : celui que l'API accepte, rien d'autre n'est relayé. */
export const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

const TIMEOUT_MS = 6_000;

export function httpApi(baseUrl: string, fetcher: typeof fetch = fetch): TrackingApi {
  const base = baseUrl.replace(/\/$/, '');
  const root = `${base}/v1/public/tracking`;
  const links = `${base}/v1/public/location-links`;
  const headers = (clientIp?: string): Record<string, string> => ({
    accept: 'application/json',
    ...(clientIp ? { 'x-forwarded-for': clientIp } : {}),
  });
  async function call(input: string, init: RequestInit): Promise<Response> {
    try {
      return await fetcher(input, { ...init, signal: AbortSignal.timeout(TIMEOUT_MS) });
    } catch (error) {
      throw new ApiUnavailableError('API injoignable', { cause: error });
    }
  }
  return {
    async view(token, clientIp) {
      const response = await call(`${root}/${encodeURIComponent(token)}`, {
        headers: headers(clientIp),
      });
      if (response.status === 404) return null;
      if (!response.ok) throw new ApiUnavailableError(`API : ${response.status}`);
      return (await response.json()) as PublicTracking;
    },
    async respond(token, body, clientIp) {
      const response = await call(`${root}/${encodeURIComponent(token)}/response`, {
        method: 'POST',
        headers: { ...headers(clientIp), 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (response.status === 404) return 'not-found';
      if (response.status === 409) return 'already';
      if (!response.ok) throw new ApiUnavailableError(`API : ${response.status}`);
      return 'ok';
    },
    async locationLink(token, clientIp) {
      const response = await call(`${links}/${encodeURIComponent(token)}`, {
        headers: headers(clientIp),
      });
      if (response.status === 404) return null;
      if (!response.ok) throw new ApiUnavailableError(`API : ${response.status}`);
      return (await response.json()) as PublicLocationLink;
    },
    async submitLocation(token, body, clientIp) {
      const response = await call(`${links}/${encodeURIComponent(token)}`, {
        method: 'POST',
        headers: { ...headers(clientIp), 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (response.ok) return 'ok';
      if (response.status === 404) return 'not-found';
      if (response.status === 409) return 'already';
      if (response.status === 410) return 'expired';
      if (response.status === 400) return 'invalid';
      if (response.status === 422) {
        const error = (await response.json().catch(() => null)) as {
          error?: { code?: string };
        } | null;
        return error?.error?.code === 'OUT_OF_SERVICE_AREA' ? 'out-of-area' : 'invalid';
      }
      throw new ApiUnavailableError(`API : ${response.status}`);
    },
  };
}
