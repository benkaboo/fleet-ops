#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: reconfigure-wireguard-listener.sh
# Purpose: Transition rath15nas from WireGuard client to listening endpoint:
#          - Set ListenPort = 51820 under [Interface]
#          - Remove stale Endpoint directive under [Peer] (dynamic roaming)
#          - Restart wg-quick@wg0 and verify interface state
# Target Host: rath15nas (Proxmox VE)
# Execution: Run with sudo or as root via bjm account
# ==============================================================================

WG_CONF="/etc/wireguard/wg0.conf"
LISTEN_PORT="51820"

# 1. Privilege Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

echo "=========================================================="
echo "  WireGuard Reconfiguration: Listening Endpoint Setup"
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

# 3. Configure Fixed ListenPort
echo "[+] Setting ListenPort = ${LISTEN_PORT} under [Interface]..."
if grep -q -E '^[[:space:]]*ListenPort[[:space:]]*=' "${WG_CONF}"; then
    sed -i -E "s|^[[:space:]]*ListenPort[[:space:]]*=.*|ListenPort = ${LISTEN_PORT}|" "${WG_CONF}"
else
    # Insert ListenPort directly after [Interface]
    sed -i -E "/^\[Interface\]/a ListenPort = ${LISTEN_PORT}" "${WG_CONF}"
fi

# 4. Remove Stale Endpoint Directive
echo "[+] Removing stale outbound Endpoint directive..."
if grep -q -E '^[[:space:]]*Endpoint[[:space:]]*=' "${WG_CONF}"; then
    sed -i -E '/^[[:space:]]*Endpoint[[:space:]]*=/d' "${WG_CONF}"
    echo "  [✓] Stale Endpoint removed. Host will passively listen for incoming peer packets."
else
    echo "  [*] No Endpoint directive found in ${WG_CONF}."
fi

chmod 600 "${WG_CONF}"

# 5. Restart WireGuard Service
echo
echo "[+] Restarting WireGuard service (wg-quick@wg0)..."
systemctl restart wg-quick@wg0

# 6. Verify Service State
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "  [!] Error: wg-quick@wg0 failed to enter active state!" >&2
    echo "  [*] Restoring previous backup from ${BACKUP_PATH}..."
    cp -p "${BACKUP_PATH}" "${WG_CONF}"
    systemctl restart wg-quick@wg0 || true
    exit 1
fi

echo "  [✓] Service wg-quick@wg0 is ACTIVE."
echo

# 7. Handshake & Interface Inspection
echo "=== Interface Status (wg show wg0) ==="
wg show wg0
echo

ACTIVE_PORT=$(wg show wg0 listen-port || true)
if [ "${ACTIVE_PORT}" = "${LISTEN_PORT}" ]; then
    echo "=========================================================="
    echo "  [✓] SUCCESS: rath15nas is now listening on UDP port ${LISTEN_PORT}!"
    echo "      Public IP:  157.85.240.10:${LISTEN_PORT}"
    echo "      Next Step: Ensure router (192.168.68.1) forwards UDP ${LISTEN_PORT}"
    echo "                 to 192.168.68.169."
    echo "=========================================================="
else
    echo "[!] Warning: Active listening port is '${ACTIVE_PORT}', expected '${LISTEN_PORT}'."
fi
