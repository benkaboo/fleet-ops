#!/usr/bin/env bash
# ==============================================================================
# Step 4.2: Deploy Calibre-Web E-book Server in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
CALIBRE_PORT="8083"
ROOT_DOMAIN="192.168.68.175.nip.io"
CALIBRE_DOMAIN="books.${ROOT_DOMAIN}"
EMPTY_DB_URL="https://github.com/janeczku/calibre-web/raw/master/library/metadata.db"

echo "======================================================================"
echo "    Step 4.2: Deploy Calibre-Web E-book Server in LXC $VMID"
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

if pct exec "$VMID" -- ss -tuln | grep -q ":${CALIBRE_PORT} "; then
    echo "[!] Error: Port $CALIBRE_PORT is already in use inside container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- test -d "/mnt/simba/Books"; then
    echo "[!] Error: Books directory '/mnt/simba/Books' not found in container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Seed Database, Provision Stack & Configure Caddy
# ------------------------------------------------------------------------------

# Calibre-Web requires an initial metadata.db file in /books. If absent, seed it.
echo "[*] Checking for Calibre library database (metadata.db)..."
pct exec "$VMID" -- bash -c "
if [ ! -f /mnt/simba/Books/metadata.db ]; then
    echo '[*] Seeding starter metadata.db into /mnt/simba/Books/...'
    curl -fsSL '$EMPTY_DB_URL' -o /mnt/simba/Books/metadata.db || true
    if [ -f /mnt/simba/Books/metadata.db ]; then
        chmod 664 /mnt/simba/Books/metadata.db
        chown 1000:1000 /mnt/simba/Books/metadata.db 2>/dev/null || true
        echo '[+] Starter metadata.db initialized successfully.'
    else
        echo '[!] Warning: Could not auto-download metadata.db. Calibre-Web wizard will prompt for path.'
    fi
else
    echo '[+] Existing metadata.db found in /mnt/simba/Books/.'
fi
"

echo "[*] Creating Calibre-Web configuration directory on fast SSD..."
pct exec "$VMID" -- mkdir -p /opt/stacks/calibre-web/config
pct exec "$VMID" -- chown -R 1000:1000 /opt/stacks/calibre-web/config 2>/dev/null || true

echo "[*] Generating /opt/stacks/calibre-web/compose.yaml..."
pct exec "$VMID" -- bash -c "cat << 'COMPEOF' > /opt/stacks/calibre-web/compose.yaml
services:
  calibre-web:
    image: lscr.io/linuxserver/calibre-web:latest
    container_name: calibre-web
    restart: unless-stopped
    ports:
      - \"${CALIBRE_PORT}:8083\"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Australia/Sydney
      - DOCKER_MODS=linuxserver/mods:universal-calibre
    volumes:
      - /opt/stacks/calibre-web/config:/config
      - /mnt/simba/Books:/books
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF"

echo "[*] Starting Calibre-Web container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/calibre-web/compose.yaml up -d

echo "[*] Adding Calibre-Web reverse-proxy route to Caddyfile..."
pct exec "$VMID" -- bash -c "
CADDYFILE='/opt/stacks/caddy/Caddyfile'
if ! grep -q '${CALIBRE_DOMAIN}' \"\$CADDYFILE\"; then
    cat << 'CADEOF' >> \"\$CADDYFILE\"

# Calibre-Web E-book Server (Native Authentication for OPDS / E-readers)
${CALIBRE_DOMAIN} {
    tls internal
    reverse_proxy calibre-web:8083
}
CADEOF
fi
"

echo "[*] Validating updated Caddyfile..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to load Calibre-Web route..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for Calibre-Web to initialize (10s)..."
sleep 10

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running
CALIBRE_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' calibre-web 2>/dev/null || echo "not running")
if [[ "$CALIBRE_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Calibre-Web container status is '$CALIBRE_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs calibre-web --tail 30
    exit 2
fi

# Verify port response inside container
echo "[*] Testing direct HTTP response on port $CALIBRE_PORT..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${CALIBRE_PORT}/" || echo "000")
if [[ "$HTTP_CODE" -ne 200 && "$HTTP_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: Direct Calibre-Web HTTP probe returned '$HTTP_CODE', expected 200 or 302."
    pct exec "$VMID" -- docker logs calibre-web --tail 25
    exit 2
fi
echo "[+] Calibre-Web service is responding on port $CALIBRE_PORT (HTTP $HTTP_CODE)."

# Verify HTTPS route via Caddy
echo "[*] Testing HTTPS reverse-proxy route (https://${CALIBRE_DOMAIN})..."
HTTPS_CODE=$(pct exec "$VMID" -- curl -k -s -o /dev/null -w "%{http_code}" --resolve "${CALIBRE_DOMAIN}:443:127.0.0.1" "https://${CALIBRE_DOMAIN}/" || echo "000")
if [[ "$HTTPS_CODE" -ne 200 && "$HTTPS_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: Caddy HTTPS route returned '$HTTPS_CODE', expected 200 or 302."
    pct exec "$VMID" -- docker logs caddy --tail 25
    exit 2
fi
echo "[+] Calibre-Web HTTPS route verified via Caddy (HTTP $HTTPS_CODE)."

echo ""
echo "======================================================================"
echo "    Step 4.2 Complete: Calibre-Web E-book Server Online!"
echo "======================================================================"
echo "Access URLs:"
echo "  * Direct LAN URL  : http://192.168.68.175:8083"
echo "  * HTTPS Proxy URL : https://${CALIBRE_DOMAIN}"
echo "  * OPDS / E-Reader : http://192.168.68.175:8083/opds (for Kobo/Moon+ Reader)"
echo ""
echo "Initial Calibre-Web Credentials:"
echo "  * Username : admin"
echo "  * Password : admin123"
echo "  * Library Location (when prompted in wizard): /books"
echo ""
echo "Media Library Storage (Btrfs):"
echo "  * Host Path     : /mnt/data/@simba/Books"
echo "  * Windows Share : S:\\Books"
echo "  * Container Path: /books"
echo ""
echo "[+] All Milestone 4 applications deployed and integrated!"
