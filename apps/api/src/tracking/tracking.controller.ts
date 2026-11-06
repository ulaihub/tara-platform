import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import { CourseTrackService } from './course-track.service.js';
import {
  AcknowledgeCourseAlertBody,
  CourseAlertDto,
  CourseAlertListQuery,
  CourseTrackDto,
  TrackBatchBody,
  TrackBatchDto,
} from './tracking.schemas.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

/** Positions d'une course gardées sur le téléphone sans réseau (E7). */
@ApiTags('Livreur')
@ApiBearerAuth()
@Roles('RIDER')
@Controller('rider/orders')
export class RiderTrackController {
  constructor(private readonly tracks: CourseTrackService) {}

  @Post(':id/track')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiZodBody(TrackBatchBody)
  @ApiZodResponse(TrackBatchDto)
  batch(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(TrackBatchBody) body: z.output<typeof TrackBatchBody>,
  ): Out<typeof TrackBatchDto> {
    return this.tracks.recordBatch(
      user.id,
      id,
      body.points.map((p) => ({ ...p, at: new Date(p.recordedAt) })),
    );
  }
}

/** Trajet des courses pour l'équipe : litiges, incidents, alertes (consultations tracées). */
@ApiTags('Back-office · support')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
@Controller('admin')
export class AdminTrackController {
  constructor(private readonly tracks: CourseTrackService) {}

  @Get('orders/:id/track')
  @ApiZodResponse(CourseTrackDto)
  view(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: Request,
  ): Out<typeof CourseTrackDto> {
    return this.tracks.view(user, id, request);
  }

  @Get('course-alerts')
  @ApiZodQuery(CourseAlertListQuery)
  @ApiZodResponse(z.array(CourseAlertDto))
  alerts(
    @ValidQuery(CourseAlertListQuery) query: z.output<typeof CourseAlertListQuery>,
  ): Out<z.ZodArray<typeof CourseAlertDto>> {
    return this.tracks.listAlerts(query.status);
  }

  @Post('course-alerts/:id/acknowledge')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(AcknowledgeCourseAlertBody)
  @ApiZodResponse(CourseAlertDto)
  acknowledge(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AcknowledgeCourseAlertBody) body: z.output<typeof AcknowledgeCourseAlertBody>,
  ): Out<typeof CourseAlertDto> {
    return this.tracks.acknowledge(id, user, body.note);
  }
}
