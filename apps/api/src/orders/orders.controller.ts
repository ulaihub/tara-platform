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
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { idempotencyKey } from '../common/idempotency.js';
import { pageSchema } from '../common/pagination.js';
import { LegalService } from '../legal/legal.service.js';
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
  PendingDeliveryDto,
  PendingDeliveryListQuery,
  PickupCodeDto,
  RateBody,
  RatingDto,
  RecipientDto,
  RecipientQuery,
  ReleasePendingBody,
} from './orders.schemas.js';
import { OrdersService } from './orders.service.js';
import { RatingsService } from './ratings.service.js';

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
  constructor(
    private readonly orders: OrdersService,
    private readonly ratings: RatingsService,
    private readonly legal: LegalService,
  ) {}

  /**
   * Nouvelle commande (C1) : le prix est recalculé côté serveur. Les conditions des
   * expéditeurs en vigueur doivent être acceptées (TERMS_ACCEPTANCE_REQUIRED sinon).
   */
  @Post()
  @IDEMPOTENCY_HEADER
  @ApiZodBody(CreateOrderBody)
  @ApiZodResponse(CreatedOrderDto, HttpStatus.CREATED)
  async create(
    @CurrentUser() user: AuthUser,
    @ValidBody(CreateOrderBody) body: z.output<typeof CreateOrderBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Promise<z.output<typeof CreatedOrderDto>> {
    await this.legal.assertAccepted(user.id, 'client');
    return this.orders.create(user, body, idempotencyKey(key));
  }

  /**
   * Jusqu'à 100 colis depuis un même point d'enlèvement (C4). Un colis sans adresse
   * (`askAddress`) attend son client : Tara lui envoie un lien par SMS et le colis part
   * dès que le point arrive (voir `pending`).
   */
  @Post('batch')
  @IDEMPOTENCY_HEADER
  @ApiZodBody(CreateBatchBody)
  @ApiZodResponse(CreatedBatchDto, HttpStatus.CREATED)
  async createBatch(
    @CurrentUser() user: AuthUser,
    @ValidBody(CreateBatchBody) body: z.output<typeof CreateBatchBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Promise<z.output<typeof CreatedBatchDto>> {
    await this.legal.assertAccepted(user.id, 'client');
    return this.orders.createBatch(user, body, idempotencyKey(key));
  }

  /** Colis qui attendent l'adresse de leur client (envoi en masse), les plus récents d'abord. */
  @Get('pending')
  @ApiZodQuery(PendingDeliveryListQuery)
  @ApiZodResponse(z.array(PendingDeliveryDto))
  listPending(
    @CurrentUser() user: AuthUser,
    @ValidQuery(PendingDeliveryListQuery) query: z.output<typeof PendingDeliveryListQuery>,
  ): Promise<z.output<typeof PendingDeliveryDto>[]> {
    return this.orders.listPending(user, query.open);
  }

  /** Retire un colis en attente de l'envoi : le lien ne sert plus, rien n'est payé. */
  @Post('pending/:id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(PendingDeliveryDto)
  cancelPending(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof PendingDeliveryDto>> {
    return this.orders.cancelPending(user, id);
  }

  /** Renvoie un lien neuf au client (lien expiré ou SMS perdu ; au plus une fois par heure). */
  @Post('pending/:id/resend')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(PendingDeliveryDto)
  resendPending(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof PendingDeliveryDto>> {
    return this.orders.resendPending(user, id);
  }

  /** Fait partir un colis bloqué (solde rechargé, ou autre moyen de paiement). */
  @Post('pending/:id/release')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(ReleasePendingBody)
  @ApiZodResponse(PendingDeliveryDto)
  async releasePending(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ReleasePendingBody) body: z.output<typeof ReleasePendingBody>,
  ): Promise<z.output<typeof PendingDeliveryDto>> {
    await this.legal.assertAccepted(user.id, 'client');
    return this.orders.retryPending(user, id, body.feePaymentMethod);
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

  /** Note du livreur après la course (F4), une fois, dans les 7 jours. */
  @Post(':id/rating')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(RateBody)
  @ApiZodResponse(RatingDto)
  rate(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(RateBody) body: z.output<typeof RateBody>,
  ): Promise<z.output<typeof RatingDto>> {
    return this.ratings.rateRider(user, id, body);
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
