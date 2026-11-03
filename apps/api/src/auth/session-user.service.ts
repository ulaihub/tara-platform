import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type AuthUser, isStaffRole } from './auth.types.js';
import { TokenService } from './token.service.js';

export interface ResolvedSession {
  /** Utilisateur avec ses rôles EFFECTIFS (voir AuthGuard). */
  user: AuthUser;
  /** Rôles détenus, second facteur vérifié ou non. */
  heldRoles: UserRole[];
  totpEnrolled: boolean;
  expiresAt: Date;
}

/**
 * Utilisateur d'un jeton d'accès, relu en base. Partagé par la garde HTTP et la connexion
 * temps réel : les deux appliquent exactement les mêmes règles (compte suspendu, rôles de
 * l'équipe accordés seulement avec un second facteur récent).
 */
@Injectable()
export class SessionUserService {
  constructor(
    private readonly tokens: TokenService,
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async resolve(accessToken: string): Promise<ResolvedSession> {
    let claims: Awaited<ReturnType<TokenService['verifyAccess']>>;
    try {
      claims = await this.tokens.verifyAccess(accessToken);
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
    return {
      user: { id: user.id, phone: user.phone, roles, locale: user.locale },
      heldRoles: user.roles,
      totpEnrolled: user.totpEnabledAt !== null,
      expiresAt: claims.expiresAt,
    };
  }
}
