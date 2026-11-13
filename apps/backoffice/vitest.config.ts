import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      '@tara-map': fileURLToPath(new URL('../../packages/tara_map/assets', import.meta.url)),
      // Les modules serveur s'importent tels quels dans les tests.
      'server-only': fileURLToPath(new URL('./test/server-only.ts', import.meta.url)),
    },
  },
  test: { include: ['test/**/*.test.ts', 'test/**/*.test.tsx'] },
});
