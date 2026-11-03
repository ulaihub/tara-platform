import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Public, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { AddressesService } from './addresses.service.js';
import {
  AddressBody,
  AddressDto,
  LocationLinkBody,
  LocationLinkDto,
  LocationLinkListQuery,
  PublicLocationLinkDto,
  PublicLocationSubmitBody,
  ZoneBody,
  ZoneDto,
  ZoneListQuery,
  ZonePatchBody,
} from './geo.schemas.js';
import { LocationLinksService } from './location-links.service.js';
import { ZonesRepository } from './zones.repository.js';

@ApiTags('Adresses')
@ApiBearerAuth()
@Controller()
export class AddressesController {
  constructor(
    private readonly addresses: AddressesService,
    private readonly prisma: PrismaService,
  ) {}

  /** Quartiers et zones actives, pour le sélecteur de quartier (B1). */
  @Get('zones')
  @ApiZodQuery(ZoneListQuery)
  @ApiZodResponse(z.array(ZoneDto))
  zones(
    @ValidQuery(ZoneListQuery) query: z.output<typeof ZoneListQuery>,
  ): Promise<z.output<typeof ZoneDto>[]> {
    return this.prisma.zone.findMany({
      where: {
        active: true,
        ...(query.city ? { city: query.city } : {}),
        ...(query.kind ? { kind: query.kind } : {}),
      },
      select: { id: true, name: true, city: true, kind: true, active: true },
      orderBy: [{ city: 'asc' }, { name: 'asc' }],
    });
  }

  @Post('addresses')
  @ApiZodBody(AddressBody)
  @ApiZodResponse(AddressDto, HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(AddressBody) body: z.output<typeof AddressBody>,
  ): Promise<z.output<typeof AddressDto>> {
    return this.addresses.create(user, body);
  }

  /** Carnet d'adresses (B5). */
  @Get('addresses')
  @ApiZodResponse(z.array(AddressDto))
  list(@CurrentUser() user: AuthUser): Promise<z.output<typeof AddressDto>[]> {
    return this.addresses.list(user);
  }

  @Get('addresses/:id')
  @ApiZodResponse(AddressDto)
  get(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof AddressDto>> {
    return this.addresses.get(user, id);
  }

  @Delete('addresses/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.addresses.remove(user, id);
  }
}

@ApiTags('Lien de localisation')
@ApiBearerAuth()
@Controller('location-links')
export class LocationLinksController {
  constructor(private readonly links: LocationLinksService) {}

  /** Crée un lien à partager au destinataire (B3). */
  @Post()
  @ApiZodBody(LocationLinkBody)
  @ApiZodResponse(LocationLinkDto, HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(LocationLinkBody) body: z.output<typeof LocationLinkBody>,
  ): Promise<z.output<typeof LocationLinkDto>> {
    return this.links.create(user, body);
  }

  @Get()
  @ApiZodQuery(LocationLinkListQuery)
  @ApiZodResponse(z.array(LocationLinkDto))
  list(
    @CurrentUser() user: AuthUser,
    @ValidQuery(LocationLinkListQuery) query: z.output<typeof LocationLinkListQuery>,
  ): Promise<z.output<typeof LocationLinkDto>[]> {
    return this.links.list(user, query);
  }

  @Get(':id')
  @ApiZodResponse(LocationLinkDto)
  get(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof LocationLinkDto>> {
    return this.links.get(user, id);
  }
}

const TokenParam = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);

/** Page publique ouverte par le destinataire depuis le lien reçu. */
@ApiTags('Public')
@Public()
@Throttle({ default: { limit: 120, ttl: 60_000 } })
@Controller('public/location-links')
export class PublicLocationLinksController {
  constructor(private readonly links: LocationLinksService) {}

  @Get(':token')
  @ApiZodResponse(PublicLocationLinkDto)
  view(@Param('token') token: string): Promise<z.output<typeof PublicLocationLinkDto>> {
    if (!TokenParam.safeParse(token).success) throw AppError.notFound('LOCATION_LINK_NOT_FOUND');
    return this.links.publicView(token);
  }

  @Post(':token')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(PublicLocationSubmitBody)
  @ApiZodResponse(PublicLocationLinkDto)
  submit(
    @Param('token') token: string,
    @ValidBody(PublicLocationSubmitBody) body: z.output<typeof PublicLocationSubmitBody>,
  ): Promise<z.output<typeof PublicLocationLinkDto>> {
    if (!TokenParam.safeParse(token).success) throw AppError.notFound('LOCATION_LINK_NOT_FOUND');
    return this.links.publicSubmit(token, body);
  }
}

/** Zones desservies, quartiers et zones interdites aux motos (B6). */
@ApiTags('Back-office · zones')
@ApiBearerAuth()
@Roles('ADMIN')
@Controller('admin/zones')
export class AdminZonesController {
  constructor(
    private readonly zones: ZonesRepository,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** Importe un polygone GeoJSON (coordonnées [longitude, latitude]). */
  @Post()
  @ApiZodBody(ZoneBody)
  @ApiZodResponse(ZoneDto, HttpStatus.CREATED)
  async create(
    @CurrentUser() user: AuthUser,
    @ValidBody(ZoneBody) body: z.output<typeof ZoneBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof ZoneDto>> {
    const zone = await this.zones.create(body);
    await this.audit.record({
      actor: user,
      action: 'zone.created',
      entityType: 'zone',
      entityId: zone.id,
      after: zone,
      request,
    });
    return zone;
  }

  @Patch(':id')
  @ApiZodBody(ZonePatchBody)
  @ApiZodResponse(ZoneDto)
  async patch(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ZonePatchBody) body: z.output<typeof ZonePatchBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof ZoneDto>> {
    const { count } = await this.prisma.zone.updateMany({
      where: { id },
      data: { active: body.active },
    });
    if (count !== 1) throw AppError.notFound();
    const zone = await this.prisma.zone.findUniqueOrThrow({
      where: { id },
      select: { id: true, name: true, city: true, kind: true, active: true },
    });
    await this.audit.record({
      actor: user,
      action: 'zone.updated',
      entityType: 'zone',
      entityId: id,
      after: zone,
      request,
    });
    return zone;
  }
}
