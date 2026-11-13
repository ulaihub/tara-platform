import { Global, Module } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { LedgerService } from '../finance/ledger.service.js';
import { REDIS } from '../redis/redis.constants.js';
import { CamPayPaymentProvider } from './campay.provider.js';
import { FakePaymentProvider, PAYMENT_PROVIDER, type PaymentProvider } from './payment.provider.js';
import { PaymentWebhookController } from './payment-webhook.controller.js';
import { PaymentsService } from './payments.service.js';
import { SebpayPaymentProvider } from './sebpay.provider.js';

function paymentProvider(env: Env, redis: Redis): PaymentProvider {
  switch (env.PAYMENT_PROVIDER) {
    case 'campay':
      return new CamPayPaymentProvider({
        baseUrl: env.CAMPAY_BASE_URL,
        username: env.CAMPAY_USERNAME ?? '',
        password: env.CAMPAY_PASSWORD ?? '',
        webhookKey: env.CAMPAY_WEBHOOK_KEY ?? '',
      });
    case 'sebpay':
      return new SebpayPaymentProvider({
        baseUrl: env.SEBPAY_BASE_URL,
        publicKey: env.SEBPAY_PUBLIC_KEY ?? '',
        secretKey: env.SEBPAY_SECRET_KEY ?? '',
        callbackUrl: `${(env.PUBLIC_API_URL ?? '').replace(/\/$/, '')}/v1/webhooks/payments/sebpay`,
      });
    case 'fake':
      return new FakePaymentProvider(redis);
  }
}

@Global()
@Module({
  controllers: [PaymentWebhookController],
  providers: [
    {
      provide: PAYMENT_PROVIDER,
      inject: [ENV, REDIS],
      useFactory: paymentProvider,
    },
    LedgerService,
    PaymentsService,
  ],
  exports: [PAYMENT_PROVIDER, LedgerService, PaymentsService],
})
export class PaymentsModule {}
