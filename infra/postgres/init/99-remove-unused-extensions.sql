-- Exécuté après le script de l'image postgis/postgis (10_postgis.sh), à la création du volume.
-- L'image installe des extensions que Tara n'utilise pas. Elles n'apparaissent pas dans
-- l'historique des migrations, et `prisma migrate dev` exigerait alors d'effacer la base.
-- Seule l'extension postgis est conservée ; les migrations la déclarent elles-mêmes.
\connect tara
DROP EXTENSION IF EXISTS postgis_tiger_geocoder CASCADE;
DROP EXTENSION IF EXISTS postgis_topology CASCADE;
DROP EXTENSION IF EXISTS fuzzystrmatch CASCADE;
DROP SCHEMA IF EXISTS tiger CASCADE;
DROP SCHEMA IF EXISTS tiger_data CASCADE;
DROP SCHEMA IF EXISTS topology CASCADE;
