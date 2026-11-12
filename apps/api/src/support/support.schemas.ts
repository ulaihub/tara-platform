import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';

export const TicketCategoryEnum = z
  .enum([
    'LOST_PARCEL',
    'DAMAGED_PARCEL',
    'LATE_DELIVERY',
    'PAYMENT',
    'RIDER_BEHAVIOR',
    'APP_BUG',
    'OTHER',
  ])
  .meta({ id: 'TicketCategory' });
export const TicketPriorityEnum = z
  .enum(['LOW', 'NORMAL', 'HIGH', 'URGENT'])
  .meta({ id: 'TicketPriority' });
export const TicketStatusEnum = z
  .enum(['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'])
  .meta({ id: 'TicketStatus' });

const Subject = z.string().trim().min(3).max(120);
const MessageBody = z.string().trim().min(2).max(2_000);
/** Référence de commande dictée au téléphone : « TR-7K3P9Q » ou « 7K3P9Q ». */
const OrderReference = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^(TR-)?[A-Z0-9]{4,10}$/, 'référence de commande attendue (ex. TR-7K3P9Q)')
  .transform((value) => (value.startsWith('TR-') ? value : `TR-${value}`));

// --- Côté utilisateur (apps) --------------------------------------------------------

/** Nouvelle demande depuis une app : sujet, premier message, commande concernée si besoin. */
export const CreateTicketBody = z.object({
  category: TicketCategoryEnum,
  subject: Subject,
  message: MessageBody,
  orderId: z.uuid().optional(),
});

export const TicketReplyBody = z.object({ body: MessageBody });

export const TicketDto = z
  .object({
    id: z.uuid(),
    /** Numéro à donner au service client : SUP-1024. */
    reference: z.string(),
    category: TicketCategoryEnum,
    status: TicketStatusEnum,
    subject: z.string(),
    order: z.object({ id: z.uuid(), reference: z.string() }).nullable(),
    createdAt: z.iso.datetime(),
    updatedAt: z.iso.datetime(),
    /** Échanges visibles par l'utilisateur (jamais les notes internes de l'équipe). */
    messages: z.array(
      z.object({
        id: z.uuid(),
        fromTara: z.boolean(),
        body: z.string(),
        at: z.iso.datetime(),
      }),
    ),
  })
  .meta({ id: 'Ticket' });

// --- Back-office (H6) -----------------------------------------------------------------

export const AdminTicketViewEnum = z
  .enum(['TO_HANDLE', 'MINE', 'URGENT', 'RESOLVED', 'ALL'])
  .meta({ id: 'AdminTicketView' });

export const AdminTicketListQuery = z.object({
  view: AdminTicketViewEnum.default('TO_HANDLE'),
  /** Numéro (SUP-1024), référence de commande, téléphone ou sujet. */
  q: z.string().trim().min(2).max(60).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
  cursor: z.uuid().optional(),
});

const Person = z.object({
  id: z.uuid().nullable(),
  name: z.string().nullable(),
  phone: z.string(),
  /** Rôle dans Tara : expéditeur, boutique, livreur ou sans compte (appelant). */
  kind: z.enum(['CUSTOMER', 'MERCHANT', 'RIDER', 'STAFF', 'NO_ACCOUNT']),
});

export const AdminTicketRowDto = z
  .object({
    id: z.uuid(),
    reference: z.string(),
    category: TicketCategoryEnum,
    priority: TicketPriorityEnum,
    status: TicketStatusEnum,
    subject: z.string(),
    requester: Person,
    assignee: z.object({ id: z.uuid(), name: z.string() }).nullable(),
    order: z.object({ id: z.uuid(), reference: z.string() }).nullable(),
    /** Ouverte depuis une app (sinon par l'équipe, à la suite d'un appel). */
    fromApp: z.boolean(),
    createdAt: z.iso.datetime(),
    lastMessageAt: z.iso.datetime(),
    /** Le dernier message visible vient du client : il attend une réponse de Tara. */
    awaitingReply: z.boolean(),
  })
  .meta({ id: 'AdminTicketRow' });

