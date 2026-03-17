#!/bin/bash
# 05_restore_customer.sh <customer_id> <date YYYY-MM-DD>

set -euo pipefail

CLIENT_ID="${1:-}"
RESTORE_DATE="${2:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$RESTORE_DATE" ]; then
  echo "Usage: $0 <customer_id> <date YYYY-MM-DD>"
  exit 1
fi

BASE_DIR="/home/hosting/customers/$CLIENT_ID"
BACKUP_DIR="/home/hosting/backups/$CLIENT_ID/$RESTORE_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup not found: $BACKUP_DIR"
  exit 1
fi

set -a
. "$BASE_DIR/.env"
set +a

cd "$BASE_DIR"
docker compose --project-name "$CLIENT_ID" down

rm -rf "$BASE_DIR/www"
tar -xzf "$BACKUP_DIR/files.tar.gz" -C "$BASE_DIR"
if [ -f "$BACKUP_DIR/filebrowser.db" ]; then
  cp "$BACKUP_DIR/filebrowser.db" "$BASE_DIR/filebrowser.db"
fi

docker compose --project-name "$CLIENT_ID" up -d db
sleep 5
cat "$BACKUP_DIR/db.sql" | docker exec -i "${CLIENT_ID}_db" sh -c "mysql -uroot -p${DB_PASSWORD}"

docker compose --project-name "$CLIENT_ID" up -d

echo "✅ Restore complete for $CLIENT_ID ($RESTORE_DATE)"
