#!/usr/bin/env bash
# ==============================================================================
# Step 7.4: Decommission Legacy Co-Administrator (dmm)
# Run only AFTER validating that 'dmgm' can successfully authenticate.
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

LEGACY_USER="dmm"
ACTIVE_USER="dmgm"
VMID="920"

echo "======================================================================"
echo "    Decommission Legacy Co-Administrator ($LEGACY_USER)"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

# Pre-flight check: ensure active user exists before deleting legacy user
if ! id -u "$ACTIVE_USER" &>/dev/null; then
    echo "[!] Safety Error: Active user '$ACTIVE_USER' does not exist on host! Aborting cleanup."
    exit 1
fi

echo "[*] Step 1: Removing legacy '$LEGACY_USER@pam' from Proxmox VE..."
if pveum user list 2>/dev/null | grep -q "$LEGACY_USER@pam"; then
    pveum user delete "$LEGACY_USER@pam"
    echo "[+] '$LEGACY_USER@pam' removed from Proxmox VE."
else
    echo "[+] '$LEGACY_USER@pam' not present in Proxmox VE."
fi

echo "[*] Step 2: Terminating any processes for '$LEGACY_USER' on rath15nas..."
pkill -u "$LEGACY_USER" 2>/dev/null || true
sleep 1

echo "[*] Step 3: Deleting host user '$LEGACY_USER' and home directory..."
if id -u "$LEGACY_USER" &>/dev/null; then
    userdel -r "$LEGACY_USER"
    echo "[+] User '$LEGACY_USER' and /home/$LEGACY_USER deleted from host."
else
    echo "[+] Host user '$LEGACY_USER' already removed."
fi

# Container cleanup (if container running)
STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" == *"status: running"* ]]; then
    echo "[*] Step 4: Checking for legacy '$LEGACY_USER' in container $VMID..."
    if pct exec "$VMID" -- id -u "$LEGACY_USER" &>/dev/null; then
        pct exec "$VMID" -- pkill -u "$LEGACY_USER" 2>/dev/null || true
        pct exec "$VMID" -- userdel -r "$LEGACY_USER"
        echo "[+] Container user '$LEGACY_USER' removed."
    fi
    pct exec "$VMID" -- rm -f "/etc/sudoers.d/$LEGACY_USER-admin"
fi

# Step 5: Verify Restic Server is Still 100% Active & Responding
echo "[*] Step 5: Verifying Restic backup server health after cleanup..."
if systemctl is-active --quiet restic-rest-server.service; then
    RESTIC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://10.10.0.4:8000/metrics || echo "000")
    if [[ "$RESTIC_HTTP" == "200" ]]; then
        echo "[âœ“] SUCCESS: Restic REST Server is ACTIVE on 10.10.0.4:8000 (HTTP 200 OK)."
        echo "    David's offsite backup pipeline is completely intact and operational."
    else
        echo "[!] Warning: restic-rest-server is running but /metrics returned HTTP $RESTIC_HTTP."
    fi
else
    echo "[!] Warning: restic-rest-server.service is not active!"
fi

echo ""
echo "======================================================================"
echo "    Decommission Complete: '$LEGACY_USER' has been safely removed."
echo "    Active Co-Administrator remains: '$ACTIVE_USER'"
echo "======================================================================"
