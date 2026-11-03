import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { defineConfig } from 'vitest/config';

// Tests d'intégration contre une vraie base PostgreSQL + PostGIS migrée.
// Prérequis : DATABASE_URL défini (fichier .env ou variable) et `pnpm db:deploy` exécuté.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['test/**/*.db-spec.ts'],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 30_000,
    env: {
      NODE_ENV: 'test',
      JWT_SECRET: 'test-jwt-secret-0123456789abcdef0123456789',
      CODE_HASH_SECRET: 'test-code-secret-0123456789abcdef012345678',
      STORAGE_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString('base64'),
      STORAGE_DRIVER: 'local',
      STORAGE_LOCAL_DIR: join(tmpdir(), 'tara-test-storage'),
      SMS_PROVIDER: 'fake',
      JOBS_ENABLED: 'false',
      PUBLIC_WEB_URL: 'https://tara.test',
      OSRM_URL: '',
    },
  },
});
