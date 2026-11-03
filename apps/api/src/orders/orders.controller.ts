import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Public, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { pageSchema } from '../common/pagination.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import {
  AdminTransitionBody,
  CancelOrderBody,
  CreateBatchBody,
  CreatedBatchDto,
  CreatedOrderDto,
  CreateOrderBody,
  OrderDto,
  OrderListQuery,
  OrderSummaryDto,
  PickupCodeDto,
  PublicTrackingDto,
  RecipientDto,
  RecipientQuery,
  RecipientResponseBody,
} from './orders.schemas.js';
import { OrdersService } from './orders.service.js';

const IdempotencyKey = z.string().regex(/^[A-Za-z0-9_-]{8,100}$/);

function idempotencyKey(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  if (!IdempotencyKey.safeParse(value).success) {
    throw AppError.badRequest('VALIDATION_FAILED', {}, [
      { path: 'Idempotency-Key', message: 'format invalide' },
    ]);
  }
  return value;
}

const IDEMPOTENCY_HEADER = ApiHeader({
  name: 'Idempotency-Key',
  required: false,
  description:
    'Identifiant unique généré par l’app (UUID conseillé). Renvoyer la même requête après une coupure réseau renvoie la commande déjà créée.',
});

@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  /** Nouvelle commande (C1) : le prix est recalculé côté serveur. */
  @Post()
  @IDEMPOTENCY_HEADER
  @ApiZodBody(CreateOrderBody)
  @ApiZodResponse(CreatedOrderDto, HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(CreateOrderBody) body: z.output<typeof CreateOrderBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Promise<z.output<typeof CreatedOrderDto>> {
    return this.orders.create(user, body, idempotencyKey(key));
  }

  /** Jusqu'à 10 livraisons depuis un même point d'enlèvement (C4). */
  @Post('batch')
  @IDEMPOTENCY_HEADER
  @ApiZodBody(CreateBatchBody)
  @ApiZodResponse(CreatedBatchDto, HttpStatus.CREATED)
  createBatch(
    @CurrentUser() user: AuthUser,
    @ValidBody(CreateBatchBody) body: z.output<typeof CreateBatchBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Promise<z.output<typeof CreatedBatchDto>> {
    return this.orders.createBatch(user, body, idempotencyKey(key));
  }

  @Get()
  @ApiZodQuery(OrderListQuery)
  @ApiZodResponse(pageSchema(OrderSummaryDto))
  list(
    @CurrentUser() user: AuthUser,
    @ValidQuery(OrderListQuery) query: z.output<typeof OrderListQuery>,
  ): Promise<{ items: z.output<typeof OrderSummaryDto>[]; nextCursor: string | null }> {
    return this.orders.list(user, query);
  }

  @Get(':id')
  @ApiZodResponse(OrderDto)
  get(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof OrderDto>> {
    return this.orders.get(user, id);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(CancelOrderBody)
  @ApiZodResponse(OrderDto)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(CancelOrderBody) body: z.output<typeof CancelOrderBody>,
  ): Promise<z.output<typeof OrderDto>> {
    return this.orders.cancel(user, id, body.reason);
  }

  /** Nouveau code d'enlèvement si l'expéditeur a perdu le précédent. */
  @Post(':id/pickup-code')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(PickupCodeDto)
  regeneratePickupCode(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof PickupCodeDto>> {
    return this.orders.regeneratePickupCode(user, id);
  }
}

@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('recipients')
export class RecipientsController {
  constructor(private readonly orders: OrdersService) {}

  /** Destinataires déjà servis, avec leur dernière adresse (B4, B5). */
  @Get()
  @ApiZodQuery(RecipientQuery)
  @ApiZodResponse(z.array(RecipientDto))
  list(
    @CurrentUser() user: AuthUser,
    @ValidQuery(RecipientQuery) query: z.output<typeof RecipientQuery>,
  ): Promise<z.output<typeof RecipientDto>[]> {
    return this.orders.recipients(user, query.q);
  }
}

const TrackingToken = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);

/** Page de suivi ouverte par le destinataire depuis le SMS, sans compte. */
@ApiTags('Public')
@Public()
@Throttle({ default: { limit: 30, ttl: 60_000 } })
@Controller('public/tracking')
export class PublicTrackingController {
  constructor(private readonly orders: OrdersService) {}

  @Get(':token')
  @ApiZodResponse(PublicTrackingDto)
  view(@Param('token') token: string): Promise<z.output<typeof PublicTrackingDto>> {
    if (!TrackingToken.safeParse(token).success) throw AppError.notFound('ORDER_NOT_FOUND');
    return this.orders.publicTracking(token);
  }

  /** Le destinataire confirme son adresse et sa disponibilité (C5). */
  @Post(':token/response')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(RecipientResponseBody)
  @ApiZodResponse(PublicTrackingDto)
  respond(
    @Param('token') token: string,
    @ValidBody(RecipientResponseBody) body: z.output<typeof RecipientResponseBody>,
  ): Promise<z.output<typeof PublicTrackingDto>> {
    if (!TrackingToken.safeParse(token).success) throw AppError.notFound('ORDER_NOT_FOUND');
    return this.orders.recipientResponse(token, body);
  }
}

@ApiTags('Back-office · commandes')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER')
@Controller('admin/orders')
export class AdminOrdersController {
  constructor(private readonly orders: OrdersService) {}

  /** Change le statut d'une commande au nom des opérations (D3 manuel, incidents). */
  @Post(':id/transition')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(AdminTransitionBody)
  @ApiZodResponse(OrderDto)
  transition(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AdminTransitionBody) body: z.output<typeof AdminTransitionBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof OrderDto>> {
    return this.orders.adminTransition(user, id, body, request);
  }
}
