#!/usr/bin/env bash
# ==============================================================================
# Step 2.1: Deploy Dockge (Docker Compose Web Manager) in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
DOCKGE_PORT="5001"

echo "======================================================================"
echo "    Step 2.1: Deploy Dockge Web Manager in LXC $VMID"
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

# Check if port 5001 is already bound
if pct exec "$VMID" -- ss -tuln | grep -q ":${DOCKGE_PORT} "; then
    echo "[!] Error: Port $DOCKGE_PORT is already in use inside container $VMID."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Setup Directories and Launch Dockge
# ------------------------------------------------------------------------------
echo "[*] Configuring Dockge directories and compose file in container $VMID..."

pct exec "$VMID" -- bash -c '
set -euo pipefail

# Create stacks and dockge data directories
mkdir -p /opt/stacks/dockge
mkdir -p /opt/dockge/data

cat << "EOF" > /opt/stacks/dockge/compose.yaml
services:
  dockge:
    image: louislam/dockge:1
    container_name: dockge
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/dockge/data:/app/data
      - /opt/stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
EOF

echo "[*] Pulling image and starting Dockge..."
docker compose -f /opt/stacks/dockge/compose.yaml up -d
'

echo "[*] Waiting for Dockge to initialize (5s)..."
sleep 5

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running in docker
CONTAINER_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' dockge 2>/dev/null || echo "not running")
if [[ "$CONTAINER_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Dockge container status is '$CONTAINER_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs dockge --tail 20
    exit 2
fi

# Verify HTTP response on port 5001
echo "[*] Testing HTTP response on port $DOCKGE_PORT..."
HTTP_CODE=$(pct exec "$VMID" -- curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${DOCKGE_PORT}/" || echo "000")

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "[!] Validation Failure: Received HTTP code '$HTTP_CODE' from Dockge, expected 200 or 302."
    exit 2
fi

echo ""
echo "[+] Validation Success: Dockge is up and responding on port $DOCKGE_PORT!"
echo "======================================================================"
echo "    Dockge Web Interface Ready"
echo "======================================================================"
echo "Open in your browser on Windows:"
echo "    http://192.168.68.175:5001"
echo ""
echo "On first open, you will create your Dockge admin account."
echo "[+] Step 2.1 Complete. Proceed to Step 2.2 (Deploy Caddy Reverse Proxy)."
