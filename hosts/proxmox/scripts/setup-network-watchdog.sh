#!/usr/bin/env bash
# ==============================================================================
# Script: setup-network-watchdog.sh
# Purpose: Provision native systemd timer watchdog on rath15nas to monitor
#          gateway reachability and auto-recover Intel e1000e nic0 DMA hangs.
#          100% VANILLA: Requires ZERO apt packages and zero package mutations.
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

WATCHDOG_SCRIPT="/usr/local/bin/nic0-watchdog.sh"
SERVICE_FILE="/etc/systemd/system/nic0-watchdog.service"
TIMER_FILE="/etc/systemd/system/nic0-watchdog.timer"

echo "======================================================================"
echo "    Configuring Native Systemd Network Watchdog on rath15nas"
echo "======================================================================"

# 1. Entry Condition Checks
if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

# 2. Author self-healing watchdog runner (zero apt packages required)
echo "[*] Creating watchdog runner at ${WATCHDOG_SCRIPT}..."
cat << 'EOF' > "${WATCHDOG_SCRIPT}"
#!/usr/bin/env bash
set -euo pipefail

GATEWAY="192.168.68.1"
INTERFACE="nic0"
LOG_FILE="/var/log/nic0-watchdog.log"

# Check if gateway responds
if ! ping -c 1 -W 2 "${GATEWAY}" >/dev/null 2>&1; then
    # Double-check probe to eliminate false positives on transient packet drop
    sleep 2
    if ! ping -c 1 -W 2 "${GATEWAY}" >/dev/null 2>&1; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${TIMESTAMP}] Gateway ${GATEWAY} unreachable via ${INTERFACE}. Initiating link reset..." >> "${LOG_FILE}"
        
        # Reset interface in software to clear Intel e1000e DMA ring hang
        ip link set dev "${INTERFACE}" down
        sleep 2
        ip link set dev "${INTERFACE}" up
        sleep 3
        
        if ping -c 1 -W 2 "${GATEWAY}" >/dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: ${INTERFACE} link reset resolved stall; gateway reachable." >> "${LOG_FILE}"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: ${INTERFACE} link reset completed but gateway still unreachable." >> "${LOG_FILE}"
        fi
    fi
fi
EOF

chmod +x "${WATCHDOG_SCRIPT}"
echo "[✓] Watchdog runner installed at ${WATCHDOG_SCRIPT}"

# 3. Create systemd oneshot service
echo "[*] Creating systemd service unit at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=Intel e1000e nic0 Link Health Watchdog
After=network.target

[Service]
Type=oneshot
ExecStart=${WATCHDOG_SCRIPT}
EOF

# 4. Create systemd timer unit (probes every 30s)
echo "[*] Creating systemd timer unit at ${TIMER_FILE}..."
cat << EOF > "${TIMER_FILE}"
[Unit]
Description=Run nic0 Link Health Watchdog Every 30 Seconds

[Timer]
OnBootSec=1min
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# 5. Enable and start the timer
echo "[*] Reloading systemd daemon and enabling nic0-watchdog.timer..."
systemctl daemon-reload
systemctl enable --now nic0-watchdog.timer

# 6. Verification
echo "[*] Verifying timer status..."
if systemctl is-active --quiet nic0-watchdog.timer; then
    echo "[✓] SUCCESS: nic0-watchdog.timer is ACTIVE and running!"
    systemctl status nic0-watchdog.timer --no-pager | head -n 10
else
    echo "[!] Error: nic0-watchdog.timer failed to activate." >&2
    exit 1
fi

echo "======================================================================"
echo "    Native Systemd Watchdog Successfully Provisioned (100% Vanilla)"
echo "======================================================================"
