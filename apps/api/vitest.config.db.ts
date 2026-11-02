import { defineConfig } from 'vitest/config';

// Tests d'intégration contre une vraie base PostgreSQL + PostGIS migrée.
// Prérequis : DATABASE_URL défini et `pnpm db:deploy` exécuté.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['test/**/*.db-spec.ts'],
    fileParallelism: false,
    testTimeout: 20_000,
  },
});
