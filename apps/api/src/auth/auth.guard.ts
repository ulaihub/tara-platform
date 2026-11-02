import {
  type CanActivate,
  type ExecutionContext,
  HttpStatus,
  Inject,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type AuthenticatedRequest, isStaffRole } from './auth.types.js';
import { IS_PUBLIC, REQUIRED_ROLES } from './decorators.js';
import { TokenService } from './token.service.js';

/**
 * Garde globale : toute route exige un jeton valide, sauf celles marquées @Public().
 *
 * - L'utilisateur est relu en base à chaque requête : une suspension ou un changement de
 *   rôle prend effet immédiatement, sans attendre l'expiration du jeton.
 * - Les rôles de l'équipe (DISPATCHER, SUPPORT, FINANCE, ADMIN) ne sont accordés que si le
 *   second facteur a été vérifié depuis moins de MFA_SESSION_HOURS. Sinon le compte est
 *   traité comme un compte client, sur TOUTES les routes : un compte de l'équipe pris par
 *   détournement de carte SIM n'obtient aucun droit de l'équipe.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw AppError.unauthorized();

    let claims: Awaited<ReturnType<TokenService['verifyAccess']>>;
    try {
      claims = await this.tokens.verifyAccess(header.slice('Bearer '.length));
    } catch {
      throw AppError.unauthorized();
    }

    const user = await this.prisma.user.findUnique({
      where: { id: claims.userId },
      select: {
        id: true,
        phone: true,
        roles: true,
        locale: true,
        status: true,
        totpEnabledAt: true,
      },
    });
    if (!user || user.status === 'DELETED') throw AppError.unauthorized();
    if (user.status === 'SUSPENDED') throw AppError.forbidden('ACCOUNT_SUSPENDED');

    const mfaFresh =
      user.totpEnabledAt !== null &&
      claims.mfaAt !== null &&
      // Le jeton porte l'heure à la seconde : comparaison à la seconde près.
      claims.mfaAt.getTime() >= Math.floor(user.totpEnabledAt.getTime() / 1000) * 1000 &&
      Date.now() - claims.mfaAt.getTime() <= this.env.MFA_SESSION_HOURS * 3_600_000;
    const roles = mfaFresh ? user.roles : user.roles.filter((role) => !isStaffRole(role));
    request.user = { id: user.id, phone: user.phone, roles, locale: user.locale };

    const required = this.reflector.getAllAndOverride<UserRole[] | undefined>(
      REQUIRED_ROLES,
      targets,
    );
    if (required?.length && !required.some((role) => roles.includes(role))) {
      // Rôle de l'équipe détenu mais second facteur absent ou périmé : l'app le redemande.
      const missingMfa = required.some((role) => isStaffRole(role) && user.roles.includes(role));
      if (missingMfa) {
        throw new AppError(
          'MFA_REQUIRED',
          HttpStatus.FORBIDDEN,
          {},
          {
            enrolled: user.totpEnabledAt !== null,
          },
        );
      }
      throw AppError.forbidden();
    }
    return true;
  }
}
