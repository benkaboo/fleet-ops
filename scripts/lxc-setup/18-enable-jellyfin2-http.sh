#!/usr/bin/env bash
# ==============================================================================
# Step 8.1: Enable Plain HTTP Relay for Remote Jellyfin (jellyfin2)
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
CADDYFILE="/opt/stacks/caddy/Caddyfile"

echo "======================================================================"
echo "    Enable Plain HTTP Relay for Remote Jellyfin (Google TV Support)"
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

echo "[*] Step 1: Backing up current Caddyfile in container $VMID..."
pct exec "$VMID" -- cp "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d_%H%M%S)"

# Check if plain HTTP block already exists
if pct exec "$VMID" -- grep -q "http://jellyfin2.192.168.68.175.nip.io" "$CADDYFILE"; then
    echo "[+] Plain HTTP block already configured in Caddyfile."
else
    echo "[*] Step 2: Appending plain HTTP block for Google TV in container $VMID..."
    pct exec "$VMID" -- bash -c 'cat << "EOF" >> /opt/stacks/caddy/Caddyfile

# Plain HTTP Relay for Google TV / Smart TVs (Bypasses Android internal CA SSL restrictions)
http://jellyfin2.192.168.68.175.nip.io, http://jellyfin2.dixon.home {
    reverse_proxy https://192.168.6.23 {
        transport http {
            tls_server_name sensenet.home.maslen.id.au
            tls_insecure_skip_verify
        }
        header_up Host sensenet.home.maslen.id.au
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Proto http
    }
}
EOF'
fi

echo "[*] Step 3: Validating updated Caddyfile syntax..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Step 4: Restarting Caddy container to apply changes (admin off mode)..."
pct exec "$VMID" -- docker restart caddy > /dev/null
sleep 2

echo ""
echo "======================================================================"
echo "    Caddy Plain HTTP Relay Successfully Activated!"
echo "======================================================================"
echo "Google TV Connection Details:"
echo "  * Server Address:  http://jellyfin2.192.168.68.175.nip.io"
echo "  * Quick Connect:   http://jellyfin2.192.168.68.175.nip.io/web/#/quickconnect"
echo "======================================================================"
