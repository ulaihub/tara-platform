import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import { trackingUrl } from '../orders/tracking-url.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { NotificationService } from './notification.service.js';
import type { PushTemplate } from './push-templates.js';
import { waitingFeeMax } from '../orders/waiting-fee.js';
import { shortDate } from '../common/time.js';

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
  HELD_AT_OFFICE: 'ORDER_HELD_AT_OFFICE',
  UNCLAIMED: 'ORDER_UNCLAIMED',
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
      case 'HELD_AT_OFFICE':
        // Retour non payé : l'expéditeur apprend où est son colis et comment le récupérer.
        await this.notifications.toPhone({
          phone: full.sender.phone,
          locale: full.sender.locale === 'EN' ? 'en' : 'fr',
          userId: order.senderId,
          orderId: order.id,
          template: 'OFFICE_HELD',
          params: {
            reference: order.reference,
            address: this.env.OFFICE_ADDRESS,
            hours: full.sender.locale === 'EN' ? this.env.OFFICE_HOURS_EN : this.env.OFFICE_HOURS,
            amount: String(order.officeDue),
            until: order.officeUntil ? shortDate(order.officeUntil) : '',
          },
        });
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
          // Annulé par l'expéditeur alors qu'il était en route : son déplacement est payé (C).
          const paid = await this.prisma.journalEntry.findUnique({
            where: { idempotencyKey: `order:${order.id}:cancel-fee` },
            select: { id: true },
          });
          await this.notifications.toUser(full.rider.userId, {
            template: paid ? 'RIDER_ORDER_CANCELLED_PAID' : 'RIDER_ORDER_CANCELLED',
            params: paid
              ? {
                  reference: order.reference,
                  amount: String(this.env.CANCELLATION_FEE_RIDER_PART),
                }
              : { reference: order.reference },
            data: { type: 'order.cancelled', orderId: order.id },
            orderId: order.id,
          });
        }
        break;
      default:
        break;
    }

    // Expéditeur absent après l'attente (D) : prévenu une fois, sur la commande facturée.
    if (to === 'CANCELLED' && actor.role === 'RIDER') {
      const absent = await this.prisma.deliveryProof.findFirst({
        where: { orderId: order.id, kind: 'SENDER_ABSENT' },
        select: { id: true },
      });
      if (absent) {
        const charged = await this.prisma.journalEntry.findUnique({
          where: { idempotencyKey: `order:${order.id}:cancel-fee` },
          select: { id: true },
        });
        if (charged) {
          await this.notifications.toUser(order.senderId, {
            template: 'ORDER_SENDER_ABSENT',
            params: {
              reference: order.reference,
              minutes: String(this.env.WAITING_MAX_MINUTES),
              fee: String(this.env.CANCELLATION_FEE + waitingFeeMax(this.env)),
            },
            data: { type: 'order.status', orderId: order.id, status: to },
            orderId: order.id,
          });
        }
        return;
      }
    }

    // L'expéditeur est prévenu, sauf de ses propres actions. Colis refusé par le livreur :
    // il apprend pourquoi et ce que coûte le déplacement.
    const refused = to === 'CANCELLED' && actor.role === 'RIDER';
    // Tournée (2c) : un seul message pour tous les colis de l'envoi que ce livreur emporte,
    // envoyé avec le plus petit numéro ; les autres colis de la tournée n'en envoient pas.
    const tour =
      to === 'ASSIGNED' && full.tourId
        ? await this.prisma.order.findMany({
            where: { tourId: full.tourId, senderId: order.senderId, batchNumber: { not: null } },
            select: { id: true, batchNumber: true },
            orderBy: { batchNumber: 'asc' },
          })
        : [];
    if (tour.length > 1 && tour[0]?.id !== order.id) return;
    const numbers = tour.map((mate) => String(mate.batchNumber));
    // Envoi de plusieurs colis : le numéro dit lequel donner au livreur qui arrive.
    const numbered = to === 'ASSIGNED' && order.batchNumber !== null;
    const template = refused
      ? 'ORDER_PARCEL_REFUSED'
      : numbers.length > 1
        ? 'ORDER_ASSIGNED_TOUR'
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
          count: numbers.length,
          numbers: numbers.slice(0, -1).join(', '),
          last: numbers.at(-1) ?? '',
          amount: order.officeDue,
          until: order.officeUntil ? shortDate(order.officeUntil) : '',
        },
        data: { type: 'order.status', orderId: order.id, status: to },
        orderId: order.id,
      });
    }
  }
}
