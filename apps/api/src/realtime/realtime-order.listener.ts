import { Injectable, type OnModuleInit } from '@nestjs/common';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from './realtime.service.js';

/** Statuts des commandes poussés en direct à l'expéditeur, au livreur et aux opérations. */
@Injectable()
export class RealtimeOrderListener implements OnModuleInit {
  constructor(
    private readonly bus: OrderEventsBus,
    private readonly realtime: RealtimeService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit(): void {
    this.bus.subscribe('realtime', (change) => this.handle(change));
  }

  private async handle({ order, to }: OrderChange): Promise<void> {
    const event = {
      orderId: order.id,
      reference: order.reference,
      status: to,
      riderId: order.riderId,
      failureDecision: order.failureDecision,
      at: order.updatedAt.toISOString(),
    };
    this.realtime.toOrder(order.id, 'order.status', event);
    this.realtime.toUser(order.senderId, 'order.status', event);
    this.realtime.toOps('order.status', event);
    if (order.riderId) {
      const rider = await this.prisma.riderProfile.findUnique({
        where: { id: order.riderId },
        select: { userId: true },
      });
      if (rider) this.realtime.toUser(rider.userId, 'order.status', event);
    }
  }
}
