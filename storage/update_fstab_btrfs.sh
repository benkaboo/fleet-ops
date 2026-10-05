#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: update_fstab_btrfs.sh
# Purpose: Safely configure /etc/fstab to mount the 2-disk Btrfs storage pool
#          ('data') with the 'nofail' option.
# Target Host: rath15nas (Proxmox VE)
# Pool UUID: 8913bd9c-a240-4ae4-a6bb-0cd496d2fb84 (spanning sdd1 and sde1)
# ==============================================================================

BTRFS_UUID="8913bd9c-a240-4ae4-a6bb-0cd496d2fb84"
MOUNT_POINT="${1:-/mnt/data}"
FSTAB_OPTIONS="defaults,nofail,x-systemd.device-timeout=15s"
FSTAB_ENTRY="UUID=${BTRFS_UUID} ${MOUNT_POINT} btrfs ${FSTAB_OPTIONS} 0 0"

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

echo "=========================================================="
echo "  Configuring /etc/fstab for Btrfs Storage Pool"
echo "=========================================================="
echo "Pool UUID:        ${BTRFS_UUID}"
echo "Mount Point:      ${MOUNT_POINT}"
echo "Mount Options:    ${FSTAB_OPTIONS}"
echo "fstab Entry:      ${FSTAB_ENTRY}"
echo "=========================================================="
echo

# 1. Create mount point directory if needed
if [ ! -d "${MOUNT_POINT}" ]; then
    echo "[+] Creating mount directory: ${MOUNT_POINT}..."
    mkdir -p "${MOUNT_POINT}"
else
    echo "[*] Mount directory ${MOUNT_POINT} already exists."
fi

# 2. Prevent duplicate entries
if grep -q "${BTRFS_UUID}" /etc/fstab; then
    echo "[!] Existing entry for UUID=${BTRFS_UUID} found in /etc/fstab:"
    grep "${BTRFS_UUID}" /etc/fstab
    echo "No modifications made to avoid duplicate entries."
    exit 0
fi

if awk '{print $2}' /etc/fstab | grep -qx "${MOUNT_POINT}"; then
    echo "[!] Error: Mount point ${MOUNT_POINT} is already in use in /etc/fstab:" >&2
    grep "[[:space:]]${MOUNT_POINT}[[:space:]]" /etc/fstab >&2
    exit 1
fi

# 3. Create a timestamped backup of /etc/fstab
BACKUP_PATH="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
echo "[+] Creating backup of /etc/fstab at: ${BACKUP_PATH}"
cp /etc/fstab "${BACKUP_PATH}"

# 4. Append the entry to /etc/fstab
echo "[+] Appending Btrfs pool entry to /etc/fstab..."
{
    echo ""
    echo "# Btrfs storage pool ('data') across /dev/sdd1 and /dev/sde1"
    echo "${FSTAB_ENTRY}"
} >> /etc/fstab

# 5. Reload systemd daemon to recognize new mount configuration
echo "[+] Reloading systemd daemon..."
systemctl daemon-reload

# 6. Test mount
echo "[+] Mounting ${MOUNT_POINT}..."
mount "${MOUNT_POINT}"

# 7. Verification
if mountpoint -q "${MOUNT_POINT}"; then
    echo
    echo "[âœ“] SUCCESS: Btrfs storage pool is mounted at ${MOUNT_POINT}!"
    echo
    df -h "${MOUNT_POINT}"
    echo
    echo "Filesystem details:"
    btrfs filesystem show "${MOUNT_POINT}" || true
else
    echo "[!] Error: Failed to mount ${MOUNT_POINT}. Rolling back /etc/fstab..." >&2
    cp "${BACKUP_PATH}" /etc/fstab
    systemctl daemon-reload
    exit 1
fi
