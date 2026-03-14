#!/bin/sh
# backup.sh — Dumps the PostgreSQL database to a compressed file.
# Called by crond inside the postgres-backup container on the BACKUP_SCHEDULE.
#
# Output format: pg_dump --format=custom (binary)
#   Restore with: pg_restore -h <host> -U <user> -d <db> <file>
#
# Required env vars: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
# Optional env vars: BACKUP_KEEP_DAYS (default 7), POSTGRES_HOST (default postgres)

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOST="${POSTGRES_HOST:-postgres}"
BACKUP_FILE="${BACKUP_DIR}/pg_${POSTGRES_DB}_${TIMESTAMP}.dump"
LOG_TAG="[backup $(date '+%Y-%m-%d %H:%M:%S')]"

log()  { echo "${LOG_TAG} $*"; }
fail() { echo "${LOG_TAG} ERROR: $*" >&2; exit 1; }

# ─── Validate required variables ──────────────────────────────────────────────
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"

# ─── Wait for PostgreSQL to be available ──────────────────────────────────────
RETRIES=10
until pg_isready -h "${HOST}" -p 5432 -U "${POSTGRES_USER}" -q; do
    RETRIES=$((RETRIES - 1))
    [ "${RETRIES}" -le 0 ] && fail "PostgreSQL did not become ready in time."
    log "Waiting for PostgreSQL at ${HOST}:5432... (${RETRIES} retries left)"
    sleep 5
done

# ─── Dump ─────────────────────────────────────────────────────────────────────
log "Starting backup → ${BACKUP_FILE}"

PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    --host="${HOST}" \
    --port=5432 \
    --username="${POSTGRES_USER}" \
    --dbname="${POSTGRES_DB}" \
    --format=custom \
    --compress=9 \
    --no-password \
    --file="${BACKUP_FILE}" \
    || fail "pg_dump failed — backup aborted."

SIZE=$(du -sh "${BACKUP_FILE}" 2>/dev/null | cut -f1)
log "Backup complete: ${BACKUP_FILE} (${SIZE})"

# ─── Retention ────────────────────────────────────────────────────────────────
KEEP="${BACKUP_KEEP_DAYS:-7}"
log "Applying retention policy: keeping ${KEEP} most recent backups..."

# List all backups oldest-first, skip the newest $KEEP, delete the rest.
BACKUPS_TO_DELETE=$(ls -t "${BACKUP_DIR}"/pg_*.dump 2>/dev/null \
    | tail -n "+$((KEEP + 1))")

if [ -n "${BACKUPS_TO_DELETE}" ]; then
    echo "${BACKUPS_TO_DELETE}" | while IFS= read -r old_file; do
        rm -f "${old_file}"
        log "Deleted old backup: ${old_file}"
    done
else
    log "No old backups to prune."
fi

REMAINING=$(ls "${BACKUP_DIR}"/pg_*.dump 2>/dev/null | wc -l | tr -d ' ')
log "Done. ${REMAINING} backup(s) retained in ${BACKUP_DIR}."
