-- Postgres extensions required by ITT-Rehber.
-- Loaded by Postgres container on first boot via /docker-entrypoint-initdb.d/.
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
