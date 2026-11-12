'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { RIDER_ROLES } from '@/lib/riders';

/** Résultat d'une action de la fiche livreur, affiché sous le formulaire. */
export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const DECISIONS = ['APPROVE', 'REJECT', 'SUSPEND', 'REACTIVATE'] as const;

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

/** Les messages de l'API sont déjà en français et parlent au membre de l'équipe. */
function failure(error: unknown): ActionState {
  if (error instanceof ApiError) return { error: error.message, done: false };
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

function done(riderId: string): ActionState {
  revalidatePath(`/livreurs/${riderId}`);
  revalidatePath('/livreurs');
  return { error: null, done: true };
}

/** Pièce validée (avec sa date d'expiration lue sur le document) ou refusée avec le motif. */
export async function reviewDocument(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(RIDER_ROLES);
  const riderId = field(form, 'riderId');
  const documentId = field(form, 'documentId');
  const decision = field(form, 'decision');
  const reason = field(form, 'reason');
  const expiresOn = field(form, 'expiresOn');
  if (!UUID.test(riderId) || !UUID.test(documentId))
    return { error: 'Pièce inconnue.', done: false };
  if (decision !== 'APPROVED' && decision !== 'REJECTED') {
    return { error: 'Décision inconnue.', done: false };
  }
  if (decision === 'REJECTED' && reason.length < 3) {
    return { error: 'Indiquez au livreur pourquoi la pièce est refusée.', done: false };
  }
  if (expiresOn && !DAY.test(expiresOn))
    return { error: 'Date d’expiration invalide.', done: false };
  try {
    await staffApi(`/admin/kyc-documents/${documentId}/review`, {
      method: 'POST',
      body:
        decision === 'APPROVED'
          ? { decision, ...(expiresOn ? { expiresOn } : {}) }
          : { decision, rejectionReason: reason },
    });
  } catch (error) {
    return failure(error);
  }
  return done(riderId);
}

/** Validation, refus, suspension ou réactivation ; motif exigé pour refuser ou suspendre. */
export async function decideRider(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(RIDER_ROLES);
  const riderId = field(form, 'riderId');
  const decision = field(form, 'decision') as (typeof DECISIONS)[number];
  const reason = field(form, 'reason');
  if (!UUID.test(riderId)) return { error: 'Livreur inconnu.', done: false };
  if (!DECISIONS.includes(decision)) return { error: 'Décision inconnue.', done: false };
  if ((decision === 'REJECT' || decision === 'SUSPEND') && reason.length < 3) {
    return { error: 'Indiquez le motif, il est gardé dans l’historique.', done: false };
  }
  try {
    await staffApi(`/admin/riders/${riderId}/decision`, {
      method: 'POST',
      body: { decision, ...(reason ? { reason } : {}) },
    });
  } catch (error) {
    return failure(error);
  }
  return done(riderId);
}

/** Seuil de retrait gratuit propre au livreur, ou retour au seuil général (champ vide). */
export async function setFreePayout(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(['ADMIN', 'FINANCE']);
  const riderId = field(form, 'riderId');
  const raw = field(form, 'freeFrom').replace(/[\s  ]/g, '');
  if (!UUID.test(riderId)) return { error: 'Livreur inconnu.', done: false };
  if (raw && !/^\d{1,9}$/.test(raw)) return { error: 'Montant invalide.', done: false };
  try {
    await staffApi(`/admin/finance/riders/${riderId}/free-payout`, {
      method: 'PUT',
      body: { freeFrom: raw ? Number(raw) : null },
    });
  } catch (error) {
    return failure(error);
  }
  return done(riderId);
}
