#!/bin/bash
# 04_backup_customers.sh [customer_id]

set -euo pipefail

TARGET_ID="${1:-}"
BASE_ROOT="/home/hosting/customers"
BACKUP_ROOT="/home/hosting/backups"
DATE="$(date +%F)"

mkdir -p "$BACKUP_ROOT"

for BASE_DIR in "$BASE_ROOT"/*; do
  [ -d "$BASE_DIR" ] || continue
  [ -f "$BASE_DIR/.env" ] || continue

  set -a
  . "$BASE_DIR/.env"
  set +a

  if [ -n "$TARGET_ID" ] && [ "$TARGET_ID" != "$CUSTOMER_ID" ]; then
    continue
  fi

  DEST_DIR="$BACKUP_ROOT/$CUSTOMER_ID/$DATE"
  mkdir -p "$DEST_DIR"

  tar -czf "$DEST_DIR/files.tar.gz" -C "$BASE_DIR" www
  cp "$BASE_DIR/filebrowser.db" "$DEST_DIR/filebrowser.db" 2>/dev/null || true

  docker exec "${CUSTOMER_ID}_db" sh -c "mysqldump -uroot -p${DB_PASSWORD} --databases main_db" > "$DEST_DIR/db.sql"

  find "$BACKUP_ROOT/$CUSTOMER_ID" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; || true
done

echo "✅ Backup complete: $DATE"
