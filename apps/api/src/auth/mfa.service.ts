import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { decrypt, deriveKey, encrypt } from '../common/crypto.js';
import { renderSms, type SmsTemplate } from '../common/i18n/sms-templates.js';
import { addMinutes } from '../common/time.js';
import type { User } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';
import { type AuthUser, isStaffRole } from './auth.types.js';
import { type SessionTokens, TokenService } from './token.service.js';
import { generateTotpSecret, otpauthUrl, verifyTotp } from './totp.js';

/** Codes faux avant blocage temporaire du second facteur. */
const MAX_FAILURES = 5;
const LOCK_MINUTES = 15;

/**
 * Double authentification de l'équipe (TOTP). Le secret est chiffré en base avec une clé
 * dérivée réservée à cet usage. Chaque activation ou réinitialisation est auditée et
 * signalée par SMS au titulaire du compte, pour qu'un détournement se remarque.
 */
@Injectable()
export class MfaService {
  private readonly logger = new Logger(MfaService.name);
  private readonly key: Buffer;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly audit: AuditService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(ENV) env: Env,
  ) {
    this.key = deriveKey(Buffer.from(env.STORAGE_ENCRYPTION_KEY, 'base64'), 'tara:mfa-totp:v1');
  }

  /** Le compte doit détenir un rôle de l'équipe (lu en base : les rôles effectifs l'excluent). */
  private async staffMember(userId: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.roles.some(isStaffRole)) throw AppError.forbidden();
    return user;
  }

  async setup(actor: AuthUser, request: Request): Promise<{ secret: string; otpauthUrl: string }> {
    const user = await this.staffMember(actor.id);
    if (user.totpEnabledAt) throw AppError.conflict('MFA_ALREADY_ENABLED');
    const secret = generateTotpSecret();
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        totpSecretEnc: encrypt(this.key, Buffer.from(secret)).toString('base64'),
        totpLastUsedStep: null,
        totpFailedAttempts: 0,
        totpLockedUntil: null,
      },
    });
    await this.audit.record({
      actor,
      action: 'security.mfa_setup',
      entityType: 'user',
      entityId: user.id,
      request,
    });
    return { secret, otpauthUrl: otpauthUrl(secret, user.phone) };
  }

  /** Premier code valide : active le second facteur et ouvre une session vérifiée. */
  async activate(
    actor: AuthUser,
    code: string,
    refreshToken: string,
    request: Request,
  ): Promise<SessionTokens> {
    const user = await this.staffMember(actor.id);
    if (user.totpEnabledAt) throw AppError.conflict('MFA_ALREADY_ENABLED');
    const now = new Date();
    const step = await this.check(user, code, now);
    await this.prisma.user.update({ where: { id: user.id }, data: { totpEnabledAt: now } });
    await this.audit.record({
      actor,
      action: 'security.mfa_enabled',
      entityType: 'user',
      entityId: user.id,
      request,
    });
    await this.notify(user, 'MFA_ENABLED');
    this.logger.log(`Second facteur activé (utilisateur ${user.id}, pas ${step})`);
    return this.tokens.rotate(refreshToken, { mfaAt: now, userId: user.id });
  }

  /** Vérification à la connexion, puis toutes les MFA_SESSION_HOURS heures. */
  async verify(actor: AuthUser, code: string, refreshToken: string): Promise<SessionTokens> {
    const user = await this.staffMember(actor.id);
    if (!user.totpEnabledAt) throw AppError.unprocessable('MFA_NOT_SET_UP');
    const now = new Date();
    await this.check(user, code, now);
    return this.tokens.rotate(refreshToken, { mfaAt: now, userId: user.id });
  }

  /** Contrôle le code, refuse sa réutilisation et bloque 15 minutes après 5 échecs. */
  private async check(user: User, code: string, now: Date): Promise<number> {
    if (!user.totpSecretEnc) throw AppError.unprocessable('MFA_NOT_SET_UP');
    if (user.totpLockedUntil && user.totpLockedUntil > now) throw AppError.tooMany('MFA_LOCKED');

    const secret = decrypt(this.key, Buffer.from(user.totpSecretEnc, 'base64')).toString();
    const step = verifyTotp(secret, code, now, user.totpLastUsedStep);
    if (step !== null) {
      // Mise à jour conditionnelle : deux requêtes simultanées avec le même code ne
      // peuvent pas réussir toutes les deux.
      const { count } = await this.prisma.user.updateMany({
        where: {
          id: user.id,
          OR: [{ totpLastUsedStep: null }, { totpLastUsedStep: { lt: step } }],
        },
        data: { totpLastUsedStep: step, totpFailedAttempts: 0, totpLockedUntil: null },
      });
      if (count === 1) return step;
    }

    const failures = user.totpFailedAttempts + 1;
    const locked = failures >= MAX_FAILURES;
    await this.prisma.user.update({
      where: { id: user.id },
      data: locked
        ? { totpFailedAttempts: 0, totpLockedUntil: addMinutes(now, LOCK_MINUTES) }
        : { totpFailedAttempts: failures },
    });
    if (locked) {
      this.logger.warn(`Second facteur bloqué ${LOCK_MINUTES} min (utilisateur ${user.id})`);
      await this.audit.record({
        actor: null,
        action: 'security.mfa_locked',
        entityType: 'user',
        entityId: user.id,
      });
      throw AppError.tooMany('MFA_LOCKED');
    }
    throw new AppError(
      'MFA_INVALID',
      HttpStatus.BAD_REQUEST,
      {},
      { remainingAttempts: MAX_FAILURES - failures },
    );
  }

  /** Téléphone perdu : un administrateur réinitialise le second facteur d'un collègue. */
  async reset(actor: AuthUser, userId: string, request: Request): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw AppError.notFound();
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          totpSecretEnc: null,
          totpEnabledAt: null,
          totpLastUsedStep: null,
          totpFailedAttempts: 0,
          totpLockedUntil: null,
        },
      });
      // Toutes les sessions du compte sont fermées : reconnexion obligatoire.
      await this.tokens.revokeAll(userId, tx);
      await this.audit.record(
        { actor, action: 'security.mfa_reset', entityType: 'user', entityId: userId, request },
        tx,
      );
    });
    await this.notify(user, 'MFA_RESET');
  }

  private async notify(user: User, template: SmsTemplate): Promise<void> {
    try {
      await this.sms.send(user.phone, renderSms(template, user.locale === 'EN' ? 'en' : 'fr', {}));
    } catch (error) {
      this.logger.error(`Notification de sécurité non envoyée (utilisateur ${user.id})`, error);
    }
  }
}
