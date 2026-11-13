#!/usr/bin/env bash
# Migrations et données de départ, par le compte propriétaire (tara_migrator). Lancé par
# `tara update` entre deux passages de infra/postgres/roles.sql (service db-roles) : le
# premier crée les comptes, le second donne les droits sur les tables nouvelles.
set -euo pipefail
: "${MIGRATOR_DB_PASSWORD:?}"
export MIGRATION_DATABASE_URL="postgresql://tara_migrator:${MIGRATOR_DB_PASSWORD}@postgres:5432/tara"
if [[ -n "${S3_ENDPOINT:-}" ]]; then
  echo "Compartiment des fichiers"
  node --input-type=module -e '
    import { CreateBucketCommand, HeadBucketCommand, S3Client } from "@aws-sdk/client-s3";
    const s3 = new S3Client({
      endpoint: process.env.S3_ENDPOINT, region: "us-east-1", forcePathStyle: true,
      credentials: { accessKeyId: process.env.S3_ACCESS_KEY_ID, secretAccessKey: process.env.S3_SECRET_ACCESS_KEY },
    });
    const Bucket = process.env.S3_BUCKET;
    try { await s3.send(new HeadBucketCommand({ Bucket })); console.log(`${Bucket} : déjà présent`); }
    catch { await s3.send(new CreateBucketCommand({ Bucket })); console.log(`${Bucket} : créé`); }
  '
fi
echo "Migrations"
pnpm exec prisma migrate deploy
echo "Données de départ (zone de Douala, grilles de prix, offre de bienvenue, administrateur)"
DATABASE_URL="$MIGRATION_DATABASE_URL" pnpm exec tsx prisma/seed.ts
