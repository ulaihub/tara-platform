import { type CanActivate, type ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppError } from '../common/errors/app-error.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthenticatedRequest } from './auth.types.js';
import { IS_PUBLIC, REQUIRED_ROLES } from './decorators.js';
import { TokenService } from './token.service.js';

/**
 * Garde globale : toute route exige un jeton valide, sauf celles marquées @Public().
 * L'utilisateur est relu en base à chaque requête : une suspension ou un changement de
 * rôle prend effet immédiatement, sans attendre l'expiration du jeton.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw AppError.unauthorized();

    let userId: string;
    try {
      userId = await this.tokens.verifyAccess(header.slice('Bearer '.length));
    } catch {
      throw AppError.unauthorized();
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, phone: true, roles: true, locale: true, status: true },
    });
    if (!user || user.status === 'DELETED') throw AppError.unauthorized();
    if (user.status === 'SUSPENDED') throw AppError.forbidden('ACCOUNT_SUSPENDED');
    request.user = { id: user.id, phone: user.phone, roles: user.roles, locale: user.locale };

    const required = this.reflector.getAllAndOverride<UserRole[] | undefined>(
      REQUIRED_ROLES,
      targets,
    );
    if (required?.length && !required.some((role) => user.roles.includes(role))) {
      throw AppError.forbidden();
    }
    return true;
  }
}
