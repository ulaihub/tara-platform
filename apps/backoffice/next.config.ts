import type { NextConfig } from 'next';

const config: NextConfig = {
  // Image Docker autonome (phase 7) : le serveur et ses seules dépendances.
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  // Le monorepo : les fichiers suivis remontent jusqu'à sa racine.
  outputFileTracingRoot: new URL('../..', import.meta.url).pathname,
};

export default config;
