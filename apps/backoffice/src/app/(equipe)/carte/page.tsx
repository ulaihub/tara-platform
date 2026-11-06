import type { Metadata } from 'next';
import { requireStaff, staffApi } from '@/lib/dal';
import { CARTE_ROLES } from '@/lib/navigation';
import type { LiveMap as LiveMapData } from '@/lib/schemas';
import { LiveMap } from './live-map';

export const metadata: Metadata = { title: 'Carte en direct' };

/** Carte en direct (H1) : premier affichage préparé sur le serveur, puis rafraîchi. */
export default async function MapPage() {
  await requireStaff(CARTE_ROLES);
  const initial = await staffApi<LiveMapData>('/admin/live-map');
  return <LiveMap initial={initial} />;
}
