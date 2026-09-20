#!/usr/bin/env bash
# ==============================================================================
# Script: 20-deploy-homepage-and-kuma.sh
# Purpose: Deploy Homepage (dashboard) and Uptime Kuma (monitoring) on LXC 920,
#          configure Caddy reverse proxy routes for both, and link to WireGuard/LXC services.
# Target Host: rath15nas (Proxmox VE host, run with sudo / as root via bjm)
# ==============================================================================

set -euo pipefail

VMID="920"
CADDYFILE="/opt/stacks/caddy/Caddyfile"

echo "======================================================================"
echo "    Deploy Homepage Dashboard & Uptime Kuma on LXC $VMID"
echo "======================================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo on the Proxmox host (rath15nas)."
    exit 1
fi

STATUS=$(pct status "$VMID" 2>/dev/null || echo "not found")
if [[ "$STATUS" != *"status: running"* ]]; then
    echo "[!] Error: Container $VMID is not running."
    exit 1
fi

echo "[*] Step 1: Ensuring Uptime Kuma is running..."
pct exec "$VMID" -- bash -c '
set -euo pipefail
mkdir -p /opt/stacks/uptime-kuma/data

cat << "EOF" > /opt/stacks/uptime-kuma/compose.yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - /opt/stacks/uptime-kuma/data:/app/data
    networks:
      - gateway_net

networks:
  gateway_net:
    external: true
EOF

docker compose -f /opt/stacks/uptime-kuma/compose.yaml up -d
'

echo "[*] Step 2: Configuring Homepage Dashboard..."
pct exec "$VMID" -- bash -c '
set -euo pipefail
mkdir -p /opt/stacks/homepage/config

cat << "EOF" > /opt/stacks/homepage/compose.yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    volumes:
      - /opt/stacks/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*
    networks:
      - gateway_net

networks:
  gateway_net:
    external: true
EOF

cat << "EOF" > /opt/stacks/homepage/config/settings.yaml
title: Dixon Fleet
theme: dark
color: slate
headerStyle: clean
cardBlur: sm
showStats: true
quicklaunch:
  searchDescriptions: true
  hideInternetSearch: false
  showSearchSuggestions: true
  provider: duckduckgo
EOF

cat << "EOF" > /opt/stacks/homepage/config/widgets.yaml
- search:
    provider: duckduckgo
    target: _blank
- datetime:
    text_size: xl
    format:
      timeStyle: short
      dateStyle: medium
- resources:
    cpu: true
    memory: true
    disk: /
EOF

cat << "EOF" > /opt/stacks/homepage/config/docker.yaml
my-docker:
  socket: /var/run/docker.sock
EOF

cat << "EOF" > /opt/stacks/homepage/config/services.yaml
- Media & Entertainment:
    - Jellyfin:
        icon: jellyfin.png
        href: https://jellyfin.dixon.home
        description: Media Streaming Server
        server: my-docker
        container: jellyfin
    - Audiobookshelf:
        icon: audiobookshelf.png
        href: https://audiobooks.dixon.home
        description: Audiobooks & Podcasts
        server: my-docker
        container: audiobookshelf
    - Calibre-Web:
        icon: calibre-web.png
        href: https://books.dixon.home
        description: Digital E-Book Library
        server: my-docker
        container: calibre-web

- Infrastructure & Administration:
    - Proxmox VE:
        icon: proxmox.png
        href: https://192.168.68.169:8006
        description: Hypervisor (rath15nas)
    - Dockge:
        icon: dockge.png
        href: https://dockge.dixon.home
        description: Docker Compose Management
        server: my-docker
        container: dockge
    - FileBrowser:
        icon: filebrowser.png
        href: https://files.dixon.home
        description: Web File Manager (Simba)
        server: my-docker
        container: filebrowser
    - AdGuard Home:
        icon: adguard-home.png
        href: https://adguard.dixon.home
        description: DNS & Ad-Blocking
        server: my-docker
        container: adguard
    - Uptime Kuma:
        icon: uptime-kuma.png
        href: https://status.dixon.home
        description: Service Health & Monitoring
        server: my-docker
        container: uptime-kuma

- Maslen Network (Remote via WireGuard):
    - Remote Jellyfin:
        icon: jellyfin.png
        href: https://jellyfin2.dixon.home
        description: Sensenet on Cortex (192.168.6.23)
    - Remote Books:
        icon: calibre-web.png
        href: https://books2.dixon.home
        description: Chiba on Neuromancer (192.168.6.23)
    - Maslen Fleet Portal:
        icon: homepage.png
        href: https://homepage.home.maslen.id.au
        description: Chatsubo Gateway (192.168.6.23)
EOF

echo "[*] Pulling and launching Homepage container..."
docker compose -f /opt/stacks/homepage/compose.yaml up -d
'

echo "[*] Step 3: Backing up Caddyfile in container $VMID..."
pct exec "$VMID" -- cp "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d_%H%M%S)"

echo "[*] Step 4: Configuring Caddy reverse proxy routes for Homepage and Uptime Kuma..."
pct exec "$VMID" -- bash -c "cat << 'EOF' >> ${CADDYFILE}

# Homepage Dashboard (Dixon Fleet Landing Page)
home.192.168.68.175.nip.io, home.dixon.home {
    tls internal
    reverse_proxy homepage:3000
}

http://home.192.168.68.175.nip.io, http://home.dixon.home {
    reverse_proxy homepage:3000
}

# Uptime Kuma Monitoring & Status Page
status.192.168.68.175.nip.io, status.dixon.home {
    tls internal
    reverse_proxy uptime-kuma:3001
}

http://status.192.168.68.175.nip.io, http://status.dixon.home {
    reverse_proxy uptime-kuma:3001
}
EOF"

echo "[*] Step 5: Validating Caddy configuration..."
pct exec "$VMID" -- docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "[*] Step 6: Reloading Caddy..."
pct exec "$VMID" -- docker restart caddy > /dev/null
sleep 2

echo ""
echo "======================================================================"
echo "    Homepage & Uptime Kuma Deployment Completed!"
echo "======================================================================"
echo "Access URLs:"
echo "  🏠 Homepage (Dixon Fleet):"
echo "     * HTTPS:  https://home.dixon.home"
echo "     * HTTPS:  https://home.192.168.68.175.nip.io"
echo "     * HTTP:   http://home.192.168.68.175.nip.io"
echo ""
echo "  📊 Uptime Kuma (Monitoring):"
echo "     * HTTPS:  https://status.dixon.home"
echo "     * HTTPS:  https://status.192.168.68.175.nip.io"
echo "     * HTTP:   http://status.192.168.68.175.nip.io"
echo "======================================================================"
