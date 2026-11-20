import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { z } from 'zod';
import { Roles } from '../auth/decorators.js';
import { ApiZodQuery, ApiZodResponse, ValidQuery } from '../common/validation/zod.js';
import { MetricsDto, MetricsQuery, TodayDto } from './metrics.schemas.js';
import { MetricsService } from './metrics.service.js';

@ApiTags('Back-office · indicateurs')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE')
@Controller('admin/metrics')
export class MetricsController {
  constructor(private readonly metrics: MetricsService) {}

  /** Indicateurs de la période (H7), comparés à la période précédente. */
  @Get()
  @ApiZodQuery(MetricsQuery)
  @ApiZodResponse(MetricsDto)
  get(
    @ValidQuery(MetricsQuery) query: z.output<typeof MetricsQuery>,
  ): Promise<z.output<typeof MetricsDto>> {
    return this.metrics.metrics(query.days);
  }

  /** La journée en cours, pour l'accueil du back-office. */
  @Get('today')
  @ApiZodResponse(TodayDto)
  today(): Promise<z.output<typeof TodayDto>> {
    return this.metrics.today();
  }
}
