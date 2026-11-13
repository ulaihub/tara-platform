'use server';

import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { OPS_ROLES } from '@/lib/navigation';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** « Je m'en occupe » sur un SOS : l'équipe voit qu'un agent a pris l'alerte (E8). */
export async function acknowledgeSos(id: string): Promise<{ error: string | null }> {
  await requireStaff(OPS_ROLES);
  if (!UUID.test(id)) return { error: 'Alerte inconnue.' };
  try {
    await staffApi(`/admin/safety-alerts/${id}/acknowledge`, { method: 'POST' });
    return { error: null };
  } catch (error) {
    return { error: error instanceof ApiError ? error.message : 'Action impossible, réessayez.' };
  }
}
