#!/usr/bin/env bash
# ==============================================================================
# Step 1: NVIDIA Host Driver Setup for Proxmox VE / Debian 13 (trixie)
# Target Host: rath15nas (192.168.68.169)
# Hardware: NVIDIA GeForce GTX 1080 Ti (GP102)
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "    NVIDIA Host Driver Setup - rath15nas (Proxmox VE)"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)." >&2
    exit 1
fi

KERNEL_VER=$(uname -r)
echo "[*] Detected running kernel: $KERNEL_VER"

# 1. Enable 'non-free' in debian.sources if not already present
DEBIAN_SOURCES="/etc/apt/sources.list.d/debian.sources"
if [[ -f "$DEBIAN_SOURCES" ]]; then
    if ! grep -q "non-free " "$DEBIAN_SOURCES" && ! grep -q "non-free$" "$DEBIAN_SOURCES"; then
        echo "[*] Adding 'non-free' component to $DEBIAN_SOURCES..."
        cp "$DEBIAN_SOURCES" "${DEBIAN_SOURCES}.bak.$(date +%Y%m%d%H%M%S)"
        sed -i 's/Components: main contrib non-free-firmware/Components: main contrib non-free non-free-firmware/g' "$DEBIAN_SOURCES"
    else
        echo "[*] 'non-free' component already present in $DEBIAN_SOURCES."
    fi
fi

# 2. Blacklist open-source nouveau driver
NOUVEAU_CONF="/etc/modprobe.d/blacklist-nouveau.conf"
echo "[*] Configuring $NOUVEAU_CONF..."
cat <<'EOF' > "$NOUVEAU_CONF"
blacklist nouveau
options nouveau modeset=0
EOF

# 3. Update APT indices
echo "[*] Updating APT package cache..."
apt-get update

# 4. Install Proxmox kernel headers and build prerequisites
echo "[*] Installing kernel headers for $KERNEL_VER and build tools..."
apt-get install -y "proxmox-headers-${KERNEL_VER}" dkms build-essential

# 5. Install official NVIDIA driver and utilities
echo "[*] Installing nvidia-driver and utilities..."
DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-driver nvidia-smi nvidia-modprobe

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

# 8. Update initramfs to apply nouveau blacklist into early boot
echo "[*] Updating initramfs..."
update-initramfs -u -k all

echo ""
echo "======================================================================"
echo "    Host Setup Completed Successfully!"
echo "======================================================================"
echo "[!] IMPORTANT: A host reboot is required to unload 'nouveau' and load"
echo "    the proprietary 'nvidia' driver into the kernel."
echo "    Reboot command: sudo reboot"
echo "======================================================================"
