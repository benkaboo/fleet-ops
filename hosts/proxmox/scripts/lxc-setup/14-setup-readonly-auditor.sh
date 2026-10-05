#!/usr/bin/env bash
# ==============================================================================
# Step 7.1: Provision Read-Only Auditor Account in LXC 920 & Revoke Root SSH
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
AUDIT_USER="agy-auditor"
AUDIT_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMSfluk+fAUAymrrf7CYHRPyhaCXzLaxqlAYPuBI/X1 agy-auditor@rath15nas"

echo "======================================================================"
echo "    Step 7.1: Provision Least-Privilege Read-Only Auditor on LXC $VMID"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on Proxmox host."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running."
    exit 1
fi

echo "[*] Step 1: Revoking root SSH access on LXC $VMID..."
pct exec "$VMID" -- rm -f /root/.ssh/authorized_keys
pct exec "$VMID" -- truncate -s 0 /root/.ssh/authorized_keys 2>/dev/null || true

echo "[*] Step 2: Creating dedicated system user '$AUDIT_USER' in LXC $VMID..."
pct exec "$VMID" -- bash -c "
if ! id -u '$AUDIT_USER' &>/dev/null; then
    useradd -m -s /bin/bash '$AUDIT_USER'
    passwd -l '$AUDIT_USER'
fi
"

echo "[*] Step 3: Installing dedicated auditor public key..."
pct exec "$VMID" -- bash -c "
mkdir -p /home/${AUDIT_USER}/.ssh
chmod 700 /home/${AUDIT_USER}/.ssh
echo '${AUDIT_PUBKEY}' > /home/${AUDIT_USER}/.ssh/authorized_keys
chmod 600 /home/${AUDIT_USER}/.ssh/authorized_keys
chown -R ${AUDIT_USER}:${AUDIT_USER} /home/${AUDIT_USER}/.ssh
"

echo "[*] Step 4: Installing strict read-only sudoers whitelist..."
pct exec "$VMID" -- bash -c "
cat << 'SUDOEOF' > /etc/sudoers.d/agy-readonly
# Strict read-only audit permissions for agy-auditor in LXC 920
${AUDIT_USER} ALL=(ALL) NOPASSWD: \
    /usr/bin/docker ps*, \
    /usr/bin/docker inspect*, \
    /usr/bin/docker logs*, \
    /usr/bin/systemctl status*, \
    /usr/bin/ss*, \
    /usr/bin/cat /opt/stacks/*
SUDOEOF
chmod 440 /etc/sudoers.d/agy-readonly
visudo -c -f /etc/sudoers.d/agy-readonly
"

echo ""
echo "======================================================================"
echo "    Read-Only Auditor Configured Successfully on LXC $VMID!"
echo "======================================================================"
echo "Security Posture:"
echo "  * Root SSH:          Completely REVOKED (/root/.ssh/authorized_keys removed)"
echo "  * Auditor User:      $AUDIT_USER (password locked)"
echo "  * Allowed Commands:  docker ps, docker inspect, docker logs, systemctl status, ss, cat compose files"
echo "  * Denied Commands:   docker run, docker exec, docker stop, file edits, apt, user modifications"
echo "======================================================================"
