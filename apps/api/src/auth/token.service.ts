import { Inject, Injectable } from '@nestjs/common';
import { jwtVerify, SignJWT } from 'jose';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { randomToken, sha256 } from '../common/crypto.js';
import { addDays } from '../common/time.js';
import type { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const ISSUER = 'tara-api';
const AUDIENCE = 'tara-apps';

export interface SessionTokens {
  accessToken: string;
  refreshToken: string;
  /** Durée de validité du jeton d'accès, en secondes. */
  expiresIn: number;
}

export interface AccessClaims {
  userId: string;
  /** Heure de la dernière vérification du second facteur, si elle a eu lieu. */
  mfaAt: Date | null;
  /** Fin de validité du jeton (les connexions temps réel sont coupées à cette heure). */
  expiresAt: Date;
}

/**
 * Jetons de session : jeton d'accès JWT court (15 min par défaut) et jeton de
 * rafraîchissement opaque (30 jours) à usage unique. Chaque rafraîchissement remplace le
 * jeton ; réutiliser un jeton déjà remplacé révoque toutes les sessions du compte
 * (signe d'un vol de jeton). L'heure de vérification du second facteur suit la session.
 */
@Injectable()
export class TokenService {
  private readonly signingKey: Uint8Array;
  /** Clé actuelle puis, pendant une rotation, l'ancienne (JWT_SECRET_PREVIOUS). */
  private readonly verificationKeys: Uint8Array[];

  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {
    const encoder = new TextEncoder();
    this.signingKey = encoder.encode(env.JWT_SECRET);
    this.verificationKeys = [env.JWT_SECRET, env.JWT_SECRET_PREVIOUS]
      .filter((secret): secret is string => Boolean(secret))
      .map((secret) => encoder.encode(secret));
  }

  async signAccess(userId: string, mfaAt: Date | null = null): Promise<string> {
    const claims = mfaAt ? { mfa: Math.floor(mfaAt.getTime() / 1000) } : {};
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt()
      .setExpirationTime(`${this.env.JWT_ACCESS_TTL_SECONDS}s`)
      .sign(this.signingKey);
  }

  /** Contenu d'un jeton valide, ou exception s'il est invalide ou expiré. */
  async verifyAccess(token: string): Promise<AccessClaims> {
    let lastError: unknown;
    for (const key of this.verificationKeys) {
      try {
        const { payload } = await jwtVerify(token, key, {
          issuer: ISSUER,
          audience: AUDIENCE,
          algorithms: ['HS256'],
        });
        if (!payload.sub) throw new Error('Jeton sans sujet');
        const mfa = typeof payload['mfa'] === 'number' ? new Date(payload['mfa'] * 1000) : null;
        const expiresAt = new Date((payload.exp ?? 0) * 1000);
        return { userId: payload.sub, mfaAt: mfa, expiresAt };
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError instanceof Error ? lastError : new Error('Jeton invalide');
  }

  async issueSession(
    userId: string,
    deviceId: string | null,
    tx?: Prisma.TransactionClient,
    mfaAt: Date | null = null,
  ): Promise<SessionTokens> {
    const refreshToken = await this.createRefreshToken(userId, deviceId, mfaAt, tx ?? this.prisma);
    return {
      accessToken: await this.signAccess(userId, mfaAt),
      refreshToken: refreshToken.token,
      expiresIn: this.env.JWT_ACCESS_TTL_SECONDS,
    };
  }

  /**
   * Remplace un jeton de rafraîchissement par un nouveau. `mfaAt` enregistre une vérification
   * du second facteur qui vient d'avoir lieu ; `userId` exige que le jeton appartienne à cet
   * utilisateur.
   */
  async rotate(
    refreshToken: string,
    options: { mfaAt?: Date; userId?: string } = {},
  ): Promise<SessionTokens> {
    const now = new Date();
    const current = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
    });
    if (!current || current.expiresAt <= now) throw AppError.unauthorized('REFRESH_TOKEN_INVALID');
    if (options.userId && current.userId !== options.userId) {
      throw AppError.unauthorized('REFRESH_TOKEN_INVALID');
    }
    if (current.revokedAt) {
      await this.revokeAll(current.userId);
      throw AppError.unauthorized('REFRESH_TOKEN_INVALID');
    }

    const mfaAt = options.mfaAt ?? current.mfaAt;
    const next = await this.prisma.$transaction(async (tx) => {
      const created = await this.createRefreshToken(current.userId, current.deviceId, mfaAt, tx);
      const { count } = await tx.refreshToken.updateMany({
        where: { id: current.id, revokedAt: null },
        data: { revokedAt: now, replacedById: created.id },
      });
      return count === 1 ? created : null;
    });
    // Deux rafraîchissements simultanés avec le même jeton : on traite comme une réutilisation.
    if (!next) {
      await this.revokeAll(current.userId);
      throw AppError.unauthorized('REFRESH_TOKEN_INVALID');
    }
    return {
      accessToken: await this.signAccess(current.userId, mfaAt),
      refreshToken: next.token,
      expiresIn: this.env.JWT_ACCESS_TTL_SECONDS,
    };
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async revokeAll(userId: string, tx?: Prisma.TransactionClient): Promise<void> {
    await (tx ?? this.prisma).refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async createRefreshToken(
    userId: string,
    deviceId: string | null,
    mfaAt: Date | null,
    client: Prisma.TransactionClient,
  ): Promise<{ id: string; token: string }> {
    const token = randomToken();
    const created = await client.refreshToken.create({
      data: {
        userId,
        deviceId,
        mfaAt,
        tokenHash: sha256(token),
        expiresAt: addDays(new Date(), this.env.REFRESH_TOKEN_TTL_DAYS),
      },
    });
    return { id: created.id, token };
  }
}
