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
import type { Request } from 'express';
import type { z } from 'zod';
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
  AddOrderNoteBody,
  AdminCancelBody,
  AdminOrderDto,
  AdminOrderListQuery,
  AdminOrderPageDto,
  OrderNoteDto,
} from './admin-orders.schemas.js';
import { AdminOrdersService } from './admin-orders.service.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

/**
 * Commandes au back-office (H2) : recherche, fiche et notes pour le dispatch, le support et
 * les administrateurs ; annulation par le dispatch et les administrateurs.
 */
@ApiTags('Back-office · commandes')
@ApiBearerAuth()
@Controller('admin/orders')
export class AdminOrderDeskController {
  constructor(private readonly orders: AdminOrdersService) {}

  @Get()
  @Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
  @ApiZodQuery(AdminOrderListQuery)
  @ApiZodResponse(AdminOrderPageDto)
  list(
    @ValidQuery(AdminOrderListQuery) query: z.output<typeof AdminOrderListQuery>,
  ): Out<typeof AdminOrderPageDto> {
    return this.orders.list(query);
  }

  @Get(':id')
  @Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
  @ApiZodResponse(AdminOrderDto)
  detail(@Param('id', ParseUUIDPipe) id: string): Out<typeof AdminOrderDto> {
    return this.orders.detail(id);
  }

  /** Note interne, visible de l'équipe seulement. */
  @Post(':id/notes')
  @Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
  @ApiZodBody(AddOrderNoteBody)
  @ApiZodResponse(OrderNoteDto, HttpStatus.CREATED)
  addNote(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AddOrderNoteBody) body: z.output<typeof AddOrderNoteBody>,
  ): Out<typeof OrderNoteDto> {
    return this.orders.addNote(user, id, body.body);
  }

  /** Annule une commande avant l'enlèvement ; l'expéditeur est prévenu, l'action tracée. */
  @Post(':id/cancel')
  @Roles('ADMIN', 'DISPATCHER')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(AdminCancelBody)
  @ApiZodResponse(AdminOrderDto)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AdminCancelBody) body: z.output<typeof AdminCancelBody>,
    @Req() request: Request,
  ): Out<typeof AdminOrderDto> {
    return this.orders.cancel(user, id, body.reason, request);
  }
}
