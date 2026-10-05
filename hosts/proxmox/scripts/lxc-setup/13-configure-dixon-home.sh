#!/usr/bin/env bash
# ==============================================================================
# Step 6.2: Configure dixon.home Dual-Stack Domain on LXC 920 (services)
# Target Host: Run inside LXC 920 as root (or via pct exec 920)
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "    Step 6.2: Configure dixon.home Domain for Authelia and Caddy"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Entry Condition Checks
# ------------------------------------------------------------------------------
echo "[*] Checking Entry Conditions..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root."
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "[!] Error: Docker is not installed."
    exit 1
fi

if [[ ! -f /opt/stacks/authelia/config/configuration.yml ]]; then
    echo "[!] Error: /opt/stacks/authelia/config/configuration.yml not found."
    exit 1
fi

if [[ ! -f /opt/stacks/caddy/Caddyfile ]]; then
    echo "[!] Error: /opt/stacks/caddy/Caddyfile not found."
    exit 1
fi

# Extract existing Authelia secrets
JWT_SECRET=$(grep 'jwt_secret:' /opt/stacks/authelia/config/configuration.yml | head -n1 | awk '{print $2}' | tr -d '"')
SESSION_SECRET=$(grep 'secret:' /opt/stacks/authelia/config/configuration.yml | head -n1 | awk '{print $2}' | tr -d '"')
STORAGE_KEY=$(grep 'encryption_key:' /opt/stacks/authelia/config/configuration.yml | head -n1 | awk '{print $2}' | tr -d '"')

if [[ -z "$JWT_SECRET" || -z "$SESSION_SECRET" || -z "$STORAGE_KEY" ]]; then
    echo "[!] Error: Failed to extract existing Authelia secrets."
    exit 1
fi

echo "[+] Entry conditions satisfied. Existing secrets successfully preserved."

# ------------------------------------------------------------------------------
# 2. Execution: Update Authelia Configuration
# ------------------------------------------------------------------------------
echo "[*] Backing up current Authelia configuration..."
cp /opt/stacks/authelia/config/configuration.yml /opt/stacks/authelia/config/configuration.yml.bak

echo "[*] Writing dual-domain Authelia configuration..."
cat << EOF > /opt/stacks/authelia/config/configuration.yml
server:
  address: "tcp://0.0.0.0:9091/"

log:
  level: "info"

theme: "auto"

telemetry:
  metrics:
    enabled: false

identity_validation:
  reset_password:
    jwt_secret: "${JWT_SECRET}"

authentication_backend:
  password_reset:
    disable: true
  file:
    path: "/config/users_database.yml"
    watch: true

access_control:
  default_policy: "one_factor"
  rules:
    - domain: "auth.192.168.68.175.nip.io"
      policy: "bypass"
    - domain: "auth.dixon.home"
      policy: "bypass"
    - domain: "*.192.168.68.175.nip.io"
      policy: "one_factor"
    - domain: "*.dixon.home"
      policy: "one_factor"

session:
  name: "authelia_session"
  same_site: "lax"
  secret: "${SESSION_SECRET}"
  expiration: "1h"
  inactivity: "15m"
  cookies:
    - domain: "192.168.68.175.nip.io"
      authelia_url: "https://auth.192.168.68.175.nip.io"
      default_redirection_url: "https://dockge.192.168.68.175.nip.io"
    - domain: "dixon.home"
      authelia_url: "https://auth.dixon.home"
      default_redirection_url: "https://dockge.dixon.home"

regulation:
  max_retries: 5
  find_time: "2m"
  ban_time: "5m"

storage:
  encryption_key: "${STORAGE_KEY}"
  local:
    path: "/data/db.sqlite3"

notifier:
  filesystem:
    filename: "/data/notification.txt"
EOF

echo "[*] Validating updated Authelia configuration..."
docker exec authelia authelia --config /config/configuration.yml validate-config

echo "[*] Restarting Authelia container..."
docker restart authelia
sleep 3

AUTH_HEALTH=$(curl -s "http://127.0.0.1:9091/api/health" || echo "")
if ! echo "$AUTH_HEALTH" | grep -iq '"status":"ok"'; then
    echo "[!] Error: Authelia failed health check: $AUTH_HEALTH"
    docker logs authelia --tail 30
    exit 2
fi
echo "[+] Authelia is healthy with multi-domain session cookies enabled."

# ------------------------------------------------------------------------------
# 3. Execution: Update Caddy Reverse Proxy
# ------------------------------------------------------------------------------
echo "[*] Backing up current Caddyfile..."
cp /opt/stacks/caddy/Caddyfile /opt/stacks/caddy/Caddyfile.bak

echo "[*] Writing dual-domain Caddyfile..."
cat << 'CADEOF' > /opt/stacks/caddy/Caddyfile
{
    # Global options
    admin off
}

