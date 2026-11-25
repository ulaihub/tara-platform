import { Injectable, Logger } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { damageClaimDeadline } from '../common/time.js';
import type { Prisma, TicketCategory, UserRole } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaService } from '../storage/media.service.js';
import {
  type AdminCreateTicketBody,
  type AdminTicketDto,
  type AdminTicketListQuery,
  type AdminTicketMessageBody,
  type AdminTicketPageDto,
  type AdminTicketRowDto,
  type AdminTicketUpdateBody,
  AdminTicketViewEnum,
  type CreateTicketBody,
  type OrderEvidenceDto,
  type TicketDto,
} from './support.schemas.js';

type View = z.output<typeof AdminTicketViewEnum>;
type Row = z.output<typeof AdminTicketRowDto>;

const STAFF_ROLES: UserRole[] = ['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'];
const ACTIVE = ['OPEN', 'IN_PROGRESS'] as const;
/** Demandes encore ouvertes au même moment par un utilisateur, au plus. */
const MAX_OPEN_PER_USER = 5;
/** Une perte de colis ou un problème d'argent passe devant le reste. */
const HIGH_PRIORITY: TicketCategory[] = ['LOST_PARCEL', 'PAYMENT'];

export const ticketReference = (number: number): string => `SUP-${number}`;

const isStaff = (roles: UserRole[]): boolean => roles.some((role) => STAFF_ROLES.includes(role));

const TICKET_INCLUDE = {
  requester: {
    select: {
      id: true,
      fullName: true,
      phone: true,
      roles: true,
      merchant: { select: { id: true } },
    },
  },
  assignee: { select: { id: true, fullName: true, phone: true } },
  order: { select: { id: true, reference: true } },
} as const satisfies Prisma.TicketInclude;

type TicketWithPeople = Prisma.TicketGetPayload<{ include: typeof TICKET_INCLUDE }>;

/** Demandes d'une vue de la file du support. */
function viewFilter(view: View, staffId: string): Prisma.TicketWhereInput {
  switch (view) {
    case 'TO_HANDLE':
      return { status: { in: [...ACTIVE] } };
    case 'MINE':
      return { status: { in: [...ACTIVE] }, assigneeId: staffId };
    case 'URGENT':
      return { status: { in: [...ACTIVE] }, priority: { in: ['HIGH', 'URGENT'] } };
    case 'RESOLVED':
      return { status: { in: ['RESOLVED', 'CLOSED'] } };
    case 'ALL':
      return {};
  }
}

/** Numéro SUP-…, référence de commande, téléphone (chiffres) ou mots du sujet. */
function searchFilter(q: string): Prisma.TicketWhereInput {
  const ticket = /^SUP-?(\d{1,9})$/i.exec(q);
  if (ticket) return { number: Number(ticket[1]) };
  const order = /^(TR-)?([A-Z0-9]{4,10})$/i.exec(q);
  const digits = /^[+\d\s]+$/.test(q) ? q.replace(/\D/g, '') : '';
  return {
    OR: [
      { subject: { contains: q, mode: 'insensitive' } },
      ...(order
        ? [{ order: { reference: { contains: (order[2] as string).toUpperCase() } } }]
        : []),
      ...(digits.length >= 4 ? [{ contactPhone: { contains: digits } }] : []),
    ],
  };
}

/**
 * Service client (H6) : demandes ouvertes depuis les apps ou par l'équipe après un appel,
 * échanges avec le client et notes internes, prise en charge, et preuves d'une commande
 * pour trancher un litige (photos, positions, appels, notes).
 */
