#!/usr/bin/env bash
# ==============================================================================
# Step: Deploy Home Assistant OS (HAOS) KVM Virtual Machine (VM 940)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="940"
VM_NAME="haos"
STORAGE="local-lvm"
DISK_SIZE="32G"
CORES="2"
RAM="2048"
BRIDGE="vmbr0"
TMP_DIR="/tmp/haos_install"

echo "======================================================================"
echo "    Deploy Home Assistant OS (HAOS) VM $VMID ($VM_NAME)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

if ! command -v qm &>/dev/null; then
    echo "[!] Error: 'qm' command not found. This script must be executed on the Proxmox host."
    exit 1
fi

if qm status "$VMID" &>/dev/null; then
    echo "[!] Error: VM $VMID already exists on this host."
    qm config "$VMID"
    exit 1
fi

for cmd in curl xz awk sed grep; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] Error: Required tool '$cmd' is not installed."
        exit 1
    fi
done

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Query Latest HAOS Release
# ------------------------------------------------------------------------------
echo "[*] Determining latest Home Assistant OS release..."
HAOS_VERSION=$(curl -sI https://github.com/home-assistant/operating-system/releases/latest | grep -i '^location:' | sed 's/.*tag\///' | tr -d '\r\n')

if [[ -z "$HAOS_VERSION" ]]; then
    echo "[!] Warning: Failed to parse latest tag via redirect. Falling back to stable 18.3..."
    HAOS_VERSION="18.3"
fi

IMAGE_NAME="haos_ova-${HAOS_VERSION}.qcow2"
ARCHIVE_NAME="${IMAGE_NAME}.xz"
DOWNLOAD_URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/${ARCHIVE_NAME}"

echo "[+] Target HAOS Version: $HAOS_VERSION"
echo "[+] Target Image: $IMAGE_NAME"

# Setup temporary directory on tmpfs
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# ------------------------------------------------------------------------------
# 3. Download and Extract HAOS Image
# ------------------------------------------------------------------------------
echo "[*] Downloading HAOS archive from GitHub..."
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$TMP_DIR/$ARCHIVE_NAME"

echo "[*] Decompressing $ARCHIVE_NAME..."
xz -d -v "$TMP_DIR/$ARCHIVE_NAME"

if [[ ! -f "$TMP_DIR/$IMAGE_NAME" ]]; then
    echo "[!] Error: Decompressed image $TMP_DIR/$IMAGE_NAME not found."
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. Create Virtual Machine Structure
# ------------------------------------------------------------------------------
echo "[*] Creating VM $VMID ($VM_NAME)..."
qm create "$VMID" \
    --name "$VM_NAME" \
    --memory "$RAM" \
    --cores "$CORES" \
    --cpu host \
    --bios ovmf \
    --machine q35 \
    --ostype l26 \
    --agent 1 \
    --onboot 1 \
    --startup order=2 \
    --scsihw virtio-scsi-pci \
    --net0 "virtio,bridge=$BRIDGE"

echo "[*] Adding EFI disk on $STORAGE..."
qm set "$VMID" --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=0"

# ------------------------------------------------------------------------------
# 5. Import and Attach Boot Disk
# ------------------------------------------------------------------------------
echo "[*] Importing disk image to $STORAGE..."
qm importdisk "$VMID" "$TMP_DIR/$IMAGE_NAME" "$STORAGE"

# Discover imported unused disk
UNUSED_DISK=$(qm config "$VMID" | grep '^unused0:' | awk '{print $2}')
if [[ -z "$UNUSED_DISK" ]]; then
    echo "[!] Error: Failed to discover imported disk for VM $VMID."
    exit 1
fi

echo "[*] Attaching $UNUSED_DISK as primary SCSI0 drive (discard=on, ssd=1)..."
qm set "$VMID" --scsi0 "${UNUSED_DISK},discard=on,ssd=1"
qm set "$VMID" --boot order=scsi0

echo "[*] Resizing SCSI0 to $DISK_SIZE..."
qm resize "$VMID" scsi0 "$DISK_SIZE"

# ------------------------------------------------------------------------------
# 6. Start VM and Verify
# ------------------------------------------------------------------------------
echo "[*] Starting VM $VMID..."
qm start "$VMID"

echo "[+] VM $VMID ($VM_NAME) successfully provisioned and started."
echo "======================================================================"
echo "    Post-Deployment Verification & Onboarding"
echo "======================================================================"
echo "Status: $(qm status "$VMID")"
echo ""
echo "Home Assistant OS is now completing its initial first-boot initialization."
echo "Once booted, it will lease an IP address from your local router via DHCP."
echo ""
echo "Access the onboarding portal at: http://homeassistant.local:8123"
echo "Or check your router DHCP client list / Proxmox VM Summary for the assigned IP."
echo "======================================================================"
