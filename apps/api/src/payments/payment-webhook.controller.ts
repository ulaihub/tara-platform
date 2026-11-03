import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Inject,
  Logger,
  Param,
  Post,
  type RawBodyRequest,
  Req,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { InvalidWebhookError, PAYMENT_PROVIDER, type PaymentProvider } from './payment.provider.js';
import { PaymentsService } from './payments.service.js';

/**
 * Notifications de l'agrégateur Mobile Money (paiements et reversements). Chaque appel est
 * authentifié par la signature du prestataire ; le contenu n'est cru qu'après vérification,
 * et une notification répétée n'a aucun effet.
 */
@ApiExcludeController()
@Public()
@SkipThrottle()
@Controller('webhooks/payments')
export class PaymentWebhookController {
  private readonly logger = new Logger(PaymentWebhookController.name);

  constructor(
    private readonly payments: PaymentsService,
    @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
  ) {}

  @Get(':provider')
  @HttpCode(HttpStatus.OK)
  receiveGet(
    @Param('provider') name: string,
    @Req() request: RawBodyRequest<Request>,
  ): Promise<{ received: true }> {
    return this.receive(name, request);
  }

  @Post(':provider')
  @HttpCode(HttpStatus.OK)
  receivePost(
    @Param('provider') name: string,
    @Req() request: RawBodyRequest<Request>,
  ): Promise<{ received: true }> {
    return this.receive(name, request);
  }

  private async receive(
    name: string,
    request: RawBodyRequest<Request>,
  ): Promise<{ received: true }> {
    if (name !== this.provider.name) throw AppError.notFound();
    let event;
    try {
      event = await this.provider.parseWebhook({
        rawBody: request.rawBody,
        headers: request.headers,
        query: request.query as Record<string, unknown>,
        body: request.body as unknown,
      });
    } catch (error) {
      if (error instanceof InvalidWebhookError) {
        this.logger.warn(
          `Notification ${name} rejetée : signature invalide (${request.ip ?? '?'})`,
        );
        throw AppError.unauthorized();
      }
      throw error;
    }
    await this.payments.handleEvent(event, { query: request.query, body: request.body as unknown });
    return { received: true };
  }
}
