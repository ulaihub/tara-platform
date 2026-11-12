import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
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
import {
  AdminCreateTicketBody,
  AdminTicketDto,
  AdminTicketListQuery,
  AdminTicketMessageBody,
  AdminTicketPageDto,
  AdminTicketUpdateBody,
  CreateTicketBody,
  OrderEvidenceDto,
  TicketDto,
  TicketReplyBody,
} from './support.schemas.js';
import { SupportService } from './support.service.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

/** Envoie un fichier (photo de preuve) sans cache, à télécharger, jamais interprété. */
function sendFile(response: Response, file: { buffer: Buffer; mimeType: string }): void {
  response
    .status(HttpStatus.OK)
    .set({
      'Content-Type': file.mimeType,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Disposition': 'attachment; filename="preuve"',
    })
    .send(file.buffer);
}

/** Demandes au service client depuis les apps (expéditeurs, boutiques, livreurs). */
@ApiTags('Service client')
@ApiBearerAuth()
@Controller('support/tickets')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Post()
  @Throttle({ default: { limit: 10, ttl: 3_600_000 } })
  @ApiZodBody(CreateTicketBody)
  @ApiZodResponse(TicketDto, 201)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(CreateTicketBody) body: z.output<typeof CreateTicketBody>,
  ): Out<typeof TicketDto> {
    return this.support.create(user, body);
  }

  @Get()
  @ApiZodResponse(z.array(TicketDto))
  list(@CurrentUser() user: AuthUser): Out<z.ZodArray<typeof TicketDto>> {
    return this.support.list(user);
  }

  @Get(':id')
  @ApiZodResponse(TicketDto)
  detail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof TicketDto> {
    return this.support.mine(user, id);
  }

  @Post(':id/messages')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 3_600_000 } })
  @ApiZodBody(TicketReplyBody)
  @ApiZodResponse(TicketDto)
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(TicketReplyBody) body: z.output<typeof TicketReplyBody>,
  ): Out<typeof TicketDto> {
    return this.support.reply(user, id, body.body);
  }
}

/**
 * Service client au back-office (H6) : file des demandes, échanges, notes internes, prise en
 * charge ; preuves des commandes pour trancher les litiges (photos consultées tracées).
 */
@ApiTags('Back-office · service client')
@ApiBearerAuth()
@Controller('admin/support')
export class AdminSupportController {
  constructor(private readonly support: SupportService) {}

  @Get('tickets')
  @Roles('ADMIN', 'SUPPORT')
  @ApiZodQuery(AdminTicketListQuery)
  @ApiZodResponse(AdminTicketPageDto)
  list(
    @CurrentUser() user: AuthUser,
    @ValidQuery(AdminTicketListQuery) query: z.output<typeof AdminTicketListQuery>,
  ): Out<typeof AdminTicketPageDto> {
    return this.support.adminList(user, query);
  }

  @Post('tickets')
  @Roles('ADMIN', 'SUPPORT')
  @ApiZodBody(AdminCreateTicketBody)
  @ApiZodResponse(AdminTicketDto, 201)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(AdminCreateTicketBody) body: z.output<typeof AdminCreateTicketBody>,
  ): Out<typeof AdminTicketDto> {
    return this.support.adminCreate(user, body);
  }

  @Get('tickets/:id')
  @Roles('ADMIN', 'SUPPORT')
  @ApiZodResponse(AdminTicketDto)
  detail(@Param('id', ParseUUIDPipe) id: string): Out<typeof AdminTicketDto> {
    return this.support.adminDetail(id);
  }

  @Post('tickets/:id/messages')
  @Roles('ADMIN', 'SUPPORT')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(AdminTicketMessageBody)
  @ApiZodResponse(AdminTicketDto)
  message(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AdminTicketMessageBody) body: z.output<typeof AdminTicketMessageBody>,
  ): Out<typeof AdminTicketDto> {
    return this.support.adminMessage(user, id, body);
  }

  @Patch('tickets/:id')
  @Roles('ADMIN', 'SUPPORT')
  @ApiZodBody(AdminTicketUpdateBody)
  @ApiZodResponse(AdminTicketDto)
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AdminTicketUpdateBody) body: z.output<typeof AdminTicketUpdateBody>,
    @Req() request: Request,
  ): Out<typeof AdminTicketDto> {
    return this.support.adminUpdate(user, id, body, request);
  }

  /** Preuves d'une commande : photos, positions, appels, notes ; pour trancher un litige. */
  @Get('orders/:orderId/evidence')
  @Roles('ADMIN', 'SUPPORT', 'DISPATCHER')
  @ApiZodResponse(OrderEvidenceDto)
  evidence(@Param('orderId', ParseUUIDPipe) orderId: string): Out<typeof OrderEvidenceDto> {
    return this.support.evidence(orderId);
  }

  @Get('proofs/:proofId/photo')
  @Roles('ADMIN', 'SUPPORT', 'DISPATCHER')
  async proofPhoto(
    @CurrentUser() user: AuthUser,
    @Param('proofId', ParseUUIDPipe) proofId: string,
    @Req() request: Request,
    @Res() response: Response,
  ): Promise<void> {
    sendFile(response, await this.support.proofPhoto(user, proofId, request));
  }

  @Get('orders/:orderId/parcel-photo')
  @Roles('ADMIN', 'SUPPORT', 'DISPATCHER')
  async parcelPhoto(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @Req() request: Request,
    @Res() response: Response,
  ): Promise<void> {
    sendFile(response, await this.support.parcelPhoto(user, orderId, request));
  }
}
