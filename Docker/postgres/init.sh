#!/bin/bash
# init.sh — Runs once during the first container start via docker-entrypoint-initdb.d.
# Creates the PgBouncer authentication user and the lookup function it uses.
#
# Required environment variables (passed from compose):
#   PGBOUNCER_AUTH_USER      — username for PgBouncer's auth connection to PostgreSQL
#   PGBOUNCER_AUTH_PASSWORD  — password for that user

set -e

: "${PGBOUNCER_AUTH_USER:?PGBOUNCER_AUTH_USER is required}"
: "${PGBOUNCER_AUTH_PASSWORD:?PGBOUNCER_AUTH_PASSWORD is required}"

echo "==> [init] Setting up PgBouncer auth user and lookup function..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-SQL

  -- ── PgBouncer auth user ────────────────────────────────────────────────────
  -- This user's only job is to run auth_query. It has no data access.
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PGBOUNCER_AUTH_USER}') THEN
      CREATE ROLE "${PGBOUNCER_AUTH_USER}" WITH LOGIN PASSWORD '${PGBOUNCER_AUTH_PASSWORD}';
      RAISE NOTICE 'Created PgBouncer auth role: ${PGBOUNCER_AUTH_USER}';
    ELSE
      -- Rotate the password in case it changed in .env / Vault
      ALTER ROLE "${PGBOUNCER_AUTH_USER}" WITH PASSWORD '${PGBOUNCER_AUTH_PASSWORD}';
      RAISE NOTICE 'Updated password for existing role: ${PGBOUNCER_AUTH_USER}';
    END IF;
  END
  \$\$;

  -- ── Isolated schema for PgBouncer helpers ─────────────────────────────────
  CREATE SCHEMA IF NOT EXISTS pgbouncer;

  -- ── Password lookup function ───────────────────────────────────────────────
  -- SECURITY DEFINER: executes with the privileges of the function owner
  -- (superuser), so the non-superuser pgbouncer role can read pg_shadow.
  CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename TEXT)
    RETURNS TABLE(username TEXT, password TEXT)
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = pg_catalog AS
  \$func\$
  BEGIN
    RETURN QUERY
      SELECT usename::TEXT, passwd::TEXT
      FROM   pg_catalog.pg_shadow
      WHERE  usename = p_usename;
  END;
  \$func\$;

  -- ── Minimal permissions ────────────────────────────────────────────────────
  GRANT USAGE  ON SCHEMA   pgbouncer                    TO "${PGBOUNCER_AUTH_USER}";
  GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(TEXT)    TO "${PGBOUNCER_AUTH_USER}";

SQL

echo "==> [init] PgBouncer auth setup complete."
