import { Controller, Headers, HttpCode, HttpStatus, Ip, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { z } from 'zod';
import { resolveLocale } from '../common/i18n/locale.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import {
  AuthSessionDto,
  OtpChallengeDto,
  RefreshBody,
  RequestOtpBody,
  SessionTokensDto,
  VerifyOtpBody,
} from './auth.schemas.js';
import { Public } from './decorators.js';
import { OtpService } from './otp.service.js';
import { TokenService } from './token.service.js';

@ApiTags('Authentification')
@Public()
@Controller('auth')
export class AuthController {
  constructor(
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
  ) {}

  /** Envoie un code de connexion à 6 chiffres par WhatsApp ou SMS (A1). */
  @Post('otp')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiZodBody(RequestOtpBody)
  @ApiZodResponse(OtpChallengeDto, HttpStatus.CREATED)
  request(
    @ValidBody(RequestOtpBody) body: z.output<typeof RequestOtpBody>,
    @Headers('accept-language') acceptLanguage: string | undefined,
    @Ip() ip: string,
  ): Promise<z.output<typeof OtpChallengeDto>> {
    return this.otp.request(body.phone, body.locale ?? resolveLocale(acceptLanguage), ip, 'LOGIN', {
      channel: body.channel,
      appHash: body.appHash,
    });
  }

  /** Vérifie le code ; crée le compte au premier passage (conditions acceptées obligatoires). */
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @ApiZodBody(VerifyOtpBody)
  @ApiZodResponse(AuthSessionDto)
  verify(
    @ValidBody(VerifyOtpBody) body: z.output<typeof VerifyOtpBody>,
    @Headers('accept-language') acceptLanguage: string | undefined,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string | undefined,
  ): Promise<z.output<typeof AuthSessionDto>> {
    return this.otp.verify(body, body.locale ?? resolveLocale(acceptLanguage), { ip, userAgent });
  }

  /** Échange le jeton de rafraîchissement contre une nouvelle paire de jetons. */
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiZodBody(RefreshBody)
  @ApiZodResponse(SessionTokensDto)
  refresh(
    @ValidBody(RefreshBody) body: z.output<typeof RefreshBody>,
  ): Promise<z.output<typeof SessionTokensDto>> {
    return this.tokens.rotate(body.refreshToken);
  }

  /** Ferme la session de cet appareil. */
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(RefreshBody)
  async logout(@ValidBody(RefreshBody) body: z.output<typeof RefreshBody>): Promise<void> {
    await this.tokens.revoke(body.refreshToken);
  }
}
