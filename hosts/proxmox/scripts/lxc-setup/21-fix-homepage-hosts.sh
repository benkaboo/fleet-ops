#!/usr/bin/env bash
set -euo pipefail

VMID="920"
echo "[*] Adding HOMEPAGE_ALLOWED_HOSTS=* to Homepage configuration..."

pct exec "$VMID" -- bash -c '
set -euo pipefail
COMPOSE="/opt/stacks/homepage/compose.yaml"

if ! grep -q "HOMEPAGE_ALLOWED_HOSTS" "$COMPOSE"; then
    sed -i "/- PGID=0/a \      - HOMEPAGE_ALLOWED_HOSTS=*" "$COMPOSE"
fi

echo "[*] Recreating Homepage container with allowed hosts..."
docker compose -f "$COMPOSE" up -d
'

echo "[✓] Homepage updated successfully!"
