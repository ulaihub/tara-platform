import 'server-only';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { cache } from 'react';
import { ApiError, api } from './api';
import { config } from './config';
import { SESSION_COOKIE, type Session, type StaffRole, openSession } from './session';

/** Session de l'équipe lue une fois par rendu. */
export const getSession = cache(async (): Promise<Session | null> => {
  const store = await cookies();
  return openSession(store.get(SESSION_COOKIE)?.value, config.sessionSecret);
});

/**
 * Membre de l'équipe connecté, second facteur vérifié ; [roles] : au moins l'un d'eux.
 * Sinon, retour à la connexion (ou à l'accueil pour un rôle manquant).
 */
export async function requireStaff(roles?: readonly StaffRole[]): Promise<Session> {
  const session = await getSession();
  if (!session?.mfaVerified) redirect('/connexion');
  if (roles && !roles.some((role) => session.roles.includes(role))) redirect('/?acces=refuse');
  return session;
}

/** Appel à l'API au nom du membre connecté ; session refusée par l'API : reconnexion. */
export async function staffApi<T>(
  path: string,
  options: Omit<Parameters<typeof api>[1] & object, 'token'> = {},
): Promise<T> {
  const session = await requireStaff();
  try {
    return await api<T>(path, { ...options, token: session.accessToken });
  } catch (error) {
    if (error instanceof ApiError && (error.status === 401 || error.code === 'MFA_REQUIRED')) {
      redirect('/connexion?expiree=1');
    }
    throw error;
  }
}
