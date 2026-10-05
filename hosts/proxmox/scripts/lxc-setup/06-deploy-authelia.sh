#!/usr/bin/env bash
# ==============================================================================
# Step 3.1: Deploy Authelia SSO Portal in LXC 920 (services)
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
AUTHELIA_PORT="9091"
DEFAULT_DOMAIN="192.168.68.175.nip.io"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTHELIA_TPL_DIR="$SCRIPT_DIR/authelia"

echo "======================================================================"
echo "    Step 3.1: Deploy Authelia SSO Portal in LXC $VMID"
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

if ! pct exec "$VMID" -- which docker &>/dev/null; then
    echo "[!] Error: Docker is not installed in container $VMID."
    exit 1
fi

if ! pct exec "$VMID" -- docker network ls --format "{{.Name}}" | grep -qx "gateway_net"; then
    echo "[!] Error: Network 'gateway_net' not found. Run 05-deploy-caddy.sh first."
    exit 1
fi

if pct exec "$VMID" -- ss -tuln | grep -q ":${AUTHELIA_PORT} "; then
    echo "[!] Error: Port $AUTHELIA_PORT is already in use inside container $VMID."
    exit 1
fi

if [[ ! -d "$AUTHELIA_TPL_DIR" ]]; then
    echo "[!] Error: Authelia templates directory not found at '$AUTHELIA_TPL_DIR'."
    exit 1
fi

if [[ ! -f "$AUTHELIA_TPL_DIR/configuration.yml.template" || ! -f "$AUTHELIA_TPL_DIR/users_database.yml.template" || ! -f "$AUTHELIA_TPL_DIR/compose.yaml" ]]; then
    echo "[!] Error: Missing required template files in '$AUTHELIA_TPL_DIR'."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Gather Configuration Parameters
# ------------------------------------------------------------------------------
echo ""
echo "Authelia requires a base domain for secure session cookies."
echo "Using wildcard DNS '192.168.68.175.nip.io' allows immediate routing"
echo "to auth.192.168.68.175.nip.io without editing any hosts files."
read -r -p "Enter root domain for Authelia [$DEFAULT_DOMAIN]: " INPUT_DOMAIN
ROOT_DOMAIN="${INPUT_DOMAIN:-$DEFAULT_DOMAIN}"

read -r -p "Enter password for user 'bjm' in Authelia [admin123]: " INPUT_PASS
AUTH_PASS="${INPUT_PASS:-admin123}"

# ------------------------------------------------------------------------------
# 3. Execution: Generate Secrets, Configurations & Deploy
# ------------------------------------------------------------------------------
echo "[*] Setting up Authelia in container $VMID..."

# Generate secrets on host
JWT_SECRET=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)
STORAGE_KEY=$(openssl rand -hex 32)

# Generate argon2 password hash inside container using Authelia CLI
echo "[*] Generating password hash for user bjm..."
RAW_HASH=$(pct exec "$VMID" -- docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$AUTH_PASS")
PASSWORD_HASH=$(echo "$RAW_HASH" | grep -o '\$argon2id[^[:space:]]*' | head -n1 | tr -d '\r\n')

if [[ -z "$PASSWORD_HASH" ]]; then
    echo "[!] Error: Failed to generate password hash. Command output:"
    echo "$RAW_HASH"
    exit 1
fi

# Render configuration templates into temporary staging directory
TEMP_DIR=$(mktemp -d /tmp/authelia_render.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "[*] Rendering configuration files..."
python3 - "$TEMP_DIR" "$AUTHELIA_TPL_DIR" "$ROOT_DOMAIN" "$JWT_SECRET" "$SESSION_SECRET" "$STORAGE_KEY" "$PASSWORD_HASH" << 'PYEOF'
import sys, os

temp_dir, tpl_dir, root_domain, jwt_sec, sess_sec, stor_key, pwd_hash = sys.argv[1:8]

# Render configuration.yml
with open(os.path.join(tpl_dir, "configuration.yml.template"), "r") as f:
    conf = f.read()
conf = conf.replace("__ROOT_DOMAIN__", root_domain)
conf = conf.replace("__JWT_SECRET__", jwt_sec)
conf = conf.replace("__SESSION_SECRET__", sess_sec)
conf = conf.replace("__STORAGE_KEY__", stor_key)
with open(os.path.join(temp_dir, "configuration.yml"), "w") as f:
    f.write(conf)

# Render users_database.yml
with open(os.path.join(tpl_dir, "users_database.yml.template"), "r") as f:
    udb = f.read()
udb = udb.replace("__ROOT_DOMAIN__", root_domain)
udb = udb.replace("__PASSWORD_HASH__", pwd_hash)
with open(os.path.join(temp_dir, "users_database.yml"), "w") as f:
    f.write(udb)
PYEOF

# Create stack directories in container
echo "[*] Preparing directories in container $VMID..."
pct exec "$VMID" -- mkdir -p /opt/stacks/authelia/config /opt/stacks/authelia/data

# Push rendered files and compose.yaml into container
echo "[*] Deploying configuration and compose files..."
pct push "$VMID" "$TEMP_DIR/configuration.yml" /opt/stacks/authelia/config/configuration.yml
pct push "$VMID" "$TEMP_DIR/users_database.yml" /opt/stacks/authelia/config/users_database.yml
pct push "$VMID" "$AUTHELIA_TPL_DIR/compose.yaml" /opt/stacks/authelia/compose.yaml

pct exec "$VMID" -- chmod 644 /opt/stacks/authelia/config/configuration.yml /opt/stacks/authelia/config/users_database.yml /opt/stacks/authelia/compose.yaml

# Static validation with Authelia CLI
echo "[*] Validating Authelia configuration..."
pct exec "$VMID" -- docker run --rm -v /opt/stacks/authelia/config:/config authelia/authelia:latest authelia config validate --config /config/configuration.yml

# Start Authelia stack
echo "[*] Starting Authelia container via Docker Compose..."
pct exec "$VMID" -- docker compose -f /opt/stacks/authelia/compose.yaml up -d

echo "[*] Waiting for Authelia to pass healthchecks (6s)..."
sleep 6

# ------------------------------------------------------------------------------
# 4. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify container is running
CONTAINER_STATUS=$(pct exec "$VMID" -- docker inspect -f "{{.State.Status}}" authelia 2>/dev/null || echo "not running")
if [[ "$CONTAINER_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Authelia container status is '$CONTAINER_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs authelia --tail 30
    exit 2
fi

# Verify health endpoint
echo "[*] Querying Authelia health endpoint..."
HEALTH=$(pct exec "$VMID" -- curl -s "http://127.0.0.1:9091/api/health" || echo "")
if ! echo "$HEALTH" | grep -iq '"status":"ok"'; then
    echo "[!] Validation Failure: Authelia health endpoint returned '$HEALTH', expected '{\"status\":\"ok\"}'."
    pct exec "$VMID" -- docker logs authelia --tail 25
    exit 2
fi

echo ""
echo "[+] Validation Success: Authelia is healthy and running on port $AUTHELIA_PORT!"
echo "======================================================================"
echo "    Authelia SSO Portal Ready"
echo "======================================================================"
echo "Direct Access (Test URL):"
echo "    http://192.168.68.175:9091"
echo ""
echo "User Credentials:"
echo "    Username: bjm"
echo "    Password: (the password you entered)"
echo ""
echo "[+] Step 3.1 Complete. Proceed to Step 3.2 (Integrate with Caddy Reverse Proxy)."
