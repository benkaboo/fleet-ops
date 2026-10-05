#!/usr/bin/env bash
# ==============================================================================
# Step 3.2: Configure Caddy Reverse Proxy with Authelia Forward Authentication
# Target Host: rath15nas (run with sudo / as root)
# ==============================================================================

set -euo pipefail

VMID="920"
ROOT_DOMAIN="192.168.68.175.nip.io"
AUTH_SUBDOMAIN="auth.${ROOT_DOMAIN}"
DOCKGE_SUBDOMAIN="dockge.${ROOT_DOMAIN}"

echo "======================================================================"
echo "    Step 3.2: Configure Caddy Reverse Proxy with Authelia in LXC $VMID"
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

# Check gateway_net
if ! pct exec "$VMID" -- docker network ls --format "{{.Name}}" | grep -qx "gateway_net"; then
    echo "[!] Error: Network 'gateway_net' not found in container $VMID."
    exit 1
fi

# Check Caddy running
CADDY_STATE=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' caddy 2>/dev/null || echo "missing")
if [[ "$CADDY_STATE" != "running" ]]; then
    echo "[!] Error: Caddy container is not running (status: '$CADDY_STATE')."
    exit 1
fi

# Check Authelia running and healthy
AUTH_STATE=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' authelia 2>/dev/null || echo "missing")
if [[ "$AUTH_STATE" != "running" ]]; then
    echo "[!] Error: Authelia container is not running (status: '$AUTH_STATE'). Run 06-deploy-authelia.sh first."
    exit 1
fi

AUTH_HEALTH=$(pct exec "$VMID" -- curl -s "http://127.0.0.1:9091/api/health" || echo "")
if ! echo "$AUTH_HEALTH" | grep -iq '"status":"ok"'; then
    echo "[!] Error: Authelia health endpoint did not return status ok: '$AUTH_HEALTH'."
    exit 1
fi

# Check Dockge running
DOCKGE_STATE=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' dockge 2>/dev/null || echo "missing")
if [[ "$DOCKGE_STATE" != "running" ]]; then
    echo "[!] Error: Dockge container is not running (status: '$DOCKGE_STATE')."
    exit 1
fi

echo "[+] Entry conditions satisfied."

# ------------------------------------------------------------------------------
# 2. Execution: Network Attach, Compose Update & Caddyfile Configuration
# ------------------------------------------------------------------------------
echo ""
echo "[*] Ensuring Dockge is connected to 'gateway_net'..."
pct exec "$VMID" -- docker network connect gateway_net dockge 2>/dev/null || true

# Update Dockge compose.yaml to persist network membership across recreations
pct exec "$VMID" -- bash -c '
if [ -f /opt/stacks/dockge/compose.yaml ]; then
    if ! grep -q "gateway_net:" /opt/stacks/dockge/compose.yaml; then
        cat << "EOF" > /opt/stacks/dockge/compose.yaml
services:
  dockge:
    image: louislam/dockge:1
    container_name: dockge
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/dockge/data:/app/data
      - /opt/stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
    networks:
      - default
      - gateway_net

networks:
  gateway_net:
    external: true
EOF
    fi
fi
'

echo "[*] Writing updated Caddyfile with Authelia forward authentication..."
pct exec "$VMID" -- bash -c "cat << 'CADEOF' > /opt/stacks/caddy/Caddyfile
{
    # Global options
    admin off
}

