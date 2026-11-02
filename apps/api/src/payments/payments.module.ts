import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { LedgerService } from '../finance/ledger.service.js';
import { CamPayPaymentProvider } from './campay.provider.js';
import { FakePaymentProvider, PAYMENT_PROVIDER, type PaymentProvider } from './payment.provider.js';
import { PaymentWebhookController } from './payment-webhook.controller.js';
import { PaymentsService } from './payments.service.js';

@Global()
@Module({
  controllers: [PaymentWebhookController],
  providers: [
    {
      provide: PAYMENT_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env): PaymentProvider =>
        env.PAYMENT_PROVIDER === 'campay'
          ? new CamPayPaymentProvider({
              baseUrl: env.CAMPAY_BASE_URL,
              username: env.CAMPAY_USERNAME ?? '',
              password: env.CAMPAY_PASSWORD ?? '',
              webhookKey: env.CAMPAY_WEBHOOK_KEY ?? '',
            })
          : new FakePaymentProvider(),
    },
    LedgerService,
    PaymentsService,
  ],
  exports: [PAYMENT_PROVIDER, LedgerService, PaymentsService],
})
export class PaymentsModule {}
