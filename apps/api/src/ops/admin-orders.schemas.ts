import { z } from 'zod';
import {
  FailureReasonEnum,
  FeePayerEnum,
  OrderStatusEnum,
  PackageContentsEnum,
  PaymentMethodEnum,
} from '../orders/orders.schemas.js';
import { PackageSizeEnum } from '../pricing/pricing.schemas.js';
import { VehicleTypeEnum } from '../riders/riders.schemas.js';
import { CourseAlertDto } from '../tracking/tracking.schemas.js';
import { DelayKindEnum } from './ops.schemas.js';

const Day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date au format AAAA-MM-JJ');

/** Vues de la liste des commandes au back-office (H2). */
export const OrderViewEnum = z
  .enum(['all', 'active', 'problems', 'delivered', 'cancelled'])
  .meta({ id: 'AdminOrderView' });

export const AdminOrderListQuery = z.object({
  /** Référence, numéro ou nom du destinataire, de l'expéditeur, boutique. */
  q: z.string().trim().min(2).max(60).optional(),
  view: OrderViewEnum.default('all'),
  /** Jour de création (heure de Douala), du … au … inclus. */
  from: Day.optional(),
  to: Day.optional(),
  riderId: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
  cursor: z.uuid().optional(),
});

const Delay = z
  .object({ kind: DelayKindEnum, dueAt: z.iso.datetime(), minutes: z.int() })
  .nullable();

const Person = z.object({ id: z.uuid(), name: z.string().nullable(), phone: z.string() });

export const AdminOrderRowDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    createdAt: z.iso.datetime(),
    scheduledFor: z.iso.datetime().nullable(),
    isExpress: z.boolean(),
    /** Gros objet : course en tricycle ou voiture. */
    isBulky: z.boolean(),
    /** Boutique du marchand ou nom de l'expéditeur. */
    senderName: z.string().nullable(),
    senderPhone: z.string(),
    recipientName: z.string(),
    rider: Person.nullable(),
    pickupNeighborhood: z.string().nullable(),
    dropoffNeighborhood: z.string().nullable(),
    totalPrice: z.int(),
    codAmount: z.int(),
    delay: Delay,
  })
  .meta({ id: 'AdminOrderRow' });

export const AdminOrderPageDto = z
  .object({
    items: z.array(AdminOrderRowDto),
    nextCursor: z.uuid().nullable(),
    /** Nombre total de commandes correspondant à la recherche. */
    total: z.int(),
  })
  .meta({ id: 'AdminOrderPage' });

const Stop = z.object({
  label: z.string().nullable(),
  landmark: z.string(),
  neighborhood: z.string().nullable(),
  latitude: z.number(),
  longitude: z.number(),
  contactName: z.string().nullable(),
  contactPhone: z.string().nullable(),
  hasPhoto: z.boolean(),
  hasVoiceNote: z.boolean(),
});

export const OrderNoteDto = z
  .object({
    id: z.uuid(),
    body: z.string(),
    createdAt: z.iso.datetime(),
    authorName: z.string().nullable(),
    authorPhone: z.string(),
  })
  .meta({ id: 'OrderNote' });

export const AdminOrderDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    createdAt: z.iso.datetime(),
    updatedAt: z.iso.datetime(),
    scheduledFor: z.iso.datetime().nullable(),
    isExpress: z.boolean(),
    delay: Delay,
    parcel: z.object({
      size: PackageSizeEnum,
      contents: PackageContentsEnum.nullable(),
      description: z.string().nullable(),
      fragile: z.boolean(),
      /** Gros objet : deux personnes pour charger (supplément manutention). */
      loadingHelp: z.boolean(),
      /** Photo du colis jointe par l'expéditeur. */
      hasPhoto: z.boolean(),
      /** Objets interdits que l'analyse de la photo a cru voir (l'expéditeur a maintenu). */
      aiWarning: z.string().nullable(),
      declaredValue: z.int().nullable(),
      instructions: z.string().nullable(),
      /** Envoi de plusieurs colis : numéro écrit sur ce colis et nombre de colis de l'envoi. */
      batchNumber: z.int().nullable(),
      batchSize: z.int().nullable(),
    }),
    sender: Person.extend({ shopName: z.string().nullable() }),
    recipient: z.object({
      name: z.string(),
      phone: z.string(),
      confirmedAt: z.iso.datetime().nullable(),
      available: z.boolean().nullable(),
      note: z.string().nullable(),
    }),
    pickup: Stop,
    dropoff: Stop,
    rider: Person.extend({
      vehicleType: VehicleTypeEnum,
      plateNumber: z.string().nullable(),
    }).nullable(),
    price: z.object({
      distanceMeters: z.int(),
      basePrice: z.int(),
      surchargesTotal: z.int(),
      discountTotal: z.int(),
      totalPrice: z.int(),
      riderEarning: z.int(),
      platformFee: z.int(),
      retryFee: z.int(),
      returnFee: z.int(),
      feePayer: FeePayerEnum,
      feePaymentMethod: PaymentMethodEnum,
      feePaidAt: z.iso.datetime().nullable(),
    }),
    /**
     * Commande « créée » qui attend encore quelque chose avant la recherche d'un livreur :
     * le paiement Mobile Money des frais, ou son créneau (commande programmée).
     */
    waitingFor: z.enum(['PAYMENT', 'SCHEDULE']).nullable(),
    /** Dernière demande de paiement Mobile Money des frais : état et motif d'un échec. */
    lastFeePayment: z
      .object({
        status: z.string(),
        failureReason: z.string().nullable(),
        at: z.iso.datetime(),
      })
      .nullable(),
    /** Montant à encaisser auprès du destinataire et, s'il l'est, l'encaissement. */
    cod: z
      .object({
        amount: z.int(),
        collectedAmount: z.int().nullable(),
        method: PaymentMethodEnum.nullable(),
        collectedAt: z.iso.datetime().nullable(),
      })
      .nullable(),
    attempts: z.int(),
    failure: z
      .object({
        reason: FailureReasonEnum.nullable(),
        at: z.iso.datetime().nullable(),
        decision: z.enum(['RETRY', 'RETURN']).nullable(),
      })
      .nullable(),
    cancelReason: z.string().nullable(),
    /** Historique des statuts, du plus ancien au plus récent. */
    timeline: z.array(
      z.object({
        id: z.uuid(),
        at: z.iso.datetime(),
        from: OrderStatusEnum.nullable(),
        to: OrderStatusEnum,
        actorRole: z.string(),
        actorName: z.string().nullable(),
        note: z.string().nullable(),
        failureReason: FailureReasonEnum.nullable(),
      }),
    ),
    proofs: z.array(
      z.object({
        id: z.uuid(),
        kind: z.string(),
        at: z.iso.datetime(),
        codeVerified: z.boolean(),
        receivedBy: z.string().nullable(),
        hasPhoto: z.boolean(),
        validatedBySupport: z.boolean(),
      }),
    ),
    courseAlerts: z.array(CourseAlertDto),
    notes: z.array(OrderNoteDto),
    /** Actions possibles pour l'équipe dans l'état actuel. */
    can: z.object({ cancel: z.boolean(), reassign: z.boolean() }),
  })
  .meta({ id: 'AdminOrder' });

export const AddOrderNoteBody = z.object({ body: z.string().trim().min(2).max(1_000) });
export const AdminCancelBody = z.object({
  /** Raison donnée à l'expéditeur et gardée dans l'historique. */
  reason: z.string().trim().min(3).max(300),
});
