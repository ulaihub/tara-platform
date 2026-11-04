import { z } from 'zod';
import { Latitude, Longitude } from '../geo/geo.schemas.js';
import { PackageSizeEnum } from '../pricing/pricing.schemas.js';

const Place = z.object({
  landmark: z.string(),
  neighborhood: z.string().nullable(),
  latitude: z.number(),
  longitude: z.number(),
});

/** Zone de livraison approximative (à 1 km près) : l'adresse exacte n'est donnée qu'au livreur retenu. */
const Area = z.object({
  city: z.string(),
  neighborhood: z.string().nullable(),
  latitude: z.number(),
  longitude: z.number(),
});

/**
 * Proposition de course affichée au livreur (D1, E1). Aucune donnée du destinataire, et
 * seulement la zone de livraison : un livreur qui refuse n'apprend pas où il habite.
 */
export const OfferDto = z
  .object({
    id: z.uuid(),
    orderId: z.uuid(),
    reference: z.string(),
    expiresAt: z.iso.datetime(),
    /** Distance à vol d'oiseau jusqu'au point d'enlèvement. */
    approachMeters: z.int().nullable(),
    pickup: Place.extend({ shopName: z.string().nullable() }),
    dropoff: Area,
    distanceMeters: z.int(),
    /** Durée estimée du trajet enlèvement → livraison, en minutes. */
    estimatedMinutes: z.int(),
    riderEarning: z.int(),
    /** Montant à encaisser auprès du destinataire. */
    codAmount: z.int(),
    /** Frais de livraison réglés en espèces au livreur. */
    cashFee: z.int(),
    packageSize: PackageSizeEnum,
    isFragile: z.boolean(),
    isExpress: z.boolean(),
  })
  .meta({ id: 'DispatchOffer' });

export const OfferClosedEvent = z
  .object({
    offerId: z.uuid(),
    orderId: z.uuid(),
    outcome: z.enum(['ACCEPTED', 'DECLINED', 'EXPIRED', 'WITHDRAWN']),
  })
  .meta({ id: 'OfferClosedEvent' });

export const AssignBody = z.object({
  riderId: z.uuid(),
  note: z.string().trim().max(300).optional(),
});

export const CandidateDto = z
  .object({
    riderId: z.uuid(),
    name: z.string().nullable(),
    phone: z.string(),
    vehicleType: z.enum(['MOTORBIKE', 'TRICYCLE', 'CAR']),
    distanceMeters: z.int(),
    score: z.int(),
    activeOrders: z.int(),
    rating: z.number().nullable(),
    /** Vide si le livreur peut recevoir la course. */
    ineligibleBecause: z.array(
      z.enum(['DOCUMENTS', 'CASH_LIMIT', 'CASH_OVERDUE', 'TOO_MANY_ORDERS', 'PENDING_OFFER']),
    ),
    position: z
      .object({ latitude: Latitude, longitude: Longitude, at: z.iso.datetime() })
      .nullable(),
  })
  .meta({ id: 'DispatchCandidate' });

export const DispatchStateDto = z
  .object({
    orderId: z.uuid(),
    status: z.string(),
    searchingSince: z.iso.datetime().nullable(),
    alerted: z.boolean(),
    offers: z.array(
      z.object({
        id: z.uuid(),
        riderId: z.uuid(),
        round: z.int(),
        approachMeters: z.int().nullable(),
        offeredAt: z.iso.datetime(),
        expiresAt: z.iso.datetime(),
        respondedAt: z.iso.datetime().nullable(),
        outcome: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'WITHDRAWN']),
      }),
    ),
  })
  .meta({ id: 'DispatchState' });
