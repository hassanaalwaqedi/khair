#!/bin/bash
# ─── Khair Database Backup Script ─────────────────
# Run daily via cron: 0 2 * * * /opt/khair/scripts/backup-db.sh
#
# Prerequisites: pg_dump, gzip, rclone (optional for cloud storage)

set -euo pipefail

# ─── Configuration ────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/opt/khair/backups}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-khair}"
DB_NAME="${DB_NAME:-khair}"
MAX_BACKUPS="${MAX_BACKUPS:-30}"  # Keep 30 days of backups
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

# ─── Setup ────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
echo "[$(date)] Starting backup of ${DB_NAME}..."

# ─── Dump & Compress ─────────────────────────────
if docker ps --format '{{.Names}}' | grep -q khair-postgres; then
    # Running in Docker — use docker exec
    docker exec khair-postgres pg_dump \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=custom \
        --compress=9 \
        --verbose \
        2>/dev/null | gzip > "$BACKUP_FILE"
else
    # Running directly
    PGPASSWORD="${DB_PASSWORD}" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=custom \
        --compress=9 \
        --verbose \
        2>/dev/null | gzip > "$BACKUP_FILE"
fi

# ─── Verify ──────────────────────────────────────
BACKUP_SIZE=$(stat --format="%s" "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE" 2>/dev/null)
if [ "$BACKUP_SIZE" -lt 100 ]; then
    echo "[$(date)] ERROR: Backup file is too small (${BACKUP_SIZE} bytes), likely failed"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "[$(date)] Backup created: ${BACKUP_FILE} ($(numfmt --to=iec $BACKUP_SIZE 2>/dev/null || echo "${BACKUP_SIZE} bytes"))"

# ─── Rotate Old Backups ──────────────────────────
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}/${DB_NAME}_"*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    echo "[$(date)] Removing ${DELETE_COUNT} old backups..."
    ls -1t "${BACKUP_DIR}/${DB_NAME}_"*.sql.gz | tail -n "$DELETE_COUNT" | xargs rm -f
fi

# ─── Optional: Upload to Cloud ───────────────────
# Uncomment and configure rclone for off-site backups:
# rclone copy "$BACKUP_FILE" remote:khair-backups/ --progress

echo "[$(date)] Backup complete. Total backups: $(ls -1 "${BACKUP_DIR}/${DB_NAME}_"*.sql.gz 2>/dev/null | wc -l)"
