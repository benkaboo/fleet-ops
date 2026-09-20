#!/usr/bin/env bash
# ==============================================================================
# Script: 19-enable-pki-download.sh
# Purpose: Configure Caddy download endpoint for Caddy Root CA certificate (root.crt)
#          to allow seamless 1-tap installation and trust on iOS / Android / PCs.
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

VMID="920"
CADDYFILE="/opt/stacks/caddy/Caddyfile"

echo "======================================================================"
echo "    Enable Caddy Root CA Certificate Download Endpoint"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host (rath15nas)."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running."
    exit 1
fi

echo "[*] Step 1: Locating Caddy root.crt inside container $VMID..."
ROOT_DIR=$(pct exec "$VMID" -- docker exec caddy find /data -name "root.crt" -exec dirname {} \; | head -n1)

if [[ -z "$ROOT_DIR" ]]; then
    echo "[!] Error: Could not find root.crt inside Caddy data directory!"
    exit 1
fi
echo "  [+] Found root certificate directory at: $ROOT_DIR"

echo "[*] Step 2: Backing up current Caddyfile in container $VMID..."
pct exec "$VMID" -- cp "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d_%H%M%S)"

# Check if PKI block already exists
if pct exec "$VMID" -- grep -q "http://pki.192.168.68.175.nip.io" "$CADDYFILE"; then
    echo "  [+] PKI download block already configured in Caddyfile."
else
    echo "[*] Step 3: Appending PKI download block to Caddyfile..."
    pct exec "$VMID" -- bash -c "cat << 'EOF' >> ${CADDYFILE}

# Public Download Endpoint for Caddy Root Certificate (Client Device Trust)
http://pki.192.168.68.175.nip.io, http://pki.dixon.home {
    root * ${ROOT_DIR}
    file_server
}
EOF"
fi

echo "[*] Step 4: Validating updated Caddyfile syntax..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Step 5: Restarting Caddy container to apply changes..."
pct exec "$VMID" -- docker restart caddy > /dev/null
sleep 2

echo ""
echo "======================================================================"
echo "    Caddy Root CA Download Endpoint is LIVE!"
echo "======================================================================"
echo "Download URL for your phone (open in Safari on iPhone):"
echo "  👉 http://pki.192.168.68.175.nip.io/root.crt"
echo "  👉 http://pki.dixon.home/root.crt"
echo "======================================================================"
