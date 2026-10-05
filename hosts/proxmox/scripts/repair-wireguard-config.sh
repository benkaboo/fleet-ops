#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: repair-wireguard-config.sh
# Purpose: Remediate INC-20260906-01 by fixing corrupted PostUp/PostDown hooks
#          in /etc/wireguard/wg0.conf, restarting WireGuard, and verifying connectivity.
# Target Host: rath15nas (Proxmox VE)
# Execution: Run with sudo or as root via bjm account
# ==============================================================================

WG_CONF="/etc/wireguard/wg0.conf"
PEER_IP="10.10.0.1"

# 1. Privilege Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

echo "=========================================================="
echo "  WireGuard Interface Repair (INC-20260906-01)"
echo "=========================================================="
echo

if [ ! -f "${WG_CONF}" ]; then
    echo "[!] Error: Configuration file ${WG_CONF} not found!" >&2
    exit 1
fi

# 2. Backup Existing Configuration
BACKUP_PATH="${WG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
echo "[+] Creating configuration backup at: ${BACKUP_PATH}"
cp -p "${WG_CONF}" "${BACKUP_PATH}"

# 3. Clean Corrupted Directives
echo "[+] Removing corrupted PostUp/PostDown directives..."
# Remove any corrupted or existing PostUp/PostDown lines containing iptables
sed -i -E '/^[[:space:]]*PostUp[[:space:]]*=.*iptables/d' "${WG_CONF}"
sed -i -E '/^[[:space:]]*PostDown[[:space:]]*=.*iptables/d' "${WG_CONF}"

# 4. Append Properly Formatted Hooks
echo "[+] Injecting properly formatted lifecycle hooks..."
cat << 'EOF' >> "${WG_CONF}"
PostUp = iptables -t nat -A POSTROUTING -o %i -j MASQUERADE; iptables -A FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -A FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o %i -j MASQUERADE; iptables -D FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -D FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
EOF

chmod 600 "${WG_CONF}"

# 5. Restart WireGuard Service
echo "[+] Restarting WireGuard service (wg-quick@wg0)..."
systemctl restart wg-quick@wg0

# 6. Verify Service State
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "[!] Error: wg-quick@wg0 failed to enter active state!" >&2
    echo "Restoring previous backup from ${BACKUP_PATH}..."
    cp -p "${BACKUP_PATH}" "${WG_CONF}"
    systemctl restart wg-quick@wg0 || true
    exit 1
fi

echo "[âœ“] Service wg-quick@wg0 is ACTIVE."
echo

# 7. Handshake & Interface Inspection
echo "=== Interface Status (wg show) ==="
wg show wg0
echo

# 8. End-to-End Ping Test
echo "[+] Testing reachability to brother's server (${PEER_IP})..."
sleep 2

if ping -c 3 -W 3 "${PEER_IP}"; then
    echo
    echo "=========================================================="
    echo " [âœ“] SUCCESS: WireGuard tunnel restored and peer is pingable!"
    echo "=========================================================="
else
    echo
    echo "[!] Warning: Service is active, but ping to ${PEER_IP} did not respond yet."
    echo "    The remote peer may take a few seconds to renegotiate the handshake."
    echo "    Check 'wg show' for latest handshake timestamp."
fi
