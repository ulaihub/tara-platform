import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { renderSms, type SmsTemplate } from '../common/i18n/sms-templates.js';
import { maskPhone } from '../common/phone.js';
import type { Order } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';

/**
 * Messages au destinataire (C5). Un échec d'envoi n'annule jamais la commande : il est
 * tracé dans la table des notifications. Le repli WhatsApp → SMS arrive en phase 2 (F3).
 * Les codes ne sont jamais enregistrés dans la notification.
 */
@Injectable()
export class RecipientNotifier {
  private readonly logger = new Logger(RecipientNotifier.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  trackingUrl(trackingToken: string): string {
    return `${this.env.PUBLIC_WEB_URL.replace(/\/$/, '')}/t/${trackingToken}`;
  }

  async confirmation(order: Order, senderName: string): Promise<void> {
    await this.send(order, 'RECIPIENT_CONFIRMATION', {
      sender: senderName,
      reference: order.reference,
      url: this.trackingUrl(order.trackingToken),
    });
  }

  async deliveryCode(order: Order, code: string): Promise<void> {
    await this.send(order, 'DELIVERY_CODE', {
      reference: order.reference,
      code,
      url: this.trackingUrl(order.trackingToken),
    });
  }

  private async send(
    order: Order,
    template: SmsTemplate,
    params: Record<string, string>,
  ): Promise<void> {
    // Langue du destinataire inconnue : français par défaut.
    const text = renderSms(template, 'fr', params);
    let status: 'SENT' | 'FAILED' = 'SENT';
    let providerReference: string | null = null;
    let lastError: string | null = null;
    try {
      providerReference = (await this.sms.send(order.recipientPhone, text)).providerReference;
    } catch (error) {
      status = 'FAILED';
      lastError = String(error).slice(0, 500);
      this.logger.error(
        `SMS ${template} non envoyé à ${maskPhone(order.recipientPhone)} (${order.reference})`,
      );
    }
    await this.prisma.notification.create({
      data: {
        recipientPhone: order.recipientPhone,
        channel: 'SMS',
        template,
        payload: { reference: order.reference },
        status,
        provider: this.sms.name,
        providerReference,
        attempts: 1,
        lastError,
        orderId: order.id,
        sentAt: status === 'SENT' ? new Date() : null,
      },
    });
  }
}
