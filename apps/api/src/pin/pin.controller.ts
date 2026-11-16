import {
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Ip,
  Post,
  Put,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import type { z } from 'zod';
import { OtpChallengeDto, OtpDeliveryBody } from '../auth/auth.schemas.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { OtpService } from '../auth/otp.service.js';
import { resolveLocale } from '../common/i18n/locale.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import {
  BiometricKeyDto,
  DisableBiometricQuery,
  EnableBiometricBody,
  PinProofBody,
  PinStatusDto,
  SetPinBody,
} from './pin.schemas.js';
import { PinService } from './pin.service.js';

/** Code secret du compte (comme Orange Money et MTN MoMo) et empreinte digitale. */
@ApiTags('Compte')
@ApiBearerAuth()
@Controller('me/pin')
export class PinController {
  constructor(
    private readonly pin: PinService,
    private readonly otp: OtpService,
  ) {}

  @Get()
  @ApiZodResponse(PinStatusDto)
  status(@CurrentUser() user: AuthUser): Promise<z.output<typeof PinStatusDto>> {
    return this.pin.status(user.id);
  }

  /** Premier code, changement (code actuel) ou code oublié (code reçu par SMS ou WhatsApp). */
  @Put()
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(SetPinBody)
  async set(
    @CurrentUser() user: AuthUser,
    @ValidBody(SetPinBody) body: z.output<typeof SetPinBody>,
    @Req() request: Request,
  ): Promise<void> {
    await this.pin.set(user, body, request);
  }

  /** Code oublié ou bloqué : code par WhatsApp ou SMS pour en choisir un nouveau. */
  @Post('code')
  @Throttle({ default: { limit: 3, ttl: 3_600_000 } })
  @ApiZodBody(OtpDeliveryBody)
  @ApiZodResponse(OtpChallengeDto, HttpStatus.CREATED)
  requestCode(
    @CurrentUser() user: AuthUser,
    @ValidBody(OtpDeliveryBody) body: z.output<typeof OtpDeliveryBody>,
    @Headers('accept-language') acceptLanguage: string | undefined,
    @Ip() ip: string,
  ): Promise<z.output<typeof OtpChallengeDto>> {
    return this.otp.request(
      user.phone,
      resolveLocale(acceptLanguage, user.locale),
      ip,
      'PIN_RESET',
      { channel: body.channel, appHash: body.appHash },
    );
  }

  /** Vérifie le code (ou l'empreinte) avant d'afficher le solde. Une erreur compte un essai. */
  @Post('verify')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiZodBody(PinProofBody)
  async verify(
    @CurrentUser() user: AuthUser,
    @ValidBody(PinProofBody) body: z.output<typeof PinProofBody>,
    @Req() request: Request,
  ): Promise<void> {
    await this.pin.assert(user, body, { required: true, request });
  }

  /** Active l'empreinte sur ce téléphone : renvoie la clé à garder dans le téléphone. */
  @Post('biometric')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(EnableBiometricBody)
  @ApiZodResponse(BiometricKeyDto, HttpStatus.CREATED)
  enableBiometric(
    @CurrentUser() user: AuthUser,
    @ValidBody(EnableBiometricBody) body: z.output<typeof EnableBiometricBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof BiometricKeyDto>> {
    return this.pin.enableBiometric(user, body, request);
  }

  @Delete('biometric')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodQuery(DisableBiometricQuery)
  async disableBiometric(
    @CurrentUser() user: AuthUser,
    @ValidQuery(DisableBiometricQuery) query: z.output<typeof DisableBiometricQuery>,
  ): Promise<void> {
    await this.pin.disableBiometric(user, query.installationId);
  }
}
