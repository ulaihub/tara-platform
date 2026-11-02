import { Injectable, Logger } from '@nestjs/common';
import type { Order } from '../generated/prisma/client.js';
import type { ActorRole, OrderStatus } from '../generated/prisma/enums.js';

/** Changement de statut d'une commande, publié APRÈS la validation de la transaction. */
export interface OrderChange {
  order: Order;
  /** null à la création de la commande. */
  from: OrderStatus | null;
  to: OrderStatus;
  actor: { id: string | null; role: ActorRole };
  /** Code de livraison en clair, présent seulement à l'enlèvement (jamais enregistré). */
  deliveryCode?: string | null;
  /** Code de retour en clair, présent seulement à l'échec de livraison (jamais enregistré). */
  returnCode?: string | null;
}

type Listener = (change: OrderChange) => Promise<void>;

/**
 * Diffusion des changements de statut aux modules intéressés (attribution, temps réel,
 * notifications) sans dépendance entre eux. Un abonné en échec ne bloque ni l'action de
 * l'utilisateur ni les autres abonnés : l'erreur est journalisée et les tâches de
 * rattrapage (balayage de l'attribution, nouvelles tentatives d'envoi) prennent le relais.
 */
@Injectable()
export class OrderEventsBus {
  private readonly logger = new Logger(OrderEventsBus.name);
  private readonly listeners: { name: string; listener: Listener }[] = [];

  subscribe(name: string, listener: Listener): void {
    this.listeners.push({ name, listener });
  }

  async publish(change: OrderChange): Promise<void> {
    for (const { name, listener } of this.listeners) {
      try {
        await listener(change);
      } catch (error) {
        this.logger.error(
          `Abonné ${name} en échec pour ${change.order.reference} (${change.from ?? '∅'} → ${change.to})`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }
  }

  async publishAll(changes: OrderChange[]): Promise<void> {
    for (const change of changes) await this.publish(change);
  }
}
