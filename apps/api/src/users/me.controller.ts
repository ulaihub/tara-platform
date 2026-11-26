import { Body, Controller, Get, HttpStatus, Patch, Post, Put, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import {
  ApiZodBody,
  ApiZodResponse,
  ValidBody,
  ZodValidationPipe,
} from '../common/validation/zod.js';
import {
  ConsentBody,
  ConsentDto,
  MeDto,
  MeStatsDto,
  MerchantBody,
  MerchantDto,
  UpdateMeBody,
} from './users.schemas.js';
import { UsersService } from './users.service.js';

@ApiTags('Mon compte')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiZodResponse(MeDto)
  me(@CurrentUser() user: AuthUser): Promise<z.output<typeof MeDto>> {
    return this.users.me(user.id, user.roles);
  }

  /** Livraisons réussies et taux de réussite de l'expéditeur, date d'arrivée sur Tara. */
  @Get('stats')
  @ApiZodResponse(MeStatsDto)
  stats(@CurrentUser() user: AuthUser): Promise<z.output<typeof MeStatsDto>> {
    return this.users.stats(user.id);
  }

  @Patch()
  @ApiZodBody(UpdateMeBody)
  @ApiZodResponse(MeDto)
  update(
    @CurrentUser() user: AuthUser,
    @Body(new ZodValidationPipe(UpdateMeBody)) body: z.output<typeof UpdateMeBody>,
  ): Promise<z.output<typeof MeDto>> {
    return this.users.update(user.id, body);
  }

  /** Passe le compte en mode marchand, ou met à jour la boutique (A2). */
  @Put('merchant')
  @ApiZodBody(MerchantBody)
  @ApiZodResponse(MerchantDto)
  upsertMerchant(
    @CurrentUser() user: AuthUser,
    @ValidBody(MerchantBody) body: z.output<typeof MerchantBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof MerchantDto>> {
    return this.users.upsertMerchant(user, body, request);
  }

  @Get('consents')
  @ApiZodResponse(z.array(ConsentDto))
  consents(@CurrentUser() user: AuthUser): Promise<z.output<typeof ConsentDto>[]> {
    return this.users.consents(user.id);
  }

  /** Enregistre un consentement ou son retrait (loi n° 2024/017). */
  @Post('consents')
  @ApiZodBody(ConsentBody)
  @ApiZodResponse(ConsentDto, HttpStatus.CREATED)
  recordConsent(
    @CurrentUser() user: AuthUser,
    @ValidBody(ConsentBody) body: z.output<typeof ConsentBody>,
  ): Promise<z.output<typeof ConsentDto>> {
    return this.users.recordConsent(user.id, body);
  }
}
