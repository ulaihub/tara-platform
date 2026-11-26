import type { Metadata } from 'next';
import { requireStaff, staffApi } from '@/lib/dal';
import { LANDMARK_ROLES } from '@/lib/merchants';
import type { LandmarkList } from '@/lib/schemas';
import { MerchantsHeader } from '../tabs';
import { LandmarkMap } from './landmark-map';

export const metadata: Metadata = { title: 'Repères de la carte' };

/**
 * Repères de Douala : l'équipe ajoute les carrefours et lieux connus que la carte ne nomme
 * pas. Ils s'affichent dans les apps et sont proposés sous l'épingle d'une adresse.
 */
export default async function LandmarksPage() {
  await requireStaff(LANDMARK_ROLES);
  const landmarks = await staffApi<LandmarkList>('/admin/landmarks');
  return (
    <div className="mx-auto max-w-[1280px]">
      <MerchantsHeader
        current="/marchands/reperes"
        aside="Carrefours et lieux connus, visibles dans les apps expéditeur et livreur."
      />
      <LandmarkMap landmarks={landmarks} />
    </div>
  );
}
