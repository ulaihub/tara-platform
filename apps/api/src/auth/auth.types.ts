import type { Request } from 'express';
import type { Locale, UserRole } from '../generated/prisma/enums.js';

/**
 * Utilisateur authentifié, rechargé depuis la base à chaque requête.
 * `roles` contient les rôles EFFECTIFS : les rôles de l'équipe n'y figurent que si le
 * second facteur a été vérifié récemment (voir AuthGuard).
 */
export interface AuthUser {
  id: string;
  phone: string;
  roles: UserRole[];
  locale: Locale;
}

export interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

/** Rôles de l'équipe Tara (back-office) : double authentification obligatoire. */
export const STAFF_ROLES = [
  'DISPATCHER',
  'SUPPORT',
  'FINANCE',
  'ADMIN',
] as const satisfies UserRole[];

export function isStaffRole(role: UserRole): boolean {
  return (STAFF_ROLES as readonly UserRole[]).includes(role);
}

export function isStaff(user: AuthUser): boolean {
  return user.roles.some(isStaffRole);
}
