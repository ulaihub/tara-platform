import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { z } from 'zod';
import { Roles } from '../auth/decorators.js';
import { ApiZodQuery, ApiZodResponse, ValidQuery } from '../common/validation/zod.js';
import { LiveMapService } from './live-map.service.js';
import { LiveMapDto, RiderTrailDto, RiderTrailQuery } from './ops.schemas.js';
import { RiderTrailService } from './rider-trail.service.js';

/** Pilotage de la journée par l'équipe (H1). */
@ApiTags('Back-office · pilotage')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
@Controller('admin')
export class OpsController {
  constructor(
    private readonly liveMap: LiveMapService,
    private readonly trails: RiderTrailService,
  ) {}

  /**
   * Carte en direct : livreurs (libres, en course, hors ligne), commandes en cours avec
   * leurs retards, alertes ouvertes. À rafraîchir toutes les 5 secondes environ.
   */
  @Get('live-map')
  @ApiZodResponse(LiveMapDto)
  map(): Promise<z.output<typeof LiveMapDto>> {
    return this.liveMap.snapshot();
  }

  /**
   * Course en cours d'un livreur : chemin parcouru recalé sur les rues et itinéraire
   * jusqu'au prochain arrêt, pour la carte quand on choisit le livreur ou sa commande.
   */
  @Get('riders/:riderId/trail')
  @ApiZodQuery(RiderTrailQuery)
  @ApiZodResponse(RiderTrailDto)
  trail(
    @Param('riderId', ParseUUIDPipe) riderId: string,
    @ValidQuery(RiderTrailQuery) query: z.output<typeof RiderTrailQuery>,
  ): Promise<z.output<typeof RiderTrailDto>> {
    return this.trails.trail(riderId, query.orderId);
  }
}
