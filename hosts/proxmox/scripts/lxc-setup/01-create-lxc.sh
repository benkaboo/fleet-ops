#!/usr/bin/env bash
# ==============================================================================
# Step 1.1: Create Unprivileged LXC 920 (services) on Proxmox
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
HOSTNAME="services"
TEMPLATE="/var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
STORAGE="local-lvm"
DISK_SIZE="64"
CORES="4"
RAM="12288"
SWAP="2048"
IP="192.168.68.175/24"
GATEWAY="192.168.68.1"
BRIDGE="vmbr0"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZ770T1Rk509xop3YRfue50lvOY9fPd0w8jckwNWYi3 ben.bmaslen@gmail.com"

echo "======================================================================"
echo "    Step 1.1: Create LXC $VMID ($HOSTNAME)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

# Must be run as root / sudo on Proxmox
if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

# Ensure pct tool is present
if ! command -v pct &>/dev/null; then
    echo "[!] Error: 'pct' command not found. This script must be executed directly on the Proxmox host."
    exit 1
fi

# Check if VMID 920 already exists
if pct status "$VMID" &>/dev/null; then
    echo "[!] Error: Container $VMID already exists on this host."
    pct config "$VMID"
    exit 1
fi

# Check template exists
if [[ ! -f "$TEMPLATE" ]]; then
    echo "[!] Error: OS template '$TEMPLATE' not found."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Create Container
# ------------------------------------------------------------------------------
echo "[*] Creating container $VMID ($HOSTNAME)..."

# Temporary keyfile for pct create
TMP_KEYFILE=$(mktemp)
echo "$SSH_KEY" > "$TMP_KEYFILE"

pct create "$VMID" "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --cores "$CORES" \
    --memory "$RAM" \
    --swap "$SWAP" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    --ostype ubuntu \
    --unprivileged 1 \
    --features nesting=1,keyctl=1 \
    --net0 "name=eth0,bridge=${BRIDGE},ip=${IP},gw=${GATEWAY}" \
    --nameserver "$GATEWAY" \
    --onboot 1 \
    --ssh-public-keys "$TMP_KEYFILE"

rm -f "$TMP_KEYFILE"

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify status is stopped
STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: stopped"* ]]; then
    echo "[!] Validation Failure: Container status is '$STATUS', expected 'status: stopped'."
    exit 2
fi

# Verify features
CONFIG=$(pct config "$VMID")
if ! grep -q "features:.*nesting=1" <<< "$CONFIG" || ! grep -q "features:.*keyctl=1" <<< "$CONFIG"; then
    echo "[!] Validation Failure: 'features: nesting=1,keyctl=1' not found in container configuration."
    exit 2
fi

echo "[+] Success: Container $VMID ($HOSTNAME) successfully created with verified features!"
echo ""
echo "Configuration summary for container $VMID:"
echo "----------------------------------------------------------------------"
pct config "$VMID"
echo "----------------------------------------------------------------------"
echo "[+] Step 1.1 Complete. Proceed to Step 1.2 (Bind-Mount & First Boot)."
