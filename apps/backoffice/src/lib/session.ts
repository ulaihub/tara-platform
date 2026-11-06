import { seal, unseal } from './seal';

/** Session d'un membre de l'équipe, chiffrée dans un cookie httpOnly. */
export interface Session {
  accessToken: string;
  refreshToken: string;
  /** Expiration du jeton d'accès (ms depuis l'époque). */
  accessExpiresAt: number;
  userId: string;
  phone: string;
  name: string | null;
  /** Rôles détenus (CUSTOMER, DISPATCHER, SUPPORT, FINANCE, ADMIN…). */
  roles: string[];
  /** Second facteur vérifié : sans lui, seule la page de connexion est ouverte. */
  mfaVerified: boolean;
}

/** Connexion en cours (avant le code SMS) : numéro et défi envoyés. */
export interface PendingLogin {
  phone: string;
  challengeId: string;
  resendAt: number;
}

export const SESSION_COOKIE = 'tara_bo_session';
export const LOGIN_COOKIE = 'tara_bo_login';
export const DEVICE_COOKIE = 'tara_bo_device';

/** La vérification du second facteur vaut 12 heures (API) : la session aussi. */
export const SESSION_MAX_AGE = 12 * 3600;
export const LOGIN_MAX_AGE = 10 * 60;

export const STAFF_ROLES = ['DISPATCHER', 'SUPPORT', 'FINANCE', 'ADMIN'] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];

export function staffRoles(roles: readonly string[]): StaffRole[] {
  return STAFF_ROLES.filter((role) => roles.includes(role));
}

export const sealSession = (session: Session, secret: string) =>
  seal(session, secret, SESSION_MAX_AGE);
export const openSession = (cookie: string | undefined, secret: string) =>
  unseal<Session>(cookie, secret);
export const sealLogin = (login: PendingLogin, secret: string) =>
  seal(login, secret, LOGIN_MAX_AGE);
export const openLogin = (cookie: string | undefined, secret: string) =>
  unseal<PendingLogin>(cookie, secret);

export function cookieOptions(maxAge: number, secure: boolean) {
  return { httpOnly: true, secure, sameSite: 'strict' as const, path: '/', maxAge };
}

/** Le jeton d'accès arrive à échéance dans moins de [marginMs] : à renouveler. */
export function needsRefresh(session: Session, now = Date.now(), marginMs = 60_000): boolean {
  return session.accessExpiresAt - now < marginMs;
}
