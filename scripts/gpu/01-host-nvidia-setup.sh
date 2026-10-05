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

# 1. Cleanly purge any partially-installed Debian 550 packages
echo "[*] Cleaning up any previous half-configured NVIDIA packages..."
dpkg --configure -a || true
apt-get purge -y "nvidia-*" "libnvidia-*" "libcuda1*" || true
apt-get autoremove -y || true

# 2. Blacklist open-source nouveau driver
NOUVEAU_CONF="/etc/modprobe.d/blacklist-nouveau.conf"
echo "[*] Configuring $NOUVEAU_CONF..."
cat <<'EOF' > "$NOUVEAU_CONF"
blacklist nouveau
options nouveau modeset=0
EOF

# 3. Install Proxmox kernel headers and build prerequisites
echo "[*] Installing kernel headers and build tools..."
apt-get update
apt-get install -y "proxmox-headers-${KERNEL_VER}" dkms build-essential curl gnupg2

# 4. Add official NVIDIA CUDA repository for Debian 12 (compatible with Debian 13/Proxmox)
KEYRING_DEB="/tmp/cuda-keyring_1.1-1_all.deb"
echo "[*] Downloading official NVIDIA CUDA keyring..."
curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb" -o "$KEYRING_DEB"

echo "[*] Installing NVIDIA keyring..."
dpkg -i "$KEYRING_DEB"
rm -f "$KEYRING_DEB"

echo "[*] Updating package index with NVIDIA repository..."
apt-get update

# 5. Install official NVIDIA 570 production driver stack
echo "[*] Installing cuda-drivers-570 (DKMS driver and utilities)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers-570 nvidia-smi nvidia-modprobe

# 6. Configure persistent module loading
MODULES_CONF="/etc/modules-load.d/nvidia.conf"
echo "[*] Ensuring NVIDIA modules load on boot ($MODULES_CONF)..."
cat <<'EOF' > "$MODULES_CONF"
nvidia
nvidia-uvm
nvidia-modeset
EOF

# 7. Configure udev rules for device node permissions
UDEV_RULE="/etc/udev/rules.d/70-nvidia.rules"
echo "[*] Creating udev rules for /dev/nvidia* device node permissions ($UDEV_RULE)..."
cat <<'EOF' > "$UDEV_RULE"
KERNEL=="nvidia", RUN+="/usr/bin/nvidia-modprobe -c0 -m"
KERNEL=="nvidia_uvm", RUN+="/usr/bin/nvidia-modprobe -c0 -u"
SUBSYSTEM=="nvidia*", MODE="0666"
EOF

# 8. Update initramfs to ensure early boot uses the new configuration
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
