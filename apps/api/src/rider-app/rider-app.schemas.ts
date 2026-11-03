import { z } from 'zod';
import { PageQuery } from '../common/pagination.js';
import { AddressDto, Latitude, Longitude } from '../geo/geo.schemas.js';
import { FailureReasonEnum, OrderStatusEnum } from '../orders/orders.schemas.js';
import { PackageSizeEnum } from '../pricing/pricing.schemas.js';

const Code4 = z.string().regex(/^\d{4}$/, 'quatre chiffres attendus');
const MediaKey = z.string().min(1).max(200);

/**
 * Champs communs aux actions du livreur. Hors réseau, l'app les met en file avec l'heure
 * et la position du moment, et un identifiant unique : renvoyer la même action au retour
 * du réseau ne la refait pas (E7).
 */
const ActionContext = {
  latitude: Latitude,
  longitude: Longitude,
  /** Heure de l'action sur le téléphone, si elle a été faite hors ligne. */
  occurredAt: z.iso.datetime().optional(),
  /** Identifiant unique de l'action généré par l'app (UUID conseillé). */
  clientEventId: z
    .string()
    .regex(/^[A-Za-z0-9_-]{8,100}$/)
    .optional(),
};

export const PositionBody = z.object({
  latitude: Latitude,
  longitude: Longitude,
  /** Cap en degrés, vitesse en m/s, précision en mètres. */
  heading: z.number().min(0).max(360).optional(),
  speed: z.number().min(0).max(100).optional(),
  accuracy: z.number().min(0).max(10_000).optional(),
  recordedAt: z.iso.datetime().optional(),
  /** Position simulée signalée par le téléphone (application de fausse position). */
  mocked: z.boolean().optional(),
});

export const PresenceBody = PositionBody.extend({ online: z.boolean() });

export const PresenceDto = z
  .object({
    online: z.boolean(),
    /** Raisons qui empêchent de recevoir des courses (pièces expirées…), vide sinon. */
    blockers: z.array(z.string()),
  })
  .meta({ id: 'RiderPresence' });

export const PickupBody = z.object({
  pickupCode: Code4,
  photoKey: MediaKey,
  ...ActionContext,
});

export const PositionActionBody = z.object({ ...ActionContext });

export const DeliverBody = z.object({
  /** Code donné par le destinataire. Sans code, la livraison attend la validation du support. */
  deliveryCode: Code4.optional(),
  photoKey: MediaKey,
  ...ActionContext,
});

export const CallLogEntry = z.object({
  to: z.enum(['RECIPIENT', 'SENDER']),
  at: z.iso.datetime(),
  durationSeconds: z.int().min(0).max(3_600),
});

export const FailBody = z.object({
  reason: FailureReasonEnum,
  note: z.string().trim().max(300).optional(),
  photoKey: MediaKey,
  /** Appels passés avant de déclarer l'échec (E6) : au moins un. */
  callLog: z.array(CallLogEntry).min(1).max(20),
  ...ActionContext,
});

export const ReturnBody = z.object({
  /** Code de l'expéditeur, celui donné à l'enlèvement. */
  senderCode: Code4,
  photoKey: MediaKey.optional(),
  ...ActionContext,
});

export const ReleaseBody = z.object({ reason: z.string().trim().min(3).max(300) });

export const SafetyAlertBody = z.object({
  latitude: Latitude,
  longitude: Longitude,
  orderId: z.uuid().optional(),
  note: z.string().trim().max(300).optional(),
});

/** Position actuelle du livreur, d'où part l'itinéraire. */
export const RouteQuery = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
});

/** Itinéraire vers la prochaine étape de la course (E2), à dessiner sur la carte. */
export const RiderRouteDto = z
  .object({
    /** Étape visée : le vendeur (enlèvement ou retour) ou le destinataire. */
    stop: z.enum(['PICKUP', 'DROPOFF']),
    meters: z.int(),
    seconds: z.int().nullable(),
    /** « osrm » : tracé routier ; « estimate » : ligne droite, distance estimée. */
    source: z.enum(['osrm', 'estimate']),
    /** Tracé en paires [longitude, latitude] (ordre GeoJSON). */
    path: z.array(z.tuple([z.number(), z.number()])).min(2),
  })
  .meta({ id: 'RiderRoute' });

