import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { FakeSmsProvider, SMS_PROVIDER, type SmsProvider } from './sms.provider.js';

@Global()
@Module({
  providers: [
    {
      provide: SMS_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env): SmsProvider => {
        switch (env.SMS_PROVIDER) {
          case 'fake':
            return new FakeSmsProvider();
        }
      },
    },
  ],
  exports: [SMS_PROVIDER],
})
export class SmsModule {}
