import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { PresenceService } from '../dispatch/presence.service.js';
import { OrderFinanceService } from '../finance/order-finance.service.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import type { PublicTrackingDto } from '../orders/orders.schemas.js';
import { shortName } from '../orders/orders.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { haversineMeters } from '../routing/distance.service.js';

/** Vitesse prudente d'une moto dans Douala (la même que l'app expéditeur). */
const METERS_PER_MINUTE = 300;

/** Au-delà, la position du livreur est trop vieille pour annoncer une heure. */
const POSITION_MAX_AGE_MS = 5 * 60_000;

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
  ) {}

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
      eta:
        coming && order.status !== 'DELIVERY_FAILED' && order.rider
          ? await this.eta(order.rider.id, order.pickupAddress, order.dropoffAddress, now)
          : null,
      due: settled ? { fee: 0, cod: 0, total: 0 } : collection.due,
      paymentPending: !settled && collection.payment ? { amount: collection.payment.amount } : null,
      failureDecision: order.status === 'DELIVERY_FAILED' ? order.failureDecision : null,
    };
  }

  /** Arrivée estimée d'après la dernière position du livreur (à vol d'oiseau, prudente). */
  private async eta(
    riderId: string,
    pickup: { latitude: number; longitude: number },
    dropoff: { latitude: number; longitude: number },
    now: Date,
  ): Promise<z.output<typeof PublicTrackingDto>['eta']> {
    const position = await this.presence.position(riderId);
    if (!position || now.getTime() - position.at.getTime() > POSITION_MAX_AGE_MS) return null;
    const remaining = haversineMeters(position, dropoff);
    const total = Math.max(haversineMeters(pickup, dropoff), 1);
    return {
      minutes: Math.max(1, Math.ceil(remaining / METERS_PER_MINUTE)),
      distanceMeters: Math.round(remaining),
      progress: Math.round(Math.min(1, Math.max(0, 1 - remaining / total)) * 100) / 100,
    };
  }
}
