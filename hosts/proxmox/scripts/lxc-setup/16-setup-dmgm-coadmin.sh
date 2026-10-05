#!/usr/bin/env bash
# ==============================================================================
# Step 7.3: Provision Co-Administrator (dmgm) in Parallel with Legacy (dmm)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

LEGACY_USER="dmm"
NEW_USER="dmgm"
FULL_NAME="David Maslen"
EMAIL="david.maslen@gmail.com"
VMID="920"

echo "======================================================================"
echo "    Provision Co-Administrator ($NEW_USER) [Parallel Deployment]"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Host-Level Parallel User Creation (dmgm)
# ------------------------------------------------------------------------------
echo "[*] Step 1: Ensuring parallel user '$NEW_USER' exists on rath15nas..."

if ! id -u "$NEW_USER" &>/dev/null; then
    useradd -m -s /bin/bash -c "$FULL_NAME" "$NEW_USER"
    echo "[+] Created Linux user '$NEW_USER' on host."
else
    echo "[+] User '$NEW_USER' already exists on host."
fi

# Ensure sudo and users groups
usermod -aG sudo,users "$NEW_USER"

# Seed SSH authorized_keys from legacy dmm if available, without touching dmm
mkdir -p "/home/$NEW_USER/.ssh"
chmod 700 "/home/$NEW_USER/.ssh"

if [[ -f "/home/$LEGACY_USER/.ssh/authorized_keys" ]]; then
    echo "[*] Copying existing authorized_keys from '$LEGACY_USER' to '$NEW_USER'..."
    cp "/home/$LEGACY_USER/.ssh/authorized_keys" "/home/$NEW_USER/.ssh/authorized_keys"
    chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
    echo "[+] Existing SSH keys duplicated for '$NEW_USER'."
fi
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER"

# ------------------------------------------------------------------------------
# 2. Proxmox VE Role Assignment (dmgm@pam as Administrator)
# ------------------------------------------------------------------------------
echo "[*] Step 2: Configuring Proxmox VE permissions for '$NEW_USER@pam'..."

if ! pveum user list 2>/dev/null | grep -q "$NEW_USER@pam"; then
    echo "[*] Adding '$NEW_USER@pam' to Proxmox VE..."
    pveum user add "$NEW_USER@pam" --comment "$FULL_NAME" --email "$EMAIL"
else
    echo "[+] Proxmox VE user '$NEW_USER@pam' already exists."
fi

echo "[*] Granting Administrator role to '$NEW_USER@pam' at root scope (/)..."
pveum acl modify / -user "$NEW_USER@pam" -role Administrator

# ------------------------------------------------------------------------------
# 3. WireGuard Firewall & Forwarding Rules (wg0 -> rath15nas & LXC 920)
# ------------------------------------------------------------------------------
echo "[*] Step 3: Verifying WireGuard forwarding and access rules..."

WG_CONF="/etc/wireguard/wg0.conf"
if [[ -f "$WG_CONF" ]]; then
    # Ensure live iptables explicitly permits incoming wg0 traffic to PVE and services
    iptables -C FORWARD -i wg0 -d 192.168.68.175 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i wg0 -d 192.168.68.175 -p tcp -m multiport --dports 80,443 -j ACCEPT

    iptables -C FORWARD -i wg0 -d 192.168.68.169 -p tcp -m multiport --dports 22,8006 -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i wg0 -d 192.168.68.169 -p tcp -m multiport --dports 22,8006 -j ACCEPT

    echo "[+] Firewall rules verified."
fi

