import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Ip,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import type { z } from 'zod';
import { OtpChallengeDto } from '../auth/auth.schemas.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Public } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { resolveLocale } from '../common/i18n/locale.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import {
  AcceptTermsBody,
  LegalDocumentDto,
  LegalDocumentEnum,
  TermsAppQuery,
  TermsStatusDto,
} from './legal.schemas.js';
import { LegalService } from './legal.service.js';

/** Textes en vigueur : conditions, notice destinataire, confidentialité (lisibles sans compte). */
@ApiTags('Public')
@Public()
@Controller('legal')
export class LegalController {
  constructor(private readonly legal: LegalService) {}

  @Get(':document')
  @ApiZodResponse(LegalDocumentDto)
  document(@Param('document') document: string): z.output<typeof LegalDocumentDto> {
    const name = LegalDocumentEnum.safeParse(document);
    if (!name.success) throw AppError.notFound('NOT_FOUND');
    return this.legal.document(name.data);
  }
}

/** Acceptation « signée » des conditions par l'utilisateur connecté. */
@ApiTags('Compte')
@ApiBearerAuth()
@Controller('me/terms')
export class TermsController {
  constructor(private readonly legal: LegalService) {}

  @Get()
  @ApiZodQuery(TermsAppQuery)
  @ApiZodResponse(TermsStatusDto)
  async status(
    @CurrentUser() user: AuthUser,
    @ValidQuery(TermsAppQuery) query: z.output<typeof TermsAppQuery>,
  ): Promise<z.output<typeof TermsStatusDto>> {
    return {
      required: await this.legal.required(user.id, query.app),
      accepted: await this.legal.accepted(user.id),
    };
  }

  /** Code SMS qui signe l'acceptation. */
  @Post('code')
  @Throttle({ default: { limit: 3, ttl: 3_600_000 } })
  @ApiZodResponse(OtpChallengeDto, HttpStatus.CREATED)
  requestCode(
    @CurrentUser() user: AuthUser,
    @Headers('accept-language') acceptLanguage: string | undefined,
    @Ip() ip: string,
  ): Promise<z.output<typeof OtpChallengeDto>> {
    return this.legal.requestCode(user, resolveLocale(acceptLanguage, user.locale), ip);
  }

  @Post()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodQuery(TermsAppQuery)
  @ApiZodBody(AcceptTermsBody)
  async accept(
    @CurrentUser() user: AuthUser,
    @ValidQuery(TermsAppQuery) query: z.output<typeof TermsAppQuery>,
    @ValidBody(AcceptTermsBody) body: z.output<typeof AcceptTermsBody>,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string | undefined,
    @Req() request: Request,
  ): Promise<void> {
    await this.legal.accept(
      user,
      query.app,
      body,
      { ip, userAgent, installationId: body.installationId },
      request,
    );
  }
}
