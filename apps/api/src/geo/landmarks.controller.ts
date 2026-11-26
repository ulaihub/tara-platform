import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LandmarkBody, LandmarkDto, LandmarkListDto } from './landmarks.schemas.js';
import { ZonesRepository } from './zones.repository.js';

const CITY = 'Douala';

/** Repères actifs de la ville, avec une version qui change à chaque ajout ou retrait. */
async function activeLandmarks(prisma: PrismaService): Promise<z.output<typeof LandmarkListDto>> {
  const rows = await prisma.landmark.findMany({
    where: { city: CITY },
    select: { id: true, name: true, latitude: true, longitude: true, active: true, updatedAt: true },
    orderBy: { name: 'asc' },
  });
  const latest = rows.reduce((max, row) => Math.max(max, row.updatedAt.getTime()), 0);
  return {
    version: `${rows.length}-${latest}`,
    items: rows
      .filter((row) => row.active)
      .map(({ id, name, latitude, longitude }) => ({ id, name, latitude, longitude })),
  };
}

/** Repères de Douala pour les cartes des apps (carrefours, ronds-points, lieux connus). */
@ApiTags('Adresses')
@ApiBearerAuth()
@Controller('map/landmarks')
export class LandmarksController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiZodResponse(LandmarkListDto)
  list(): Promise<z.output<typeof LandmarkListDto>> {
    return activeLandmarks(this.prisma);
  }
}

/** L'équipe ajoute les repères que la carte ne connaît pas, et retire ceux qui sont faux. */
@ApiTags('Back-office · zones')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER')
@Controller('admin/landmarks')
export class AdminLandmarksController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly zones: ZonesRepository,
    private readonly audit: AuditService,
  ) {}

  @Get()
  @ApiZodResponse(LandmarkListDto)
  async list(): Promise<z.output<typeof LandmarkListDto>> {
    return activeLandmarks(this.prisma);
  }

  @Post()
  @ApiZodBody(LandmarkBody)
  @ApiZodResponse(LandmarkDto, HttpStatus.CREATED)
  async create(
    @CurrentUser() user: AuthUser,
    @ValidBody(LandmarkBody) body: z.output<typeof LandmarkBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof LandmarkDto>> {
    // Un repère hors de la zone desservie ne servirait à personne (et trahirait une erreur).
    const areas = await this.zones.findContaining(body.latitude, body.longitude, 'SERVICE_AREA');
    if (areas.length === 0) throw AppError.unprocessable('OUT_OF_SERVICE_AREA');
    const landmark = await this.prisma.landmark.create({
      data: { ...body, city: CITY, createdById: user.id },
      select: { id: true, name: true, latitude: true, longitude: true },
    });
    await this.audit.record({
      actor: user,
      action: 'landmark.created',
      entityType: 'landmark',
      entityId: landmark.id,
      after: landmark,
      request,
    });
    return landmark;
  }

  /** Retiré des cartes (gardé en base pour l'historique). */
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: Request,
  ): Promise<void> {
    const landmark = await this.prisma.landmark.findUnique({ where: { id } });
    if (!landmark?.active) throw AppError.notFound('NOT_FOUND');
    await this.prisma.landmark.update({ where: { id }, data: { active: false } });
    await this.audit.record({
      actor: user,
      action: 'landmark.removed',
      entityType: 'landmark',
      entityId: id,
      before: { name: landmark.name },
      request,
    });
  }
}
