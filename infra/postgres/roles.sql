-- =============================================================================
-- Comptes PostgreSQL à moindre privilège (production, préproduction et CI).
--
--   tara_migrator : propriétaire des tables ; sert UNIQUEMENT aux migrations.
--   tara_app      : compte de l'API ; lit et écrit les données, sans pouvoir modifier la
--                   structure, désactiver les triggers de protection, ni modifier ou
--                   supprimer le grand livre, l'historique des commandes et l'audit.
--
-- À exécuter avec un compte administrateur, AVANT et APRÈS chaque `prisma migrate deploy`
-- (le second passage applique les droits aux tables créées par la migration) :
--
--   psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 \
--        -v app_password="$APP_DB_PASSWORD" -v migrator_password="$MIGRATOR_DB_PASSWORD" \
--        -f infra/postgres/roles.sql
--
-- Idempotent : peut être rejoué sans risque.
-- =============================================================================

SELECT 'CREATE ROLE tara_migrator'
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tara_migrator') \gexec
SELECT 'CREATE ROLE tara_app'
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tara_app') \gexec

ALTER ROLE tara_migrator WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD :'migrator_password';
ALTER ROLE tara_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD :'app_password';

-- Les extensions ne peuvent être créées que par l'administrateur.
CREATE EXTENSION IF NOT EXISTS postgis;

SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO tara_migrator, tara_app', current_database()) \gexec

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO tara_migrator;
GRANT USAGE ON SCHEMA public TO tara_app;

-- Tables créées plus tard par les migrations : droits de données pour l'API.
ALTER DEFAULT PRIVILEGES FOR ROLE tara_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tara_app;
ALTER DEFAULT PRIVILEGES FOR ROLE tara_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO tara_app;

-- Tables existantes : mêmes droits, puis retraits ciblés.
DO $$
DECLARE
  t text;
BEGIN
  EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tara_app';

  -- Historique des migrations : réservé au migrateur.
  IF to_regclass('public._prisma_migrations') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON public._prisma_migrations FROM tara_app';
  END IF;
  -- Table de référence de PostGIS : lecture seule.
  IF to_regclass('public.spatial_ref_sys') IS NOT NULL THEN
    EXECUTE 'REVOKE INSERT, UPDATE, DELETE ON public.spatial_ref_sys FROM tara_app';
  END IF;
  -- Tables en ajout seul : le trigger l'interdit déjà, le droit l'interdit aussi.
  FOREACH t IN ARRAY ARRAY['journal_entries', 'ledger_postings', 'order_events', 'audit_logs'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE ON public.%I FROM tara_app', t);
    END IF;
  END LOOP;
END $$;
