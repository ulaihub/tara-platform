import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { hashCode, randomDigits, randomReadableId, verifyCode } from '../common/crypto.js';
import type { AppLocale } from '../common/i18n/locale.js';
import { renderSms } from '../common/i18n/sms-templates.js';
import { maskPhone } from '../common/phone.js';
import { addMinutes } from '../common/time.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';
import type { AuthSessionDto, OtpChallengeDto, VerifyOtpBody } from './auth.schemas.js';
import { TokenService } from './token.service.js';

const OTP_LENGTH = 6;
const MAX_ATTEMPTS = 5;
const RESEND_DELAY_SECONDS = 60;
const WINDOW_MINUTES = 15;
const MAX_REQUESTS_PER_WINDOW = 5;

/** Connexion par code à usage unique envoyé par SMS (A1). Aucun mot de passe. */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private hash(phone: string, code: string): string {
    return hashCode(this.env.CODE_HASH_SECRET, `otp:${phone}`, code);
  }

  async request(
    phone: string,
    locale: AppLocale,
    ip: string | undefined,
  ): Promise<z.output<typeof OtpChallengeDto>> {
    const now = new Date();
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

    const code = randomDigits(OTP_LENGTH);
    const expiresAt = new Date(now.getTime() + this.env.OTP_TTL_SECONDS * 1000);
    const challenge = await this.prisma.otpChallenge.create({
      data: { phone, codeHash: this.hash(phone, code), expiresAt, ip: ip ?? null },
    });

    try {
      await this.sms.send(
        phone,
        renderSms('OTP', locale, { code, minutes: Math.round(this.env.OTP_TTL_SECONDS / 60) }),
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

  async verify(
    input: z.output<typeof VerifyOtpBody>,
    locale: AppLocale,
  ): Promise<z.output<typeof AuthSessionDto>> {
    const now = new Date();
    const challenge = await this.prisma.otpChallenge.findUnique({
      where: { id: input.challengeId },
    });
    if (!challenge || challenge.consumedAt) throw AppError.badRequest('OTP_INVALID');
    if (challenge.expiresAt <= now) throw AppError.badRequest('OTP_EXPIRED');
    if (challenge.attempts >= MAX_ATTEMPTS) throw AppError.tooMany('OTP_TOO_MANY_ATTEMPTS');

    if (
      !verifyCode(
        this.env.CODE_HASH_SECRET,
        `otp:${challenge.phone}`,
        input.code,
        challenge.codeHash,
      )
    ) {
      const attempts = challenge.attempts + 1;
      await this.prisma.otpChallenge.update({ where: { id: challenge.id }, data: { attempts } });
      if (attempts >= MAX_ATTEMPTS) throw AppError.tooMany('OTP_TOO_MANY_ATTEMPTS');
      throw AppError.badRequest('OTP_INVALID', {}, { remainingAttempts: MAX_ATTEMPTS - attempts });
    }

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
