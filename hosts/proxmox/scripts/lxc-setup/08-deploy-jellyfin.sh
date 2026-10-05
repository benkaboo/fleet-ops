#!/usr/bin/env bash
# ==============================================================================
# Step 4.1: Deploy Jellyfin Media Server in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
JELLYFIN_PORT="8096"
ROOT_DOMAIN="192.168.68.175.nip.io"
JELLYFIN_DOMAIN="jellyfin.${ROOT_DOMAIN}"

echo "======================================================================"
echo "    Step 4.1: Deploy Jellyfin Media Server in LXC $VMID"
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

if pct exec "$VMID" -- ss -tuln | grep -q ":${JELLYFIN_PORT} "; then
    echo "[!] Error: Port $JELLYFIN_PORT is already in use inside container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- test -d "/mnt/simba/Media"; then
    echo "[!] Error: Media directory '/mnt/simba/Media' not found in container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Provision Stack & Update Caddyfile
# ------------------------------------------------------------------------------
echo "[*] Creating Jellyfin directories on fast SSD..."
pct exec "$VMID" -- mkdir -p /opt/stacks/jellyfin/config /opt/stacks/jellyfin/cache

echo "[*] Generating /opt/stacks/jellyfin/compose.yaml..."
pct exec "$VMID" -- bash -c "cat << 'COMPEOF' > /opt/stacks/jellyfin/compose.yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - \"${JELLYFIN_PORT}:8096\"
    volumes:
      - /opt/stacks/jellyfin/config:/config
      - /opt/stacks/jellyfin/cache:/cache
      - /mnt/simba/Media:/media:ro
    environment:
      - TZ=Australia/Sydney
      - JELLYFIN_PublishedServerUrl=https://${JELLYFIN_DOMAIN}
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF"

echo "[*] Starting Jellyfin container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/jellyfin/compose.yaml up -d

echo "[*] Adding Jellyfin reverse-proxy route to Caddyfile..."
pct exec "$VMID" -- bash -c "
CADDYFILE='/opt/stacks/caddy/Caddyfile'
if ! grep -q '${JELLYFIN_DOMAIN}' \"\$CADDYFILE\"; then
    cat << 'CADEOF' >> \"\$CADDYFILE\"

# Jellyfin Media Server (Native Authentication for Client & TV Apps)
${JELLYFIN_DOMAIN} {
    tls internal
    reverse_proxy jellyfin:8096
}
CADEOF
fi
"

echo "[*] Validating updated Caddyfile..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to load new Jellyfin route..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for Jellyfin and Caddy to initialize (8s)..."
sleep 8

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running
JELLY_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' jellyfin 2>/dev/null || echo "not running")
if [[ "$JELLY_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Jellyfin container status is '$JELLY_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs jellyfin --tail 30
    exit 2
fi

# Verify port response inside container
echo "[*] Testing direct HTTP response on port $JELLYFIN_PORT..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${JELLYFIN_PORT}/health" || echo "000")
if [[ "$HTTP_CODE" -ne 200 && "$HTTP_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: Direct Jellyfin HTTP probe returned '$HTTP_CODE', expected 200 or 302."
    pct exec "$VMID" -- docker logs jellyfin --tail 25
    exit 2
fi
echo "[+] Jellyfin service is responding on port $JELLYFIN_PORT (HTTP $HTTP_CODE)."

# Verify HTTPS route via Caddy
echo "[*] Testing HTTPS reverse-proxy route (https://${JELLYFIN_DOMAIN})..."
HTTPS_CODE=$(pct exec "$VMID" -- curl -k -s -o /dev/null -w "%{http_code}" --resolve "${JELLYFIN_DOMAIN}:443:127.0.0.1" "https://${JELLYFIN_DOMAIN}/health" || echo "000")
if [[ "$HTTPS_CODE" -ne 200 && "$HTTPS_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: Caddy HTTPS route returned '$HTTPS_CODE', expected 200 or 302."
    pct exec "$VMID" -- docker logs caddy --tail 25
    exit 2
fi
echo "[+] Jellyfin HTTPS route verified via Caddy (HTTP $HTTPS_CODE)."

echo ""
echo "======================================================================"
echo "    Step 4.1 Complete: Jellyfin Media Server Online!"
echo "======================================================================"
echo "Access URLs:"
echo "  * Direct LAN URL  : http://192.168.68.175:8096"
echo "  * HTTPS Proxy URL : https://${JELLYFIN_DOMAIN}"
echo ""
echo "Media Library Paths (Mounted from /mnt/data/@simba/Media):"
echo "  * Movies   : /media/Movies"
echo "  * TV Shows : /media/TV Shows"
echo "  * Music    : /media/Music"
echo ""
echo "Next Step: Complete initial Jellyfin web wizard at https://${JELLYFIN_DOMAIN}"
echo "then proceed to Step 4.2 (Deploy Calibre-Web)."
