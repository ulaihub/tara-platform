-- Exécuté une seule fois, à la création du volume PostgreSQL.
-- Base « fantôme » utilisée par `prisma migrate dev` pour détecter les écarts de schéma.
CREATE DATABASE tara_shadow OWNER tara;
\connect tara_shadow
CREATE EXTENSION IF NOT EXISTS postgis;
