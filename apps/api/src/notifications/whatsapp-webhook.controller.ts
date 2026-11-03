import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Inject,
  Post,
  Query,
  type RawBodyRequest,
  Req,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../auth/decorators.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { NotificationService } from './notification.service.js';

interface WhatsAppWebhookBody {
  entry?: {
    changes?: {
      value?: {
        statuses?: {
          id?: string;
          status?: string;
          errors?: { code?: number; title?: string }[];
        }[];
      };
    }[];
  }[];
}

const STATUSES = new Set(['sent', 'delivered', 'read', 'failed']);

function sameSecret(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/**
 * Accusés de remise de WhatsApp Cloud API : un message « failed » (numéro sans WhatsApp,
 * modèle refusé…) déclenche le repli par SMS (F3). Chaque appel est authentifié par la
 * signature HMAC-SHA256 du corps brut avec le secret de l'app Meta.
 */
@ApiExcludeController()
@Public()
@SkipThrottle()
@Controller('webhooks/whatsapp')
export class WhatsAppWebhookController {
  constructor(
    private readonly notifications: NotificationService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private assertEnabled(): { secret: string; verifyToken: string } {
    const secret = this.env.WHATSAPP_APP_SECRET;
    const verifyToken = this.env.WHATSAPP_VERIFY_TOKEN;
    if (this.env.WHATSAPP_PROVIDER !== 'meta' || !secret || !verifyToken) {
      throw AppError.notFound();
    }
    return { secret, verifyToken };
  }

  /** Vérification demandée par Meta à l'enregistrement du webhook. */
  @Get()
  verify(
    @Query('hub.mode') mode: string | undefined,
    @Query('hub.verify_token') token: string | undefined,
    @Query('hub.challenge') challenge: string | undefined,
  ): string {
    const { verifyToken } = this.assertEnabled();
    if (mode !== 'subscribe' || !token || !sameSecret(token, verifyToken) || !challenge) {
      throw AppError.forbidden();
    }
    return challenge;
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  async receive(
    @Req() request: RawBodyRequest<Request>,
    @Headers('x-hub-signature-256') signature: string | undefined,
  ): Promise<{ received: true }> {
    const { secret } = this.assertEnabled();
    const raw = request.rawBody;
    if (!raw || !signature?.startsWith('sha256=')) throw AppError.unauthorized();
    const expected = `sha256=${createHmac('sha256', secret).update(raw).digest('hex')}`;
    if (!sameSecret(signature, expected)) throw AppError.unauthorized();

    const body = request.body as WhatsAppWebhookBody;
    for (const entry of body.entry ?? []) {
      for (const change of entry.changes ?? []) {
        for (const status of change.value?.statuses ?? []) {
          if (!status.id || !status.status || !STATUSES.has(status.status)) continue;
          const error = status.errors?.[0];
          await this.notifications.whatsappStatus(
            status.id,
            status.status as 'sent' | 'delivered' | 'read' | 'failed',
            error ? `${error.code ?? ''} ${error.title ?? ''}`.trim() : undefined,
          );
        }
      }
    }
    return { received: true };
  }
}