export const RiderOrdersQuery = PageQuery.extend({
  scope: z.enum(['active', 'history']).default('active'),
});

const Party = z.object({ name: z.string().nullable(), phone: z.string().nullable() });

/** Course vue par le livreur (E2) : contacts visibles seulement tant qu'elle est en cours. */
export const RiderOrderDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    packageSize: PackageSizeEnum,
    isFragile: z.boolean(),
    isExpress: z.boolean(),
    instructions: z.string().nullable(),
    pickup: AddressDto,
    dropoff: AddressDto,
    sender: Party,
    recipient: Party,
    riderEarning: z.int(),
    /** Espèces à encaisser à l'enlèvement (frais payés par l'expéditeur en espèces). */
    collectAtPickup: z.int(),
    /** Espèces ou Mobile Money à encaisser à la livraison (frais du destinataire + COD). */
    collectAtDelivery: z.int(),
    /** Liens d'itinéraire vers la prochaine étape (E2). */
    navigation: z.object({ googleMaps: z.url(), waze: z.url() }).nullable(),
    failureDecision: z.enum(['RETRY', 'RETURN']).nullable(),
    /** Livraison sans code déclarée, en attente de la validation du support (E4). */
    awaitingSupportValidation: z.boolean(),
    assignedAt: z.iso.datetime().nullable(),
    pickedUpAt: z.iso.datetime().nullable(),
    deliveredAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'RiderOrder' });

export const EarningsQuery = z.object({ period: z.enum(['day', 'week', 'month']).default('day') });

export const EarningsDto = z
  .object({
    period: z.enum(['day', 'week', 'month']),
    from: z.iso.datetime(),
    to: z.iso.datetime(),
    delivered: z.int(),
    failed: z.int(),
    returned: z.int(),
    /** Gains des courses terminées sur la période, en FCFA. */
    earnings: z.int(),
    /** Espèces encaissées sur la période (à déposer). */
    cashCollected: z.int(),
    /** Temps passé en ligne sur la période, en secondes. */
    onlineSeconds: z.int(),
    /**
     * Histogramme : tranches de 2 h de 6 h à 22 h (jour), jours du lundi au dimanche
     * (semaine), semaines du mois à partir du 1er, 8, 15, 22 et 29 (mois). L'app
     * affiche les libellés dans la langue du livreur.
     */
    bucket: z.enum(['two_hours', 'day', 'week']),
    series: z.array(z.object({ start: z.iso.datetime(), earnings: z.int(), delivered: z.int() })),
  })
  .meta({ id: 'RiderEarnings' });

export const SafetyAlertDto = z
  .object({
    id: z.uuid(),
    riderId: z.uuid(),
    riderName: z.string().nullable(),
    riderPhone: z.string(),
    orderId: z.uuid().nullable(),
    latitude: z.number(),
    longitude: z.number(),
    note: z.string().nullable(),
    createdAt: z.iso.datetime(),
    acknowledgedAt: z.iso.datetime().nullable(),
    resolvedAt: z.iso.datetime().nullable(),
    /** Annulée par le livreur : l'équipe le rappelle avant de clore. */
    cancelledAt: z.iso.datetime().nullable(),
    resolution: z.string().nullable(),
  })
  .meta({ id: 'SafetyAlert' });

export const SafetyAlertListQuery = z.object({ status: z.enum(['open', 'all']).default('open') });
export const ResolveAlertBody = z.object({ resolution: z.string().trim().min(3).max(500) });
export const ValidateDeliveryBody = z.object({ note: z.string().trim().min(3).max(300) });
export const FailureDecisionBody = z.object({ decision: z.enum(['RETRY', 'RETURN']) });

/** Réglages de l'app livreur venant du serveur : rien de propre au pays n'est codé dans l'app. */
export const RiderConfigDto = z
  .object({
    country: z.object({
      code: z.string().length(2),
      dialCode: z.string(),
      currency: z.string(),
    }),
    safetyHotline: z.string(),
    supportPhone: z.string().nullable(),
    mobileMoneyOperators: z.array(z.object({ code: z.string(), name: z.string() })),
    offerTimeoutSeconds: z.number(),
  })
  .meta({ id: 'RiderConfig' });
