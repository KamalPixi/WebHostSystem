#!/bin/bash
# 02_setup_host.sh

# 1. Create Shared Docker Network
docker network inspect web-proxy >/dev/null 2>&1 || docker network create web-proxy

# 2. Setup Traefik Directory
mkdir -p /home/hosting/gateway
touch /home/hosting/gateway/acme.json
chmod 600 /home/hosting/gateway/acme.json

# 3. Create Traefik Master Config
cat <<EOF > /home/hosting/gateway/docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik-master
    restart: always
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=web-proxy"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.address=:80"
      - "--accesslog=true"
      - "--log.level=INFO"
    ports:
      - "80:80"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./acme.json:/letsencrypt/acme.json"
    networks:
      - web-proxy
networks:
  web-proxy:
    external: true
EOF

cd /home/hosting/gateway && docker compose up -d
echo "✅ Traefik Gateway is running."
