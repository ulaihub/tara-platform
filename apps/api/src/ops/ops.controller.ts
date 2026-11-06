import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { z } from 'zod';
import { Roles } from '../auth/decorators.js';
import { ApiZodResponse } from '../common/validation/zod.js';
import { LiveMapService } from './live-map.service.js';
import { LiveMapDto } from './ops.schemas.js';

/** Pilotage de la journée par l'équipe (H1). */
@ApiTags('Back-office · pilotage')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
@Controller('admin')
export class OpsController {
  constructor(private readonly liveMap: LiveMapService) {}

  /**
   * Carte en direct : livreurs (libres, en course, hors ligne), commandes en cours avec
   * leurs retards, alertes ouvertes. À rafraîchir toutes les 5 secondes environ.
   */
  @Get('live-map')
  @ApiZodResponse(LiveMapDto)
  map(): Promise<z.output<typeof LiveMapDto>> {
    return this.liveMap.snapshot();
  }
}
