#!/usr/bin/env bash
# ==============================================================================
# Step 3: NVIDIA Container Toolkit & Docker Runtime Configuration
# Target Host: LXC 920 / services (192.168.68.175, Ubuntu 24.04 LTS)
# Target Environment: Docker Daemon Runtime
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "    NVIDIA Container Toolkit Setup - LXC 920 (Ubuntu 24.04)"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)." >&2
    exit 1
fi

# 1. Verify NVIDIA device nodes exist inside container
if [[ ! -e "/dev/nvidia0" ]]; then
    echo "ERROR: /dev/nvidia0 not detected inside container!"
    echo "Verify that Step 2 (LXC passthrough in 920.conf) has been executed." >&2
    exit 1
fi
echo "[*] Confirmed /dev/nvidia0 present in container."

# 2. Add NVIDIA Container Toolkit official APT repository
echo "[*] Adding NVIDIA Container Toolkit repository..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 3. Update APT and install nvidia-container-toolkit
echo "[*] Installing nvidia-container-toolkit..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit

# 4. Configure Docker daemon to register the NVIDIA runtime
echo "[*] Configuring Docker daemon runtime..."
nvidia-ctk runtime configure --runtime=docker

# 5. Restart Docker daemon
echo "[*] Restarting Docker daemon..."
systemctl restart docker

echo ""
echo "======================================================================"
echo "    NVIDIA Container Toolkit Installed & Configured!"
echo "======================================================================"
echo "Verify GPU access in Docker with:"
echo "docker run --rm --gpus all ubuntu nvidia-smi"
echo "======================================================================"
