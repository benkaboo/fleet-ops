#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: add-wireguard-client.sh
# Purpose: Provision a new mobile client (Ben-Phone) on rath15nas:
#          - Generates dedicated client keypair
#          - Registers peer in /etc/wireguard/wg0.conf and live wg0 interface
#          - Ensures LAN outbound NAT masquerading for 10.10.0.0/24
#          - Renders terminal QR code for instant mobile app scanning
#          - Securely wipes temporary keys on completion
# Target Host: rath15nas (Proxmox VE)
# Execution: Run with sudo or as root via bjm account
# ==============================================================================

WG_CONF="/etc/wireguard/wg0.conf"
CLIENT_NAME="ben-phone"
CLIENT_IP="10.10.0.5/32"
SERVER_PUBKEY="tGJ4LkKA1GZY6CKdQJ47LW++iSP1LAtj/GkggcYFMiM="
SERVER_ENDPOINT="157.85.240.10:51820"
DNS_SERVERS="192.168.68.175, 1.1.1.1"
SPLIT_ALLOWED_IPS="192.168.68.0/24, 192.168.6.0/24, 10.10.0.0/24"
CLIENT_CONF="/tmp/${CLIENT_NAME}.conf"
CLIENT_PNG="/tmp/${CLIENT_NAME}-qr.png"

# 1. Privilege Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

if ! command -v qrencode >/dev/null 2>&1; then
    echo "[*] Installing qrencode for terminal QR code generation..."
    apt-get update -qq && apt-get install -y -qq qrencode
fi

echo "=========================================================="
echo "  WireGuard Mobile Client Provisioning (${CLIENT_NAME})"
echo "=========================================================="
echo

# 2. Backup Existing Configuration
BACKUP_PATH="${WG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
echo "[1/5] Backing up WireGuard configuration to ${BACKUP_PATH}..."
cp -p "${WG_CONF}" "${BACKUP_PATH}"

# 3. Generate Cryptographic Keypair
echo "[2/5] Generating unique client keypair..."
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "${CLIENT_PRIVKEY}" | wg pubkey)

# 4. Update wg0.conf and Live Interface
echo "[3/5] Registering peer on rath15nas..."
# Append peer to wg0.conf
cat << EOF >> "${WG_CONF}"

# Mobile Client: Ben Phone (Split-Tunnel)
[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = ${CLIENT_IP}
EOF
chmod 600 "${WG_CONF}"

# Add peer live to running wg0 without dropping existing peer sessions
wg set wg0 peer "${CLIENT_PUBKEY}" allowed-ips "${CLIENT_IP}"
echo "  [✓] Peer registered in kernel with zero downtime to active tunnels."

# 5. Ensure LAN Egress NAT Masquerading for 10.10.0.0/24
echo "[4/5] Verifying LAN egress NAT masquerade..."
iptables -t nat -C POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE

# Persist rule into wg0.conf PostUp/PostDown if not already present
if ! grep -q "10.10.0.0/24 -o vmbr0 -j MASQUERADE" "${WG_CONF}"; then
    sed -i "s|PostUp = |PostUp = iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE; |" "${WG_CONF}"
    sed -i "s|PostDown = |PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE; |" "${WG_CONF}"
    echo "  [✓] NAT rule persisted in wg0.conf lifecycle hooks."
fi

# 6. Generate Client Profile & QR Code
echo "[5/5] Generating client configuration profile..."
cat << EOF > "${CLIENT_CONF}"
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = ${CLIENT_IP}
DNS = ${DNS_SERVERS}

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${SERVER_ENDPOINT}
AllowedIPs = ${SPLIT_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
chmod 600 "${CLIENT_CONF}"

# Also generate a high-res PNG in /tmp just in case
qrencode -s 8 -o "${CLIENT_PNG}" < "${CLIENT_CONF}"
chmod 600 "${CLIENT_PNG}"

echo
echo "=========================================================="
echo "  SCAN THIS QR CODE WITH YOUR WIREGUARD APP"
echo "  1. Open WireGuard on your phone"
echo "  2. Tap '+' -> 'Create from QR code' (or 'Scan from QR code')"
echo "  3. Name the tunnel: Home"
echo "=========================================================="
echo

qrencode -t ansiutf8 < "${CLIENT_CONF}"

echo
echo "=========================================================="
echo "  Client IP:   ${CLIENT_IP}"
echo "  Endpoint:    ${SERVER_ENDPOINT}"
echo "  AllowedIPs:  ${SPLIT_ALLOWED_IPS} (Split-Tunnel)"
echo "  DNS:         ${DNS_SERVERS} (AdGuard Home)"
echo "=========================================================="
echo

read -r -p "[*] Press [Enter] after scanning to wipe temporary keys from disk: " _CONFIRM

# 7. Secure Cleanup
rm -f "${CLIENT_CONF}" "${CLIENT_PNG}"
echo "[✓] Temporary client profile and private keys wiped from disk."
echo "[✓] Setup complete!"
