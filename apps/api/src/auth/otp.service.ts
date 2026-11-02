import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { hashCode, randomDigits, randomReadableId, sha256, verifyCode } from '../common/crypto.js';
import type { AppLocale } from '../common/i18n/locale.js';
import { renderSms, type SmsTemplate } from '../common/i18n/sms-templates.js';
import { maskPhone } from '../common/phone.js';
import { addMinutes } from '../common/time.js';
import type { OtpChallenge } from '../generated/prisma/client.js';
import type { OtpPurpose } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';
import type { AuthSessionDto, OtpChallengeDto, VerifyOtpBody } from './auth.schemas.js';
import { TokenService } from './token.service.js';

const OTP_LENGTH = 6;
/** Essais par code. */
const MAX_ATTEMPTS = 5;
const RESEND_DELAY_SECONDS = 60;
const WINDOW_MINUTES = 15;
const MAX_REQUESTS_PER_WINDOW = 5;
/**
 * Codes faux tolérés par numéro sur 24 h, tous codes confondus. Sans ce plafond, un
 * attaquant qui enchaîne les demandes pourrait tenter environ 100 codes par heure
 * (≈ 7 % de chances par mois de deviner un code à 6 chiffres).
 */
export const MAX_FAILURES_PER_DAY = 10;
const DAY_MINUTES = 24 * 60;

const TEMPLATES: Record<OtpPurpose, SmsTemplate> = {
  LOGIN: 'OTP',
  PHONE_CHANGE: 'OTP',
  ACCOUNT_DELETION: 'ACCOUNT_DELETION_OTP',
};

