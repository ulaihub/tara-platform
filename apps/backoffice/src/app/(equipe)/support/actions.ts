'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import type { AdminTicket } from '@/lib/schemas';
import { SUPPORT_ROLES } from '@/lib/support';

/** Résultat d'une action du service client, affiché sous le formulaire. */
export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CATEGORIES = [
  'LOST_PARCEL',
  'DAMAGED_PARCEL',
  'LATE_DELIVERY',
  'PAYMENT',
  'RIDER_BEHAVIOR',
  'APP_BUG',
  'OTHER',
];
const PRIORITIES = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];
const STATUSES = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

/** Les messages de l'API sont déjà en français et parlent au membre de l'équipe. */
function failure(error: unknown): ActionState {
  if (error instanceof ApiError) {
    if (error.code === 'VALIDATION_FAILED') {
      return { error: 'Vérifiez le numéro ou la référence de commande.', done: false };
    }
    return { error: error.message, done: false };
  }
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

/** Demande ouverte après un appel ; on ouvre ensuite sa fiche. */
export async function createTicket(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(SUPPORT_ROLES);
  const phone = field(form, 'phone');
  const orderReference = field(form, 'orderReference');
  const category = field(form, 'category');
  const priority = field(form, 'priority') || 'NORMAL';
  const subject = field(form, 'subject');
  const message = field(form, 'message');
  if (!phone && !orderReference) {
    return {
      error: 'Indiquez le numéro de la personne ou la référence de la commande.',
      done: false,
    };
  }
  if (!CATEGORIES.includes(category))
    return { error: 'Choisissez le motif de l’appel.', done: false };
  if (!PRIORITIES.includes(priority)) return { error: 'Priorité inconnue.', done: false };
  if (subject.length < 3) return { error: 'Donnez un titre court à la demande.', done: false };
  if (message.length < 2) return { error: 'Résumez l’appel en quelques mots.', done: false };
  let ticket: AdminTicket;
  try {
    ticket = await staffApi<AdminTicket>('/admin/support/tickets', {
      method: 'POST',
      body: {
        ...(phone ? { phone } : {}),
        ...(orderReference ? { orderReference } : {}),
        category,
        priority,
        subject,
        message,
      },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/support');
  redirect(`/support/${ticket.id}`);
}

/** Réponse au client (il est prévenu) ou note interne. */
export async function sendMessage(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(SUPPORT_ROLES);
  const ticketId = field(form, 'ticketId');
  const body = field(form, 'body');
  const internal = field(form, 'internal') === 'true';
  if (!UUID.test(ticketId)) return { error: 'Demande inconnue.', done: false };
  if (body.length < 2) return { error: 'Le message est vide.', done: false };
  try {
    await staffApi(`/admin/support/tickets/${ticketId}/messages`, {
      method: 'POST',
      body: { body, internal },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath(`/support/${ticketId}`);
  revalidatePath('/support');
  return { error: null, done: true };
}

/** Prise en charge, priorité ou statut. */
export async function updateTicket(_: ActionState, form: FormData): Promise<ActionState> {
  const session = await requireStaff(SUPPORT_ROLES);
  const ticketId = field(form, 'ticketId');
  const status = field(form, 'status');
  const priority = field(form, 'priority');
  const assign = field(form, 'assign');
  if (!UUID.test(ticketId)) return { error: 'Demande inconnue.', done: false };
  const body: Record<string, unknown> = {};
  if (status) {
    if (!STATUSES.includes(status)) return { error: 'Statut inconnu.', done: false };
    body.status = status;
  }
  if (priority) {
    if (!PRIORITIES.includes(priority)) return { error: 'Priorité inconnue.', done: false };
    body.priority = priority;
  }
  if (assign === 'me') body.assigneeId = session.userId;
  if (assign === 'none') body.assigneeId = null;
  if (Object.keys(body).length === 0) return { error: 'Rien à modifier.', done: false };
  try {
    await staffApi(`/admin/support/tickets/${ticketId}`, { method: 'PATCH', body });
  } catch (error) {
    return failure(error);
  }
  revalidatePath(`/support/${ticketId}`);
  revalidatePath('/support');
  return { error: null, done: true };
}
