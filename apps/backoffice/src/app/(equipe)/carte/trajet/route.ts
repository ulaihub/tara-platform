import { NextResponse, type NextRequest } from 'next/server';
import { requireStaff, staffApi } from '@/lib/dal';
import { OPS_ROLES } from '@/lib/navigation';
import type { RiderTrail } from '@/lib/schemas';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Course du livreur choisi sur la carte : chemin parcouru et itinéraire sur les rues. */
export async function GET(request: NextRequest) {
  await requireStaff(OPS_ROLES);
  const rider = request.nextUrl.searchParams.get('livreur') ?? '';
  const order = request.nextUrl.searchParams.get('commande');
  if (!UUID.test(rider) || (order !== null && !UUID.test(order))) {
    return NextResponse.json({ error: 'Livreur ou commande inconnus.' }, { status: 400 });
  }
  const trail = await staffApi<RiderTrail>(`/admin/riders/${rider}/trail`, {
    query: { orderId: order ?? undefined },
  });
  return NextResponse.json(trail, { headers: { 'cache-control': 'no-store' } });
}
