import type { GeoPoint } from '../routing/distance.service.js';

export interface TimedPosition {
  latitude: number;
  longitude: number;
  at: Date;
}

/**
 * Positions des livreurs ramenées sur la chaussée pour la carte en direct (H1) : une demande
 * à OSRM par nouvelle position seulement, les autres viennent du cache. La carte attend au
 * plus `budgetMs` : les positions pas encore recalées partent sans recalage (le back-office
 * prend alors la position GPS) et leur recalage continue en arrière-plan, prêt pour le
 * rafraîchissement suivant. Une position déjà en cours de recalage n'est pas redemandée.
 */
export class RoadSnapCache {
  private readonly snapped = new Map<string, { at: number; road: GeoPoint | null }>();
  private readonly snapping = new Set<string>();

  constructor(
    private readonly snap: (point: GeoPoint) => Promise<GeoPoint | null>,
    private readonly budgetMs: number,
    private readonly concurrency: number,
  ) {}

  async positions(positions: Map<string, TimedPosition>): Promise<Map<string, GeoPoint | null>> {
    const result = new Map<string, GeoPoint | null>();
    for (const id of this.snapped.keys()) if (!positions.has(id)) this.snapped.delete(id);
    const todo: [string, TimedPosition][] = [];
    for (const [id, position] of positions) {
      const cached = this.snapped.get(id);
      if (cached?.at === position.at.getTime()) result.set(id, cached.road);
      else if (!this.snapping.has(id)) todo.push([id, position]);
    }
    if (todo.length === 0) return result;
    for (const [id] of todo) this.snapping.add(id);
    let open = true;
    const worker = async () => {
      for (let next = todo.shift(); next; next = todo.shift()) {
        const [id, position] = next;
        try {
          const road = await this.snap(position);
          this.snapped.set(id, { at: position.at.getTime(), road });
          if (open) result.set(id, road);
        } finally {
          this.snapping.delete(id);
        }
      }
    };
    const all = Promise.all(Array.from({ length: this.concurrency }, worker)).catch(
      () => undefined,
    );
    let timer: NodeJS.Timeout | undefined;
    await Promise.race([
      all,
      new Promise<void>((resolve) => {
        timer = setTimeout(resolve, this.budgetMs);
      }),
    ]);
    clearTimeout(timer);
    open = false;
    return result;
  }
}
