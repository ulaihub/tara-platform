import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { hashCode, randomDigits } from '../common/crypto.js';
import type { Order, Prisma } from '../generated/prisma/client.js';
import type { ActorRole, FailureReason, OrderStatus } from '../generated/prisma/enums.js';
import { OrderEventsBus, type OrderChange } from '../events/order-events.bus.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { checkTransition } from './order-state-machine.js';

export interface TransitionActor {
  /** Utilisateur à l'origine de l'action ; null pour le système. */
  id: string | null;
  role: ActorRole;
}

export interface TransitionOptions {
  riderId?: string | null | undefined;
  failureReason?: FailureReason | undefined;
  note?: string | undefined;
  latitude?: number | undefined;
  longitude?: number | undefined;
  /** Heure de l'action sur le téléphone, si elle a été faite hors ligne (E7). */
  occurredAt?: Date | undefined;
  /** Identifiant généré par l'app : rejouer la même action ne fait rien de plus (E7). */
  clientEventId?: string | undefined;
}

export interface TransitionResult {
  order: Order;
  /** Code de livraison en clair, généré à l'enlèvement, à envoyer après validation. */
  deliveryCode: string | null;
  /** À publier une fois la transaction validée (voir OrderEventsBus). */
  change: OrderChange;
}

/**
 * Seul point d'entrée pour changer le statut d'une commande : règles de la machine à états,
 * verrouillage optimiste (deux changements simultanés ne peuvent pas réussir tous les deux),
 * historique horodaté et effets associés.
 */
@Injectable()
export class OrderTransitionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: OrderEventsBus,
    @Inject(ENV) private readonly env: Env,
  ) {}

  deliveryCodeHash(order: Pick<Order, 'reference'>, code: string): string {
    return hashCode(this.env.CODE_HASH_SECRET, `delivery:${order.reference}`, code);
  }

  async apply(
    orderId: string,
    to: OrderStatus,
    actor: TransitionActor,
    options: TransitionOptions = {},
  ): Promise<Order> {
    if (options.clientEventId) {
      const replay = await this.prisma.orderEvent.findUnique({
        where: { clientEventId: options.clientEventId },
      });
      if (replay) {
        if (replay.orderId !== orderId) throw AppError.conflict('IDEMPOTENCY_CONFLICT');
        return this.prisma.order.findUniqueOrThrow({ where: { id: orderId } });
      }
    }
    const result = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
      return this.applyIn(tx, order, to, actor, options);
    });
    await this.events.publish(result.change);
    return result.order;
  }

  /**
   * Variante utilisable dans une transaction existante. L'appelant publie `change` une fois
   * la transaction validée : un abonné ne doit jamais voir un changement annulé ensuite.
   */
  async applyIn(
    tx: Prisma.TransactionClient,
    order: Order,
    to: OrderStatus,
    actor: TransitionActor,
    options: TransitionOptions = {},
  ): Promise<TransitionResult> {
    const verdict = checkTransition({ from: order.status, to, actor: actor.role, ...options });
    if (!verdict.ok) {
      switch (verdict.reason) {
        case 'INVALID':
          if (to === 'CANCELLED') throw AppError.conflict('ORDER_NOT_CANCELLABLE');
          throw AppError.conflict('ORDER_TRANSITION_INVALID', { from: order.status, to });
        case 'FORBIDDEN':
          throw AppError.forbidden();
        case 'RIDER_REQUIRED':
          throw AppError.badRequest('VALIDATION_FAILED', {}, [
            { path: 'riderId', message: 'requis' },
          ]);
        case 'FAILURE_REASON_REQUIRED':
          throw AppError.badRequest('VALIDATION_FAILED', {}, [
            { path: 'failureReason', message: 'requis' },
          ]);
        case 'NOTE_REQUIRED':
          throw AppError.badRequest('VALIDATION_FAILED', {}, [
            { path: 'reason', message: 'requis' },
          ]);
      }
    }
    if (actor.role === 'RIDER') {
      // Le livreur agit sur une course qui lui est attribuée, ou accepte celle qu'on lui propose.
      await this.assertRider(tx, to === 'ASSIGNED' ? options.riderId : order.riderId, actor.id);
    }

    const now = new Date();
    let deliveryCode: string | null = null;
    const data: Prisma.OrderUpdateManyMutationInput & { riderId?: string | null } = { status: to };
    switch (to) {
      case 'ASSIGNED':
        data.riderId = options.riderId ?? null;
        data.assignedAt = now;
        data.searchingSince = null;
        break;
      case 'SEARCHING_RIDER':
        if (order.status === 'ASSIGNED') {
          data.riderId = null;
          data.assignedAt = null;
        }
        // Nouvelle recherche : le délai d'alerte au dispatch repart de zéro (D2).
        data.searchingSince = now;
        data.dispatchAlertedAt = null;
        break;
      case 'PICKED_UP':
        deliveryCode = randomDigits(4);
        data.pickedUpAt = now;
        data.deliveryCodeHash = this.deliveryCodeHash(order, deliveryCode);
        break;
      case 'DELIVERY_FAILED':
        data.attemptCount = { increment: 1 };
        data.failureDecision = null;
        break;
      case 'DELIVERED':
        data.deliveredAt = now;
        break;
      case 'CANCELLED':
        data.cancelledAt = now;
        data.cancelReason = options.note ?? null;
        data.searchingSince = null;
        break;
      default:
        break;
    }

    const { count } = await tx.order.updateMany({
      where: { id: order.id, status: order.status },
      data,
    });
    if (count !== 1) throw AppError.conflict('ORDER_CONFLICT');

    await tx.orderEvent.create({
      data: {
        orderId: order.id,
        fromStatus: order.status,
        toStatus: to,
        actorId: actor.id,
        actorRole: actor.role,
        failureReason: options.failureReason ?? null,
        note: options.note ?? null,
        latitude: options.latitude ?? null,
        longitude: options.longitude ?? null,
        occurredAt: options.occurredAt ?? now,
        clientEventId: options.clientEventId ?? null,
      },
    });

    if (to === 'CANCELLED') {
      // Une commande annulée rend son code promo.
      await tx.promoRedemption.deleteMany({ where: { orderId: order.id } });
    }
    if (to === 'DELIVERED') {
      // Le point de livraison est confirmé : il sera proposé pour ce destinataire (B4).
      await tx.address.update({ where: { id: order.dropoffAddressId }, data: { verifiedAt: now } });
    }

    const updated = await tx.order.findUniqueOrThrow({ where: { id: order.id } });
    return {
      order: updated,
      deliveryCode,
      change: { order: updated, from: order.status, to, actor, deliveryCode },
    };
  }

  private async assertRider(
    tx: Prisma.TransactionClient,
    riderId: string | null | undefined,
    userId: string | null,
  ): Promise<void> {
    const rider = userId ? await tx.riderProfile.findUnique({ where: { userId } }) : null;
    if (!rider || !riderId || rider.id !== riderId) {
      throw new AppError('FORBIDDEN', HttpStatus.FORBIDDEN);
    }
  }
}