export const AdminTicketPageDto = z
  .object({
    items: z.array(AdminTicketRowDto),
    nextCursor: z.uuid().nullable(),
    /** Nombre de demandes par vue (sans la recherche). */
    counts: z.object({
      TO_HANDLE: z.int(),
      MINE: z.int(),
      URGENT: z.int(),
      RESOLVED: z.int(),
      ALL: z.int(),
    }),
  })
  .meta({ id: 'AdminTicketPage' });

export const AdminTicketDto = AdminTicketRowDto.extend({
  resolvedAt: z.iso.datetime().nullable(),
  /**
   * La personne a l'app Tara (un téléphone qui reçoit les notifications). Sinon la réponse
   * part par SMS, et l'équipe l'appelle pour la lui donner.
   */
  requesterHasApp: z.boolean(),
  /** Tous les échanges, notes internes comprises, du plus ancien au plus récent. */
  messages: z.array(
    z.object({
      id: z.uuid(),
      body: z.string(),
      at: z.iso.datetime(),
      internal: z.boolean(),
      fromTara: z.boolean(),
      authorName: z.string().nullable(),
    }),
  ),
  /** Autres demandes de la même personne (les 5 plus récentes). */
  otherTickets: z.array(
    z.object({
      id: z.uuid(),
      reference: z.string(),
      subject: z.string(),
      status: TicketStatusEnum,
      createdAt: z.iso.datetime(),
    }),
  ),
}).meta({ id: 'AdminTicket' });

/**
 * Demande ouverte par l'équipe à la suite d'un appel : la personne est retrouvée par son
 * numéro (avec ou sans compte) ou par la commande ; le premier message résume l'appel.
 */
export const AdminCreateTicketBody = z
  .object({
    phone: CameroonMobile.optional(),
    orderReference: OrderReference.optional(),
    category: TicketCategoryEnum,
    priority: TicketPriorityEnum.default('NORMAL'),
    subject: Subject,
    message: MessageBody,
  })
  .refine((body) => body.phone || body.orderReference, {
    message: 'numéro de téléphone ou référence de commande requis',
    path: ['phone'],
  });

/** Réponse au client (visible, il est prévenu) ou note interne (équipe seulement). */
export const AdminTicketMessageBody = z.object({
  body: MessageBody,
  internal: z.boolean().default(false),
});

/** Prise en charge, priorité, statut ; `assigneeId: null` libère la demande. */
export const AdminTicketUpdateBody = z
  .object({
    status: TicketStatusEnum.optional(),
    priority: TicketPriorityEnum.optional(),
    assigneeId: z.uuid().nullable().optional(),
  })
  .refine((body) => Object.keys(body).length > 0, { message: 'rien à modifier' });

/** Preuves d'une commande pour trancher un litige (H6). */
export const OrderEvidenceDto = z
  .object({
    orderId: z.uuid(),
    /** Enlèvement, livraison, échec, retour : heure, position, code, photo, appels. */
    proofs: z.array(
      z.object({
        id: z.uuid(),
        kind: z.string(),
        at: z.iso.datetime(),
        latitude: z.number(),
        longitude: z.number(),
        codeVerified: z.boolean(),
        receivedBy: z.string().nullable(),
        hasPhoto: z.boolean(),
        /** Appels passés par le livreur avant de déclarer un échec. */
        calls: z.array(
          z.object({
            to: z.enum(['RECIPIENT', 'SENDER']),
            at: z.iso.datetime(),
            durationSeconds: z.int(),
          }),
        ),
      }),
    ),
    /** Photo du colis prise par l'expéditeur à la commande. */
    hasParcelPhoto: z.boolean(),
    ratings: z.array(
      z.object({
        by: z.enum(['SENDER', 'RIDER']),
        score: z.int(),
        comment: z.string().nullable(),
        at: z.iso.datetime(),
      }),
    ),
    /** Points du trajet enregistrés pendant la course (gardés 90 jours). */
    trackPoints: z.int(),
  })
  .meta({ id: 'OrderEvidence' });
