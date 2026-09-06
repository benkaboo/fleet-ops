#!/usr/bin/env bash
# ==============================================================================
# Step 2.2: Deploy Caddy Reverse Proxy & Gateway Network in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"

echo "======================================================================"
echo "    Step 2.2: Deploy Caddy Reverse Proxy in LXC $VMID"
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
    echo "[!] Error: Docker is not installed in container $VMID. Run 03-install-docker.sh first."
    exit 1
fi

# Check if ports 80 and 443 are free inside container
if pct exec "$VMID" -- ss -tuln | grep -q ":80 "; then
    echo "[!] Error: Port 80 is already in use inside container $VMID."
    exit 1
fi

if pct exec "$VMID" -- ss -tuln | grep -q ":443 "; then
    echo "[!] Error: Port 443 is already in use inside container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Setup Gateway Network, Caddy Directories & Compose
# ------------------------------------------------------------------------------
echo "[*] Configuring Gateway network and Caddy in container $VMID..."

pct exec "$VMID" -- bash -c '
set -euo pipefail

# 1. Create shared gateway bridge network for reverse proxying
if ! docker network ls --format "{{.Name}}" | grep -qx "gateway_net"; then
    echo "[*] Creating shared Docker bridge network: gateway_net..."
    docker network create gateway_net
else
    echo "[*] Network gateway_net already exists."
fi

# 2. Attach dockge to gateway_net if running
if docker ps --format "{{.Names}}" | grep -qx "dockge"; then
    echo "[*] Connecting dockge to gateway_net..."
    docker network connect gateway_net dockge 2>/dev/null || true
fi

# 3. Create Caddy directories
mkdir -p /opt/stacks/caddy
mkdir -p /opt/caddy/data
mkdir -p /opt/caddy/config

# 4. Generate Caddyfile
cat << "CADEOF" > /opt/stacks/caddy/Caddyfile
{
    # Global options
    admin off
}

# Default landing on port 80
:80 {
    respond "Caddy Reverse Proxy is online on rath15nas (LXC 920)!" 200
}
CADEOF

# 5. Generate Docker Compose file
cat << "COMPEOF" > /opt/stacks/caddy/compose.yaml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - /opt/stacks/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - /opt/caddy/data:/data
      - /opt/caddy/config:/config
    networks:
      - gateway_net

networks:
  gateway_net:
    external: true
COMPEOF

echo "[*] Pulling image and starting Caddy..."
docker compose -f /opt/stacks/caddy/compose.yaml up -d
'

echo "[*] Waiting for Caddy to initialize (4s)..."
sleep 4

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running
CONTAINER_STATUS=$(pct exec "$VMID" -- docker inspect -f "{{.State.Status}}" caddy 2>/dev/null || echo "not running")
if [[ "$CONTAINER_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Caddy container status is '$CONTAINER_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs caddy --tail 25
    exit 2
fi

# Verify HTTP response on port 80
echo "[*] Testing HTTP response on port 80..."
HTTP_RESPONSE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:80/" || echo "000")
if [[ "$HTTP_RESPONSE" != "200" ]]; then
    echo "[!] Validation Failure: Received HTTP code '$HTTP_RESPONSE' on port 80, expected 200."
    exit 2
fi

echo ""
echo "[+] Validation Success: Caddy is active, listening on ports 80 & 443, and connected to gateway_net!"
echo "======================================================================"
echo "    Caddy Reverse Proxy Online"
echo "======================================================================"
echo "Test in your browser on Windows:"
echo "    http://192.168.68.175"
echo ""
echo "Displays: 'Caddy Reverse Proxy is online on rath15nas (LXC 920)!'"
echo "[+] Step 2.2 Complete. Milestone 2 (Management & Reverse Proxy Foundation) Finished!"
