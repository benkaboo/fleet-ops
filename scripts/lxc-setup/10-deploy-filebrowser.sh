#!/usr/bin/env bash
# ==============================================================================
# Step 5.1: Deploy FileBrowser (Web File Manager) in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
FILEBROWSER_PORT="8082"
ROOT_DOMAIN="192.168.68.175.nip.io"
FILEBROWSER_DOMAIN="files.${ROOT_DOMAIN}"
AUTH_SUBDOMAIN="auth.${ROOT_DOMAIN}"

echo "======================================================================"
echo "    Step 5.1: Deploy FileBrowser in LXC $VMID"
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

# If previous filebrowser container exists, remove it so it frees port 8082
pct exec "$VMID" -- docker rm -f filebrowser 2>/dev/null || true

if pct exec "$VMID" -- ss -tuln | grep -q ":${FILEBROWSER_PORT} "; then
    echo "[!] Error: Port $FILEBROWSER_PORT is already in use by another service inside container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- test -d "/mnt/simba"; then
    echo "[!] Error: Storage mount '/mnt/simba' not found in container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Provision Stack & Configure Caddy
# ------------------------------------------------------------------------------
echo "[*] Cleaning up any previous FileBrowser state on SSD..."
pct exec "$VMID" -- bash -c "
if [ -f /opt/stacks/filebrowser/compose.yaml ]; then
    docker compose -f /opt/stacks/filebrowser/compose.yaml down 2>/dev/null || true
fi
rm -rf /opt/stacks/filebrowser/config /opt/stacks/filebrowser/data
mkdir -p /opt/stacks/filebrowser/database
chown -R 1000:1000 /opt/stacks/filebrowser
"

echo "[*] Generating /opt/stacks/filebrowser/compose.yaml..."
pct exec "$VMID" -- bash -c "cat << 'COMPEOF' > /opt/stacks/filebrowser/compose.yaml
services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    restart: unless-stopped
    ports:
      - \"${FILEBROWSER_PORT}:80\"
    volumes:
      - /mnt/simba:/srv
      - /opt/stacks/filebrowser/database:/database
    environment:
      - FB_DATABASE=/database/filebrowser.db
      - FB_ROOT=/srv
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF"

echo "[*] Starting FileBrowser container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/filebrowser/compose.yaml up -d

echo "[*] Adding FileBrowser route (protected by Authelia) to Caddyfile..."
pct exec "$VMID" -- bash -c "
CADDYFILE='/opt/stacks/caddy/Caddyfile'
if ! grep -q '${FILEBROWSER_DOMAIN}' \"\$CADDYFILE\"; then
    cat << 'CADEOF' >> \"\$CADDYFILE\"

# FileBrowser Web File Manager (Protected by Authelia SSO)
${FILEBROWSER_DOMAIN} {
    tls internal
    import authelia-auth
    reverse_proxy filebrowser:80
}
CADEOF
fi
"

echo "[*] Validating updated Caddyfile..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to load new FileBrowser route..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for FileBrowser to initialize (5s)..."
sleep 5

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

FILEBROWSER_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' filebrowser 2>/dev/null || echo "not running")
if [[ "$FILEBROWSER_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: FileBrowser container status is '$FILEBROWSER_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs filebrowser --tail 30
    exit 2
fi

echo "[*] Testing FileBrowser port ${FILEBROWSER_PORT} inside container..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${FILEBROWSER_PORT}/" || echo "000")
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "[!] Validation Warning: FileBrowser HTTP response code is '$HTTP_CODE'."
else
    echo "[+] FileBrowser responded with HTTP $HTTP_CODE."
fi

echo ""
echo "======================================================================"
echo "    FileBrowser Deployment Completed Successfully!"
echo "======================================================================"
echo "Access Details:"
echo "  * HTTPS URL:      https://${FILEBROWSER_DOMAIN}"
echo "  * Direct Port:    http://192.168.68.175:${FILEBROWSER_PORT}"
echo "  * Default Login:  admin / admin (change upon first login)"
echo "  * SSO Gateway:    Protected via Authelia"
echo "  * Root Directory: /mnt/simba (Books, Documents, Media, Shared-All-Family)"
echo "======================================================================"
