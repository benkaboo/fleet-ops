# ADR-0005: Media Applications Deployment (Jellyfin & Calibre-Web) on LXC 920

* **Status:** Accepted
* **Date:** 2026-09-06
* **Component:** Media & Applications
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Media Streaming:** Living-room clients, mobile devices, and smart TVs require high-performance, direct-play and hardware-assisted media streaming without needing raw SMB network drive access.
2. **Digital Library Management:** An accessible e-book library is required for reading, metadata management, and conversion on local devices without exposing raw storage filesystems to unauthenticated clients.
3. **Container Storage Architecture:** Both stacks require high-speed configuration databases on NVMe/SSD storage while reading bulk libraries from the resilient Btrfs storage pool (`/mnt/simba`).

## Action
1. **Jellyfin Media Server Deployment (`08-deploy-jellyfin.sh`):**
   * Deployed official `jellyfin/jellyfin:latest` stack in `/opt/stacks/jellyfin/compose.yaml` on host port `8096`.
   * Bind-mounted `/mnt/simba/Media` as read-only (`:ro`) into container `/media`.
   * Routed HTTPS endpoint `https://jellyfin.192.168.68.175.nip.io` via Caddy with native authentication to support smart TV and mobile client apps.
2. **Calibre-Web E-Book Library Deployment (`09-deploy-calibre-web.sh`):**
   * Deployed `lscr.io/linuxserver/calibre-web:latest` in `/opt/stacks/calibre-web/compose.yaml` on host port `8083`.
   * Seeded official starter `metadata.db` into `/mnt/simba/Books/metadata.db`.
   * Configured dynamic DOCKER_MODS (`linuxserver/mods:universal-calibre`) with polling retry validation for automated e-book cover conversion and format processing.
   * Routed HTTPS endpoint `https://books.192.168.68.175.nip.io` via Caddy with Authelia forward authentication.

## Consequences
* **Positive:** High-performance media playback and digital reading portals available across the home LAN.
* **Positive:** Bulk media datasets remain protected in read-only mode for streaming, preventing accidental deletion from client apps.
