#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: update-wireguard-endpoint.sh
# Purpose: Update WireGuard remote endpoint to maslen.id.au:51820,
#          fix non-responsive DNS nameserver in /etc/resolv.conf,
#          and restart wg-quick@wg0 to re-establish the site-to-site VPN.
# Target Host: rath15nas (Proxmox VE)
# Execution: Run with sudo or as root via bjm account
# ==============================================================================

WG_CONF="/etc/wireguard/wg0.conf"
RESOLV_CONF="/etc/resolv.conf"
PEER_IP="10.10.0.1"
DOMAIN="maslen.id.au"
EXPECTED_ENDPOINT="maslen.id.au:51820"

# 1. Privilege Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

echo "=========================================================="
echo "  WireGuard Endpoint & DNS Remediation"
echo "=========================================================="
echo

# 2. DNS Verification & Remediation
echo "[1/4] Checking DNS resolution for ${DOMAIN}..."
if ! getent hosts "${DOMAIN}" >/dev/null 2>&1; then
    echo "  [-] System resolver failed to resolve ${DOMAIN}."
    echo "  [*] Inspecting ${RESOLV_CONF}..."
    
    # Backup resolv.conf
    RESOLV_BACKUP="${RESOLV_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -p "${RESOLV_CONF}" "${RESOLV_BACKUP}"
    echo "  [+] Backed up resolv.conf to ${RESOLV_BACKUP}"

    # Replace dead Superloop DNS (119.40.106.35) with reliable resolvers (LAN gateway + Cloudflare)
    cat << 'EOF' > "${RESOLV_CONF}"
search benevolency.com
nameserver 192.168.68.1
nameserver 1.1.1.1
EOF
    echo "  [+] Updated ${RESOLV_CONF} with nameservers: 192.168.68.1, 1.1.1.1"

    # Retest DNS
    if getent hosts "${DOMAIN}" >/dev/null 2>&1; then
        RESOLVED_IP=$(getent hosts "${DOMAIN}" | awk '{print $1}' | head -n1)
        echo "  [✓] DNS resolution fixed! ${DOMAIN} -> ${RESOLVED_IP}"
    else
        echo "  [!] Warning: DNS resolution for ${DOMAIN} still failing. Please verify network access." >&2
    fi
else
    RESOLVED_IP=$(getent hosts "${DOMAIN}" | awk '{print $1}' | head -n1)
    echo "  [✓] DNS resolution healthy: ${DOMAIN} -> ${RESOLVED_IP}"
fi

# 3. WireGuard Configuration Inspection & Update
echo
echo "[2/4] Inspecting WireGuard configuration (${WG_CONF})..."
if [ ! -f "${WG_CONF}" ]; then
    echo "[!] Error: Configuration file ${WG_CONF} not found!" >&2
    exit 1
fi

# Backup wg0.conf
WG_BACKUP="${WG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
cp -p "${WG_CONF}" "${WG_BACKUP}"
echo "  [+] Backed up ${WG_CONF} to ${WG_BACKUP}"

CURRENT_ENDPOINT=$(grep -E '^[[:space:]]*Endpoint[[:space:]]*=' "${WG_CONF}" || true)
echo "  [*] Current configuration: ${CURRENT_ENDPOINT}"

if grep -q -E '^[[:space:]]*Endpoint[[:space:]]*=' "${WG_CONF}"; then
    sed -i -E "s|^[[:space:]]*Endpoint[[:space:]]*=.*|Endpoint = ${EXPECTED_ENDPOINT}|" "${WG_CONF}"
else
    echo "Endpoint = ${EXPECTED_ENDPOINT}" >> "${WG_CONF}"
fi

chmod 600 "${WG_CONF}"
echo "  [✓] Updated ${WG_CONF} endpoint to ${EXPECTED_ENDPOINT}"

# 4. Restart WireGuard Service
echo
echo "[3/4] Restarting WireGuard service (wg-quick@wg0)..."
systemctl restart wg-quick@wg0

if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "  [!] Error: wg-quick@wg0 failed to enter active state!" >&2
    echo "  [*] Restoring previous backup from ${WG_BACKUP}..."
    cp -p "${WG_BACKUP}" "${WG_CONF}"
    systemctl restart wg-quick@wg0 || true
    exit 1
fi
echo "  [✓] Service wg-quick@wg0 is ACTIVE."

# 5. Verification & Handshake Check
echo
echo "[4/4] Verifying WireGuard tunnel and peer connectivity..."
echo "=== Interface Status (wg show wg0) ==="
wg show wg0
echo

echo "[*] Waiting 2 seconds for initial handshake..."
sleep 2

echo "[*] Testing ping to peer IP ${PEER_IP}..."
if ping -c 3 -W 3 "${PEER_IP}"; then
    echo
    echo "=========================================================="
    echo "  [✓] SUCCESS: WireGuard VPN tunnel re-established!"
    echo "      Endpoint: ${EXPECTED_ENDPOINT} (${RESOLVED_IP:-157.85.240.12})"
    echo "      Peer IP:  ${PEER_IP} reachable"
    echo "=========================================================="
else
    echo
    echo "[!] Warning: wg-quick@wg0 is active and endpoint updated, but ping to ${PEER_IP} timed out."
    echo "    The remote router/peer may still be renegotiating or firewalling ICMP."
    echo "    Check 'wg show wg0' for handshake timestamp."
fi
