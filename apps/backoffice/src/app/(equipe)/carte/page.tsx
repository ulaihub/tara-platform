import type { Metadata } from 'next';
import { requireStaff, staffApi } from '@/lib/dal';
import { OPS_ROLES } from '@/lib/navigation';
import type { LiveMap as LiveMapData } from '@/lib/schemas';
import { LiveMap } from './live-map';

export const metadata: Metadata = { title: 'Carte en direct' };

/** Carte en direct (H1) : premier affichage préparé sur le serveur, puis rafraîchi. */
export default async function MapPage({
  searchParams,
}: {
  searchParams: Promise<{ commande?: string }>;
}) {
  await requireStaff(OPS_ROLES);
  const { commande } = await searchParams;
  const initial = await staffApi<LiveMapData>('/admin/live-map');
  // Lien « Voir sur la carte » depuis une fiche commande : la commande est choisie d'emblée.
  const focusOrder =
    commande && initial.orders.some((order) => order.id === commande) ? commande : null;
  return <LiveMap initial={initial} focusOrder={focusOrder} />;
}
