import { Global, Module } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { REDIS } from '../redis/redis.constants.js';
import { OrangeSmsProvider } from './orange-sms.provider.js';
import { FailoverSmsProvider, MeteredSmsProvider } from './resilient-sms.provider.js';
import { FakeSmsProvider, SMS_PROVIDER, type SmsProvider } from './sms.provider.js';
import { TwilioSmsProvider } from './twilio-sms.provider.js';

function build(name: 'orange' | 'twilio', env: Env): SmsProvider {
  if (name === 'orange') {
    return new OrangeSmsProvider({
      clientId: env.ORANGE_SMS_CLIENT_ID ?? '',
      clientSecret: env.ORANGE_SMS_CLIENT_SECRET ?? '',
      senderPhone: env.ORANGE_SMS_SENDER_PHONE ?? '',
      senderName: env.ORANGE_SMS_SENDER_NAME,
    });
  }
  return new TwilioSmsProvider({
    accountSid: env.TWILIO_ACCOUNT_SID ?? '',
    authToken: env.TWILIO_AUTH_TOKEN ?? '',
    from: env.TWILIO_FROM ?? '',
  });
}

@Global()
@Module({
  providers: [
    {
      provide: SMS_PROVIDER,
      inject: [ENV, REDIS, RealtimeService],
      useFactory: (env: Env, redis: Redis, realtime: RealtimeService): SmsProvider => {
        if (env.SMS_PROVIDER === 'fake') return new FakeSmsProvider();
        const chain = [build(env.SMS_PROVIDER, env)];
        if (env.SMS_FALLBACK_PROVIDER !== 'none') chain.push(build(env.SMS_FALLBACK_PROVIDER, env));
        return new MeteredSmsProvider(
          new FailoverSmsProvider(chain),
          redis,
          env.SMS_DAILY_ALERT_COUNT,
          (level, count, limit) => {
            realtime.toOps('ops.sms-volume', { level, count, limit, at: new Date().toISOString() });
          },
        );
      },
    },
  ],
  exports: [SMS_PROVIDER],
})
export class SmsModule {}
