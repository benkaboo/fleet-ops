#!/usr/bin/env bash
# ==============================================================================
# Step 2: Proxmox LXC 920 NVIDIA Passthrough Configuration
# Target Host: rath15nas (Proxmox VE Host)
# Target Container: LXC 920 (services)
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "    Proxmox LXC 920 GPU Passthrough Configuration"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)." >&2
    exit 1
fi

LXC_ID=920
CONF_FILE="/etc/pve/lxc/${LXC_ID}.conf"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERROR: Container configuration file $CONF_FILE not found!" >&2
    exit 1
fi

# 1. Verify NVIDIA devices are active on the host
if ! command -v nvidia-smi &>/dev/null; then
    echo "ERROR: nvidia-smi not found. Run 01-host-nvidia-setup.sh and reboot first." >&2
    exit 1
fi

# Ensure UVM module and device nodes exist
nvidia-modprobe -c0 -u || true

if [[ ! -e "/dev/nvidia0" ]]; then
    echo "ERROR: /dev/nvidia0 does not exist. Verify NVIDIA driver installation." >&2
    exit 1
fi

# 2. Dynamically determine major device numbers
NV_MAJOR=$(stat -c "%t" /dev/nvidia0 | tr 'a-f' 'A-F')
NV_MAJOR_DEC=$((16#$NV_MAJOR))

UVM_MAJOR=$(stat -c "%t" /dev/nvidia-uvm | tr 'a-f' 'A-F')
UVM_MAJOR_DEC=$((16#$UVM_MAJOR))

echo "[*] NVIDIA Driver Major Number: $NV_MAJOR_DEC"
echo "[*] NVIDIA UVM Major Number:    $UVM_MAJOR_DEC"

# 3. Backup container configuration
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
echo "[*] Backing up $CONF_FILE to $BACKUP_FILE..."
cp "$CONF_FILE" "$BACKUP_FILE"

# 4. Check if passthrough already exists
if grep -q "lxc.cgroup2.devices.allow: c $NV_MAJOR_DEC:\* rwm" "$CONF_FILE"; then
    echo "[*] GPU passthrough already present in $CONF_FILE. Skipping append."
else
    echo "[*] Appending GPU passthrough rules to $CONF_FILE..."
    cat <<EOF >> "$CONF_FILE"

# --- NVIDIA GPU & DRI Passthrough (GeForce GTX 1080 Ti) ---
lxc.cgroup2.devices.allow: c $NV_MAJOR_DEC:* rwm
lxc.cgroup2.devices.allow: c $UVM_MAJOR_DEC:* rwm
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
EOF
fi

echo "[*] Restarting LXC $LXC_ID to apply GPU passthrough..."
pct reboot "$LXC_ID"

echo ""
echo "======================================================================"
echo "    LXC 920 GPU Passthrough Complete!"
echo "======================================================================"
echo "Verify inside LXC 920 with: ls -la /dev/nvidia*"
echo "======================================================================"