/**
 * Codes à usage unique envoyés par SMS : connexion (A1) et confirmation des actions
 * sensibles (suppression de compte). Aucun mot de passe.
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly audit: AuditService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private hash(phone: string, purpose: OtpPurpose, code: string): string {
    // Le motif fait partie du hachage : un code de connexion ne confirme pas une suppression.
    return hashCode(this.env.CODE_HASH_SECRET, `otp:${purpose}:${phone}`, code);
  }

  private async failuresToday(phone: string, now: Date): Promise<number> {
    const result = await this.prisma.otpChallenge.aggregate({
      _sum: { attempts: true },
      where: { phone, createdAt: { gte: addMinutes(now, -DAY_MINUTES) } },
    });
    return result._sum.attempts ?? 0;
  }

  async request(
    phone: string,
    locale: AppLocale,
    ip: string | undefined,
    purpose: OtpPurpose = 'LOGIN',
  ): Promise<z.output<typeof OtpChallengeDto>> {
    const now = new Date();
    if ((await this.failuresToday(phone, now)) >= MAX_FAILURES_PER_DAY) {
      throw AppError.tooMany('OTP_LOCKED');
    }

    const recent = await this.prisma.otpChallenge.findMany({
      where: { phone, createdAt: { gte: addMinutes(now, -WINDOW_MINUTES) } },
      orderBy: { createdAt: 'desc' },
      take: MAX_REQUESTS_PER_WINDOW,
      select: { createdAt: true },
    });
    const last = recent[0];
    if (last) {
      const elapsed = Math.floor((now.getTime() - last.createdAt.getTime()) / 1000);
      if (elapsed < RESEND_DELAY_SECONDS) {
        throw AppError.tooMany('OTP_REQUEST_TOO_SOON', { seconds: RESEND_DELAY_SECONDS - elapsed });
      }
    }
    const oldest = recent.at(-1);
    if (recent.length >= MAX_REQUESTS_PER_WINDOW && oldest) {
      const unlockAt = addMinutes(oldest.createdAt, WINDOW_MINUTES);
      const minutes = Math.max(1, Math.ceil((unlockAt.getTime() - now.getTime()) / 60_000));
      throw AppError.tooMany('OTP_REQUEST_LIMIT', { minutes });
    }

    await this.guardAgainstSmsPumping(phone, ip, now);

    const code = randomDigits(OTP_LENGTH);
    const expiresAt = new Date(now.getTime() + this.env.OTP_TTL_SECONDS * 1000);
    const challenge = await this.prisma.otpChallenge.create({
      data: {
        phone,
        purpose,
        codeHash: this.hash(phone, purpose, code),
        expiresAt,
        ip: ip ?? null,
      },
    });

    try {
      await this.sms.send(
        phone,
        renderSms(TEMPLATES[purpose], locale, {
          code,
          minutes: Math.round(this.env.OTP_TTL_SECONDS / 60),
        }),
      );
    } catch (error) {
      this.logger.error(`Échec d'envoi du code à ${maskPhone(phone)}`, error);
      await this.prisma.otpChallenge.update({
        where: { id: challenge.id },
        data: { expiresAt: now },
      });
      throw new AppError('SMS_SEND_FAILED', HttpStatus.BAD_GATEWAY);
    }

    return {
      challengeId: challenge.id,
      expiresAt: expiresAt.toISOString(),
      resendAfterSeconds: RESEND_DELAY_SECONDS,
    };
  }

  /**
   * Plafonds contre l'envoi massif de SMS : par adresse IP sur une heure, et global sur
   * 24 h. Le plafond global n'arrête que les numéros inconnus : les clients existants
   * peuvent toujours se connecter, une attaque ne bloque donc pas le service.
   */
  private async guardAgainstSmsPumping(
    phone: string,
    ip: string | undefined,
    now: Date,
  ): Promise<void> {
    if (ip) {
      const fromIp = await this.prisma.otpChallenge.count({
        where: { ip, createdAt: { gte: addMinutes(now, -60) } },
      });
      if (fromIp >= this.env.OTP_MAX_PER_IP_PER_HOUR) {
        this.logger.warn(`Plafond de codes SMS par IP atteint (${ip})`);
        throw AppError.tooMany('RATE_LIMITED');
      }
    }
    const limit = this.env.OTP_DAILY_GLOBAL_LIMIT;
    const today = await this.prisma.otpChallenge.count({
      where: { createdAt: { gte: addMinutes(now, -DAY_MINUTES) } },
    });
    if (today >= limit) {
      const known = await this.prisma.user.findUnique({
        where: { phone },
        select: { status: true },
      });
      if (known?.status !== 'ACTIVE') {
        this.logger.error(`ALERTE : plafond global de ${limit} codes SMS par 24 h atteint`);
        throw new AppError('SMS_TEMPORARILY_UNAVAILABLE', HttpStatus.SERVICE_UNAVAILABLE);
      }
    } else if (today === Math.floor(limit * 0.8)) {
      this.logger.warn(`ALERTE : 80 % du plafond global de codes SMS atteint (${today}/${limit})`);
    }
  }

  /** Contrôle un code ; en cas d'erreur, compte l'échec et bloque le numéro au besoin. */
  private async check(
    challenge: OtpChallenge | null,
    code: string,
    purpose: OtpPurpose,
    now: Date,
  ): Promise<OtpChallenge> {
    if (!challenge || challenge.consumedAt || challenge.purpose !== purpose) {
      throw AppError.badRequest('OTP_INVALID');
    }
    if (challenge.expiresAt <= now) throw AppError.badRequest('OTP_EXPIRED');
    const failures = await this.failuresToday(challenge.phone, now);
    if (failures >= MAX_FAILURES_PER_DAY) throw AppError.tooMany('OTP_LOCKED');
    if (challenge.attempts >= MAX_ATTEMPTS) throw AppError.tooMany('OTP_TOO_MANY_ATTEMPTS');

    const valid = verifyCode(
      this.env.CODE_HASH_SECRET,
      `otp:${purpose}:${challenge.phone}`,
      code,
      challenge.codeHash,
    );
    if (valid) return challenge;

    const attempts = challenge.attempts + 1;
    await this.prisma.otpChallenge.update({ where: { id: challenge.id }, data: { attempts } });
    if (failures + 1 >= MAX_FAILURES_PER_DAY) {
      await this.recordLock(challenge.phone);
      throw AppError.tooMany('OTP_LOCKED');
    }
    if (attempts >= MAX_ATTEMPTS) throw AppError.tooMany('OTP_TOO_MANY_ATTEMPTS');
    throw AppError.badRequest('OTP_INVALID', {}, { remainingAttempts: MAX_ATTEMPTS - attempts });
  }

  private async recordLock(phone: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { phone }, select: { id: true } });
    this.logger.warn(
      `Numéro ${maskPhone(phone)} bloqué 24 h après ${MAX_FAILURES_PER_DAY} codes faux`,
    );
    await this.audit.record({
      actor: null,
      action: 'security.otp_locked',
      entityType: user ? 'user' : 'phone',
      entityId: user?.id ?? sha256(phone).slice(0, 32),
      after: { phone: maskPhone(phone) },
    });
  }

  /** Confirme une action sensible de l'utilisateur connecté par un code SMS. */
  async confirm(
    phone: string,
    challengeId: string,
    code: string,
    purpose: OtpPurpose,
  ): Promise<void> {
    const now = new Date();
    const challenge = await this.prisma.otpChallenge.findUnique({ where: { id: challengeId } });
    if (challenge && challenge.phone !== phone) throw AppError.badRequest('OTP_INVALID');
    await this.check(challenge, code, purpose, now);
    const consumed = await this.prisma.otpChallenge.updateMany({
      where: { id: challengeId, consumedAt: null },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) throw AppError.badRequest('OTP_INVALID');
  }

  async verify(
    input: z.output<typeof VerifyOtpBody>,
    locale: AppLocale,
  ): Promise<z.output<typeof AuthSessionDto>> {
    const now = new Date();
    const challenge = await this.check(
      await this.prisma.otpChallenge.findUnique({ where: { id: input.challengeId } }),
      input.code,
      'LOGIN',
      now,
    );

    const existing = await this.prisma.user.findUnique({ where: { phone: challenge.phone } });
    // Vérifié avant de consommer le code : l'app affiche les conditions puis renvoie le même code.
    if (!existing && !input.termsVersion) throw AppError.unprocessable('TERMS_REQUIRED');
    if (existing?.status === 'SUSPENDED') throw AppError.forbidden('ACCOUNT_SUSPENDED');

    const result = await this.prisma.$transaction(async (tx) => {
      const consumed = await tx.otpChallenge.updateMany({
        where: { id: challenge.id, consumedAt: null },
        data: { consumedAt: now },
      });
      if (consumed.count !== 1) throw AppError.badRequest('OTP_INVALID');

      let user = existing;
      let referralApplied = false;
      if (!user) {
        user = await tx.user.create({
          data: {
            phone: challenge.phone,
            locale: locale === 'en' ? 'EN' : 'FR',
            roles: ['CUSTOMER'],
            referralCode: `TARA-${randomReadableId(6)}`,
          },
        });
        const version = input.termsVersion ?? '';
        await tx.consent.createMany({
          data: [
            { userId: user.id, kind: 'TERMS', version, granted: true },
            { userId: user.id, kind: 'PRIVACY', version, granted: true },
          ],
        });
        if (input.referralCode) {
          const referrer = await tx.user.findUnique({
            where: { referralCode: input.referralCode.trim().toUpperCase() },
          });
          if (referrer && referrer.id !== user.id) {
            await tx.referral.create({ data: { referrerId: referrer.id, refereeId: user.id } });
            referralApplied = true;
          }
        }
      }

      const device = await tx.device.upsert({
        where: {
          userId_installationId: { userId: user.id, installationId: input.device.installationId },
        },
        create: {
          userId: user.id,
          installationId: input.device.installationId,
          platform: input.device.platform,
          appVersion: input.device.appVersion ?? null,
          model: input.device.model ?? null,
        },
        update: {
          platform: input.device.platform,
          appVersion: input.device.appVersion ?? null,
          model: input.device.model ?? null,
          lastSeenAt: now,
        },
      });

      const session = await this.tokens.issueSession(user.id, device.id, tx);
      return { user, session, referralApplied };
    });

    return {
      ...result.session,
      isNewUser: !existing,
      referralApplied: result.referralApplied,
      user: {
        id: result.user.id,
        phone: result.user.phone,
        fullName: result.user.fullName,
        roles: result.user.roles,
        locale: result.user.locale,
      },
    };
  }
}
