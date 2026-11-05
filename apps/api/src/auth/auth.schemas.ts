import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';
import { AcceptedVersions } from '../legal/legal.schemas.js';

export const LocaleParam = z.enum(['fr', 'en']);

export const RequestOtpBody = z.object({
  phone: CameroonMobile,
  /** Langue du SMS ; à défaut, celle de l'en-tête Accept-Language. */
  locale: LocaleParam.optional(),
});

export const OtpChallengeDto = z
  .object({
    challengeId: z.uuid(),
    expiresAt: z.iso.datetime(),
    resendAfterSeconds: z.int(),
  })
  .meta({ id: 'OtpChallenge' });

export const DeviceInput = z
  .object({
    installationId: z.string().min(8).max(128),
    platform: z.enum(['ANDROID', 'IOS', 'WEB']),
    appVersion: z.string().max(32).optional(),
    model: z.string().max(64).optional(),
  })
  .meta({ id: 'DeviceInput' });

export const VerifyOtpBody = z.object({
  challengeId: z.uuid(),
  code: z.string().regex(/^\d{6}$/, 'six chiffres attendus'),
  device: DeviceInput,
  /**
   * Textes lus et acceptés (case cochée) à la création du compte : les conditions de l'app et
   * la politique de confidentialité, dans leur version en vigueur. Le code SMS signe
   * l'acceptation. Ignoré pour un compte existant.
   */
  terms: AcceptedVersions.optional(),
  /** Code de parrainage saisi à l'inscription (C6). */
  referralCode: z.string().max(32).optional(),
  locale: LocaleParam.optional(),
});

export const SessionUserDto = z
  .object({
    id: z.uuid(),
    phone: z.string(),
    fullName: z.string().nullable(),
    roles: z.array(
      z.enum(['CUSTOMER', 'MERCHANT', 'RIDER', 'DISPATCHER', 'SUPPORT', 'FINANCE', 'ADMIN']),
    ),
    locale: z.enum(['FR', 'EN']),
  })
  .meta({ id: 'SessionUser' });

export const SessionTokensDto = z
  .object({
    accessToken: z.string(),
    refreshToken: z.string(),
    expiresIn: z.int().meta({ description: 'Validité du jeton d’accès, en secondes' }),
  })
  .meta({ id: 'SessionTokens' });

export const AuthSessionDto = SessionTokensDto.extend({
  isNewUser: z.boolean(),
  referralApplied: z.boolean(),
  user: SessionUserDto,
}).meta({ id: 'AuthSession' });

export const RefreshBody = z.object({ refreshToken: z.string().min(20).max(200) });
