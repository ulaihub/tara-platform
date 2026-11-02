import { createParamDecorator, type ExecutionContext, SetMetadata } from '@nestjs/common';
import type { UserRole } from '../generated/prisma/enums.js';
import type { AuthenticatedRequest, AuthUser } from './auth.types.js';

export const IS_PUBLIC = 'tara:isPublic';
export const REQUIRED_ROLES = 'tara:requiredRoles';

/** Route accessible sans connexion. Toutes les autres exigent un jeton valide. */
export const Public = (): MethodDecorator & ClassDecorator => SetMetadata(IS_PUBLIC, true);

/** Route réservée aux comptes ayant au moins un des rôles indiqués. */
export const Roles = (...roles: UserRole[]): MethodDecorator & ClassDecorator =>
  SetMetadata(REQUIRED_ROLES, roles);

/** Utilisateur connecté. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AuthUser =>
    context.switchToHttp().getRequest<AuthenticatedRequest>().user,
);
