#!/usr/bin/env bash
# ==============================================================================
# Script: setup-network-watchdog.sh
# Purpose: Provision native systemd timer watchdog on rath15nas to monitor
#          gateway reachability and auto-recover Intel e1000e nic0 DMA hangs.
#          100% VANILLA: Requires ZERO apt packages and zero package mutations.
#          Logs directly to journalctl, syslog, and console login banner.
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

WATCHDOG_SCRIPT="/usr/local/bin/nic0-watchdog.sh"
SERVICE_FILE="/etc/systemd/system/nic0-watchdog.service"
TIMER_FILE="/etc/systemd/system/nic0-watchdog.timer"
BANNER_FILE="/etc/profile.d/99-nic0-watchdog-notice.sh"

echo "======================================================================"
echo "    Configuring Native Systemd Network Watchdog on rath15nas"
echo "======================================================================"

# 1. Entry Condition Checks
if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo." >&2
    exit 1
fi

# 2. Author self-healing watchdog runner with journalctl/syslog logging
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
        WARN_MSG="Gateway ${GATEWAY} unreachable via ${INTERFACE}. Initiating software link reset to clear Intel e1000e DMA hang."
        
        # Log to both standard syslog (journalctl -xe) and dedicated log
        echo "[${TIMESTAMP}] [WARNING] ${WARN_MSG}" | tee -a "${LOG_FILE}"
        logger -t nic0-watchdog -p daemon.warn "${WARN_MSG}"
        
        # Reset interface in software to re-initialize e1000e DMA descriptors
        ip link set dev "${INTERFACE}" down
        sleep 2
        ip link set dev "${INTERFACE}" up
        sleep 3
        
        if ping -c 1 -W 2 "${GATEWAY}" >/dev/null 2>&1; then
            SUCC_MSG="SUCCESS: ${INTERFACE} link reset resolved stall; gateway reachable."
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NOTICE] ${SUCC_MSG}" | tee -a "${LOG_FILE}"
            logger -t nic0-watchdog -p daemon.notice "${SUCC_MSG}"
        else
            FAIL_MSG="WARNING: ${INTERFACE} link reset completed but gateway still unreachable."
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${FAIL_MSG}" | tee -a "${LOG_FILE}"
            logger -t nic0-watchdog -p daemon.err "${FAIL_MSG}"
        fi
    fi
fi
EOF

chmod +x "${WATCHDOG_SCRIPT}"
echo "[✓] Watchdog runner installed at ${WATCHDOG_SCRIPT}"

# 3. Create systemd oneshot service with documentation metadata
echo "[*] Creating systemd service unit at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=Intel e1000e nic0 Link Health Watchdog (Auto-resets on DMA hang)
Documentation=https://github.com/benkaboo/fleet-ops/blob/main/hosts/proxmox/docs/adr/0027-linux-standard-watchdog-daemon-and-immich-workload-regulation.md
After=network.target

[Service]
Type=oneshot
ExecStart=${WATCHDOG_SCRIPT}
StandardOutput=journal
StandardError=journal
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

# 5. Create interactive login notice for maintainers and agents
echo "[*] Installing login banner at ${BANNER_FILE}..."
cat << 'EOF' > "${BANNER_FILE}"
# Surfaced notice for future operators and AI agents (ADR-0027)
if [ -n "${PS1:-}" ]; then
    echo -e "\e[36m⚡ [Fleet Watchdog Active]\e[0m nic0-watchdog.timer (probes 192.168.68.1 every 30s)"
    echo -e "   Logs: \e[32mjournalctl -u nic0-watchdog\e[0m | Maintenance: \e[33msudo systemctl stop nic0-watchdog.timer\e[0m"
fi
EOF
chmod +x "${BANNER_FILE}"
echo "[✓] Login banner installed at ${BANNER_FILE}"

# 6. Enable and start the timer
echo "[*] Reloading systemd daemon and enabling nic0-watchdog.timer..."
systemctl daemon-reload
systemctl enable --now nic0-watchdog.timer

# 7. Verification
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
