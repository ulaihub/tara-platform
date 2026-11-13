# Images de production de Tara (phase 7), construites depuis la racine du dépôt :
#
#   docker build --target api        -t tara-api .
#   docker build --target migrate    -t tara-migrate .     (migrations et données de départ)
#   docker build --target backoffice -t tara-backoffice .
#   docker build --target tracking   -t tara-tracking .
#
# Utilisées par infra/production/docker-compose.yml. Chaque image ne contient que son service
# et ses dépendances de production, et tourne sans droits d'administrateur (utilisateur node).

FROM node:22-bookworm-slim AS base
ENV PNPM_HOME=/pnpm PATH=/pnpm:$PATH CI=true NEXT_TELEMETRY_DISABLED=1
RUN corepack enable && corepack prepare pnpm@10.28.0 --activate
WORKDIR /repo

# --- Dépendances (couche en cache tant que les manifestes ne changent pas) ------------------
FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/
COPY apps/backoffice/package.json apps/backoffice/
COPY apps/tracking/package.json apps/tracking/
RUN pnpm install --frozen-lockfile --filter @tara/api... --filter @tara/backoffice... --filter @tara/tracking...

# --- Construction ---------------------------------------------------------------------------
FROM deps AS build
COPY apps/api apps/api
COPY apps/backoffice apps/backoffice
COPY apps/tracking apps/tracking
COPY packages/tara_map/assets packages/tara_map/assets
COPY infra/postgres/roles.sql infra/postgres/roles.sql
RUN pnpm --filter @tara/api generate \
 && pnpm --filter @tara/api build \
 && pnpm --filter @tara/tracking build \
 && pnpm --filter @tara/backoffice build
RUN pnpm --filter @tara/api deploy --prod --legacy /out/api \
 && cp -r apps/api/dist /out/api/dist \
 && pnpm --filter @tara/tracking deploy --prod --legacy /out/tracking \
 && cp -r apps/tracking/dist /out/tracking/dist

# --- API ------------------------------------------------------------------------------------
FROM node:22-bookworm-slim AS api
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /out/api ./
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]

# --- Migrations et données de départ (lancé à chaque mise à jour, voir migrate.sh) ---------
FROM build AS migrate
WORKDIR /repo/apps/api
COPY infra/production/migrate.sh /usr/local/bin/tara-migrate
CMD ["tara-migrate"]

# --- Back-office (Next.js autonome) ---------------------------------------------------------
FROM node:22-bookworm-slim AS backoffice
ENV NODE_ENV=production PORT=3100 HOSTNAME=0.0.0.0 NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=build --chown=node:node /repo/apps/backoffice/.next/standalone ./
COPY --from=build --chown=node:node /repo/apps/backoffice/.next/static ./apps/backoffice/.next/static
COPY --from=build --chown=node:node /repo/apps/backoffice/public ./apps/backoffice/public
USER node
EXPOSE 3100
CMD ["node", "apps/backoffice/server.js"]

# --- Page de suivi et lien de localisation --------------------------------------------------
FROM node:22-bookworm-slim AS tracking
ENV NODE_ENV=production PORT=3001
WORKDIR /app
COPY --from=build --chown=node:node /out/tracking ./
USER node
EXPOSE 3001
CMD ["node", "dist/server.js"]
