# ADR-0015: Homepage Dashboard ("Dixon Fleet") & Uptime Kuma 24/7 Monitoring Deployment

* **Status:** Accepted
* **Date:** 2026-09-20
* **Component:** Media & Applications
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
Operator and family required a unified, clean application launcher (matching brother's "Maslen Fleet" dashboard) and 24/7 service uptime monitoring with incident alerting.

## Action
1. **Uptime Kuma Deployment:**
   * Provisioned `louislam/uptime-kuma:1` Docker stack under `/opt/stacks/uptime-kuma/compose.yaml` attached to `gateway_net`.
   * Configured Caddy routes at `https://status.dixon.home` and `https://status.192.168.68.175.nip.io` (plain HTTP at `http://status.192.168.68.175.nip.io`).
2. **Homepage Dashboard Deployment:**
   * Provisioned `ghcr.io/gethomepage/homepage:latest` Docker stack under `/opt/stacks/homepage/compose.yaml` attached to `gateway_net`.
   * Configured read-only bind mount `/var/run/docker.sock:/var/run/docker.sock:ro` for live container health telemetry and CPU/RAM telemetry.
   * Set `HOMEPAGE_ALLOWED_HOSTS=*` in container environment to support Caddy reverse proxy headers.
   * Configured Caddy routes at `https://home.dixon.home` and `https://home.192.168.68.175.nip.io` (plain HTTP at `http://home.192.168.68.175.nip.io`).
   * Pre-populated service catalog with local services (Jellyfin, Audiobookshelf, Calibre-Web, Proxmox, Dockge, FileBrowser, AdGuard, Uptime Kuma) and remote brother services (Jellyfin 2, Books 2, Maslen Fleet).
3. **Local PKI Distribution Endpoint:**
   * Configured Caddy endpoint `http://pki.192.168.68.175.nip.io/root.crt` to facilitate downloading Caddy's root CA certificate for client device trust on Android/iOS.
4. **FileBrowser Database Permission Remediation:**
   * Diagnosed container restart loop caused by `Error: open /database/filebrowser.db: permission denied`.
   * Set database file permissions to `0664` owned by `1001:1001` (matching unprivileged container UID), restoring FileBrowser to `Up (healthy)`.

## Consequences
* **Positive:** Centralized, responsive start page ("Dixon Fleet") provides single-click access to all homelab and remote brother services with live status dots.
* **Positive:** 24/7 monitoring active via Uptime Kuma for continuous health checks and alerting.
* **Positive:** All 11 Docker containers on LXC 920 are confirmed healthy.
