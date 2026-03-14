#!/bin/sh
# backup-entrypoint.sh — Configures crond and runs it in the foreground.
# Used as the entrypoint for the postgres-backup container.
#
# BACKUP_SCHEDULE defaults to "0 2 * * *" (daily at 02:00 UTC).
# Override in .env: BACKUP_SCHEDULE=*/30 * * * *   (every 30 minutes)

set -e

SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"
LOG_DIR="/var/log/backup"
LOG_FILE="${LOG_DIR}/backup.log"

mkdir -p "${LOG_DIR}" /backups

# Write the crontab for root.
# BusyBox crond reads /etc/crontabs/root.
printf '%s /bin/sh /scripts/backup.sh >> %s 2>&1\n' \
    "${SCHEDULE}" "${LOG_FILE}" \
    > /etc/crontabs/root

echo "[backup-entrypoint] Schedule   : ${SCHEDULE}"
echo "[backup-entrypoint] Log file   : ${LOG_FILE}"
echo "[backup-entrypoint] Backup dir : /backups"
echo "[backup-entrypoint] Starting crond..."

# -f  run in foreground (required for Docker)
# -d 6  log level: notice and above (visible via docker logs)
exec crond -f -d 6
