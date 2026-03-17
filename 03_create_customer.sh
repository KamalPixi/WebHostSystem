#!/bin/bash
# 03_create_customer.sh <id> <domain> <disk_limit> <ram_limit> <ssh_port>

CLIENT_ID=$1
DOMAIN=$2
DISK=$3         # e.g., 5G
RAM=$4          # e.g., 512M
SSH_PORT=$5     # e.g., 2201
HOST_DOMAIN="yourprovider.com"

if [ -z "$SSH_PORT" ]; then echo "Usage: $0 <id> <domain> <disk> <ram> <ssh_port>"; exit 1; fi

BASE_DIR="/home/hosting/customers/$CLIENT_ID"
mkdir -p "$BASE_DIR/www" "$BASE_DIR/db_data" "$BASE_DIR/config/cron"

# 1. SET XFS QUOTA (Assumes /home/hosting is on XFS)
# Generates a unique Project ID for XFS tracking
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
PROJ_ID_FILE="/home/hosting/.projid.next"
if [ -f "$PROJ_ID_FILE" ]; then
  PROJ_ID=$(cat "$PROJ_ID_FILE")
else
  PROJ_ID=1000
fi
echo $((PROJ_ID + 1)) > "$PROJ_ID_FILE"
$SUDO xfs_quota -x -c "project -s -p $BASE_DIR $PROJ_ID" /home/hosting
$SUDO xfs_quota -x -c "limit -p bhard=$DISK $PROJ_ID" /home/hosting

# 2. Generate Random DB Pass
DB_PASS=$(openssl rand -base64 12)
SSH_PASS=$(openssl rand -base64 12)
BASIC_AUTH_USER="${CLIENT_ID}"
BASIC_AUTH_PASS=$(openssl rand -base64 12)
BASIC_AUTH_HASH=$(openssl passwd -apr1 "$BASIC_AUTH_PASS")

# 3. Create Customer .env
cat <<EOF > "$BASE_DIR/.env"
CUSTOMER_ID=$CLIENT_ID
PRIMARY_DOMAIN=$DOMAIN
HOST_DOMAIN=$HOST_DOMAIN
DB_PASSWORD=$DB_PASS
SSH_PASSWORD=$SSH_PASS
BASIC_AUTH=$BASIC_AUTH_USER:$BASIC_AUTH_HASH
RAM_LIMIT=$RAM
APP_CPUS=0.5
DB_RAM_LIMIT=256M
FILES_RAM_LIMIT=128M
PMA_RAM_LIMIT=128M
SSH_RAM_LIMIT=128M
SSH_PORT=$SSH_PORT
DISK_LIMIT=$DISK
EOF

# 4. Deploy (Using the template we discussed previously)
cp /home/hosting/templates/template.yml "$BASE_DIR/docker-compose.yml"
cp /home/hosting/templates/customer.Dockerfile "$BASE_DIR/customer.Dockerfile"
cp /home/hosting/templates/nginx-provider.conf "$BASE_DIR/nginx-provider.conf"
cp /home/hosting/templates/supervisord.conf "$BASE_DIR/supervisord.conf"
cd "$BASE_DIR" && docker compose --project-name "$CLIENT_ID" up -d

echo "✅ Customer $CLIENT_ID is LIVE."
echo "SSH access: ssh customer@your-ip -p $SSH_PORT"
echo "File Manager: https://files.$CLIENT_ID.$HOST_DOMAIN"
echo "phpMyAdmin:   https://pma.$CLIENT_ID.$HOST_DOMAIN"
echo "Panel user:   $BASIC_AUTH_USER"
echo "Panel pass:   $BASIC_AUTH_PASS"