# Reusable Authelia Forward-Auth Snippet
(authelia-auth) {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth?authelia_url=https://${AUTH_SUBDOMAIN}
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# Authelia SSO Portal
${AUTH_SUBDOMAIN} {
    tls internal
    reverse_proxy authelia:9091
}

# Dockge Web Management Portal (Protected by Authelia)
${DOCKGE_SUBDOMAIN} {
    tls internal
    import authelia-auth
    reverse_proxy dockge:5001
}

# Default landing on port 80
:80 {
    respond \"Caddy Reverse Proxy is online on rath15nas (LXC 920)!\" 200
}
CADEOF"

echo "[*] Validating Caddyfile configuration..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Restarting Caddy to apply new configuration..."
pct exec "$VMID" -- docker restart caddy

echo "[*] Waiting for Caddy to initialize (4s)..."
sleep 4

# ------------------------------------------------------------------------------
# 3. Exit Condition Validation
# ------------------------------------------------------------------------------
echo ""
echo "[*] Validating Exit Conditions..."

# Verify Caddy is running
CADDY_STATUS=$(pct exec "$VMID" -- docker inspect -f '{{.State.Status}}' caddy 2>/dev/null || echo "not running")
if [[ "$CADDY_STATUS" != "running" ]]; then
    echo "[!] Validation Failure: Caddy container status is '$CADDY_STATUS', expected 'running'."
    pct exec "$VMID" -- docker logs caddy --tail 30
    exit 2
fi

# Test 1: Verify Authelia portal via Caddy HTTPS
echo "[*] Testing HTTPS reverse proxy for Authelia ($AUTH_SUBDOMAIN)..."
AUTH_HTTP_CODE=$(pct exec "$VMID" -- curl -k -s -o /dev/null -w "%{http_code}" --resolve "${AUTH_SUBDOMAIN}:443:127.0.0.1" "https://${AUTH_SUBDOMAIN}/" || echo "000")
if [[ "$AUTH_HTTP_CODE" -ne 200 ]]; then
    echo "[!] Validation Failure: Authelia HTTPS route returned HTTP '$AUTH_HTTP_CODE', expected '200'."
    pct exec "$VMID" -- docker logs caddy --tail 25
    exit 2
fi
echo "[+] Authelia portal accessible via Caddy (HTTP $AUTH_HTTP_CODE OK)."

# Test 2: Verify Dockge is protected and redirects to Authelia
echo "[*] Testing HTTPS forward-auth protection for Dockge ($DOCKGE_SUBDOMAIN)..."
DOCKGE_HEADERS=$(pct exec "$VMID" -- curl -k -s -I --resolve "${DOCKGE_SUBDOMAIN}:443:127.0.0.1" "https://${DOCKGE_SUBDOMAIN}/" || echo "")
DOCKGE_HTTP_CODE=$(echo "$DOCKGE_HEADERS" | grep -i "^HTTP" | head -n1 | awk '{print $2}')

if [[ "$DOCKGE_HTTP_CODE" != "302" && "$DOCKGE_HTTP_CODE" != "401" ]]; then
    echo "[!] Validation Failure: Dockge route returned HTTP '$DOCKGE_HTTP_CODE', expected '302' or '401'."
    echo "$DOCKGE_HEADERS"
    exit 2
fi

if ! echo "$DOCKGE_HEADERS" | grep -iq "location:.*auth"; then
    echo "[!] Validation Failure: Dockge route did not redirect to Authelia portal."
    echo "$DOCKGE_HEADERS"
    exit 2
fi

echo "[+] Dockge successfully protected by Authelia SSO (HTTP $DOCKGE_HTTP_CODE Redirect to ${AUTH_SUBDOMAIN})."
echo ""
echo "======================================================================"
echo "    Step 3.2 Complete: Reverse Proxy & SSO Fully Integrated!"
echo "======================================================================"
echo "Configured Endpoints:"
echo "  * Authelia SSO Portal : https://${AUTH_SUBDOMAIN}"
echo "  * Dockge (Protected)  : https://${DOCKGE_SUBDOMAIN}"
echo ""
echo "Note: Because Caddy generates internal certificates ('tls internal'),"
echo "your browser may show a certificate warning on first visit. Accept the"
echo "self-signed certificate to reach the login screen."
echo ""
echo "User Credentials:"
echo "  * Username: bjm"
echo "  * Password: (configured in Step 3.1)"
