#!/usr/bin/env bash
# ==============================================================================
# Step 6.1: Deploy AdGuard Home (Local DNS & Ad-Blocking) in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
ROOT_DOMAIN="192.168.68.175.nip.io"
ADGUARD_DOMAIN="adguard.${ROOT_DOMAIN}"
ADGUARD_SETUP_PORT="3000"
ADGUARD_HTTP_PORT="8085"

echo "======================================================================"
echo "    Step 6.1: Deploy AdGuard Home in LXC $VMID"
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

# Remove previous adguard container if exists to free ports for re-runs
pct exec "$VMID" -- docker rm -f adguard 2>/dev/null || true

# Check if port 53 (DNS) is free
if pct exec "$VMID" -- ss -tuln | grep -q ":53 "; then
    echo "[!] Warning: Port 53 is in use inside container $VMID (checking systemd-resolved)..."
    # Disable systemd-resolved stub listener if active
    pct exec "$VMID" -- bash -c "
    if grep -q '^#*DNSStubListener=yes' /etc/systemd/resolved.conf 2>/dev/null || ! grep -q 'DNSStubListener=no' /etc/systemd/resolved.conf 2>/dev/null; then
        sed -i 's/^#*DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved || true
    fi
    "
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Provision Stack & Configure Caddy
# ------------------------------------------------------------------------------
echo "[*] Creating AdGuard Home persistent directories on SSD..."
pct exec "$VMID" -- mkdir -p /opt/stacks/adguard/work /opt/stacks/adguard/conf

echo "[*] Generating /opt/stacks/adguard/compose.yaml..."
pct exec "$VMID" -- bash -c "cat << 'COMPEOF' > /opt/stacks/adguard/compose.yaml
services:
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    ports:
      - \"53:53/tcp\"
      - \"53:53/udp\"
      - \"${ADGUARD_SETUP_PORT}:3000/tcp\"
      - \"${ADGUARD_HTTP_PORT}:80/tcp\"
    volumes:
      - /opt/stacks/adguard/work:/opt/adguardhome/work
      - /opt/stacks/adguard/conf:/opt/adguardhome/conf
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF"

echo "[*] Starting AdGuard Home container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/adguard/compose.yaml up -d

echo "[*] Adding AdGuard Home route to Caddyfile..."
pct exec "$VMID" -- bash -c "
CADDYFILE='/opt/stacks/caddy/Caddyfile'
if ! grep -q '${ADGUARD_DOMAIN}' \"\$CADDYFILE\"; then
    cat << 'CADEOF' >> \"\$CADDYFILE\"

# AdGuard Home DNS & Ad-Blocking Dashboard
${ADGUARD_DOMAIN}, adguard.dixon.home {
    tls internal
    reverse_proxy adguard:80
}
CADEOF
fi
"

echo "[*] Validating updated Caddyfile..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to load AdGuard Home route..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for AdGuard Home to initialize (5s)..."
sleep 5

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

ADGUARD_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' adguard 2>/dev/null || echo "not running")
if [[ "$ADGUARD_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: AdGuard Home container status is '$ADGUARD_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs adguard --tail 30
    exit 2
fi

echo "[*] Testing AdGuard Home setup port ${ADGUARD_SETUP_PORT}..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${ADGUARD_SETUP_PORT}/" || echo "000")
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "[!] Validation Warning: AdGuard Home setup response code is '$HTTP_CODE'."
else
    echo "[+] AdGuard Home setup wizard is active on port ${ADGUARD_SETUP_PORT} (HTTP $HTTP_CODE)."
fi

echo ""
echo "======================================================================"
echo "    AdGuard Home Deployment Completed Successfully!"
echo "======================================================================"
echo "Initial Setup Steps (1-Minute Wizard):"
echo "  1. Open http://192.168.68.175:${ADGUARD_SETUP_PORT} in your browser."
echo "  2. Follow the prompt to set the admin username & password."
echo "  3. Leave Web interface port at 80 (inside container) and DNS at 53."
echo "  4. Once complete, access via HTTPS at: https://${ADGUARD_DOMAIN}"
echo ""
echo "Enabling *.dixon.home Local Domain:"
echo "  * In AdGuard Home -> Filters -> DNS rewrites -> Add DNS rewrite:"
echo "    Domain: *.dixon.home"
echo "    IP:     192.168.68.175"
echo "  * Also add root entry if desired:"
echo "    Domain: dixon.home"
echo "    IP:     192.168.68.175"
echo "======================================================================"
