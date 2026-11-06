import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';
import { PageQuery } from '../common/pagination.js';
import { AddressDto } from '../geo/geo.schemas.js';
import { PackageSizeEnum } from '../pricing/pricing.schemas.js';

export const OrderStatusEnum = z
  .enum([
    'CREATED',
    'SEARCHING_RIDER',
    'ASSIGNED',
    'PICKED_UP',
    'IN_DELIVERY',
    'DELIVERED',
    'DELIVERY_FAILED',
    'RETURNED',
    'CANCELLED',
  ])
  .meta({ id: 'OrderStatus' });
export const PaymentMethodEnum = z
  .enum(['MOMO_MTN', 'MOMO_ORANGE', 'CASH', 'WALLET'])
  .meta({ id: 'PaymentMethod' });
export const FeePayerEnum = z.enum(['SENDER', 'RECIPIENT']).meta({ id: 'FeePayer' });
export const FailureReasonEnum = z
  .enum([
    'RECIPIENT_ABSENT',
    'RECIPIENT_UNREACHABLE',
    'REFUSED',
    'ADDRESS_NOT_FOUND',
    'PAYMENT_REFUSED',
    'OTHER',
  ])
  .meta({ id: 'FailureReason' });
export const ActorRoleEnum = z
  .enum(['SENDER', 'RECIPIENT', 'RIDER', 'DISPATCHER', 'SUPPORT', 'SYSTEM'])
  .meta({ id: 'ActorRole' });

/** Plafond d'encaissement par commande, pour limiter le risque espèces (G5). */
export const MAX_COD_AMOUNT = 500_000;

const Fcfa = z.int().min(0).max(10_000_000);

/** Ce qui varie d'une livraison à l'autre (C1). */
export const DeliveryItem = z.object({
  dropoffAddressId: z.uuid(),
  recipientName: z.string().trim().min(2).max(80),
  recipientPhone: CameroonMobile,
  packageSize: PackageSizeEnum,
  isFragile: z.boolean().default(false),
  declaredValue: Fcfa.optional(),
  /** Montant à encaisser auprès du destinataire, 0 si aucun (réservé aux marchands). */
  codAmount: Fcfa.default(0),
  instructions: z.string().trim().max(300).optional(),
});

export const CreateOrderBody = DeliveryItem.extend({
  pickupAddressId: z.uuid(),
  isExpress: z.boolean().default(false),
  scheduledFor: z.iso.datetime().optional(),
  feePayer: FeePayerEnum.default('SENDER'),
  feePaymentMethod: PaymentMethodEnum,
  promoCode: z.string().trim().max(32).optional(),
});

/** Jusqu'à 10 livraisons depuis un même point d'enlèvement (C4). */
export const CreateBatchBody = z.object({
  pickupAddressId: z.uuid(),
  isExpress: z.boolean().default(false),
  scheduledFor: z.iso.datetime().optional(),
  feePayer: FeePayerEnum.default('SENDER'),
  feePaymentMethod: PaymentMethodEnum,
  items: z.array(DeliveryItem).min(1).max(10),
});

export const OrderEventDto = z
  .object({
    status: OrderStatusEnum,
    at: z.iso.datetime(),
    actorRole: ActorRoleEnum,
    failureReason: FailureReasonEnum.nullable(),
    note: z.string().nullable(),
  })
  .meta({ id: 'OrderEvent' });

export const OrderDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    trackingUrl: z.url(),
    batchId: z.uuid().nullable(),
    isExpress: z.boolean(),
    scheduledFor: z.iso.datetime().nullable(),
    packageSize: PackageSizeEnum,
    isFragile: z.boolean(),
    declaredValue: z.int().nullable(),
    instructions: z.string().nullable(),
    pickup: AddressDto,
    dropoff: AddressDto,
    recipient: z.object({
      name: z.string(),
      phone: z.string(),
      confirmedAt: z.iso.datetime().nullable(),
      available: z.boolean().nullable(),
      note: z.string().nullable(),
    }),
    pricing: z.object({
      currency: z.literal('XAF'),
      distanceMeters: z.int(),
      basePrice: z.int(),
      surchargesTotal: z.int(),
      discountTotal: z.int(),
      totalPrice: z.int(),
      feePayer: FeePayerEnum,
      feePaymentMethod: PaymentMethodEnum,
      codAmount: z.int(),
    }),
    riderId: z.uuid().nullable(),
    attemptCount: z.int(),
    cancelReason: z.string().nullable(),
    timeline: z.array(OrderEventDto),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'Order' });

export const CreatedOrderDto = z
  .object({
    order: OrderDto,
    /** Code à 4 chiffres à donner au livreur à l'enlèvement. Affiché une seule fois. */
    pickupCode: z.string().nullable(),
    /** Vrai si la requête rejouée avec la même clé d'idempotence a renvoyé la commande existante. */
    replayed: z.boolean(),
  })
  .meta({ id: 'CreatedOrder' });

export const CreatedBatchDto = z
  .object({
    batchId: z.uuid(),
    pickupCode: z.string().nullable(),
    replayed: z.boolean(),
    orders: z.array(OrderDto),
  })
  .meta({ id: 'CreatedBatch' });

export const OrderSummaryDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    recipientName: z.string(),
    dropoffLandmark: z.string(),
    totalPrice: z.int(),
    codAmount: z.int(),
    scheduledFor: z.iso.datetime().nullable(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'OrderSummary' });

export const OrderListQuery = PageQuery.extend({ status: OrderStatusEnum.optional() });

export const CancelOrderBody = z.object({ reason: z.string().trim().min(3).max(300) });

export const PickupCodeDto = z.object({ pickupCode: z.string() }).meta({ id: 'PickupCode' });

export const AdminTransitionBody = z.object({
  to: OrderStatusEnum,
  riderId: z.uuid().optional(),
  failureReason: FailureReasonEnum.optional(),
  note: z.string().trim().max(300).optional(),
});

export const RecipientDto = z
  .object({
    phone: z.string(),
    name: z.string(),
    ordersCount: z.int(),
    lastOrderAt: z.iso.datetime(),
    /** Dernière adresse de livraison ; « verifiedAt » renseigné si une livraison l'a confirmée (B4). */
    lastAddress: AddressDto,
  })
  .meta({ id: 'Recipient' });

export const RecipientQuery = z.object({ q: z.string().trim().min(1).max(40).optional() });

export const PublicTrackingDto = z
  .object({
    reference: z.string(),
    status: OrderStatusEnum,
    senderName: z.string().nullable(),
    recipientName: z.string(),
    dropoffLandmark: z.string(),
    scheduledFor: z.iso.datetime().nullable(),
    recipientConfirmedAt: z.iso.datetime().nullable(),
    recipientAvailable: z.boolean().nullable(),
    /** Le destinataire peut encore confirmer sa disponibilité (avant l'enlèvement). */
    canRespond: z.boolean(),
    timeline: z.array(z.object({ status: OrderStatusEnum, at: z.iso.datetime() })),
  })
  .meta({ id: 'PublicTracking' });

export const RecipientResponseBody = z.object({
  available: z.boolean(),
  note: z.string().trim().max(300).optional(),
});
