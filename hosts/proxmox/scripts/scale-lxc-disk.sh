#!/usr/bin/env bash
# ==============================================================================
# Scale Proxmox LXC 920 (services) Root Disk Allocation
# Target Host: rath15nas (Proxmox VE Host, run with sudo / as root)
# ==============================================================================
set -euo pipefail

VMID="920"
TARGET_SIZE="64G"

echo "======================================================================"
echo "    Scaling LXC $VMID Root Disk to $TARGET_SIZE"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on Proxmox." >&2
    exit 1
fi

if ! command -v pct &>/dev/null; then
    echo "[!] Error: 'pct' command not found. Run directly on Proxmox host." >&2
    exit 1
fi

if ! pct status "$VMID" &>/dev/null; then
    echo "[!] Error: Container $VMID not found on this host." >&2
    exit 1
fi

echo "[*] Current container configuration:"
pct config "$VMID" | grep -E '^rootfs:' || true

echo "[*] Performing online volume resize for LXC $VMID rootfs to $TARGET_SIZE..."
pct resize "$VMID" rootfs "$TARGET_SIZE"

echo "[+] Success! Updated container configuration:"
pct config "$VMID" | grep -E '^rootfs:'

echo "======================================================================"
echo "    LXC $VMID Root Disk Resized Successfully"
echo "======================================================================"
