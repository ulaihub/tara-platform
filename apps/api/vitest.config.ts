import { defineConfig } from 'vitest/config';

// Tests unitaires : aucun accès réseau ni base de données.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['src/**/*.spec.ts'],
  },
});
