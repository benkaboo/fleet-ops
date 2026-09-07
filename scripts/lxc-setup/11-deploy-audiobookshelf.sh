#!/usr/bin/env bash
# ==============================================================================
# Step 5.2: Deploy Audiobookshelf in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
AUDIOBOOK_PORT="13378"
ROOT_DOMAIN="192.168.68.175.nip.io"
AUDIOBOOK_DOMAIN="audiobooks.${ROOT_DOMAIN}"

echo "======================================================================"
echo "    Step 5.2: Deploy Audiobookshelf in LXC $VMID"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running. Current status: '$STATUS'."
    exit 1
fi

if ! pct exec "$VMID" -- which docker &>/dev/null; then
    echo "[!] Error: Docker is not installed in container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- docker network ls --format "{{.Name}}" | grep -qx "gateway_net"; then
    echo "[!] Error: Network 'gateway_net' not found in container $VMID."
    exit 1
fi

# If previous audiobookshelf container exists, remove it so it frees port 13378
pct exec "$VMID" -- docker rm -f audiobookshelf 2>/dev/null || true

if pct exec "$VMID" -- ss -tuln | grep -q ":${AUDIOBOOK_PORT} "; then
    echo "[!] Error: Port $AUDIOBOOK_PORT is already in use by another service inside container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- test -d "/mnt/simba"; then
    echo "[!] Error: Storage mount '/mnt/simba' not found in container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Provision Storage, Stack & Configure Caddy
# ------------------------------------------------------------------------------
echo "[*] Ensuring Audiobooks and Podcasts directories exist on Btrfs storage..."
HOST_MEDIA_DIR="/mnt/data/@simba/Media"
if [[ ! -d "$HOST_MEDIA_DIR" && -d "/mnt/simba/Media" ]]; then
    HOST_MEDIA_DIR="/mnt/simba/Media"
fi

mkdir -p "$HOST_MEDIA_DIR/Audiobooks" "$HOST_MEDIA_DIR/Podcasts"
chown -R 1000:1000 "$HOST_MEDIA_DIR/Audiobooks" "$HOST_MEDIA_DIR/Podcasts"
chmod -R 777 "$HOST_MEDIA_DIR/Audiobooks" "$HOST_MEDIA_DIR/Podcasts"

echo "[*] Creating Audiobookshelf state directories on SSD..."
pct exec "$VMID" -- mkdir -p /opt/stacks/audiobookshelf/config /opt/stacks/audiobookshelf/metadata
pct exec "$VMID" -- chown -R 1000:1000 /opt/stacks/audiobookshelf

echo "[*] Generating /opt/stacks/audiobookshelf/compose.yaml..."
pct exec "$VMID" -- bash -c "cat << 'COMPEOF' > /opt/stacks/audiobookshelf/compose.yaml
services:
  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    restart: unless-stopped
    ports:
      - \"${AUDIOBOOK_PORT}:80\"
    environment:
      - AUDIOBOOKSHELF_UID=1000
      - AUDIOBOOKSHELF_GID=1000
      - TZ=Australia/Sydney
    volumes:
      - /mnt/simba/Media/Audiobooks:/audiobooks
      - /mnt/simba/Media/Podcasts:/podcasts
      - /opt/stacks/audiobookshelf/config:/config
      - /opt/stacks/audiobookshelf/metadata:/metadata
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF"

echo "[*] Starting Audiobookshelf container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/audiobookshelf/compose.yaml up -d

echo "[*] Adding Audiobookshelf route to Caddyfile..."
pct exec "$VMID" -- bash -c "
CADDYFILE='/opt/stacks/caddy/Caddyfile'
if ! grep -q '${AUDIOBOOK_DOMAIN}' \"\$CADDYFILE\"; then
    cat << 'CADEOF' >> \"\$CADDYFILE\"

# Audiobookshelf Server (Native Authentication for iOS & Android Mobile Apps)
${AUDIOBOOK_DOMAIN}, audiobooks.dixon.home {
    tls internal
    reverse_proxy audiobookshelf:80
}
CADEOF
fi
"

echo "[*] Validating updated Caddyfile..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to load Audiobookshelf route..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for Audiobookshelf to initialize (5s)..."
sleep 5

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

AUDIOBOOK_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' audiobookshelf 2>/dev/null || echo "not running")
if [[ "$AUDIOBOOK_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Audiobookshelf container status is '$AUDIOBOOK_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs audiobookshelf --tail 30
    exit 2
fi

echo "[*] Testing Audiobookshelf port ${AUDIOBOOK_PORT} inside container..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${AUDIOBOOK_PORT}/" || echo "000")
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "[!] Validation Warning: Audiobookshelf HTTP response code is '$HTTP_CODE'."
else
    echo "[+] Audiobookshelf responded with HTTP $HTTP_CODE."
fi

echo ""
echo "======================================================================"
echo "    Audiobookshelf Deployment Completed Successfully!"
echo "======================================================================"
echo "Access Details:"
echo "  * HTTPS URL:      https://${AUDIOBOOK_DOMAIN}"
echo "  * Direct Port:    http://192.168.68.175:${AUDIOBOOK_PORT}"
echo "  * Mobile Apps:    Compatible with official iOS & Android Audiobookshelf apps"
echo "  * Libraries:      /mnt/simba/Media/Audiobooks and /mnt/simba/Media/Podcasts"
echo "======================================================================"
