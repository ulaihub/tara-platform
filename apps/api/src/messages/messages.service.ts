import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { shortName } from '../orders/orders.service.js';
import type { Order, OrderMessage } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type { OrderConversationDto, OrderMessageDto } from './messages.schemas.js';

/** Étapes où l'expéditeur et le livreur peuvent s'écrire. */
const OPEN_STATUSES = ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'] as const;
const STAFF_ROLES = ['ADMIN', 'DISPATCHER', 'SUPPORT'];
const HISTORY_LIMIT = 200;

type Side = 'SENDER' | 'RIDER' | 'STAFF';

/**
 * Messages entre l'expéditeur et le livreur d'une commande. Chacun ne lit que sa
 * conversation ; l'équipe la lit en cas de litige, sans pouvoir écrire à leur place.
 */
@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
  ) {}

  async list(user: AuthUser, orderId: string): Promise<z.output<typeof OrderConversationDto>> {
    const { order, side } = await this.access(user, orderId);
    const messages = await this.prisma.orderMessage.findMany({
      where: { orderId },
      orderBy: { createdAt: 'asc' },
      take: HISTORY_LIMIT,
    });
    // Ouvrir la conversation marque comme lus les messages de l'autre personne.
    if (side !== 'STAFF') {
      await this.prisma.orderMessage.updateMany({
        where: { orderId, authorRole: side === 'SENDER' ? 'RIDER' : 'SENDER', readAt: null },
        data: { readAt: new Date() },
      });
    }
    return {
      open: this.isOpen(order),
      messages: messages.map((message) => this.toDto(message, user.id)),
    };
  }

  async send(
    user: AuthUser,
    orderId: string,
    body: string,
  ): Promise<z.output<typeof OrderMessageDto>> {
    const { order, side } = await this.access(user, orderId);
    if (side === 'STAFF') throw AppError.forbidden();
    if (!this.isOpen(order)) throw AppError.conflict('CONVERSATION_CLOSED');
    const message = await this.prisma.orderMessage.create({
      data: { orderId, authorId: user.id, authorRole: side, body },
    });
    const author = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { fullName: true },
    });
    const recipientId =
      side === 'SENDER'
        ? (
            await this.prisma.riderProfile.findUniqueOrThrow({
              where: { id: order.riderId as string },
              select: { userId: true },
            })
          ).userId
        : order.senderId;
    this.realtime.toUser(recipientId, 'order.message', {
      orderId,
      reference: order.reference,
      message: this.toDto(message, recipientId),
    });
    await this.notifications.toUser(recipientId, {
      template: side === 'SENDER' ? 'MESSAGE_FROM_SENDER' : 'MESSAGE_FROM_RIDER',
      params: {
        name: shortName(author.fullName) || order.reference,
        reference: order.reference,
        body: body.length > 120 ? `${body.slice(0, 117)}…` : body,
      },
      data: { type: 'order.message', orderId },
      orderId,
    });
    return this.toDto(message, user.id);
  }

  private isOpen(order: Order): boolean {
    return order.riderId !== null && (OPEN_STATUSES as readonly string[]).includes(order.status);
  }

  private async access(user: AuthUser, orderId: string): Promise<{ order: Order; side: Side }> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    if (order.senderId === user.id) return { order, side: 'SENDER' };
    if (order.riderId) {
      const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
      if (rider?.id === order.riderId) return { order, side: 'RIDER' };
    }
    if (user.roles.some((role) => STAFF_ROLES.includes(role))) return { order, side: 'STAFF' };
    throw AppError.notFound('ORDER_NOT_FOUND');
  }

  private toDto(message: OrderMessage, viewerId: string): z.output<typeof OrderMessageDto> {
    return {
      id: message.id,
      mine: message.authorId === viewerId,
      authorRole: message.authorRole === 'RIDER' ? 'RIDER' : 'SENDER',
      body: message.body,
      createdAt: message.createdAt.toISOString(),
      readAt: message.readAt?.toISOString() ?? null,
    };
  }
}
