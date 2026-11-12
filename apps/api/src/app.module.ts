import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuditModule } from './audit/audit.module.js';
import { AuthGuard } from './auth/auth.guard.js';
import { AuthModule } from './auth/auth.module.js';
import { UserAwareThrottlerGuard } from './auth/user-aware-throttler.guard.js';
import { AppExceptionFilter } from './common/errors/app-exception.filter.js';
import { ConfigModule, ENV } from './config/config.module.js';
import type { Env } from './config/env.js';
import { EventsModule } from './events/events.module.js';
import { FinanceModule } from './finance/finance.module.js';
import { GeoModule } from './geo/geo.module.js';
import { HealthModule } from './health/health.module.js';
import { LegalModule } from './legal/legal.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { OpsModule } from './ops/ops.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { PricingModule } from './pricing/pricing.module.js';
import { PrivacyModule } from './privacy/privacy.module.js';
import { PublicTrackingModule } from './public-tracking/public-tracking.module.js';
import { PaymentsModule } from './payments/payments.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { RealtimeModule } from './realtime/realtime.module.js';
import { RedisModule } from './redis/redis.module.js';
import { RedisThrottlerStorage } from './redis/redis-throttler.storage.js';
import { RiderAppModule } from './rider-app/rider-app.module.js';
import { SupportModule } from './support/support.module.js';
import { RidersModule } from './riders/riders.module.js';
import { SmsModule } from './sms/sms.module.js';
import { ParcelAnalysisModule } from './parcel-analysis/parcel-analysis.module.js';
import { StorageModule } from './storage/storage.module.js';
import { UsersModule } from './users/users.module.js';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    RedisModule,
    ThrottlerModule.forRootAsync({
      inject: [ENV, RedisThrottlerStorage],
      useFactory: (env: Env, storage: RedisThrottlerStorage) => ({
        throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
        // Compteurs partagés entre les instances de l'API.
        storage,
        skipIf: () => env.NODE_ENV === 'test',
      }),
    }),
    ScheduleModule.forRoot(),
    EventsModule,
    RealtimeModule,
    AuditModule,
    SmsModule,
    NotificationsModule,
    PaymentsModule,
    StorageModule,
    AuthModule,
    HealthModule,
    LegalModule,
    UsersModule,
    RidersModule,
    GeoModule,
    PricingModule,
    OrdersModule,
    ParcelAnalysisModule,
    PublicTrackingModule,
    RiderAppModule,
    FinanceModule,
    PrivacyModule,
    OpsModule,
    SupportModule,
  ],
  providers: [
    { provide: APP_FILTER, useClass: AppExceptionFilter },
    // Ordre important : l'authentification d'abord, pour limiter le débit par compte.
    { provide: APP_GUARD, useExisting: AuthGuard },
    { provide: APP_GUARD, useExisting: UserAwareThrottlerGuard },
  ],
})
export class AppModule {}
