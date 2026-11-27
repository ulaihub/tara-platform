'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { OPS_ROLES } from '@/lib/navigation';

/** Résultat d'une action sur un colis gardé au bureau, affiché sous le formulaire. */
export interface OfficeActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

function failure(error: unknown): OfficeActionState {
  if (error instanceof ApiError) return { error: error.message, done: false };
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

/**
 * Colis rendu à l'expéditeur venu au bureau : contre son code de retrait (frais payés dans
 * l'app), ou contre les frais reçus en espèces (case cochée).
 */
export async function handOver(_: OfficeActionState, form: FormData): Promise<OfficeActionState> {
  await requireStaff(OPS_ROLES);
  const orderId = field(form, 'orderId');
  const code = field(form, 'code');
  const cash = form.get('cash') === 'on';
  if (!UUID.test(orderId)) return { error: 'Commande inconnue.', done: false };
  if (!cash && !/^\d{4}$/.test(code)) {
    return { error: 'Tapez le code de retrait à 4 chiffres reçu par SMS.', done: false };
  }
  try {
    await staffApi(`/admin/office-returns/${orderId}/hand-over`, {
      method: 'POST',
      body: cash ? { cashReceived: true } : { code },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/bureau');
  return { error: null, done: true };
}

/** Garde finie sans que l'expéditeur vienne : ce que Tara a fait du colis. */
export async function markUnclaimed(
  _: OfficeActionState,
  form: FormData,
): Promise<OfficeActionState> {
  await requireStaff(OPS_ROLES);
  const orderId = field(form, 'orderId');
  const note = field(form, 'note');
  if (!UUID.test(orderId)) return { error: 'Commande inconnue.', done: false };
  if (note.length < 3) return { error: 'Dites ce que Tara a fait du colis.', done: false };
  try {
    await staffApi(`/admin/office-returns/${orderId}/unclaimed`, {
      method: 'POST',
      body: { note },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/bureau');
  return { error: null, done: true };
}
