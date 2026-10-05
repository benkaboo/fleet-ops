#!/usr/bin/env bash
# ==============================================================================
# Step 7.2: Provision Administrative Operator (bjm) in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
ADMIN_USER="bjm"
ADMIN_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZ770T1Rk509xop3YRfue50lvOY9fPd0w8jckwNWYi3 ben.bmaslen@gmail.com"

echo "======================================================================"
echo "    Provision Administrative Operator ($ADMIN_USER) on LXC $VMID"
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

echo "[*] Step 1: Ensuring user '$ADMIN_USER' exists with sudo and docker groups..."
if ! pct exec "$VMID" -- id -u "$ADMIN_USER" &>/dev/null; then
    pct exec "$VMID" -- useradd -m -s /bin/bash "$ADMIN_USER"
fi
pct exec "$VMID" -- usermod -aG sudo,docker "$ADMIN_USER"

echo "[*] Step 2: Installing SSH public key for '$ADMIN_USER'..."
pct exec "$VMID" -- mkdir -p "/home/$ADMIN_USER/.ssh"
pct exec "$VMID" -- chmod 700 "/home/$ADMIN_USER/.ssh"
echo "$ADMIN_PUBKEY" | pct exec "$VMID" -- tee "/home/$ADMIN_USER/.ssh/authorized_keys" > /dev/null
pct exec "$VMID" -- chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
pct exec "$VMID" -- chown -R "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh"

echo "[*] Step 3: Configuring passwordless sudoers entry for '$ADMIN_USER'..."
echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" | pct exec "$VMID" -- tee /etc/sudoers.d/bjm-admin > /dev/null
pct exec "$VMID" -- chmod 440 /etc/sudoers.d/bjm-admin
pct exec "$VMID" -- visudo -c -f /etc/sudoers.d/bjm-admin

echo "[*] Step 4: Granting ownership of /opt/stacks to '$ADMIN_USER' for VS Code..."
pct exec "$VMID" -- chown -R "$ADMIN_USER:$ADMIN_USER" /opt/stacks

echo ""
echo "======================================================================"
echo "    Admin Account '$ADMIN_USER' Configured Successfully on LXC $VMID!"
echo "======================================================================"
echo "Access Details:"
echo "  * SSH Target:       $ADMIN_USER@192.168.68.175 (or host alias 'services')"
echo "  * Auth Method:      Dedicated Ed25519 key"
echo "  * Permissions:      Full NOPASSWD sudo + docker group"
echo "  * Stack Dir:        /opt/stacks (owned by $ADMIN_USER:$ADMIN_USER)"
echo "======================================================================"
