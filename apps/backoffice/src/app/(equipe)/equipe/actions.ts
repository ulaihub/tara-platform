'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { cameroonMobile } from '@/lib/phone';
import { TEAM_ROLES } from '@/lib/team';

export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STAFF = ['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'];

function failure(error: unknown): ActionState {
  if (error instanceof ApiError) return { error: error.message, done: false };
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

function rolesOf(form: FormData): string[] {
  return form.getAll('roles').filter((role): role is string => STAFF.includes(String(role)));
}

/** Donne l'accès au back-office à un numéro, avec ses rôles. */
export async function addMember(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(TEAM_ROLES);
  const phone = cameroonMobile(String(form.get('phone') ?? ''));
  const fullName = String(form.get('fullName') ?? '').trim();
  const roles = rolesOf(form);
  if (!phone) return { error: 'Numéro camerounais attendu (6XX XX XX XX).', done: false };
  if (fullName.length < 2) return { error: 'Indiquez le nom de la personne.', done: false };
  if (roles.length === 0) return { error: 'Choisissez au moins un rôle.', done: false };
  try {
    await staffApi('/admin/team', { method: 'POST', body: { phone, fullName, roles } });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/equipe');
  return { error: null, done: true };
}

export async function saveRoles(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(TEAM_ROLES);
  const userId = String(form.get('userId') ?? '');
  const roles = rolesOf(form);
  if (!UUID.test(userId)) return { error: 'Membre inconnu.', done: false };
  if (roles.length === 0) {
    return { error: 'Au moins un rôle ; pour retirer l’accès, utilisez « Retirer ».', done: false };
  }
  try {
    await staffApi(`/admin/team/${userId}/roles`, { method: 'PUT', body: { roles } });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/equipe');
  return { error: null, done: true };
}

export async function removeMember(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(TEAM_ROLES);
  const userId = String(form.get('userId') ?? '');
  if (!UUID.test(userId)) return { error: 'Membre inconnu.', done: false };
  try {
    await staffApi(`/admin/team/${userId}`, { method: 'DELETE' });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/equipe');
  return { error: null, done: true };
}

/** Téléphone perdu : nouvelle configuration de la double authentification. */
export async function resetMfa(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(TEAM_ROLES);
  const userId = String(form.get('userId') ?? '');
  if (!UUID.test(userId)) return { error: 'Membre inconnu.', done: false };
  try {
    await staffApi(`/admin/users/${userId}/mfa/reset`, { method: 'POST' });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/equipe');
  return { error: null, done: true };
}
