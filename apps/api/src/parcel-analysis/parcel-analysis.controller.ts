import { Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { AnalyzeParcelBody, ParcelAnalysisDto } from './parcel-analysis.schemas.js';
import { ParcelAnalysisService } from './parcel-analysis.service.js';

@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('orders')
export class ParcelAnalysisController {
  constructor(private readonly analyses: ParcelAnalysisService) {}

  /**
   * Analyse la photo du colis (C1) et propose taille, nature, fragilité ; signale les objets
   * interdits que la photo semble montrer. Une proposition : l'expéditeur confirme ou corrige.
   * 503 PARCEL_ANALYSIS_UNAVAILABLE : l'app laisse l'expéditeur choisir lui-même.
   */
  @Post('parcel-analysis')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(AnalyzeParcelBody)
  @ApiZodResponse(ParcelAnalysisDto)
  analyze(
    @CurrentUser() user: AuthUser,
    @ValidBody(AnalyzeParcelBody) body: z.output<typeof AnalyzeParcelBody>,
  ): Promise<z.output<typeof ParcelAnalysisDto>> {
    return this.analyses.analyze(user.id, body.photoKey);
  }
}
