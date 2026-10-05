#!/usr/bin/env bash
# ==============================================================================
# Step 1.3: Install Docker Engine & Compose inside LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"

echo "======================================================================"
echo "    Step 1.3: Install Docker Engine & Compose in LXC $VMID"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running. Current status: '$STATUS'."
    exit 1
fi

if ! pct exec "$VMID" -- ping -c 2 1.1.1.1 &>/dev/null; then
    echo "[!] Error: Container $VMID does not have internet access."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Install Docker inside Container 920
# ------------------------------------------------------------------------------
echo "[*] Executing Docker installation inside container $VMID..."

pct exec "$VMID" -- bash -c '
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating package lists..."
apt-get update -qq

echo "[*] Installing prerequisites..."
apt-get install -y -qq ca-certificates curl gnupg lsb-release

echo "[*] Adding official Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "[*] Adding Docker APT repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[*] Installing Docker packages..."
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[*] Enabling and starting Docker service..."
systemctl enable --now docker.service
'

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify Docker version
echo -n "[*] Docker Engine: "
pct exec "$VMID" -- docker --version

# Verify Compose version
echo -n "[*] Docker Compose: "
pct exec "$VMID" -- docker compose version

# Run Hello-World container test
echo "[*] Running hello-world validation container..."
TEST_OUTPUT=$(pct exec "$VMID" -- docker run --rm hello-world)

if ! grep -q "Hello from Docker!" <<< "$TEST_OUTPUT"; then
    echo "[!] Validation Failure: Hello-world container test failed."
    echo "$TEST_OUTPUT"
    exit 2
fi

echo ""
echo "[+] Validation Success: Hello-world container ran cleanly!"
echo "[+] Step 1.3 Complete: Docker Engine & Compose are fully operational in LXC $VMID!"
