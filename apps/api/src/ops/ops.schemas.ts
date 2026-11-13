import { z } from 'zod';
import { OrderStatusEnum } from '../orders/orders.schemas.js';
import { SafetyAlertDto } from '../rider-app/rider-app.schemas.js';
import { VehicleTypeEnum } from '../riders/riders.schemas.js';
import { CourseAlertDto } from '../tracking/tracking.schemas.js';

export const LiveRiderStateEnum = z
  .enum(['FREE', 'ON_COURSE', 'OFFLINE'])
  .meta({ id: 'LiveRiderState', description: 'Libre, en course ou hors ligne' });

export const LiveRiderDto = z
  .object({
    id: z.uuid(),
    name: z.string().nullable(),
    phone: z.string(),
    vehicleType: VehicleTypeEnum,
    plateNumber: z.string().nullable(),
    state: LiveRiderStateEnum,
    /** En ligne d'après le livreur, mais plus aucune position reçue depuis un moment. */
    signalLost: z.boolean(),
    /** Dernière position connue (gardée 15 min après la dernière réception). */
    position: z
      .object({
        latitude: z.number(),
        longitude: z.number(),
        heading: z.number().nullable(),
        at: z.iso.datetime(),
      })
      .nullable(),
    /**
     * Même position ramenée sur la rue la plus proche (à moins de 40 m), pour l'afficher sur
     * la chaussée. Null sans serveur d'itinéraires ou loin de toute rue.
     */
    roadPosition: z.object({ latitude: z.number(), longitude: z.number() }).nullable(),
    /** Commandes en cours du livreur. */
    orderIds: z.array(z.uuid()),
    /** Note moyenne sur 5, null sans note. */
    rating: z.number().nullable(),
  })
  .meta({ id: 'LiveRider' });

const LiveStopDto = z.object({
  latitude: z.number(),
  longitude: z.number(),
  neighborhood: z.string().nullable(),
  landmark: z.string(),
});

export const DelayKindEnum = z.enum(['NO_RIDER', 'PICKUP', 'DELIVERY']).meta({
  id: 'DelayKind',
  description: 'Sans livreur, enlèvement en retard, livraison en retard',
});

export const LiveOrderDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    isExpress: z.boolean(),
    scheduledFor: z.iso.datetime().nullable(),
    /** Boutique du marchand, ou nom de l'expéditeur. */
    senderName: z.string().nullable(),
    riderId: z.uuid().nullable(),
    pickup: LiveStopDto,
    dropoff: LiveStopDto,
    /** Montant à encaisser auprès du destinataire, 0 si aucun. */
    codAmount: z.int(),
    createdAt: z.iso.datetime(),
    assignedAt: z.iso.datetime().nullable(),
    pickedUpAt: z.iso.datetime().nullable(),
    delay: z.object({ kind: DelayKindEnum, dueAt: z.iso.datetime(), minutes: z.int() }).nullable(),
    /** Remise sans code signalée par le livreur : le support doit la valider (E4). */
    awaitingValidation: z.boolean(),
    /** Échec de livraison : l'expéditeur doit choisir nouvelle tentative ou retour (E6). */
    awaitingDecision: z.boolean(),
  })
  .meta({ id: 'LiveOrder' });

/** Carte en direct du back-office (H1) : tout ce qu'il faut pour piloter la ville. */
export const LiveMapDto = z
  .object({
    generatedAt: z.iso.datetime(),
    riders: z.array(LiveRiderDto),
    orders: z.array(LiveOrderDto),
    /** Alertes de sécurité non closes, les plus récentes d'abord. */
    safetyAlerts: z.array(SafetyAlertDto),
    /** Alertes de trajet pas encore vues par le support. */
    courseAlerts: z.array(CourseAlertDto),
    rules: z.object({
      searchingMinutes: z.number(),
      pickupMinutes: z.int(),
      deliveryMarginMinutes: z.int(),
    }),
  })
  .meta({ id: 'LiveMap' });

const PathDto = z
  .array(z.tuple([z.number(), z.number()]))
  .meta({ description: 'Tracé en paires [longitude, latitude]' });

/** Course en cours d'un livreur sur la carte : chemin parcouru et itinéraire restant. */
export const RiderTrailDto = z
  .object({
    riderId: z.uuid(),
    /** Course suivie (la plus récente s'il en a plusieurs), null s'il n'en a pas. */
    order: z
      .object({
        id: z.uuid(),
        reference: z.string(),
        status: OrderStatusEnum,
        /** Prochain arrêt : vendeur, client, ou aucun (décision attendue après un échec). */
        target: z.enum(['pickup', 'dropoff']).nullable(),
      })
      .nullable(),
    /** Position actuelle, sur la rue si possible. */
    position: z.object({ latitude: z.number(), longitude: z.number() }).nullable(),
    /** Chemin parcouru depuis l'acceptation de la course. */
    traveled: z
      .object({
        path: PathDto,
        /** Recalé sur les rues ; sinon positions GPS reliées entre elles. */
        onRoads: z.boolean(),
      })
      .nullable(),
    /** Itinéraire jusqu'au prochain arrêt. */
    remaining: z
      .object({
        path: PathDto,
        meters: z.int(),
        seconds: z.int().nullable(),
        /** Itinéraire routier ; sinon ligne droite et distance estimée. */
        onRoads: z.boolean(),
      })
      .nullable(),
  })
  .meta({ id: 'RiderTrail' });

export const RiderTrailQuery = z.object({
  /** Course à suivre parmi celles du livreur (par défaut la plus récente). */
  orderId: z.uuid().optional(),
});
