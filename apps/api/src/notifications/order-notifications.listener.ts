import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import { trackingUrl } from '../orders/tracking-url.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { NotificationService } from './notification.service.js';
import type { PushTemplate } from './push-templates.js';

/** Prénom du destinataire, pour dire à l'expéditeur quel colis donner. */
function firstName(name: string): string {
  return name.trim().split(/\s+/)[0] ?? name;
}

const SENDER_PUSH: Partial<Record<OrderChange['to'], PushTemplate>> = {
  ASSIGNED: 'ORDER_ASSIGNED',
  PICKED_UP: 'ORDER_PICKED_UP',
  IN_DELIVERY: 'ORDER_IN_DELIVERY',
  DELIVERED: 'ORDER_DELIVERED',
  DELIVERY_FAILED: 'ORDER_DELIVERY_FAILED',
  RETURNED: 'ORDER_RETURNED',
  CANCELLED: 'ORDER_CANCELLED',
};

/**
 * Messages envoyés à chaque étape d'une commande (cycle de vie du cahier des charges) :
 * push à l'expéditeur, WhatsApp ou SMS au destinataire, push au livreur concerné.
 */
@Injectable()
export class OrderNotificationsListener implements OnModuleInit {
  constructor(
    private readonly bus: OrderEventsBus,
    private readonly notifications: NotificationService,
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  onModuleInit(): void {
    this.bus.subscribe('notifications', (change) => this.handle(change));
  }

  private async handle({
    order,
    from,
    to,
    actor,
    deliveryCode,
    returnCode,
  }: OrderChange): Promise<void> {
    if (to === 'SEARCHING_RIDER') return;
    const full = await this.prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: {
        merchant: true,
        sender: { include: { merchant: true } },
        rider: { include: { user: true } },
      },
    });
    const senderName =
      full.merchant?.shopName ??
      full.sender.merchant?.shopName ??
      full.sender.fullName ??
      'Un expéditeur';
    const url = trackingUrl(this.env, order.trackingToken);
    const recipient = {
      phone: order.recipientPhone,
      locale: 'fr' as const, // Langue du destinataire inconnue : français par défaut.
      orderId: order.id,
    };

    switch (to) {
      case 'CREATED':
        await this.notifications.toPhone({
          ...recipient,
          template: 'RECIPIENT_CONFIRMATION',
          params: { sender: senderName, reference: order.reference, url },
        });
        return;
      case 'PICKED_UP':
        if (deliveryCode) {
          await this.notifications.toPhone({
            ...recipient,
            template: 'DELIVERY_CODE',
            params: { reference: order.reference, url },
            secretParams: { code: deliveryCode },
          });
        }
        break;
      case 'DELIVERY_FAILED':
        if (returnCode) {
          await this.notifications.toPhone({
            phone: full.sender.phone,
            locale: full.sender.locale === 'EN' ? 'en' : 'fr',
            userId: order.senderId,
            orderId: order.id,
            template: 'RETURN_CODE',
            params: { reference: order.reference },
            secretParams: { code: returnCode },
            smsOnly: true,
          });
        }
        break;
      case 'DELIVERED':
        await this.notifications.toPhone({
          ...recipient,
          template: 'DELIVERY_RECEIPT',
          params: { reference: order.reference },
        });
        break;
      case 'CANCELLED':
        await this.notifications.toPhone({
          ...recipient,
          template: 'ORDER_CANCELLED_RECIPIENT',
          params: { sender: senderName, reference: order.reference },
        });
        // Le livreur déjà en route vers le point d'enlèvement est prévenu, sauf si c'est lui
        // qui a refusé le colis.
        if (from === 'ASSIGNED' && full.rider && actor.id !== full.rider.userId) {
          await this.notifications.toUser(full.rider.userId, {
            template: 'RIDER_ORDER_CANCELLED',
            params: { reference: order.reference },
            data: { type: 'order.cancelled', orderId: order.id },
            orderId: order.id,
          });
        }
        break;
      default:
        break;
    }

    // L'expéditeur est prévenu, sauf de ses propres actions. Colis refusé par le livreur :
    // il apprend pourquoi et ce que coûte le déplacement.
    const refused = to === 'CANCELLED' && actor.role === 'RIDER';
    // Envoi de plusieurs colis : le numéro dit lequel donner au livreur qui arrive.
    const numbered = to === 'ASSIGNED' && order.batchNumber !== null;
    const template = refused
      ? 'ORDER_PARCEL_REFUSED'
      : numbered
        ? 'ORDER_ASSIGNED_BATCH'
        : SENDER_PUSH[to];
    if (template && actor.id !== order.senderId) {
      await this.notifications.toUser(order.senderId, {
        template,
        params: {
          reference: order.reference,
          rider: full.rider?.user.fullName ?? 'Votre livreur',
          reason: full.cancelReason ?? 'Colis non conforme',
          fee: order.retryFee,
          number: order.batchNumber ?? '',
          recipient: firstName(order.recipientName),
        },
        data: { type: 'order.status', orderId: order.id, status: to },
        orderId: order.id,
      });
    }
  }
}
