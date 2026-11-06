import { NextResponse } from 'next/server';
import { requireStaff, staffApi } from '@/lib/dal';
import { CARTE_ROLES } from '@/lib/navigation';
import type { LiveMap } from '@/lib/schemas';

/**
 * Données de la carte en direct, lues par la page toutes les 5 secondes. Le jeton reste
 * sur le serveur ; sans session valide, la réponse renvoie vers la connexion.
 */
export async function GET() {
  await requireStaff(CARTE_ROLES);
  const map = await staffApi<LiveMap>('/admin/live-map');
  return NextResponse.json(map, { headers: { 'cache-control': 'no-store' } });
}
