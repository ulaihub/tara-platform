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
    'DAMAGED',
    'OTHER',
  ])
  .meta({ id: 'FailureReason' });
export const ActorRoleEnum = z
  .enum(['SENDER', 'RECIPIENT', 'RIDER', 'DISPATCHER', 'SUPPORT', 'SYSTEM'])
  .meta({ id: 'ActorRole' });

/** Nature du contenu d'un colis (C1) : tout type d'objet, précisé en clair à côté. */
export const PackageContentsEnum = z
  .enum([
    'DOCUMENTS',
    'CLOTHING',
    'MEDICINE',
    'LAUNDRY',
    'HOUSEHOLD',
    'ELECTRONICS',
    'FOOD',
    'BEAUTY',
    'SECONDHAND',
    'OTHER',
  ])
  .meta({ id: 'PackageContents' });

/** Plafond d'encaissement par commande, pour limiter le risque espèces (G5). */
export const MAX_COD_AMOUNT = 500_000;

const Fcfa = z.int().min(0).max(10_000_000);

/** Ce qui varie d'une livraison à l'autre (C1). */
export const DeliveryItem = z.object({
  dropoffAddressId: z.uuid(),
  recipientName: z.string().trim().min(2).max(80),
  recipientPhone: CameroonMobile,
  packageSize: PackageSizeEnum,
  /** Nature du contenu ; « Autre » si l'app ne la donne pas. */
  packageContents: PackageContentsEnum.default('OTHER'),
  /** Précision libre, ex. « 2 paires de chaussures ». */
  packageDescription: z.string().trim().max(120).optional(),
  isFragile: z.boolean().default(false),
  /** Gros objet : aide au chargement par deux personnes (supplément manutention). */
  loadingHelp: z.boolean().default(false),
  /** Valeur du contenu : plafond du remboursement en cas de perte ou de dommage (500 000 F au plus). */
  declaredValue: Fcfa.max(500_000).optional(),
  /** Photo du colis (POST /media, kind=PARCEL_PHOTO), analysée par POST /orders/parcel-analysis. */
  parcelPhotoKey: z.string().min(1).max(200).optional(),
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

/** Colis au plus dans un même envoi (C4) : les grosses boutiques envoient leur journée d'un coup. */
export const MAX_BATCH_ITEMS = 100;

/**
 * Un colis d'un envoi : adresse connue, ou demandée au client (`askAddress`) — Tara lui envoie
 * alors un lien par SMS et le colis part dès que son point arrive, payé à ce moment-là.
 */
export const BatchItem = DeliveryItem.extend({
  dropoffAddressId: z.uuid().optional(),
  askAddress: z.boolean().default(false),
}).refine((item) => (item.dropoffAddressId === undefined) === item.askAddress, {
  message: 'une adresse connue, ou askAddress, pas les deux',
  path: ['dropoffAddressId'],
});

/** Jusqu'à 100 colis depuis un même point d'enlèvement (C4), numérotés dans cet ordre. */
export const CreateBatchBody = z.object({
  pickupAddressId: z.uuid(),
  isExpress: z.boolean().default(false),
  scheduledFor: z.iso.datetime().optional(),
  feePayer: FeePayerEnum.default('SENDER'),
  feePaymentMethod: PaymentMethodEnum,
  items: z.array(BatchItem).min(1).max(MAX_BATCH_ITEMS),
});

/**
 * Où en est un colis qui attend l'adresse de son client : lien envoyé (WAITING), lien expiré
 * sans réponse (EXPIRED), parti (RELEASED, la commande existe), départ bloqué (BLOCKED, voir
 * `blockedReason`), ou retiré par l'expéditeur (CANCELLED).
 */
export const PendingDeliveryStatusEnum = z
  .enum(['WAITING', 'EXPIRED', 'RELEASED', 'BLOCKED', 'CANCELLED'])
  .meta({ id: 'PendingDeliveryStatus' });

export const PendingDeliveryDto = z
  .object({
    id: z.uuid(),
    batchId: z.uuid(),
    batchNumber: z.int(),
    recipientName: z.string(),
    recipientPhone: z.string(),
    packageSize: PackageSizeEnum,
    packageDescription: z.string().nullable(),
    codAmount: z.int(),
    status: PendingDeliveryStatusEnum,
    /** Code d'erreur quand le départ automatique a échoué (ex. INSUFFICIENT_BALANCE). */
    blockedReason: z.string().nullable(),
    linkUrl: z.string(),
    linkExpiresAt: z.iso.datetime(),
    /** Commande créée quand le point est arrivé. */
    orderId: z.uuid().nullable(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'PendingDelivery' });

export const PendingDeliveryListQuery = z.object({
  /** Seulement ceux qui attendent encore une action (WAITING, EXPIRED, BLOCKED). */
  open: z
    .enum(['true', 'false'])
    .default('true')
    .transform((value) => value === 'true'),
});

/** Faire partir un colis bloqué (solde insuffisant) avec un autre moyen de paiement. */
export const ReleasePendingBody = z.object({
  feePaymentMethod: PaymentMethodEnum.optional(),
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

/** Note après la course (F4) : 1 à 5 étoiles, mot facultatif pour l'équipe. */
export const RateBody = z.object({
  score: z.int().min(1).max(5),
  /** Mot laissé à l'équipe Tara ; jamais montré à la personne notée. */
  comment: z.string().trim().max(300).optional(),
});

export const RatingDto = z
  .object({
    score: z.int(),
    comment: z.string().nullable(),
    at: z.iso.datetime(),
  })
  .meta({ id: 'Rating' });

export const OrderDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    trackingUrl: z.url(),
    batchId: z.uuid().nullable(),
    /** Numéro du colis dans son envoi (à écrire sur le colis) et nombre de colis de l'envoi. */
    batchNumber: z.int().nullable(),
    batchSize: z.int().nullable(),
    isExpress: z.boolean(),
    scheduledFor: z.iso.datetime().nullable(),
    packageSize: PackageSizeEnum,
    packageContents: PackageContentsEnum.nullable(),
    packageDescription: z.string().nullable(),
    isFragile: z.boolean(),
    loadingHelp: z.boolean(),
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
      /** Frais payés (prépaiement Mobile Money ou solde Tara) : sinon la commande attend. */
      feePaid: z.boolean(),
      codAmount: z.int(),
      /** Frais d'échec figés à la commande (E6), à la charge de l'expéditeur. */
      retryFee: z.int(),
      returnFee: z.int(),
      /** Garantie payée pour la valeur déclarée au-delà de 25 000 F, comprise dans le total. */
      valueFee: z.int(),
      /**
       * Frais si l'expéditeur annule maintenant (livreur déjà en route), 0 sinon : à annoncer
       * avant qu'il confirme l'annulation.
       */
      cancellationFee: z.int(),
      /** Attente du livreur au point d'enlèvement au-delà du temps gratuit (D), à l'enlèvement. */
      waitingFee: z.int(),
      /** Arrivée du livreur au point d'enlèvement : l'attente compte depuis là (D). */
      riderArrivedAt: z.iso.datetime().nullable(),
    }),
    riderId: z.uuid().nullable(),
    /**
     * Livreur de la course, pour l'expéditeur (F1) : prénom et initiale, véhicule, plaque ;
     * numéro seulement pendant la course (pour l'appeler).
     */
    rider: z
      .object({
        name: z.string(),
        phone: z.string().nullable(),
        vehicleType: z.enum(['MOTORBIKE', 'TRICYCLE', 'CAR']),
        plateNumber: z.string().nullable(),
      })
      .nullable(),
    attemptCount: z.int(),
    /** Après un échec (E6) : motif, choix de l'expéditeur et heure du retour automatique. */
    failure: z
      .object({
        reason: FailureReasonEnum.nullable(),
        note: z.string().nullable(),
        at: z.iso.datetime(),
        decision: z.enum(['RETRY', 'RETURN']).nullable(),
        /** Sans choix d'ici là, le colis repart chez l'expéditeur (null une fois choisi). */
        decisionDueAt: z.iso.datetime().nullable(),
        /** Une seule nouvelle tentative : false après un deuxième échec. */
        retryAllowed: z.boolean(),
      })
      .nullable(),
    cancelReason: z.string().nullable(),
    /** Note donnée au livreur par l'expéditeur (F4), null tant qu'il n'a pas noté. */
    rating: RatingDto.nullable(),
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
    /** Colis qui attendent l'adresse de leur client (lien envoyé par SMS). */
    pending: z.array(PendingDeliveryDto),
  })
  .meta({ id: 'CreatedBatch' });

export const OrderSummaryDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    status: OrderStatusEnum,
    /** Numéro du colis dans son envoi (null hors envoi groupé). */
    batchNumber: z.int().nullable(),
    recipientName: z.string(),
    dropoffLandmark: z.string(),
    /** Quartier de livraison (null hors des quartiers connus). */
    dropoffNeighborhood: z.string().nullable(),
    totalPrice: z.int(),
    codAmount: z.int(),
    scheduledFor: z.iso.datetime().nullable(),
    /** Après un échec : choix fait (null tant que l'expéditeur doit décider). */
    failureDecision: z.enum(['RETRY', 'RETURN']).nullable(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'OrderSummary' });

