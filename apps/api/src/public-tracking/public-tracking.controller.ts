import { Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { z } from 'zod';
import { Public } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { PublicTrackingDto, RecipientResponseBody } from '../orders/orders.schemas.js';
import { OrdersService } from '../orders/orders.service.js';
import { PublicTrackingService } from './public-tracking.service.js';

const TrackingToken = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);

/** Page de suivi ouverte par le destinataire depuis le SMS, sans compte (F2). */
@ApiTags('Public')
@Public()
@Throttle({ default: { limit: 120, ttl: 60_000 } })
@Controller('public/tracking')
export class PublicTrackingController {
  constructor(
    private readonly tracking: PublicTrackingService,
    private readonly orders: OrdersService,
  ) {}

  @Get(':token')
  @ApiZodResponse(PublicTrackingDto)
  view(@Param('token') token: string): Promise<z.output<typeof PublicTrackingDto>> {
    if (!TrackingToken.safeParse(token).success) throw AppError.notFound('ORDER_NOT_FOUND');
    return this.tracking.view(token);
  }

  /** « Je n'ai pas reçu le code » : nouveau code au numéro du destinataire (3 fois au plus). */
  @Post(':token/delivery-code')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.NO_CONTENT)
  async resendCode(@Param('token') token: string): Promise<void> {
    if (!TrackingToken.safeParse(token).success) throw AppError.notFound('ORDER_NOT_FOUND');
    await this.tracking.resendDeliveryCode(token);
  }

  /** Le destinataire confirme son adresse et sa disponibilité (C5). */
  @Post(':token/response')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(RecipientResponseBody)
  @ApiZodResponse(PublicTrackingDto)
  async respond(
    @Param('token') token: string,
    @ValidBody(RecipientResponseBody) body: z.output<typeof RecipientResponseBody>,
  ): Promise<z.output<typeof PublicTrackingDto>> {
    if (!TrackingToken.safeParse(token).success) throw AppError.notFound('ORDER_NOT_FOUND');
    await this.orders.recipientResponse(token, body);
    return this.tracking.view(token);
  }
}
