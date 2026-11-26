import { Inject, Injectable } from '@nestjs/common';
import { randomDigits } from '../common/crypto.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { trackingUrl } from '../orders/tracking-url.js';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { PresenceService } from '../dispatch/presence.service.js';
import { OrderFinanceService } from '../finance/order-finance.service.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import type { PublicTrackingDto } from '../orders/orders.schemas.js';
import { shortName } from '../orders/orders.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { etaFrom } from '../orders/eta.js';

/** Renvois du code de livraison par le destinataire, et délai entre deux envois. */
export const DELIVERY_CODE_RESENDS = 3;
const RESEND_COOLDOWN_MS = 2 * 60_000;

/** « +237 6•• •• 22 33 » : assez pour reconnaître son numéro, pas pour le lire en entier. */
export function maskPhone(phone: string): string {
  const digits = phone.replace(/\D/g, '').slice(-9);
  if (digits.length < 9) return '••••';
  return `+237 ${digits[0]}•• •• ${digits.slice(5, 7)} ${digits.slice(7)}`;
}

/** Le colis est à bord et le livreur va (ou retourne) chez le destinataire : son code compte. */
function codeActive(order: { status: OrderStatus; failureDecision: string | null }): boolean {
  return (
    order.status === 'PICKED_UP' ||
    order.status === 'IN_DELIVERY' ||
    (order.status === 'DELIVERY_FAILED' && order.failureDecision === 'RETRY')
  );
}

const BEFORE_PICKUP: readonly OrderStatus[] = ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'];

/** Le livreur a le colis et vient vers le destinataire (ou vient d'échouer à sa porte). */
const COMING: readonly OrderStatus[] = ['PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'];

/**
 * Page de suivi du destinataire (F2), ouverte depuis le SMS sans compte : statut, livreur à
 * appeler, heure estimée, somme à payer à la porte et demande Mobile Money en cours.
 */
@Injectable()
export class PublicTrackingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly finance: OrderFinanceService,
    private readonly transitions: OrderTransitionsService,
    private readonly notifications: NotificationService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Le destinataire n'a pas reçu son code : un nouveau code part par SMS (WhatsApp d'abord)
   * au numéro enregistré par l'expéditeur, jamais à un autre. L'ancien ne vaut plus rien ; les
   * essais ratés du livreur ne sont pas remis à zéro (pas de devinette par renvois).
   */
  async resendDeliveryCode(token: string, now = new Date()): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { trackingToken: token } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    if (!codeActive(order) || !order.pickedUpAt)
      throw AppError.conflict('DELIVERY_CODE_NOT_ACTIVE');
    if (order.deliveryCodeResends >= DELIVERY_CODE_RESENDS) {
      throw AppError.tooMany('DELIVERY_CODE_RESEND_LIMIT');
    }
    const last = order.deliveryCodeSentAt ?? order.pickedUpAt;
    if (now.getTime() - last.getTime() < RESEND_COOLDOWN_MS) {
      throw AppError.tooMany('DELIVERY_CODE_RESEND_TOO_SOON');
    }
    const code = randomDigits(4);
    // Mise à jour conditionnelle : deux clics simultanés ne font qu'un renvoi.
    const updated = await this.prisma.order.updateMany({
      where: { id: order.id, deliveryCodeResends: order.deliveryCodeResends, status: order.status },
      data: {
        deliveryCodeHash: this.transitions.deliveryCodeHash(order, code),
        deliveryCodeResends: { increment: 1 },
        deliveryCodeSentAt: now,
      },
    });
    if (updated.count === 0) throw AppError.tooMany('DELIVERY_CODE_RESEND_TOO_SOON');
    await this.notifications.toPhone({
      phone: order.recipientPhone,
      locale: 'fr',
      orderId: order.id,
      template: 'DELIVERY_CODE',
      params: { reference: order.reference, url: trackingUrl(this.env, order.trackingToken) },
      secretParams: { code },
    });
  }

  async view(token: string, now = new Date()): Promise<z.output<typeof PublicTrackingDto>> {
    const order = await this.prisma.order.findUnique({
      where: { trackingToken: token },
      include: {
        pickupAddress: { select: { latitude: true, longitude: true } },
        dropoffAddress: {
          select: {
            landmark: true,
            latitude: true,
            longitude: true,
            neighborhood: { select: { name: true } },
          },
        },
        merchant: { select: { shopName: true } },
        sender: { select: { fullName: true } },
        rider: {
          select: {
            id: true,
            vehicleType: true,
            plateNumber: true,
            user: { select: { fullName: true, phone: true } },
          },
        },
        events: { orderBy: { recordedAt: 'asc' } },
      },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');

    const coming =
      COMING.includes(order.status) &&
      !(order.status === 'DELIVERY_FAILED' && order.failureDecision === 'RETURN');
    const collection = await this.finance.collectionState(order);
    const position =
      coming && order.status !== 'DELIVERY_FAILED' && order.rider
        ? await this.presence.position(order.rider.id)
        : null;
    const eta = etaFrom(position, order.pickupAddress, order.dropoffAddress, now);
    // Course finie, ou colis qui repart chez l'expéditeur : plus rien à payer pour le
    // destinataire (les frais de retour ne regardent que l'expéditeur).
    const settled =
      ['DELIVERED', 'RETURNED', 'CANCELLED'].includes(order.status) ||
      (order.status === 'DELIVERY_FAILED' && order.failureDecision === 'RETURN');
    return {
      reference: order.reference,
      status: order.status,
      senderName: order.merchant?.shopName ?? order.sender.fullName ?? null,
      recipientName: order.recipientName,
      dropoffLandmark: order.dropoffAddress.landmark,
      dropoffNeighborhood: order.dropoffAddress.neighborhood?.name ?? null,
      scheduledFor: order.scheduledFor?.toISOString() ?? null,
      recipientConfirmedAt: order.recipientConfirmedAt?.toISOString() ?? null,
      recipientAvailable: order.recipientAvailable,
      canRespond: BEFORE_PICKUP.includes(order.status) && !order.recipientConfirmedAt,
      timeline: order.events.map((event) => ({
        status: event.toStatus,
        at: event.occurredAt.toISOString(),
      })),
      rider: order.rider
        ? {
            name: shortName(order.rider.user.fullName),
            vehicleType: order.rider.vehicleType,
            plateNumber: order.rider.plateNumber,
            phone: coming ? order.rider.user.phone : null,
          }
        : null,
      eta,
      deliveryCode:
        codeActive(order) && order.pickedUpAt
          ? {
              phone: maskPhone(order.recipientPhone),
              sentAt: (order.deliveryCodeSentAt ?? order.pickedUpAt).toISOString(),
              resendsLeft: Math.max(0, DELIVERY_CODE_RESENDS - order.deliveryCodeResends),
            }
          : null,
      map: {
        dropoff: {
          latitude: order.dropoffAddress.latitude,
          longitude: order.dropoffAddress.longitude,
        },
        // Même règle que l'heure d'arrivée : position récente, livreur en route vers la porte.
        rider:
          eta && position ? { latitude: position.latitude, longitude: position.longitude } : null,
      },
      due: settled ? { fee: 0, cod: 0, total: 0 } : collection.due,
      mobileMoneyFee: settled ? 0 : collection.mobileMoneyFee,
      paymentPending: !settled && collection.payment ? { amount: collection.payment.total } : null,
      failureDecision: order.status === 'DELIVERY_FAILED' ? order.failureDecision : null,
    };
  }
}
