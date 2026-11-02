import type { Request } from 'express';
import type { Locale, UserRole } from '../generated/prisma/enums.js';

/** Utilisateur authentifié, rechargé depuis la base à chaque requête. */
export interface AuthUser {
  id: string;
  phone: string;
  roles: UserRole[];
  locale: Locale;
}

export interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

/** Rôles de l'équipe Tara (back-office). */
export const STAFF_ROLES = [
  'DISPATCHER',
  'SUPPORT',
  'FINANCE',
  'ADMIN',
] as const satisfies UserRole[];

export function isStaff(user: AuthUser): boolean {
  return user.roles.some((role) => (STAFF_ROLES as readonly string[]).includes(role));
}
