/**
 * Applique [fn] à chaque élément, au plus [limit] à la fois, et rend les résultats dans
 * l'ordre des éléments. Sert aux calculs en série (prix de 100 colis) sans saturer le
 * calcul d'itinéraire ni la base. La première erreur interrompt le tout.
 */
export async function mapLimit<T, R>(
  items: readonly T[],
  limit: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await fn(items[index] as T, index);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, worker));
  return results;
}
