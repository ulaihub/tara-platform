import { Controller, Get, Headers, HttpCode, HttpStatus, Ip, Post, Req, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { z } from 'zod';
import { OtpChallengeDto } from '../auth/auth.schemas.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { resolveLocale } from '../common/i18n/locale.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { PrivacyService } from './privacy.service.js';

const DeletionBody = z.object({
  challengeId: z.uuid(),
  code: z.string().regex(/^\d{6}$/, 'six chiffres attendus'),
});

const ExportDto = z
  .record(z.string(), z.unknown())
  .meta({ id: 'DataExport', description: 'Toutes les données personnelles du compte (JSON)' });

/** Droits sur les données personnelles (loi n° 2024/017). */
@ApiTags('Mon compte')
@ApiBearerAuth()
@Controller('me')
export class PrivacyController {
  constructor(private readonly privacy: PrivacyService) {}

  /** Télécharge toutes ses données personnelles (droit d'accès). */
  @Get('export')
  @Throttle({ default: { limit: 3, ttl: 3_600_000 } })
  @ApiZodResponse(ExportDto)
  async export(
    @CurrentUser() user: AuthUser,
    @Req() request: Request,
    @Res() response: Response,
  ): Promise<void> {
    const data = await this.privacy.export(user, request);
    const date = new Date().toISOString().slice(0, 10);
    response
      .status(HttpStatus.OK)
      .set({ 'Content-Disposition': `attachment; filename="tara-donnees-${date}.json"` })
      .json(data);
  }

  /** Envoie par SMS le code qui confirme la suppression du compte. */
  @Post('deletion/code')
  @Throttle({ default: { limit: 3, ttl: 3_600_000 } })
  @ApiZodResponse(OtpChallengeDto, HttpStatus.CREATED)
  requestCode(
    @CurrentUser() user: AuthUser,
    @Headers('accept-language') acceptLanguage: string | undefined,
    @Ip() ip: string,
  ): Promise<z.output<typeof OtpChallengeDto>> {
    return this.privacy.requestDeletionCode(user, resolveLocale(acceptLanguage, user.locale), ip);
  }

  /** Supprime définitivement le compte (droit à l'effacement). */
  @Post('deletion')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(DeletionBody)
  deleteAccount(
    @CurrentUser() user: AuthUser,
    @ValidBody(DeletionBody) body: z.output<typeof DeletionBody>,
    @Req() request: Request,
  ): Promise<void> {
    return this.privacy.deleteAccount(user, body.challengeId, body.code, request);
  }
}
