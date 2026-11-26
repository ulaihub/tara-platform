import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { DevicesController } from './devices.controller.js';
import { InboxController } from './inbox.controller.js';
import { NotificationService } from './notification.service.js';
import { OrderNotificationsListener } from './order-notifications.listener.js';
import {
  FakePushProvider,
  FcmPushProvider,
  PUSH_PROVIDER,
  type PushProvider,
} from './push.provider.js';
import { WhatsAppWebhookController } from './whatsapp-webhook.controller.js';
import {
  FakeWhatsAppProvider,
  MetaWhatsAppProvider,
  WHATSAPP_PROVIDER,
  type WhatsAppProvider,
} from './whatsapp.provider.js';

@Global()
@Module({
  controllers: [DevicesController, InboxController, WhatsAppWebhookController],
  providers: [
    {
      provide: PUSH_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env): PushProvider =>
        env.PUSH_PROVIDER === 'fcm' && env.FCM_SERVICE_ACCOUNT_BASE64
          ? new FcmPushProvider(env.FCM_SERVICE_ACCOUNT_BASE64)
          : new FakePushProvider(),
    },
    {
      provide: WHATSAPP_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env): WhatsAppProvider | null => {
        switch (env.WHATSAPP_PROVIDER) {
          case 'none':
            return null;
          case 'fake':
            return new FakeWhatsAppProvider();
          case 'meta':
            return new MetaWhatsAppProvider(
              env.WHATSAPP_PHONE_NUMBER_ID ?? '',
              env.WHATSAPP_ACCESS_TOKEN ?? '',
              env.WHATSAPP_API_VERSION ?? '',
            );
        }
      },
    },
    NotificationService,
    OrderNotificationsListener,
  ],
  exports: [NotificationService, PUSH_PROVIDER, WHATSAPP_PROVIDER],
})
export class NotificationsModule {}
