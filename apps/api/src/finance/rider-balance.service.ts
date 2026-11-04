import { Injectable, type OnModuleInit } from '@nestjs/common';
import { AppError } from '../common/errors/app-error.js';
import { cashCarried } from '../dispatch/rider-scoring.js';
import {
  OrderTransitionHooks,
  type TransitionHookContext,
} from '../events/order-transition.hooks.js';
import type { Order, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { riderCashHeld, riderPayable } from './ledger.accounts.js';
import { LedgerService } from './ledger.service.js';

type Db = Prisma.TransactionClient | PrismaService;

/**
 * Solde prépayé du livreur (G5, décision 36). Le solde est le compte « gains dus au
 * livreur » : ses gains et ses recharges l'augmentent ; l'argent qu'il encaisse en espèces
 * en est déduit aussitôt (il garde les espèces, Tara reverse le marchand). Une course avec
 * encaissement n'est donnée qu'à un livreur dont le solde disponible couvre le montant, mis
 * de côté dès l'acceptation : le solde ne peut pas devenir négatif, aucune dette n'existe.
 */
@Injectable()
export class RiderBalanceService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly hooks: OrderTransitionHooks,
  ) {}

  onModuleInit(): void {
    this.hooks.register('rider-balance', (context) => this.onTransition(context));
  }

  /** Solde, montants mis de côté et disponible (solde − réservé − anciennes espèces dues). */
  async overview(
    riderId: string,
    db: Db = this.prisma,
  ): Promise<{ balance: number; reserved: number; legacyCash: number; available: number }> {
    // Une requête après l'autre : `db` peut être une transaction (une seule connexion).
    const balance = await this.ledger.balance(riderPayable(riderId), db);
    const legacyCash = Math.max(0, await this.ledger.balance(riderCashHeld(riderId), db));
    const reserved = await this.reserved(riderId, db);
    return {
      balance,
      reserved,
      legacyCash,
      available: Math.max(0, balance - reserved - legacyCash),
    };
  }

  async reserved(riderId: string, db: Db = this.prisma): Promise<number> {
    const sum = await db.riderBalanceHold.aggregate({
      where: { riderId, releasedAt: null },
      _sum: { amount: true },
    });
    return sum._sum.amount ?? 0;
  }

  /** Disponible de plusieurs livreurs à la fois (choix du livreur d'une course). */
  async availableFor(riderIds: string[]): Promise<Map<string, number>> {
    if (riderIds.length === 0) return new Map();
    const balances = await this.ledger.balances([
      ...riderIds.map(riderPayable),
      ...riderIds.map(riderCashHeld),
    ]);
    const holds = await this.prisma.riderBalanceHold.groupBy({
      by: ['riderId'],
      where: { riderId: { in: riderIds }, releasedAt: null },
      _sum: { amount: true },
    });
    const reserved = new Map(holds.map((hold) => [hold.riderId, hold._sum.amount ?? 0]));
    return new Map(
      riderIds.map((id) => {
        const balance = balances.get(riderPayable(id).code) ?? 0;
        const legacy = Math.max(0, balances.get(riderCashHeld(id).code) ?? 0);
        return [id, Math.max(0, balance - (reserved.get(id) ?? 0) - legacy)];
      }),
    );
  }

  private async onTransition({ tx, before, after, to }: TransitionHookContext): Promise<void> {
    switch (to) {
      case 'ASSIGNED':
        if (after.riderId) await this.reserve(tx, after, after.riderId);
        return;
      case 'SEARCHING_RIDER':
        // Course rendue ou retirée au livreur : son argent redevient disponible.
        if (before?.status === 'ASSIGNED') await this.release(tx, after.id);
        return;
      case 'DELIVERED':
      case 'RETURNED':
      case 'CANCELLED':
        await this.release(tx, after.id);
        return;
      default:
        return;
    }
  }

  /** Met de côté l'argent à encaisser ; refuse si le solde disponible ne le couvre pas. */
  private async reserve(
    tx: Prisma.TransactionClient,
    order: Order,
    riderId: string,
  ): Promise<void> {
    const amount = cashCarried(order);
    if (amount <= 0) return;
    // Deux acceptations simultanées ne peuvent pas engager le même solde.
    await this.ledger.lock(tx, [riderPayable(riderId), riderCashHeld(riderId)]);
    await this.release(tx, order.id);
    const { available } = await this.overview(riderId, tx);
    if (available < amount) {
      throw AppError.unprocessable('RIDER_BALANCE_TOO_LOW', { available, required: amount });
    }
    await tx.riderBalanceHold.create({ data: { riderId, orderId: order.id, amount } });
  }

  private async release(tx: Prisma.TransactionClient, orderId: string): Promise<void> {
    await tx.riderBalanceHold.updateMany({
      where: { orderId, releasedAt: null },
      data: { releasedAt: new Date() },
    });
  }
}
