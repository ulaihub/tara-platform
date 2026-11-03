import { Injectable } from '@nestjs/common';
import type { Order, Prisma } from '../generated/prisma/client.js';
import type { ActorRole, OrderStatus } from '../generated/prisma/enums.js';

export interface TransitionHookContext {
  tx: Prisma.TransactionClient;
  /** null à la création de la commande. */
  before: Order | null;
  after: Order;
  to: OrderStatus;
  actor: { id: string | null; role: ActorRole };
}

type Hook = (context: TransitionHookContext) => Promise<void>;

/**
 * Effets exécutés DANS la transaction d'un changement de statut (contrairement à
 * OrderEventsBus, après validation). Sert aux écritures comptables : le statut et l'argent
 * changent ensemble ou pas du tout. Une erreur annule le changement de statut.
 */
@Injectable()
export class OrderTransitionHooks {
  private readonly hooks: { name: string; hook: Hook }[] = [];

  register(name: string, hook: Hook): void {
    this.hooks.push({ name, hook });
  }

  async run(context: TransitionHookContext): Promise<void> {
    for (const { hook } of this.hooks) await hook(context);
  }
}
