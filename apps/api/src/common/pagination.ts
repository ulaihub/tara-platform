import { z } from 'zod';

/**
 * Pagination par curseur : les identifiants UUID v7 sont triés dans le temps,
 * le curseur est simplement le dernier identifiant reçu.
 */
export const PageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.uuid().optional(),
});
export type PageQuery = z.output<typeof PageQuery>;

export function pageOf<T extends { id: string }>(
  rows: T[],
  limit: number,
): { items: T[]; nextCursor: string | null } {
  const items = rows.slice(0, limit);
  return { items, nextCursor: rows.length > limit ? (items.at(-1)?.id ?? null) : null };
}

export function pageSchema<T extends z.ZodType>(item: T) {
  return z.object({ items: z.array(item), nextCursor: z.uuid().nullable() });
}
