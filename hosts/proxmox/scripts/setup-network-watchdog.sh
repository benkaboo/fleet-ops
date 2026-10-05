#!/usr/bin/env bash
# ==============================================================================
# Script: setup-network-watchdog.sh
# Purpose: Install and configure Linux standard watchdog daemon on rath15nas
#          to monitor gateway ping and nic0 interface health, auto-recovering
#          e1000e DMA ring hangs via /usr/local/bin/nic0-repair.sh.
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

GATEWAY_IP="192.168.68.1"
INTERFACE="nic0"
REPAIR_SCRIPT="/usr/local/bin/nic0-repair.sh"
CONFIG_FILE="/etc/watchdog.conf"

echo "======================================================================"
echo "    Configuring Network & Hardware Watchdog Daemon on rath15nas"
echo "======================================================================"

# 1. Entry Condition Checks
if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

# 2. Install watchdog package if not present
if ! dpkg -s watchdog 2>/dev/null | grep -q "Status: install ok installed"; then
    echo "[*] Installing official Linux watchdog package..."
    apt-get update -y
    apt-get install -y watchdog
else
    echo "[*] watchdog package is already installed."
fi

# 3. Create repair script
echo "[*] Authoring self-healing repair binary at ${REPAIR_SCRIPT}..."
cat << 'EOF' > "${REPAIR_SCRIPT}"
#!/usr/bin/env bash
# ==============================================================================
# Script: nic0-repair.sh
# Invoked by: Linux watchdog daemon on ping/interface failure
# Purpose: Perform software link reset on nic0 to clear Intel e1000e DMA ring hang
# ==============================================================================
set -euo pipefail

LOG_FILE="/var/log/nic0-repair.log"
GATEWAY="192.168.68.1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[${TIMESTAMP}] Watchdog trigger: network test failed ($*). Initiating nic0 software link reset..." >> "${LOG_FILE}"

# Flap the physical link to trigger e1000e controller re-initialization
ip link set dev nic0 down
sleep 2
ip link set dev nic0 up
sleep 3

# Verify gateway reachability after reset
if ping -c 1 -W 2 "${GATEWAY}" >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: nic0 recovered cleanly; gateway reachable. System reboot averted." >> "${LOG_FILE}"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: nic0 reset attempted but gateway still unreachable." >> "${LOG_FILE}"
    exit 1
fi
EOF

chmod +x "${REPAIR_SCRIPT}"
echo "[✓] Repair binary installed and executable."

# 4. Back up existing watchdog configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    echo "[*] Backing up existing ${CONFIG_FILE} to ${BACKUP_FILE}..."
    cp "${CONFIG_FILE}" "${BACKUP_FILE}"
fi

# 5. Author declarative watchdog configuration
echo "[*] Writing declarative monitoring rules to ${CONFIG_FILE}..."
cat << EOF > "${CONFIG_FILE}"
# /etc/watchdog.conf - Managed by fleet-ops
# Hardware & Network Watchdog Daemon Configuration

watchdog-device = /dev/watchdog
watchdog-timeout = 60

# Network Telemetry Probes
ping = ${GATEWAY_IP}
interface = ${INTERFACE}
ping-count = 3
interval = 15

# Dynamic Self-Healing Binary
repair-binary = ${REPAIR_SCRIPT}
repair-timeout = 15
repair-maximum = 3

# System Health & Logging
log-dir = /var/log/watchdog
realtime = yes
priority = 1
log-tick = 60
EOF

# Ensure log directory exists
mkdir -p /var/log/watchdog

# 6. Enable and restart watchdog service
echo "[*] Enabling and restarting watchdog.service..."
systemctl daemon-reload
systemctl enable watchdog.service
systemctl restart watchdog.service

# 7. Verification
echo "[*] Verifying watchdog service status..."
if systemctl is-active --quiet watchdog.service; then
    echo "[✓] SUCCESS: watchdog.service is ACTIVE and running!"
    systemctl status watchdog.service --no-pager | head -n 12
else
    echo "[!] Error: watchdog.service failed to activate." >&2
    exit 1
fi

echo "======================================================================"
echo "    Watchdog Daemon Successfully Provisioned"
echo "======================================================================"