# Reusable Authelia Forward-Auth Snippet
(authelia-auth) {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Authelia SSO Portal
auth.192.168.68.175.nip.io, auth.dixon.home {
    tls internal
    reverse_proxy authelia:9091
}

# Dockge Web Management Portal (Protected by Authelia SSO)
dockge.192.168.68.175.nip.io, dockge.dixon.home {
    tls internal
    import authelia-auth
    reverse_proxy dockge:5001
}

# Default landing on port 80 and root dixon.home
:80, dixon.home {
    respond "Welcome to the Dixon Homelab on rath15nas (LXC 920)!" 200
}

# Jellyfin Media Server (Native Authentication for Client & TV Apps)
jellyfin.192.168.68.175.nip.io, jellyfin.dixon.home {
    tls internal
    reverse_proxy jellyfin:8096
}

# Calibre-Web E-book Server (Native Authentication for OPDS / E-readers)
books.192.168.68.175.nip.io, books.dixon.home {
    tls internal
    reverse_proxy calibre-web:8083
}

# FileBrowser Web File Manager (Protected by Authelia SSO)
files.192.168.68.175.nip.io, files.dixon.home {
    tls internal
    import authelia-auth
    reverse_proxy filebrowser:80
}

# AdGuard Home DNS & Ad-Blocking Dashboard
adguard.192.168.68.175.nip.io, adguard.dixon.home {
    tls internal
    reverse_proxy adguard:80
}
CADEOF

echo "[*] Validating updated Caddyfile..."
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy reverse proxy..."
docker restart caddy
sleep 3

# ------------------------------------------------------------------------------
# 4. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating HTTPS Endpoints for dixon.home..."

# Test 1: Authelia
AUTH_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "auth.dixon.home:443:127.0.0.1" "https://auth.dixon.home/" || echo "000")
if [[ "$AUTH_CODE" -ne 200 ]]; then
    echo "[!] Validation Failure: https://auth.dixon.home returned HTTP '$AUTH_CODE', expected 200."
    exit 2
fi
echo "[+] https://auth.dixon.home is online (HTTP $AUTH_CODE OK)."

# Test 2: Jellyfin
JELLY_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "jellyfin.dixon.home:443:127.0.0.1" "https://jellyfin.dixon.home/" || echo "000")
if [[ "$JELLY_CODE" -ne 200 && "$JELLY_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: https://jellyfin.dixon.home returned HTTP '$JELLY_CODE', expected 200 or 302."
    exit 2
fi
echo "[+] https://jellyfin.dixon.home is online (HTTP $JELLY_CODE OK)."

# Test 3: Dockge (Protected - should redirect to auth.dixon.home)
DOCKGE_HEADERS=$(curl -k -s -I --resolve "dockge.dixon.home:443:127.0.0.1" "https://dockge.dixon.home/" || echo "")
if ! echo "$DOCKGE_HEADERS" | grep -iq "location:.*auth.dixon.home"; then
    echo "[!] Validation Failure: https://dockge.dixon.home did not redirect to auth.dixon.home."
    echo "$DOCKGE_HEADERS"
    exit 2
fi
echo "[+] https://dockge.dixon.home is protected by Authelia SSO (Redirects to auth.dixon.home)."

# Test 4: FileBrowser (Protected - should redirect to auth.dixon.home)
FILES_HEADERS=$(curl -k -s -I --resolve "files.dixon.home:443:127.0.0.1" "https://files.dixon.home/" || echo "")
if ! echo "$FILES_HEADERS" | grep -iq "location:.*auth.dixon.home"; then
    echo "[!] Validation Failure: https://files.dixon.home did not redirect to auth.dixon.home."
    echo "$FILES_HEADERS"
    exit 2
fi
echo "[+] https://files.dixon.home is protected by Authelia SSO (Redirects to auth.dixon.home)."

# Test 5: AdGuard Dashboard
ADGUARD_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "adguard.dixon.home:443:127.0.0.1" "https://adguard.dixon.home/" || echo "000")
if [[ "$ADGUARD_CODE" -ne 200 && "$ADGUARD_CODE" -ne 302 ]]; then
    echo "[!] Validation Failure: https://adguard.dixon.home returned HTTP '$ADGUARD_CODE', expected 200 or 302."
    exit 2
fi
echo "[+] https://adguard.dixon.home is online (HTTP $ADGUARD_CODE OK)."

echo ""
echo "======================================================================"
echo "    Step 6.2 Complete: *.dixon.home is fully operational!"
echo "======================================================================"
echo "Available Endpoints (Dual-Stack):"
echo "  * AdGuard Home:   https://adguard.dixon.home"
echo "  * Jellyfin Media: https://jellyfin.dixon.home"
echo "  * Calibre Books:  https://books.dixon.home"
echo "  * FileBrowser:    https://files.dixon.home"
echo "  * Dockge Portal:  https://dockge.dixon.home"
echo "  * Authelia SSO:   https://auth.dixon.home"
echo "======================================================================"
