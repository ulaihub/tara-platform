import { type CanActivate, type ExecutionContext, HttpStatus, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppError } from '../common/errors/app-error.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { type AuthenticatedRequest, isStaffRole } from './auth.types.js';
import { IS_PUBLIC, REQUIRED_ROLES } from './decorators.js';
import { SessionUserService } from './session-user.service.js';

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
    private readonly sessions: SessionUserService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Temps réel : la connexion est authentifiée une fois, à l'ouverture (RealtimeGateway).
    if (context.getType() !== 'http') return true;
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw AppError.unauthorized();

    const session = await this.sessions.resolve(header.slice('Bearer '.length));
    const { roles } = session.user;
    request.user = session.user;

    const required = this.reflector.getAllAndOverride<UserRole[] | undefined>(
      REQUIRED_ROLES,
      targets,
    );
    if (required?.length && !required.some((role) => roles.includes(role))) {
      // Rôle de l'équipe détenu mais second facteur absent ou périmé : l'app le redemande.
      const missingMfa = required.some(
        (role) => isStaffRole(role) && session.heldRoles.includes(role),
      );
      if (missingMfa) {
        throw new AppError(
          'MFA_REQUIRED',
          HttpStatus.FORBIDDEN,
          {},
          {
            enrolled: session.totpEnrolled,
          },
        );
      }
      throw AppError.forbidden();
    }
    return true;
  }
}
