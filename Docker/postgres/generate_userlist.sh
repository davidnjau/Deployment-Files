#!/bin/sh
# generate_userlist.sh — PgBouncer container entrypoint.
#
# 1. Writes /etc/pgbouncer/userlist.txt from environment variables.
# 2. Starts pgbouncer.
#
# userlist.txt contains ONLY the auth_user's credentials.
# All other users are verified dynamically via auth_query → pgbouncer.get_auth().
#
# Why plaintext in userlist.txt?
#   PgBouncer uses the plaintext password to participate in SCRAM-SHA-256
#   authentication with PostgreSQL. The file is chmod 600 and generated
#   at runtime — it is never written to disk or committed to version control.
#
# Standalone dry-run (for debugging):
#   PGBOUNCER_AUTH_USER=pgbouncer PGBOUNCER_AUTH_PASSWORD=secret \
#     ./generate_userlist.sh --dry-run

set -e

: "${PGBOUNCER_AUTH_USER:?PGBOUNCER_AUTH_USER env var is required}"
: "${PGBOUNCER_AUTH_PASSWORD:?PGBOUNCER_AUTH_PASSWORD env var is required}"

USERLIST="/etc/pgbouncer/userlist.txt"

if [ "${1:-}" = "--dry-run" ]; then
    printf 'Would write to %s:\n' "${USERLIST}"
    printf '"%s" "%s"\n' "${PGBOUNCER_AUTH_USER}" "***"
    exit 0
fi

# Write the auth_user entry. Format: "username" "password"
# PgBouncer accepts plaintext, md5, or SCRAM verifier strings here.
printf '"%s" "%s"\n' "${PGBOUNCER_AUTH_USER}" "${PGBOUNCER_AUTH_PASSWORD}" \
    > "${USERLIST}"
chmod 600 "${USERLIST}"

echo "[pgbouncer-entrypoint] userlist.txt written (auth_user: ${PGBOUNCER_AUTH_USER})"
echo "[pgbouncer-entrypoint] starting pgbouncer..."

exec pgbouncer /etc/pgbouncer/pgbouncer.ini "$@"
