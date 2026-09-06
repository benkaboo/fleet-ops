#!/usr/bin/env bash
# ==============================================================================
# Step 1.2: Bind-Mount Btrfs Pool & Start LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
HOST_SHARE="/mnt/data/@simba"
LXC_MOUNT="/mnt/simba"

echo "======================================================================"
echo "    Step 1.2: Bind-Mount Storage & Start LXC $VMID"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

if ! pct status "$VMID" &>/dev/null; then
    echo "[!] Error: Container $VMID does not exist. Please run 01-create-lxc.sh first."
    exit 1
fi

if [[ ! -d "$HOST_SHARE" ]]; then
    echo "[!] Error: Host share directory '$HOST_SHARE' does not exist."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Attach Bind Mount & Boot Container
# ------------------------------------------------------------------------------

echo "[*] Attaching bind-mount: $HOST_SHARE -> $LXC_MOUNT inside container $VMID..."
# mp0: mount point 0
pct set "$VMID" -mp0 "${HOST_SHARE},mp=${LXC_MOUNT}"

echo "[*] Starting container $VMID..."
pct start "$VMID"

echo "[*] Waiting for container network to initialize (5s)..."
sleep 5

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running
STATUS=$(pct status "$VMID")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Validation Failure: Container status is '$STATUS', expected 'status: running'."
    exit 2
fi

# Verify bind-mount accessibility inside container
echo "[*] Verifying bind-mount contents inside container..."
pct exec "$VMID" -- ls -la "$LXC_MOUNT"

# Verify container network connectivity
echo "[*] Verifying internet gateway ping from container..."
if ! pct exec "$VMID" -- ping -c 2 1.1.1.1 &>/dev/null; then
    echo "[!] Validation Failure: Container cannot ping 1.1.1.1."
    exit 2
fi

# Verify DNS resolution
echo "[*] Verifying DNS resolution from container..."
if ! pct exec "$VMID" -- ping -c 2 google.com &>/dev/null; then
    echo "[!] Validation Failure: Container cannot resolve DNS for google.com."
    exit 2
fi

echo ""
echo "[+] Success: Container $VMID is running, storage is bind-mounted, and networking is verified!"
echo "[+] Step 1.2 Complete. Proceed to Step 1.3 (Install Docker Engine)."