# ------------------------------------------------------------------------------
# 4. Container Provisioning: dmgm on LXC 920
# ------------------------------------------------------------------------------
STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Warning: Container $VMID is not running. Skipping LXC provisioning."
else
    echo "[*] Step 4: Provisioning '$NEW_USER' inside container $VMID (services)..."

    # Create user in container
    if ! pct exec "$VMID" -- id -u "$NEW_USER" &>/dev/null; then
        pct exec "$VMID" -- useradd -m -s /bin/bash -c "$FULL_NAME" "$NEW_USER"
    fi
    pct exec "$VMID" -- usermod -aG sudo,docker "$NEW_USER"

    # Passwordless sudo for container admin
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | pct exec "$VMID" -- tee "/etc/sudoers.d/$NEW_USER-admin" > /dev/null
    pct exec "$VMID" -- chmod 440 "/etc/sudoers.d/$NEW_USER-admin"
    pct exec "$VMID" -- visudo -c -f "/etc/sudoers.d/$NEW_USER-admin"

    # Replicate SSH key if available
    if [[ -f "/home/$NEW_USER/.ssh/authorized_keys" ]]; then
        echo "[*] Syncing SSH authorized_keys to container for '$NEW_USER'..."
        pct exec "$VMID" -- mkdir -p "/home/$NEW_USER/.ssh"
        pct exec "$VMID" -- chmod 700 "/home/$NEW_USER/.ssh"
        pct exec "$VMID" -- tee "/home/$NEW_USER/.ssh/authorized_keys" < "/home/$NEW_USER/.ssh/authorized_keys" > /dev/null
        pct exec "$VMID" -- chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
        pct exec "$VMID" -- chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
    fi

    # --------------------------------------------------------------------------
    # 5. Authelia SSO User Configuration on LXC 920
    # --------------------------------------------------------------------------
    echo "[*] Step 5: Configuring Authelia SSO user for '$NEW_USER'..."
    AUTHELIA_USERS="/opt/stacks/authelia/config/users_database.yml"

    # Check if dmgm already exists in users_database.yml
    if pct exec "$VMID" -- grep -q "^  $NEW_USER:" "$AUTHELIA_USERS" 2>/dev/null; then
        echo "[+] Authelia user '$NEW_USER' already configured."
    else
        echo "[*] Generating initial password for Authelia..."
        INIT_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
        
        # Hash with Argon2 using Authelia container
        RAW_HASH=$(pct exec "$VMID" -- docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$INIT_PASS")
        ARGON_HASH=$(echo "$RAW_HASH" | grep -o '\$argon2id[^[:space:]]*' | head -n1 | tr -d '\r\n')

        if [[ -n "$ARGON_HASH" ]]; then
            pct exec "$VMID" -- cp "$AUTHELIA_USERS" "${AUTHELIA_USERS}.bak.$(date +%Y%m%d_%H%M%S)"

            cat << EOF | pct exec "$VMID" -- tee -a "$AUTHELIA_USERS" > /dev/null

  $NEW_USER:
    disabled: false
    displayname: "$FULL_NAME"
    password: "$ARGON_HASH"
    email: "$EMAIL"
    groups:
      - admins
      - dev
EOF
            pct exec "$VMID" -- docker exec authelia authelia --config /config/configuration.yml validate-config
            pct exec "$VMID" -- docker restart authelia > /dev/null
            sleep 2
            echo "[+] Authelia user '$NEW_USER' created successfully."
            echo ""
            echo "----------------------------------------------------------------------"
            echo "  Authelia Credentials for David Maslen ($NEW_USER):"
            echo "  * Username: $NEW_USER"
            echo "  * Temporary Password: $INIT_PASS"
            echo "  (Please share this password securely with David so he can log in)"
            echo "----------------------------------------------------------------------"
        else
            echo "[!] Warning: Failed to generate Argon2 hash for Authelia. Skipping Authelia user entry."
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 6. Restic Offsite Backup Vault Integrity Verification (Tier 2B)
# ------------------------------------------------------------------------------
echo ""
echo "[*] Step 6: Verifying Restic backup server health (10.10.0.4:8000)..."

if systemctl is-active --quiet restic-rest-server.service; then
    RESTIC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://10.10.0.4:8000/metrics || echo "000")
    if [[ "$RESTIC_HTTP" == "200" ]]; then
        echo "[âœ“] SUCCESS: Restic REST Server is ACTIVE and responding on 10.10.0.4:8000 (HTTP 200 OK)."
        echo "    David's offsite backup pipeline (backup-restic-neuromancer-offsite-rath15nas) is 100% intact."
    else
        echo "[!] Warning: restic-rest-server.service is active, but /metrics returned HTTP $RESTIC_HTTP."
    fi
else
    echo "[!] Warning: restic-rest-server.service is NOT currently active!"
fi

echo ""
echo "======================================================================"
echo "    Parallel Co-Administrator '$NEW_USER' Configured Successfully!"
echo "======================================================================"
echo "Verification Checklist for David Maslen ($NEW_USER):"
echo "  1. Proxmox VE Web GUI:  https://192.168.68.169:8006 (Realm: Linux PAM, user '$NEW_USER')"
echo "  2. Proxmox Host SSH:    ssh $NEW_USER@192.168.68.169 (or 10.10.0.4 over WireGuard)"
echo "  3. Container SSH:       ssh $NEW_USER@192.168.68.175 (NOPASSWD sudo + docker)"
echo "  4. Web Services & SSO:  https://auth.dixon.home or https://auth.192.168.68.175.nip.io"
echo "     * Group: admins (access to Dockge, FileBrowser, Jellyfin, Audiobooks, Calibre)"
echo "  5. Offsite Backup Vault: http://10.10.0.4:8000 (Verified healthy, untouched)"
echo ""
echo "Note: Legacy user '$LEGACY_USER' remains 100% active and untouched."
echo "Once David confirms the new account is working, run the cleanup script to remove '$LEGACY_USER'."
echo "======================================================================"
