#!/usr/bin/env bash
# ==============================================================================
# Script: configure-caddy-ha.sh
# Purpose: Add Caddy reverse proxy routes for Home Assistant (VM 940)
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
CADDYFILE="/opt/stacks/caddy/Caddyfile"

echo "======================================================================"
echo "    Configure Caddy Reverse Proxy for Home Assistant on LXC $VMID"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running."
    exit 1
fi

# 1. Take a timestamped backup of the Caddyfile
echo "[*] Backing up Caddyfile in container $VMID..."
pct exec "$VMID" -- cp "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d_%H%M%S)"

# 2. Check if route already exists
if pct exec "$VMID" -- grep -q "ha.192.168.68.175.nip.io" "$CADDYFILE"; then
    echo "[!] Home Assistant route already exists in $CADDYFILE."
else
    echo "[*] Appending Home Assistant reverse proxy block to $CADDYFILE..."
    pct exec "$VMID" -- bash -c "cat << 'EOF' >> ${CADDYFILE}

# Home Assistant (VM 940)
ha.192.168.68.175.nip.io, ha.dixon.home {
    tls internal
    reverse_proxy 192.168.68.170:80
}

http://ha.192.168.68.175.nip.io, http://ha.dixon.home {
    reverse_proxy 192.168.68.170:80
}
EOF"
fi

# 3. Validate Caddy configuration
echo "[*] Validating Caddyfile syntax..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# 4. Reload Caddy container
echo "[*] Reloading Caddy service..."
pct exec "$VMID" -- docker restart caddy > /dev/null
sleep 2

echo ""
echo "======================================================================"
echo "    Home Assistant Caddy Routing Configured Successfully!"
echo "======================================================================"
echo "Access URLs:"
echo "  * HTTPS: https://ha.192.168.68.175.nip.io"
echo "  * HTTPS: https://ha.dixon.home"
echo "  * HTTP:  http://ha.192.168.68.175.nip.io"
echo "======================================================================"
