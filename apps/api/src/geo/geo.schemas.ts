import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';

export const ZoneKindEnum = z
  .enum(['SERVICE_AREA', 'NEIGHBORHOOD', 'NO_MOTORBIKE'])
  .meta({ id: 'ZoneKind' });

export const Latitude = z.number().min(-90).max(90);
export const Longitude = z.number().min(-180).max(180);

export const ZoneDto = z
  .object({
    id: z.uuid(),
    name: z.string(),
    city: z.string(),
    kind: ZoneKindEnum,
    active: z.boolean(),
  })
  .meta({ id: 'Zone' });

export const ZoneListQuery = z.object({
  city: z.string().min(1).max(60).optional(),
  kind: ZoneKindEnum.optional(),
});

/** Polygone GeoJSON (coordonnées en [longitude, latitude]). */
export const ZoneBody = z.object({
  name: z.string().trim().min(2).max(80),
  city: z.string().trim().min(2).max(60),
  kind: ZoneKindEnum,
  geometry: z.object({
    type: z.enum(['Polygon', 'MultiPolygon']),
    coordinates: z.array(z.unknown()).min(1),
  }),
});

export const ZonePatchBody = z.object({ active: z.boolean() });

const MediaKey = z.string().min(10).max(200);

/** Adresse = point GPS + quartier + repère écrit obligatoire (B1), médias facultatifs (B2). */
export const AddressBody = z.object({
  label: z.string().trim().max(60).optional(),
  contactName: z.string().trim().max(80).optional(),
  contactPhone: CameroonMobile.optional(),
  latitude: Latitude,
  longitude: Longitude,
  landmark: z
    .string()
    .trim()
    .min(3)
    .max(300)
    .meta({ description: 'Repère écrit, ex. « Portail bleu après la pharmacie du carrefour »' }),
  neighborhoodId: z.uuid().optional(),
  photoKey: MediaKey.optional(),
  voiceNoteKey: MediaKey.optional(),
});

export const AddressDto = z
  .object({
    id: z.uuid(),
    label: z.string().nullable(),
    contactName: z.string().nullable(),
    contactPhone: z.string().nullable(),
    city: z.string(),
    neighborhood: z.object({ id: z.uuid(), name: z.string() }).nullable(),
    landmark: z.string(),
    latitude: z.number(),
    longitude: z.number(),
    photoKey: z.string().nullable(),
    voiceNoteKey: z.string().nullable(),
    source: z.enum(['SENDER', 'LOCATION_LINK', 'DELIVERY_CONFIRMED', 'BACKOFFICE']),
    /** Point confirmé par une livraison réussie (B4). */
    verifiedAt: z.iso.datetime().nullable(),
    /** Adresse située dans une zone interdite aux motos (B6). */
    motorbikeRestricted: z.boolean(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'Address' });

export const LocationLinkBody = z.object({
  recipientName: z.string().trim().max(80).optional(),
  recipientPhone: CameroonMobile.optional(),
  /** Durée de validité, 72 h par défaut, 7 jours au plus. */
  ttlHours: z.int().min(1).max(168).default(72),
});

export const LocationLinkStatusEnum = z
  .enum(['PENDING', 'SUBMITTED', 'EXPIRED'])
  .meta({ id: 'LocationLinkStatus' });

export const LocationLinkDto = z
  .object({
    id: z.uuid(),
    url: z.url().meta({ description: 'Lien à partager au destinataire (WhatsApp, SMS)' }),
    recipientName: z.string().nullable(),
    recipientPhone: z.string().nullable(),
    expiresAt: z.iso.datetime(),
    status: LocationLinkStatusEnum,
    address: AddressDto.nullable(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'LocationLink' });

export const LocationLinkListQuery = z.object({ status: LocationLinkStatusEnum.optional() });

export const PublicLocationLinkDto = z
  .object({
    senderName: z.string().nullable(),
    recipientName: z.string().nullable(),
    expiresAt: z.iso.datetime(),
    status: LocationLinkStatusEnum,
  })
  .meta({ id: 'PublicLocationLink' });

export const PublicLocationSubmitBody = z.object({
  latitude: Latitude,
  longitude: Longitude,
  landmark: AddressBody.shape.landmark,
  contactName: z.string().trim().max(80).optional(),
  contactPhone: CameroonMobile.optional(),
});
