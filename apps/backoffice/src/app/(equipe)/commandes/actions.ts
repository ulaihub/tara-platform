'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { OPS_ROLES } from '@/lib/navigation';

/** Résultat d'une action de la fiche commande, affiché sous le formulaire. */
export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DISPATCH = ['ADMIN', 'DISPATCHER'] as const;

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

function failure(error: unknown): ActionState {
  if (error instanceof ApiError) {
    if (error.code === 'RIDER_NOT_ELIGIBLE') {
      return { error: 'Ce livreur ne peut pas rouler : pièce manquante ou expirée.', done: false };
    }
    if (error.code === 'ORDER_NOT_CANCELLABLE') {
      return {
        error: 'Le colis est déjà récupéré : la commande ne peut plus être annulée.',
        done: false,
      };
    }
    return { error: error.message, done: false };
  }
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

/** Note interne (dispatch, support, administrateurs). */
export async function addNote(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(OPS_ROLES);
  const orderId = field(form, 'orderId');
  const body = field(form, 'body');
  if (!UUID.test(orderId)) return { error: 'Commande inconnue.', done: false };
  if (body.length < 2) return { error: 'La note est vide.', done: false };
  try {
    await staffApi(`/admin/orders/${orderId}/notes`, { method: 'POST', body: { body } });
  } catch (error) {
    return failure(error);
  }
  revalidatePath(`/commandes/${orderId}`);
  return { error: null, done: true };
}

/** Annulation avant l'enlèvement, avec la raison donnée à l'expéditeur. */
export async function cancelOrder(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(DISPATCH);
  const orderId = field(form, 'orderId');
  const reason = field(form, 'reason');
  if (!UUID.test(orderId)) return { error: 'Commande inconnue.', done: false };
  if (reason.length < 3) return { error: 'Indiquez la raison de l’annulation.', done: false };
  try {
    await staffApi(`/admin/orders/${orderId}/cancel`, { method: 'POST', body: { reason } });
  } catch (error) {
    return failure(error);
  }
  revalidatePath(`/commandes/${orderId}`);
  return { error: null, done: true };
}

/** Confie la course à un livreur choisi (réattribution si un autre l'avait). */
export async function assignRider(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(DISPATCH);
  const orderId = field(form, 'orderId');
  const riderId = field(form, 'riderId');
  const note = field(form, 'note');
  if (!UUID.test(orderId) || !UUID.test(riderId)) {
    return { error: 'Commande ou livreur inconnu.', done: false };
  }
  try {
    await staffApi(`/admin/orders/${orderId}/assign`, {
      method: 'POST',
      body: { riderId, ...(note ? { note } : {}) },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath(`/commandes/${orderId}`);
  return { error: null, done: true };
}
