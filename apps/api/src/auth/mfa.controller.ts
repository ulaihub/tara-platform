import { Controller, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { SessionTokensDto } from './auth.schemas.js';
import type { AuthUser } from './auth.types.js';
import { CurrentUser, Roles } from './decorators.js';
import { MfaService } from './mfa.service.js';

const MfaSetupDto = z
  .object({
    secret: z
      .string()
      .meta({ description: 'À saisir dans l’application si le QR code ne peut pas être lu' }),
    otpauthUrl: z.string().meta({ description: 'À afficher en QR code' }),
  })
  .meta({ id: 'MfaSetup' });

const MfaCodeBody = z.object({
  code: z.string().regex(/^\d{6}$/, 'six chiffres attendus'),
  /** Jeton de rafraîchissement de la session à élever ; il est remplacé. */
  refreshToken: z.string().min(20).max(200),
});

/** Double authentification des comptes de l'équipe Tara. */
@ApiTags('Authentification')
@ApiBearerAuth()
@Throttle({ default: { limit: 10, ttl: 60_000 } })
@Controller('auth/mfa')
export class MfaController {
  constructor(private readonly mfa: MfaService) {}

  /** Génère le secret à enregistrer dans l'application d'authentification. */
  @Post('setup')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(MfaSetupDto)
  setup(
    @CurrentUser() user: AuthUser,
    @Req() request: Request,
  ): Promise<z.output<typeof MfaSetupDto>> {
    return this.mfa.setup(user, request);
  }

  /** Confirme l'enrôlement avec un premier code et ouvre une session vérifiée. */
  @Post('activate')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(MfaCodeBody)
  @ApiZodResponse(SessionTokensDto)
  activate(
    @CurrentUser() user: AuthUser,
    @ValidBody(MfaCodeBody) body: z.output<typeof MfaCodeBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof SessionTokensDto>> {
    return this.mfa.activate(user, body.code, body.refreshToken, request);
  }

  /** Vérifie le code et renvoie des jetons donnant accès au back-office. */
  @Post('verify')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(MfaCodeBody)
  @ApiZodResponse(SessionTokensDto)
  verify(
    @CurrentUser() user: AuthUser,
    @ValidBody(MfaCodeBody) body: z.output<typeof MfaCodeBody>,
  ): Promise<z.output<typeof SessionTokensDto>> {
    return this.mfa.verify(user, body.code, body.refreshToken);
  }
}

@ApiTags('Back-office · sécurité')
@ApiBearerAuth()
@Roles('ADMIN')
@Controller('admin/users')
export class AdminSecurityController {
  constructor(private readonly mfa: MfaService) {}

  /** Réinitialise le second facteur d'un membre de l'équipe (téléphone perdu ou volé). */
  @Post(':userId/mfa/reset')
  @HttpCode(HttpStatus.NO_CONTENT)
  reset(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Req() request: Request,
  ): Promise<void> {
    return this.mfa.reset(user, userId, request);
  }
}
