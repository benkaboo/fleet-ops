# ADR-0010: Audiobookshelf Audiobook & Podcast Server Deployment on LXC 920

* **Status:** Accepted
* **Date:** 2026-09-07
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Dedicated Spoken-Word Media Management:** The homelab required an accessible, high-performance platform for managing audiobooks and podcasts with progress synchronization across web browsers, e-readers, and dedicated mobile apps (iOS and Android).
2. **Storage Architecture & SMB Integration:** Media files need to reside on the resilient Btrfs RAID1 storage pool (`/mnt/data/@simba/Media`) while application metadata and SQLite databases require high-IOPS NVMe/SSD storage (`/opt/stacks/audiobookshelf`). Rather than creating a disjoint root share, nesting `Audiobooks` and `Podcasts` inside `/mnt/simba/Media` allows direct drag-and-drop ingestion via Windows SMB (`\\rath15nas\Media` or `M:\`) alongside `Movies`, `Music`, and `TV Shows`.
3. **Unprivileged Container Permission Boundaries:** Container LXC 920 is an unprivileged container (UID mapping 100000+). Initializing storage directories from inside the container (`pct exec`) triggers permission denial against host-owned directories (`bjm:bjm`, mode 775). Provisioning must occur directly on the host with open write permissions (`0777`) so container processes and SMB users can write simultaneously.
4. **Mobile Client Compatibility:** Official Audiobookshelf mobile apps fail if wrapped in reverse-proxy forward-auth redirects. The endpoint requires direct native authentication at the Caddy proxy level.

## Action
1. **Turnkey Deployment Pipeline (`11-deploy-audiobookshelf.sh`):**
   * Pre-provisioned Btrfs storage directories on the Proxmox host at `/mnt/data/@simba/Media/Audiobooks` and `/mnt/data/@simba/Media/Podcasts` with `0777` permissions owned by `bjm:bjm` (`1000:1000`).
   * Created application state directories on the SSD root at `/opt/stacks/audiobookshelf/config` and `/opt/stacks/audiobookshelf/metadata`.
2. **Container Stack Provisioning:**
   * Deployed `ghcr.io/advplyr/audiobookshelf:latest` in `/opt/stacks/audiobookshelf/compose.yaml` on host port `13378:80`.
   * Attached the container to internal bridge `gateway_net` for isolated proxy communication.
   * Bind-mounted `/mnt/simba/Media/Audiobooks` to `/audiobooks` and `/mnt/simba/Media/Podcasts` to `/podcasts`.
3. **Reverse Proxy & Domain Routing:**
   * Added Caddy site blocks for `audiobooks.dixon.home` and `audiobooks.192.168.68.175.nip.io` using automated internal TLS and native reverse proxy to `audiobookshelf:80`.
   * Leveraged AdGuard Home's wildcard rewrite `*.dixon.home` $\rightarrow$ `192.168.68.175` for instant local resolution.
4. **Validation:**
   * Validated database initialization (`absdatabase.sqlite`), SQLite extensions, and HTTP 200 responses via Caddy edge proxy.

## Consequences
* **Positive:** Complete, self-hosted audiobook and podcast streaming server active with multi-device listening progress sync.
* **Positive:** Seamless Windows desktop management: audiobooks and podcasts can be dropped directly into `M:\Audiobooks` and `M:\Podcasts`.
* **Positive:** Official iOS and Android mobile apps can connect directly via `https://audiobooks.dixon.home` without proxy redirect issues.
* **Positive:** High performance achieved by isolating high-write SQLite databases on SSD while keeping bulk audio on Btrfs RAID1.
* **Operational:** Verified client playback, browser downloading, and offline downloading via third-party mobile clients (e.g. Absorb) over direct LAN.
