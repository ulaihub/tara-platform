import { Global, Inject, Injectable, Module, type OnApplicationShutdown } from '@nestjs/common';
import { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { QueueService } from './queue.service.js';
import { REDIS, REDIS_KEY_PREFIX } from './redis.constants.js';
import { RedisThrottlerStorage } from './redis-throttler.storage.js';

@Injectable()
class RedisShutdown implements OnApplicationShutdown {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async onApplicationShutdown(): Promise<void> {
    await this.redis.quit().catch(() => undefined);
  }
}

@Global()
@Module({
  providers: [
    {
      provide: REDIS,
      inject: [ENV],
      // Connexion à la première commande : la génération de l'OpenAPI n'a pas besoin de Redis.
      useFactory: (env: Env): Redis =>
        new Redis(env.REDIS_URL, {
          keyPrefix: REDIS_KEY_PREFIX,
          lazyConnect: true,
          maxRetriesPerRequest: 3,
        }),
    },
    RedisShutdown,
    QueueService,
    RedisThrottlerStorage,
  ],
  exports: [REDIS, QueueService, RedisThrottlerStorage],
})
export class RedisModule {}
