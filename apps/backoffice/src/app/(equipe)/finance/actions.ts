'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { FINANCE_ROLES } from '@/lib/finance';

/** Résultat d'une action de la finance, affiché sous le bouton. */
export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

function failure(error: unknown): ActionState {
  if (error instanceof ApiError) return { error: error.message, done: false };
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

function refresh(): void {
  revalidatePath('/finance');
  revalidatePath('/finance/reversements');
}

/** Gros reversement validé : il part vers le téléphone du bénéficiaire. */
export async function approvePayout(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(FINANCE_ROLES);
  const payoutId = field(form, 'payoutId');
  if (!UUID.test(payoutId)) return { error: 'Reversement inconnu.', done: false };
  try {
    await staffApi(`/admin/finance/payouts/${payoutId}/approve`, { method: 'POST' });
  } catch (error) {
    return failure(error);
  }
  refresh();
  return { error: null, done: true };
}

/** Reversement refusé : l'argent reste sur le solde du bénéficiaire, avec le motif. */
export async function rejectPayout(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(FINANCE_ROLES);
  const payoutId = field(form, 'payoutId');
  const reason = field(form, 'reason');
  if (!UUID.test(payoutId)) return { error: 'Reversement inconnu.', done: false };
  if (reason.length < 3) return { error: 'Indiquez le motif du refus.', done: false };
  try {
    await staffApi(`/admin/finance/payouts/${payoutId}/reject`, {
      method: 'POST',
      body: { reason },
    });
  } catch (error) {
    return failure(error);
  }
  refresh();
  return { error: null, done: true };
}

/** Contrôle d'une journée relancé (après correction d'un écart). */
export async function rerunCheck(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(FINANCE_ROLES);
  const day = field(form, 'day');
  if (!DAY.test(day)) return { error: 'Journée inconnue.', done: false };
  try {
    await staffApi(`/admin/finance/reconciliations/${day}/run`, { method: 'POST' });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/finance');
  revalidatePath('/finance/controle');
  return { error: null, done: true };
}
