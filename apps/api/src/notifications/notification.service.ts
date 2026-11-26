import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Job } from 'bullmq';
import { ENV } from '../config/config.module.js';
import { type Env, storageKeys } from '../config/env.js';
import { decryptWithAny, deriveKey, encrypt } from '../common/crypto.js';
import type { AppLocale } from '../common/i18n/locale.js';
import { renderSms, type SmsTemplate, withAppHash } from '../common/i18n/sms-templates.js';
import { maskPhone } from '../common/phone.js';
import type { Notification, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { QueueService } from '../redis/queue.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';
import { PUSH_PROVIDER, type PushProvider, PushTokenInvalidError } from './push.provider.js';
import { type PushTemplate, pushChannel, renderPush } from './push-templates.js';
import { WHATSAPP_PROVIDER, type WhatsAppProvider } from './whatsapp.provider.js';

/**
 * Modèles également envoyés par WhatsApp, avec l'ordre des paramètres du modèle approuvé
 * chez Meta (`tara_<modèle en minuscules>`). Les autres partent directement par SMS.
 */
export const WHATSAPP_PARAMETERS: Partial<Record<SmsTemplate, string[]>> = {
  // Modèle d'authentification de Meta : texte imposé, bouton « Copier le code ».
  OTP: ['code'],
  RECIPIENT_CONFIRMATION: ['sender', 'reference', 'url'],
  DELIVERY_CODE: ['reference', 'code', 'url'],
  DELIVERY_RECEIPT: ['reference'],
  ORDER_CANCELLED_RECIPIENT: ['sender', 'reference'],
};

export interface PhoneNotification {
  phone: string;
  template: SmsTemplate;
  locale: AppLocale;
  params: Record<string, string>;
  /** Paramètres sensibles (code de livraison) : chiffrés en base, jamais en clair en file. */
  secretParams?: Record<string, string>;
  orderId?: string | null;
  userId?: string | null;
  /** SMS directement, sans tenter WhatsApp (alertes à l'équipe). */
  smsOnly?: boolean;
}

export interface PushNotification {
  template: PushTemplate;
  params: Record<string, string | number>;
  data: Record<string, string>;
  orderId?: string | null;
  urgent?: boolean;
  ttlSeconds?: number;
}

/** Modèles de code de connexion : SMS de secours inutile une fois le code expiré. */
const CODE_TEMPLATES = new Set<SmsTemplate>(['OTP']);

interface StoredPayload {
  params: Record<string, string | number>;
  /** Paramètres sensibles chiffrés (AES-256-GCM, base64), effacés après remise. */
  sealed?: string;
  data?: Record<string, string>;
  urgent?: boolean;
  ttlSeconds?: number;
}

const DELIVERY_ATTEMPTS = 3;

/**
 * Code de connexion par WhatsApp sans accusé de remise après ce délai (téléphone sans
 * WhatsApp que Meta n'a pas encore signalé, webhook en panne…) : le même code part par SMS.
 */
export const WHATSAPP_CODE_RECEIPT_SECONDS = 45;

/**
 * Notifications push, WhatsApp et SMS (F3), toutes tracées dans la table `notifications`.
 *
 * - Destinataire sans compte : WhatsApp d'abord s'il est activé, puis SMS si WhatsApp
 *   échoue (refus immédiat, ou accusé « failed » reçu plus tard par le webhook).
 * - Utilisateur de l'app : push sur ses appareils ; un jeton refusé est effacé.
 * - Avec JOBS_ENABLED, les envois passent par une file (3 essais espacés) ; sinon ils sont
 *   faits tout de suite, un seul essai (tests, scripts).
 * - Un échec d'envoi n'interrompt jamais l'action de l'utilisateur.
 */
@Injectable()
export class NotificationService implements OnModuleInit {
  private readonly logger = new Logger(NotificationService.name);
  /** Clé actuelle d'abord, puis l'ancienne pendant une rotation de la clé maîtresse. */
  private readonly secretKeys: Buffer[];

  constructor(
    private readonly prisma: PrismaService,
    private readonly queue: QueueService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(PUSH_PROVIDER) private readonly push: PushProvider,
    @Inject(WHATSAPP_PROVIDER) private readonly whatsapp: WhatsAppProvider | null,
    @Inject(ENV) private readonly env: Env,
  ) {
    this.secretKeys = storageKeys(env).map((master) => deriveKey(master, 'notification-secrets'));
  }

  onModuleInit(): void {
    this.queue.register('notifications', (job: Job<{ id: string }>) =>
      this.deliver(job.data.id, job.attemptsMade + 1 >= (job.opts.attempts ?? 1)),
    );
  }

  // --- Envoi --------------------------------------------------------------------------------

  async toPhone(message: PhoneNotification): Promise<void> {
    const viaWhatsApp =
      !message.smsOnly && this.whatsapp !== null && WHATSAPP_PARAMETERS[message.template];
    const payload: StoredPayload = { params: message.params };
    if (message.secretParams) payload.sealed = this.seal(message.secretParams);
    const notification = await this.prisma.notification.create({
      data: {
        userId: message.userId ?? null,
        recipientPhone: message.phone,
        channel: viaWhatsApp ? 'WHATSAPP' : 'SMS',
        template: message.template,
        locale: message.locale === 'en' ? 'EN' : 'FR',
        payload: payload as unknown as Prisma.InputJsonObject,
        orderId: message.orderId ?? null,
      },
    });
    await this.dispatch(notification.id);
  }

  /**
   * Code de connexion par WhatsApp (modèle d'authentification `tara_otp`, bouton « Copier le
   * code »), envoyé tout de suite. Renvoie false si WhatsApp le refuse : l'appelant envoie
   * alors le SMS. Un échec signalé ensuite par Meta (numéro sans WhatsApp) déclenche le SMS
   * de secours, tant que le code est valable ; [smsHash] y est ajouté pour l'app Android.
   */
  async codeByWhatsApp(input: {
    phone: string;
    locale: AppLocale;
    code: string;
    minutes: number;
    smsHash: string | null;
  }): Promise<boolean> {
    if (!this.whatsapp) return false;
    const payload: StoredPayload = {
      params: { minutes: input.minutes, ...(input.smsHash ? { smsHash: input.smsHash } : {}) },
      sealed: this.seal({ code: input.code }),
    };
    const notification = await this.prisma.notification.create({
      data: {
        recipientPhone: input.phone,
        channel: 'WHATSAPP',
        template: 'OTP',
        locale: input.locale === 'en' ? 'EN' : 'FR',
        payload: payload as unknown as Prisma.InputJsonObject,
      },
    });
    try {
      const sent = await this.whatsapp.send(input.phone, {
        template: 'tara_otp',
        locale: input.locale,
        parameters: [input.code],
        copyCode: input.code,
      });
      await this.prisma.notification.update({
        where: { id: notification.id },
        data: {
          status: 'SENT',
          provider: this.whatsapp.name,
          providerReference: sent.providerReference,
          attempts: 1,
          sentAt: new Date(),
        },
      });
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Code WhatsApp refusé pour ${maskPhone(input.phone)} : ${message}`);
      await this.prisma.notification.update({
        where: { id: notification.id },
        data: {
          status: 'FAILED',
          attempts: 1,
          lastError: message.slice(0, 500),
          payload: withoutSecrets(payload) as unknown as Prisma.InputJsonObject,
        },
      });
      return false;
    }
  }

  /**
   * Push sur tous les appareils de l'utilisateur. Renvoie false s'il n'en a aucun. La
   * notification entre aussi dans sa boîte de réception (cloche de l'app), même sans
   * téléphone joignable ; pas les propositions de course, qui ne valent que 30 s.
   */
  async toUser(userId: string, message: PushNotification): Promise<boolean> {
    if (!message.urgent && message.template !== 'OFFER_NEW') {
      await this.prisma.inboxItem.create({
        data: {
          userId,
          template: message.template,
          params: message.params as Prisma.InputJsonObject,
          orderId: message.orderId ?? null,
        },
      });
    }
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        locale: true,
        devices: { where: { pushToken: { not: null } }, select: { id: true } },
      },
    });
    if (!user || user.devices.length === 0) return false;
    const payload: StoredPayload = { params: message.params, data: message.data };
    if (message.urgent) payload.urgent = true;
    if (message.ttlSeconds) payload.ttlSeconds = message.ttlSeconds;
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        channel: 'PUSH',
        template: message.template,
        locale: user.locale,
        payload: payload as unknown as Prisma.InputJsonObject,
        orderId: message.orderId ?? null,
      },
    });
    // Une proposition de course n'attend pas la file : elle n'a d'intérêt que dans les 30 s.
    if (message.urgent) await this.deliver(notification.id, true);
    else await this.dispatch(notification.id);
    return true;
  }

  /** SMS à l'équipe des opérations (alerte de sécurité, course sans livreur). */
  async toOps(template: SmsTemplate, params: Record<string, string>): Promise<void> {
    const phones = this.env.OPS_ALERT_PHONES.split(',')
      .map((phone) => phone.trim())
      .filter(Boolean);
    for (const phone of phones) {
      await this.toPhone({ phone, template, locale: 'fr', params, smsOnly: true });
    }
  }

  private async dispatch(id: string): Promise<void> {
    if (this.queue.workersEnabled) {
      await this.queue.add(
        'notifications',
        'deliver',
        { id },
        {
          jobId: `notification-${id}`,
          attempts: DELIVERY_ATTEMPTS,
          backoff: { type: 'exponential', delay: 5_000 },
        },
      );
      return;
    }
    await this.deliver(id, true).catch(() => undefined);
  }

  /**
   * Un essai d'envoi. En échec, l'erreur est relancée pour que la file réessaie ; au
   * dernier essai, la notification passe en échec et, pour WhatsApp, le SMS prend le relais.
   */
  async deliver(id: string, finalAttempt: boolean): Promise<void> {
    const notification = await this.prisma.notification.findUnique({ where: { id } });
    if (!notification || notification.status !== 'QUEUED') return;
    const payload = notification.payload as unknown as StoredPayload;
    try {
      const { provider, providerReference } = await this.send(notification, payload);
      await this.prisma.notification.update({
        where: { id },
        data: {
          status: 'SENT',
          provider,
          providerReference,
          attempts: { increment: 1 },
          sentAt: new Date(),
          // Le code reste chiffré tant qu'un repli WhatsApp → SMS reste possible.
          payload: (notification.channel === 'WHATSAPP'
            ? payload
            : withoutSecrets(payload)) as unknown as Prisma.InputJsonObject,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await this.prisma.notification.update({
        where: { id },
        data: {
          attempts: { increment: 1 },
          lastError: message.slice(0, 500),
          ...(finalAttempt
            ? {
                status: 'FAILED',
                payload: withoutSecrets(payload) as unknown as Prisma.InputJsonObject,
              }
            : {}),
        },
      });
      if (!finalAttempt) throw error;
      this.logger.warn(
        `${notification.channel} ${notification.template} non remis${
          notification.recipientPhone ? ` à ${maskPhone(notification.recipientPhone)}` : ''
        } : ${message}`,
      );
      if (notification.channel === 'WHATSAPP') await this.fallbackToSms(notification, payload);
    }
  }

  private async send(
    notification: Notification,
    payload: StoredPayload,
  ): Promise<{ provider: string; providerReference: string | null }> {
    const params = { ...payload.params, ...this.unseal(payload.sealed) };
    const locale: AppLocale = notification.locale === 'EN' ? 'en' : 'fr';
    switch (notification.channel) {
      case 'SMS': {
        if (!notification.recipientPhone) throw new Error('Numéro effacé');
        const text = withAppHash(
          renderSms(notification.template as SmsTemplate, locale, params),
          typeof params['smsHash'] === 'string' ? params['smsHash'] : null,
        );
        const sent = await this.sms.send(notification.recipientPhone, text);
        return {
          provider: sent.provider ?? this.sms.name,
          providerReference: sent.providerReference,
        };
      }
      case 'WHATSAPP': {
        if (!this.whatsapp) throw new Error('WhatsApp désactivé');
        if (!notification.recipientPhone) throw new Error('Numéro effacé');
        const order = WHATSAPP_PARAMETERS[notification.template as SmsTemplate] ?? [];
        const sent = await this.whatsapp.send(notification.recipientPhone, {
          template: `tara_${notification.template.toLowerCase()}`,
          locale,
          parameters: order.map((key) => String(params[key] ?? '')),
        });
        return { provider: this.whatsapp.name, providerReference: sent.providerReference };
      }
      case 'PUSH':
        return this.sendPush(notification, payload, locale);
    }
  }

  private async sendPush(
    notification: Notification,
    payload: StoredPayload,
    locale: AppLocale,
  ): Promise<{ provider: string; providerReference: string | null }> {
    if (!notification.userId) throw new Error('Push sans utilisateur');
    const devices = await this.prisma.device.findMany({
      where: { userId: notification.userId, pushToken: { not: null } },
    });
    const { title, body } = renderPush(
      notification.template as PushTemplate,
      locale,
      payload.params,
    );
    const references: string[] = [];
    let lastError: unknown = new Error('Aucun appareil enregistré');
    for (const device of devices) {
      if (!device.pushToken) continue;
      try {
        const sent = await this.push.send(device.pushToken, {
          title,
          body,
          data: { ...payload.data, notificationId: notification.id },
          urgent: payload.urgent ?? false,
          channel: pushChannel(notification.template as PushTemplate, payload.urgent ?? false),
          ...(payload.ttlSeconds ? { ttlSeconds: payload.ttlSeconds } : {}),
        });
        references.push(sent.providerReference);
      } catch (error) {
        lastError = error;
        if (error instanceof PushTokenInvalidError) {
          // App désinstallée ou jeton remplacé : on ne l'utilise plus.
          await this.prisma.device.update({ where: { id: device.id }, data: { pushToken: null } });
        }
      }
    }
    if (references.length === 0) throw lastError;
    return { provider: this.push.name, providerReference: references.join(',').slice(0, 500) };
  }

  /** Repli SMS d'un message WhatsApp non remis (une seule fois). */
  async fallbackToSms(original: Notification, payload: StoredPayload): Promise<void> {
    if (!original.recipientPhone) return;
    const codeExpired =
      CODE_TEMPLATES.has(original.template as SmsTemplate) &&
      Date.now() - original.createdAt.getTime() >= this.env.OTP_TTL_SECONDS * 1000;
    if (codeExpired) return;
    const fallback = await this.prisma.notification
      .create({
        data: {
          userId: original.userId,
          recipientPhone: original.recipientPhone,
          channel: 'SMS',
          template: original.template,
          locale: original.locale,
          payload: payload as unknown as Prisma.InputJsonObject,
          orderId: original.orderId,
          fallbackForId: original.id,
        },
      })
      .catch(() => null); // Repli déjà créé (accusé reçu deux fois).
    if (fallback) await this.dispatch(fallback.id);
  }

  // --- Accusés de remise WhatsApp (webhook) -------------------------------------------------

  @Cron('*/15 * * * * *', { name: 'whatsapp-code-receipts' })
  async scheduledCodeReceipts(): Promise<void> {
    if (!this.env.JOBS_ENABLED || !this.whatsapp) return;
    await this.watchWhatsAppCodes();
  }

  /**
   * Codes de connexion envoyés par WhatsApp, encore valables, sans accusé « remis » après
   * [WHATSAPP_CODE_RECEIPT_SECONDS] : marqués en échec et renvoyés par SMS (une seule fois).
   * Un accusé « remis » arrivé ensuite est quand même enregistré.
   */
  async watchWhatsAppCodes(now = new Date()): Promise<number> {
    if (!this.whatsapp) return 0;
    const waiting = await this.prisma.notification.findMany({
      where: {
        channel: 'WHATSAPP',
        template: 'OTP',
        status: 'SENT',
        sentAt: { lte: new Date(now.getTime() - WHATSAPP_CODE_RECEIPT_SECONDS * 1000) },
        createdAt: { gte: new Date(now.getTime() - this.env.OTP_TTL_SECONDS * 1000) },
      },
      take: 200,
    });
    let resent = 0;
    for (const notification of waiting) {
      // Une autre instance peut traiter le même code : seule celle qui le passe en échec renvoie.
      const claimed = await this.prisma.notification.updateMany({
        where: { id: notification.id, status: 'SENT' },
        data: {
          status: 'FAILED',
          lastError: `Pas d'accusé de remise WhatsApp après ${WHATSAPP_CODE_RECEIPT_SECONDS} s`,
          payload: withoutSecrets(
            notification.payload as unknown as StoredPayload,
          ) as unknown as Prisma.InputJsonObject,
        },
      });
      if (claimed.count === 0) continue;
      this.logger.warn(
        `Code WhatsApp non confirmé pour ${maskPhone(notification.recipientPhone ?? '')} : SMS de secours`,
      );
      await this.fallbackToSms(notification, notification.payload as unknown as StoredPayload);
      resent += 1;
    }
    return resent;
  }

  async whatsappStatus(
    providerReference: string,
    status: 'sent' | 'delivered' | 'read' | 'failed',
    error?: string,
  ): Promise<void> {
    if (!this.whatsapp) return;
    const notification = await this.prisma.notification.findFirst({
      where: { provider: this.whatsapp.name, providerReference, channel: 'WHATSAPP' },
    });
    if (!notification) return;
    const payload = notification.payload as unknown as StoredPayload;
    if (status === 'delivered' || status === 'read') {
      if (notification.status === 'DELIVERED') return;
      await this.prisma.notification.update({
        where: { id: notification.id },
        data: {
          status: 'DELIVERED',
          deliveredAt: new Date(),
          lastError: null,
          payload: withoutSecrets(payload) as unknown as Prisma.InputJsonObject,
        },
      });
      return;
    }
    if (status !== 'failed' || notification.status === 'FAILED') return;
    await this.prisma.notification.update({
      where: { id: notification.id },
      data: {
        status: 'FAILED',
        lastError: (error ?? 'Échec signalé par WhatsApp').slice(0, 500),
        payload: withoutSecrets(payload) as unknown as Prisma.InputJsonObject,
      },
    });
    await this.fallbackToSms(notification, payload);
  }

  // --- Secrets ------------------------------------------------------------------------------

  private seal(secrets: Record<string, string>): string {
    return encrypt(this.secretKeys[0] as Buffer, Buffer.from(JSON.stringify(secrets))).toString(
      'base64',
    );
  }

  private unseal(sealed: string | undefined): Record<string, string> {
    if (!sealed) return {};
    return JSON.parse(
      decryptWithAny(this.secretKeys, Buffer.from(sealed, 'base64')).toString('utf8'),
    ) as Record<string, string>;
  }
}

function withoutSecrets(payload: StoredPayload): StoredPayload {
  const { sealed: _sealed, ...rest } = payload;
  return rest;
}
