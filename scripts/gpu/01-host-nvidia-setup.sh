#!/usr/bin/env bash
# ==============================================================================
# Step 1: NVIDIA Host Driver Setup via Official NVIDIA CUDA Repository (Path B)
# Target Host: rath15nas (192.168.68.169, Proxmox VE 9 / Debian 13)
# Driver Branch: cuda-drivers-570 (Native Linux 6.17 DRM API support)
# Hardware: NVIDIA GeForce GTX 1080 Ti (GP102)
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "    NVIDIA Host Driver Setup (Path B: Official NVIDIA 570 Repo)"
echo "    Target Host: rath15nas (Proxmox VE)"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)." >&2
    exit 1
fi

KERNEL_VER=$(uname -r)
echo "[*] Detected running kernel: $KERNEL_VER"

# 1. Clean up any invalid backup files in /etc/apt/sources.list.d/
rm -f /etc/apt/sources.list.d/*.bak* || true

# 2. Configure NVIDIA CUDA repository BEFORE running apt-get update
# Note: Debian 13 (Trixie) enforces sqv SHA-1 deprecation (active since 2026-02-01).
# [trusted=yes] instructs APT to bypass sqv signature verification for this repo.
CUDA_LIST="/etc/apt/sources.list.d/cuda-debian12-x86_64.list"
echo "[*] Configuring NVIDIA repository with [trusted=yes] in $CUDA_LIST..."
echo "deb [trusted=yes] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" > "$CUDA_LIST"

# 3. Blacklist open-source nouveau driver
NOUVEAU_CONF="/etc/modprobe.d/blacklist-nouveau.conf"
echo "[*] Configuring $NOUVEAU_CONF..."
cat <<'EOF' > "$NOUVEAU_CONF"
blacklist nouveau
options nouveau modeset=0
EOF

# 4. Update APT package indices with NVIDIA repository included
echo "[*] Updating package indices..."
apt-get update

# 5. Ensure kernel headers, dkms, and build tools are installed
echo "[*] Installing kernel headers and build tools..."
apt-get install -y "proxmox-headers-${KERNEL_VER}" dkms build-essential

# 6. Install official NVIDIA 570 production driver stack
echo "[*] Installing cuda-drivers-570 (DKMS driver and utilities)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers-570

# 7. Configure persistent module loading
MODULES_CONF="/etc/modules-load.d/nvidia.conf"
echo "[*] Ensuring NVIDIA modules load on boot ($MODULES_CONF)..."
cat <<'EOF' > "$MODULES_CONF"
nvidia
nvidia-uvm
nvidia-modeset
EOF

# 8. Configure udev rules for device node permissions
UDEV_RULE="/etc/udev/rules.d/70-nvidia.rules"
echo "[*] Creating udev rules for /dev/nvidia* device node permissions ($UDEV_RULE)..."
cat <<'EOF' > "$UDEV_RULE"
KERNEL=="nvidia", RUN+="/usr/bin/nvidia-modprobe -c0 -m"
KERNEL=="nvidia_uvm", RUN+="/usr/bin/nvidia-modprobe -c0 -u"
SUBSYSTEM=="nvidia*", MODE="0666"
EOF

# 9. Update initramfs to ensure early boot uses the new configuration
echo "[*] Updating initramfs..."
update-initramfs -u -k all

echo ""
echo "======================================================================"
echo "    NVIDIA 570 Host Setup Completed Successfully!"
echo "======================================================================"
echo "[!] IMPORTANT: A host reboot is required to unload 'nouveau' and load"
echo "    the official 'nvidia' 570 driver into the kernel."
echo "    Reboot command: sudo reboot"
echo "======================================================================"
