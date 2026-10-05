#!/usr/bin/env bash
# ==============================================================================
# Script: repair-filebrowser-permissions.sh
# Purpose: Fix filebrowser.db permission denied error and restart FileBrowser
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

VMID="920"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

echo "======================================================================"
echo "    Repair FileBrowser Database Permissions in LXC $VMID"
echo "======================================================================"

pct exec "$VMID" -- bash -c '
set -euo pipefail
DB_PATH="/opt/stacks/filebrowser/database"

echo "[*] Setting read/write permissions on FileBrowser database..."
chmod 777 "$DB_PATH"
if [ -f "$DB_PATH/filebrowser.db" ]; then
    chmod 666 "$DB_PATH/filebrowser.db"
fi

echo "[*] Restarting FileBrowser container..."
docker compose -f /opt/stacks/filebrowser/compose.yaml restart
'

echo ""
echo "======================================================================"
echo "    FileBrowser Successfully Repaired and Restarted!"
echo "======================================================================"
