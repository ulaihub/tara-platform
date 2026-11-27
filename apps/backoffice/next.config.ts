import { fileURLToPath } from 'node:url';
import type { NextConfig } from 'next';

const config: NextConfig = {
  // Image Docker autonome (phase 7) : le serveur et ses seules dépendances.
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  // Le monorepo : les fichiers suivis remontent jusqu'à sa racine. fileURLToPath : chemin
  // valable aussi sous Windows (`.pathname` donnerait « /C:/… », refusé par Next.js).
  outputFileTracingRoot: fileURLToPath(new URL('../..', import.meta.url)),
};

export default config;