/** Statuts d'une commande en cours (suivie sur l'accueil) ; les autres sont terminées. */
export const ACTIVE_ORDER_STATUSES = [
  'CREATED',
  'SEARCHING_RIDER',
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
] as const;

export const OrderListQuery = PageQuery.extend({
  status: OrderStatusEnum.optional(),
  /** active : commandes en cours ; history : livrées, retournées ou annulées. */
  scope: z.enum(['active', 'history']).optional(),
});

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

/** Page de suivi du destinataire (F2), sans compte : rien de plus que ce qu'il lui faut. */
export const PublicTrackingDto = z
  .object({
    reference: z.string(),
    status: OrderStatusEnum,
    senderName: z.string().nullable(),
    recipientName: z.string(),
    dropoffLandmark: z.string(),
    dropoffNeighborhood: z.string().nullable(),
    scheduledFor: z.iso.datetime().nullable(),
    recipientConfirmedAt: z.iso.datetime().nullable(),
    recipientAvailable: z.boolean().nullable(),
    /** Le destinataire peut encore confirmer sa disponibilité (avant l'enlèvement). */
    canRespond: z.boolean(),
    timeline: z.array(z.object({ status: OrderStatusEnum, at: z.iso.datetime() })),
    /**
     * Livreur : prénom et initiale, véhicule, plaque ; son numéro seulement quand il vient
     * vers le destinataire (colis à bord, ou échec en attente).
     */
    rider: z
      .object({
        name: z.string(),
        vehicleType: z.enum(['MOTORBIKE', 'TRICYCLE', 'CAR']),
        plateNumber: z.string().nullable(),
        phone: z.string().nullable(),
      })
      .nullable(),
    /**
     * Arrivée estimée (prudente) quand le livreur roule vers le destinataire, d'après sa
     * dernière position (de moins de 5 min). `progress` : part du trajet faite, de 0 à 1.
     */
    eta: z
      .object({
        minutes: z.int(),
        distanceMeters: z.int(),
        progress: z.number().min(0).max(1),
      })
      .nullable(),
    /** À payer à la porte : frais de livraison (si le destinataire les paie) et colis. */
    due: z.object({ fee: z.int(), cod: z.int(), total: z.int() }),
    /** Frais Mobile Money ajoutés si le destinataire paie par Mobile Money (en espèces : rien). */
    mobileMoneyFee: z.int(),
    /** Demande Mobile Money envoyée par le livreur, à valider sur le téléphone (frais compris). */
    paymentPending: z.object({ amount: z.int() }).nullable(),
    /** Après un échec : nouvelle tentative ou retour à l'expéditeur, si c'est décidé. */
    failureDecision: z.enum(['RETRY', 'RETURN']).nullable(),
  })
  .meta({ id: 'PublicTracking' });

export const RecipientResponseBody = z.object({
  available: z.boolean(),
  note: z.string().trim().max(300).optional(),
});
