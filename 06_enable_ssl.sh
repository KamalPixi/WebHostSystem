#!/bin/bash
# 06_enable_ssl.sh <customer_id> <email>

set -euo pipefail

CLIENT_ID="${1:-}"
EMAIL="${2:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <customer_id> <email>"
  exit 1
fi

GW_DIR="/home/hosting/gateway"
GW_FILE="$GW_DIR/docker-compose.yml"
ACME_FILE="$GW_DIR/acme.json"

if [ ! -f "$GW_FILE" ]; then
  echo "Gateway compose not found: $GW_FILE"
  exit 1
fi

mkdir -p "$GW_DIR"
touch "$ACME_FILE"
chmod 600 "$ACME_FILE"

insert_after() {
  local pattern="$1"
  local newline="$2"
  local file="$3"
  if grep -qF "$newline" "$file"; then
    return
  fi
  awk -v pat="$pattern" -v ins="$newline" '{
    print
    if ($0 ~ pat) {
      print ins
    }
  }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Enable HTTPS entrypoint and ACME on Traefik
insert_after '--entrypoints.web.address=:80' '      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"' "$GW_FILE"
insert_after '--entrypoints.web.address=:80' '      - "--entrypoints.websecure.address=:443"' "$GW_FILE"
insert_after '--entrypoints.web.address=:80' '      - "--entrypoints.websecure.http.tls=true"' "$GW_FILE"
insert_after '--entrypoints.web.address=:80' '      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"' "$GW_FILE"

if grep -q 'certificatesresolvers.myresolver.acme.email' "$GW_FILE"; then
  sed -i "s|--certificatesresolvers.myresolver.acme.email=.*|--certificatesresolvers.myresolver.acme.email=${EMAIL}|" "$GW_FILE"
else
  insert_after 'certificatesresolvers.myresolver.acme.tlschallenge' "      - \"--certificatesresolvers.myresolver.acme.email=${EMAIL}\"" "$GW_FILE"
fi

insert_after 'certificatesresolvers.myresolver.acme.email' '      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"' "$GW_FILE"

if ! grep -q '"443:443"' "$GW_FILE"; then
  insert_after '"80:80"' '      - "443:443"' "$GW_FILE"
fi

if ! grep -q '/letsencrypt/acme.json' "$GW_FILE"; then
  insert_after '/var/run/docker.sock' '      - "./acme.json:/letsencrypt/acme.json"' "$GW_FILE"
fi

cd "$GW_DIR" && docker compose up -d

# Enable HTTPS for the specific customer
BASE_DIR="/home/hosting/customers/$CLIENT_ID"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Customer compose not found: $COMPOSE_FILE"
  exit 1
fi

sed -i "s/routers.${CLIENT_ID}.entrypoints=web/routers.${CLIENT_ID}.entrypoints=websecure/" "$COMPOSE_FILE"
sed -i "s/routers.${CLIENT_ID}_files.entrypoints=web/routers.${CLIENT_ID}_files.entrypoints=websecure/" "$COMPOSE_FILE"
sed -i "s/routers.${CLIENT_ID}_pma.entrypoints=web/routers.${CLIENT_ID}_pma.entrypoints=websecure/" "$COMPOSE_FILE"

if ! grep -q "routers.${CLIENT_ID}.tls.certresolver" "$COMPOSE_FILE"; then
  insert_after "routers.${CLIENT_ID}.entrypoints=websecure" "      - \"traefik.http.routers.${CLIENT_ID}.tls.certresolver=myresolver\"" "$COMPOSE_FILE"
fi
if ! grep -q "routers.${CLIENT_ID}_files.tls.certresolver" "$COMPOSE_FILE"; then
  insert_after "routers.${CLIENT_ID}_files.entrypoints=websecure" "      - \"traefik.http.routers.${CLIENT_ID}_files.tls.certresolver=myresolver\"" "$COMPOSE_FILE"
fi
if ! grep -q "routers.${CLIENT_ID}_pma.tls.certresolver" "$COMPOSE_FILE"; then
  insert_after "routers.${CLIENT_ID}_pma.entrypoints=websecure" "      - \"traefik.http.routers.${CLIENT_ID}_pma.tls.certresolver=myresolver\"" "$COMPOSE_FILE"
fi

cd "$BASE_DIR" && docker compose --project-name "$CLIENT_ID" up -d

echo "✅ SSL enabled for $CLIENT_ID"