@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
    private readonly media: MediaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeService,
  ) {}

  // --- Côté utilisateur ----------------------------------------------------------------

  async create(
    actor: AuthUser,
    body: z.output<typeof CreateTicketBody>,
  ): Promise<z.output<typeof TicketDto>> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: actor.id },
      select: { phone: true },
    });
    if (body.orderId) await this.assertOrderConcerns(actor.id, user.phone, body.orderId);
    if (body.orderId && body.category === 'DAMAGED_PARCEL') {
      await this.assertDamageClaimInTime(body.orderId, new Date());
    }
    const open = await this.prisma.ticket.count({
      where: { requesterId: actor.id, status: { in: [...ACTIVE] } },
    });
    if (open >= MAX_OPEN_PER_USER) throw AppError.tooMany('TICKET_LIMIT_REACHED');
    const ticket = await this.prisma.ticket.create({
      data: {
        openedById: actor.id,
        requesterId: actor.id,
        contactPhone: user.phone,
        orderId: body.orderId ?? null,
        category: body.category,
        priority: HIGH_PRIORITY.includes(body.category) ? 'HIGH' : 'NORMAL',
        subject: body.subject,
        messages: { create: { authorId: actor.id, body: body.message } },
      },
    });
    return this.mine(actor, ticket.id);
  }

  /** Demandes de l'utilisateur, des plus récentes aux plus anciennes (30 au plus). */
  async list(actor: AuthUser): Promise<z.output<typeof TicketDto>[]> {
    const tickets = await this.prisma.ticket.findMany({
      where: { requesterId: actor.id },
      orderBy: { createdAt: 'desc' },
      take: 30,
      select: { id: true },
    });
    const out: z.output<typeof TicketDto>[] = [];
    for (const ticket of tickets) out.push(await this.mine(actor, ticket.id));
    return out;
  }

  async mine(actor: AuthUser, id: string): Promise<z.output<typeof TicketDto>> {
    const ticket = await this.prisma.ticket.findFirst({
      where: { id, requesterId: actor.id },
      include: {
        order: { select: { id: true, reference: true } },
        messages: {
          where: { isInternal: false },
          orderBy: { createdAt: 'asc' },
          include: { author: { select: { roles: true } } },
        },
      },
    });
    if (!ticket) throw AppError.notFound('TICKET_NOT_FOUND');
    return {
      id: ticket.id,
      reference: ticketReference(ticket.number),
      category: ticket.category,
      status: ticket.status,
      subject: ticket.subject,
      order: ticket.order,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
      messages: ticket.messages.map((message) => ({
        id: message.id,
        fromTara: isStaff(message.author.roles),
        body: message.body,
        at: message.createdAt.toISOString(),
      })),
    };
  }

  /** Réponse du client ; une demande résolue est rouverte, une demande close ne l'est plus. */
  async reply(actor: AuthUser, id: string, body: string): Promise<z.output<typeof TicketDto>> {
    const ticket = await this.prisma.ticket.findFirst({ where: { id, requesterId: actor.id } });
    if (!ticket) throw AppError.notFound('TICKET_NOT_FOUND');
    if (ticket.status === 'CLOSED') throw AppError.conflict('TICKET_CLOSED');
    await this.prisma.$transaction([
      this.prisma.ticketMessage.create({ data: { ticketId: id, authorId: actor.id, body } }),
      this.prisma.ticket.update({
        where: { id },
        data:
          ticket.status === 'RESOLVED'
            ? { status: 'OPEN', resolvedAt: null }
            : { updatedAt: new Date() },
      }),
    ]);
    // L'équipe voit la réponse arriver dans la demande ouverte, sans recharger.
    this.realtime.toOps('ops.support-message', { ticketId: id });
    return this.mine(actor, id);
  }

  /**
   * Colis abîmé : à signaler au plus tard 7 jours après la livraison, dimanches non compris
   * (dommage caché) ; un dommage visible se signale à la remise. Au-delà, le colis est présumé
   * remis en bon état : seul le service client, au téléphone, peut encore ouvrir la demande.
   */
  private async assertDamageClaimInTime(orderId: string, now: Date): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { deliveredAt: true, returnedAt: true },
    });
    const handedOver = order?.deliveredAt ?? order?.returnedAt;
    if (handedOver && now >= damageClaimDeadline(handedOver)) {
      throw AppError.unprocessable('DAMAGE_CLAIM_TOO_LATE');
    }
  }

  /** La commande concerne l'utilisateur : il l'a envoyée, la reçoit ou la livre. */
  private async assertOrderConcerns(userId: string, phone: string, orderId: string): Promise<void> {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        OR: [{ senderId: userId }, { recipientPhone: phone }, { rider: { userId } }],
      },
      select: { id: true },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
  }

  // --- Back-office ---------------------------------------------------------------------

  async adminList(
    staff: AuthUser,
    query: z.output<typeof AdminTicketListQuery>,
  ): Promise<z.output<typeof AdminTicketPageDto>> {
    const rows = await this.prisma.ticket.findMany({
      where: { AND: [viewFilter(query.view, staff.id), query.q ? searchFilter(query.q) : {}] },
      // Les plus urgentes d'abord ; à priorité égale, les plus anciennes (premier arrivé).
      orderBy:
        query.view === 'RESOLVED' || query.view === 'ALL'
          ? [{ createdAt: 'desc' }, { id: 'desc' }]
          : [{ priority: 'desc' }, { createdAt: 'asc' }, { id: 'asc' }],
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      take: query.limit + 1,
      include: TICKET_INCLUDE,
    });
    const items = rows.slice(0, query.limit);
    const latest = await this.latestMessages(items.map((ticket) => ticket.id));
    const counts = {} as Record<View, number>;
    for (const view of AdminTicketViewEnum.options) {
      counts[view] = await this.prisma.ticket.count({ where: viewFilter(view, staff.id) });
    }
    return {
      items: items.map((ticket) => this.toRow(ticket, latest.get(ticket.id))),
      nextCursor: rows.length > query.limit ? (items.at(-1)?.id ?? null) : null,
      counts,
    };
  }

  async adminDetail(id: string): Promise<z.output<typeof AdminTicketDto>> {
    const ticket = await this.prisma.ticket.findUnique({
      where: { id },
      include: {
        ...TICKET_INCLUDE,
        messages: {
          orderBy: { createdAt: 'asc' },
          include: { author: { select: { fullName: true, phone: true, roles: true } } },
        },
      },
    });
    if (!ticket) throw AppError.notFound('TICKET_NOT_FOUND');
    const latest = await this.latestMessages([id]);
    const devices = ticket.requesterId
      ? await this.prisma.device.count({
          where: { userId: ticket.requesterId, pushToken: { not: null } },
        })
      : 0;
    const others = await this.prisma.ticket.findMany({
      where: {
        id: { not: id },
        OR: [
          ...(ticket.requesterId ? [{ requesterId: ticket.requesterId }] : []),
          { contactPhone: ticket.contactPhone },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });
    return {
      ...this.toRow(ticket, latest.get(id)),
      resolvedAt: ticket.resolvedAt?.toISOString() ?? null,
      requesterHasApp: devices > 0,
      messages: ticket.messages.map((message) => {
        const fromTara = isStaff(message.author.roles);
        return {
          id: message.id,
          body: message.body,
          at: message.createdAt.toISOString(),
          internal: message.isInternal,
          fromTara,
          authorName: message.author.fullName ?? (fromTara ? null : message.author.phone),
        };
      }),
      otherTickets: others.map((other) => ({
        id: other.id,
        reference: ticketReference(other.number),
        subject: other.subject,
        status: other.status,
        createdAt: other.createdAt.toISOString(),
      })),
    };
  }

  /** Demande ouverte par l'équipe après un appel ; elle est confiée à qui l'a ouverte. */
  async adminCreate(
    staff: AuthUser,
    body: z.output<typeof AdminCreateTicketBody>,
  ): Promise<z.output<typeof AdminTicketDto>> {
    const order = body.orderReference
      ? await this.prisma.order.findUnique({
          where: { reference: body.orderReference },
          select: { id: true, sender: { select: { id: true, phone: true } } },
        })
      : null;
    if (body.orderReference && !order) throw AppError.notFound('ORDER_NOT_FOUND');
    const phone = body.phone ?? order?.sender.phone;
    if (!phone)
      throw AppError.badRequest('VALIDATION_FAILED', {}, [{ path: 'phone', message: 'requis' }]);
    const requester = await this.prisma.user.findUnique({ where: { phone }, select: { id: true } });
    const ticket = await this.prisma.ticket.create({
      data: {
        openedById: staff.id,
        requesterId: requester?.id ?? null,
        contactPhone: phone,
        orderId: order?.id ?? null,
        assigneeId: staff.id,
        category: body.category,
        priority: body.priority,
        subject: body.subject,
        messages: { create: { authorId: staff.id, body: body.message } },
      },
    });
    return this.adminDetail(ticket.id);
  }

  /**
   * Réponse au client (il est prévenu : notification, sinon SMS) ou note interne. Une
   * réponse prend en charge la demande si personne ne l'a encore.
   */
  async adminMessage(
    staff: AuthUser,
    id: string,
    body: z.output<typeof AdminTicketMessageBody>,
  ): Promise<z.output<typeof AdminTicketDto>> {
    const ticket = await this.prisma.ticket.findUnique({ where: { id } });
    if (!ticket) throw AppError.notFound('TICKET_NOT_FOUND');
    await this.prisma.$transaction([
      this.prisma.ticketMessage.create({
        data: { ticketId: id, authorId: staff.id, body: body.body, isInternal: body.internal },
      }),
      this.prisma.ticket.update({
        where: { id },
        data: body.internal
          ? { updatedAt: new Date() }
          : {
              assigneeId: ticket.assigneeId ?? staff.id,
              ...(ticket.status === 'OPEN' ? { status: 'IN_PROGRESS' as const } : {}),
            },
      }),
    ]);
    if (!body.internal) {
      // L'expéditeur ou le livreur voit la réponse dans la demande ouverte, en direct.
      if (ticket.requesterId) this.realtime.toUser(ticket.requesterId, 'support.message', { ticketId: id });
      await this.notifyReply(ticket.requesterId, ticket.contactPhone, ticket.number, body.body);
    }
    this.realtime.toOps('ops.support-message', { ticketId: id });
    return this.adminDetail(id);
  }

  async adminUpdate(
    staff: AuthUser,
    id: string,
    body: z.output<typeof AdminTicketUpdateBody>,
    request: Request,
  ): Promise<z.output<typeof AdminTicketDto>> {
    const ticket = await this.prisma.ticket.findUnique({ where: { id } });
    if (!ticket) throw AppError.notFound('TICKET_NOT_FOUND');
    if (body.assigneeId) {
      const assignee = await this.prisma.user.findUnique({
        where: { id: body.assigneeId },
        select: { roles: true },
      });
      if (!assignee || !isStaff(assignee.roles))
        throw AppError.badRequest('TICKET_ASSIGNEE_INVALID');
    }
    const data: Prisma.TicketUpdateInput = {};
    if (body.priority) data.priority = body.priority;
    if (body.assigneeId !== undefined) {
      data.assignee = body.assigneeId ? { connect: { id: body.assigneeId } } : { disconnect: true };
    }
    if (body.status) {
      data.status = body.status;
      if (body.status === 'RESOLVED') data.resolvedAt = new Date();
      if (body.status === 'OPEN' || body.status === 'IN_PROGRESS') data.resolvedAt = null;
    }
    await this.prisma.ticket.update({ where: { id }, data });
    await this.audit.record({
      actor: staff,
      action: 'ticket.updated',
      entityType: 'ticket',
      entityId: id,
      before: { status: ticket.status, priority: ticket.priority, assigneeId: ticket.assigneeId },
      after: body,
      request,
    });
    return this.adminDetail(id);
  }

  /** Preuves d'une commande pour trancher un litige. */
  async evidence(orderId: string): Promise<z.output<typeof OrderEvidenceDto>> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        senderId: true,
        parcelPhotoKey: true,
        proofs: { orderBy: { occurredAt: 'asc' } },
        ratings: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const trackPoints = await this.prisma.courseTrackPoint.count({ where: { orderId } });
    return {
      orderId: order.id,
      proofs: order.proofs.map((proof) => ({
        id: proof.id,
        kind: proof.kind,
        at: proof.occurredAt.toISOString(),
        latitude: proof.latitude,
        longitude: proof.longitude,
        codeVerified: proof.codeVerified,
        receivedBy: proof.receivedBy,
        hasPhoto: proof.photoKey !== null,
        calls: Array.isArray(proof.callLog)
          ? (proof.callLog as { to: 'RECIPIENT' | 'SENDER'; at: string; durationSeconds: number }[])
          : [],
      })),
      hasParcelPhoto: order.parcelPhotoKey !== null,
      ratings: order.ratings.map((rating) => ({
        by: rating.raterId === order.senderId ? ('SENDER' as const) : ('RIDER' as const),
        score: rating.score,
        comment: rating.comment,
        at: rating.createdAt.toISOString(),
      })),
      trackPoints,
    };
  }

  /** Photo d'une preuve (enlèvement, livraison, échec, retour) ; consultation tracée. */
  async proofPhoto(
    staff: AuthUser,
    proofId: string,
    request: Request,
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    const proof = await this.prisma.deliveryProof.findUnique({ where: { id: proofId } });
    if (!proof?.photoKey) throw AppError.notFound('MEDIA_NOT_FOUND');
    await this.audit.record({
      actor: staff,
      action: 'delivery_proof.photo_viewed',
      entityType: 'delivery_proof',
      entityId: proofId,
      request,
    });
    return this.media.read(proof.photoKey);
  }

  /** Photo du colis prise par l'expéditeur à la commande ; consultation tracée. */
  async parcelPhoto(
    staff: AuthUser,
    orderId: string,
    request: Request,
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { parcelPhotoKey: true },
    });
    if (!order?.parcelPhotoKey) throw AppError.notFound('MEDIA_NOT_FOUND');
    await this.audit.record({
      actor: staff,
      action: 'order.parcel_photo_viewed',
      entityType: 'order',
      entityId: orderId,
      request,
    });
    return this.media.read(order.parcelPhotoKey);
  }

  // --- Interne ---------------------------------------------------------------------------

  /** Dernier message et dernier message visible de chaque demande. */
  private async latestMessages(
    ids: string[],
  ): Promise<Map<string, { at: Date; awaitingReply: boolean }>> {
    const result = new Map<string, { at: Date; awaitingReply: boolean }>();
    if (ids.length === 0) return result;
    const last = await this.prisma.ticketMessage.findMany({
      where: { ticketId: { in: ids } },
      orderBy: [{ ticketId: 'asc' }, { createdAt: 'desc' }],
      distinct: ['ticketId'],
      select: { ticketId: true, createdAt: true },
    });
    const lastPublic = await this.prisma.ticketMessage.findMany({
      where: { ticketId: { in: ids }, isInternal: false },
      orderBy: [{ ticketId: 'asc' }, { createdAt: 'desc' }],
      distinct: ['ticketId'],
      select: { ticketId: true, author: { select: { roles: true } } },
    });
    const waiting = new Set(
      lastPublic.filter((message) => !isStaff(message.author.roles)).map((m) => m.ticketId),
    );
    for (const message of last) {
      result.set(message.ticketId, {
        at: message.createdAt,
        awaitingReply: waiting.has(message.ticketId),
      });
    }
    return result;
  }

  private toRow(
    ticket: TicketWithPeople,
    latest: { at: Date; awaitingReply: boolean } | undefined,
  ): Row {
    const requester = ticket.requester;
    const kind: Row['requester']['kind'] = !requester
      ? 'NO_ACCOUNT'
      : isStaff(requester.roles)
        ? 'STAFF'
        : requester.roles.includes('RIDER')
          ? 'RIDER'
          : requester.merchant
            ? 'MERCHANT'
            : 'CUSTOMER';
    return {
      id: ticket.id,
      reference: ticketReference(ticket.number),
      category: ticket.category,
      priority: ticket.priority,
      status: ticket.status,
      subject: ticket.subject,
      requester: {
        id: requester?.id ?? null,
        name: requester?.fullName ?? null,
        phone: ticket.contactPhone,
        kind,
      },
      assignee: ticket.assignee
        ? { id: ticket.assignee.id, name: ticket.assignee.fullName ?? ticket.assignee.phone }
        : null,
      order: ticket.order,
      fromApp: ticket.openedById === ticket.requesterId,
      createdAt: ticket.createdAt.toISOString(),
      lastMessageAt: (latest?.at ?? ticket.createdAt).toISOString(),
      awaitingReply: latest?.awaitingReply ?? false,
    };
  }

  /**
   * Prévient le client d'une réponse : notification sur son téléphone, sinon SMS avec la
   * réponse (un appelant sans compte n'a que le SMS). Un échec d'envoi n'annule rien.
   */
  private async notifyReply(
    requesterId: string | null,
    phone: string,
    number: number,
    body: string,
  ): Promise<void> {
    const reference = ticketReference(number);
    const excerpt = body.length > 280 ? `${body.slice(0, 277)}…` : body;
    try {
      const pushed = requesterId
        ? await this.notifications.toUser(requesterId, {
            template: 'SUPPORT_REPLY',
            params: { reference, excerpt },
            data: { type: 'support.reply', reference },
          })
        : false;
      if (!pushed) {
        await this.notifications.toPhone({
          phone,
          userId: requesterId ?? undefined,
          template: 'SUPPORT_REPLY',
          locale: 'fr',
          params: { reference, message: excerpt },
          smsOnly: true,
        });
      }
    } catch (error) {
      this.logger.warn(`Réponse ${reference} : client non prévenu (${String(error)})`);
    }
  }
}
