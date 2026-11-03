import { Redis } from 'ioredis';
import { RedisThrottlerStorage } from './redis-throttler.storage.js';

const url = process.env['TEST_REDIS_URL'] ?? 'redis://localhost:6379/1';

describe('limitation de débit partagée (Redis)', () => {
  let redis: Redis;
  let storage: RedisThrottlerStorage;

  beforeAll(async () => {
    redis = new Redis(url, { keyPrefix: 'tara-spec:', lazyConnect: true });
    await redis.connect();
    storage = new RedisThrottlerStorage(redis);
  });
  afterAll(async () => {
    await redis.quit();
  });

  it('compte les requêtes et bloque au-delà de la limite', async () => {
    const key = `cle-${Date.now()}`;
    const first = await storage.increment(key, 60_000, 2, 0, 'default');
    expect(first).toMatchObject({ totalHits: 1, isBlocked: false });
    await storage.increment(key, 60_000, 2, 0, 'default');
    const third = await storage.increment(key, 60_000, 2, 0, 'default');
    expect(third.isBlocked).toBe(true);
    expect(third.timeToBlockExpire).toBeGreaterThan(0);
    expect(third.timeToExpire).toBeLessThanOrEqual(60);
  });

  it('réinitialise le compteur à la fin de la fenêtre', async () => {
    const key = `fenetre-${Date.now()}`;
    await storage.increment(key, 100, 1, 0, 'default');
    await new Promise((resolve) => setTimeout(resolve, 150));
    const after = await storage.increment(key, 100, 1, 0, 'default');
    expect(after).toMatchObject({ totalHits: 1, isBlocked: false });
  });
});
