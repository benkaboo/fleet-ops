# System Architecture & Network Topology

## 1. Host Overview

* **Hostname:** `rath15nas`
* **Operating System:** Debian GNU/Linux 13 (trixie) / Proxmox VE 9 (Kernel `6.17.2-1-pve`)
* **Primary IP:** `192.168.68.169/24` (via `vmbr0`)
* **Default Gateway:** `192.168.68.1`
* **Dedicated GPU:** NVIDIA GeForce GTX 1080 Ti (11 GB VRAM, GP102, PCI ID `10de:1b06`)
* **Driver Stack:** NVIDIA 580.178.04 (Proprietary DKMS, CUDA 13.0, APT pinned via `nvidia-driver-pinning-580`)

---

## 2. Network Topology & Interfaces

| Interface | Type | IP / Subnet | State | Role / Description |
| :--- | :--- | :--- | :--- | :--- |
| `vmbr0` | Linux Bridge | `192.168.68.169/24` | UP | Management LAN & Proxmox Web GUI bridge |
| `vmbr1` | Linux Bridge | Unassigned | DOWN | Secondary bridge |
| `wg0` | WireGuard Interface | `10.10.0.4/24` | UP | WireGuard VPN tunnel (Listening Port: `51820`) |
| `veth910i0` | Virtual Ethernet | Attached to `vmbr0` | UP | Virtual interface for LXC 910 (`codebox`) |
| `veth920i0` | Virtual Ethernet | Attached to `vmbr0` | UP | Virtual interface for LXC 920 (`services`) |

### Routing Table
* `default via 192.168.68.1 dev vmbr0`
* `10.10.0.0/24 dev wg0 proto kernel scope link src 10.10.0.4`
* `192.168.6.0/24 dev wg0 scope link`
* `192.168.68.0/24 dev vmbr0 proto kernel scope link src 192.168.68.169`

### WireGuard Configuration & Peer Inventory (`wg0`)
* **Topology Role:** Inbound Listening Endpoint / Hub (Role Reversal from brother-hosted to Ben-hosted).
* **Listening Port:** `51820` (UDP port forwarded from router `192.168.68.1` $\rightarrow$ `192.168.68.169:51820`).
* **Public Endpoint:** `157.85.240.10:51820` (Neptune Internet dedicated static IPv4).
* **Systemd Service:** `wg-quick@wg0.service` (`enabled` on boot).

#### Registered Peers:
| Peer Name | Virtual IP | Allowed IPs | Roaming / Endpoint | Role / Description |
| :--- | :--- | :--- | :--- | :--- |
| **Brother Router** | `10.10.0.1` | `10.10.0.0/24`, `192.168.6.0/24` | Dynamic / Roaming (`115.70.61.168`) | Site-to-site VPN link to brother's home network (`192.168.6.0/24`). |
| **Ben Mobile Phone** | `10.10.0.5` | `10.10.0.5/32` | Dynamic / Roaming (Cellular / Remote Wi-Fi) | Split-tunnel mobile client for remote homelab management and media access. |

### 2.1. Gateway & NAT Forwarding (Cross-Subnet Access)

To enable client devices on the local LAN (`192.168.68.0/24`) to route to the remote subnet (`192.168.6.0/24`) through Proxmox without requiring changes to the remote peer's routing or AllowedIPs:

* **Kernel IPv4 Forwarding:** `net.ipv4.ip_forward = 1` (persisted via `/etc/sysctl.d/99-wireguard-forwarding.conf`).
* **Lifecycle NAT & Filter Hooks (`/etc/wireguard/wg0.conf`):**
  Rules are automatically applied on tunnel up and cleaned up on tunnel down via `wg-quick` directives:
  ```ini
  PostUp = iptables -t nat -A POSTROUTING -o %i -j MASQUERADE; iptables -A FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -A FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  PostDown = iptables -t nat -D POSTROUTING -o %i -j MASQUERADE; iptables -D FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -D FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  ```
* **Workstation Route:**
  * Windows persistent route: `route -p add 192.168.6.0 mask 255.255.255.0 192.168.68.169`



---

## 3. Storage & Filesystem Architecture

### 3.1. Drive Layout & Btrfs RAID1 Pool

Heterogeneous spinning disk pool configured with Btrfs native chunk mirroring (`raid1` data and metadata):

| Device | Partition | Physical Disk | Size | Role / Filesystem |
| :--- | :--- | :--- | :--- | :--- |
| `/dev/sdd` | `/dev/sdd1` | Seagate IronWolf (`ST4000VN008`) | 3.6 TB | Member of Btrfs pool `data` |
| `/dev/sde` | `/dev/sde1` | WD Red (`WD40EFRX`) | 3.6 TB | Member of Btrfs pool `data` |
| `/dev/sdc` | `/dev/sdc1` | WD Purple (`WD30PURX`) | 2.7 TB | Member of Btrfs pool `data` |
| `/dev/sdb` | *(None)* | Crucial BX500 SSD (`CT1000BX500SSD1`) | 931.5 GB | Spare unallocated flash drive |
| `/dev/sda` | `/dev/sda1..3` | Crucial BX500 SSD (`CT1000BX500SSD1`) | 931.5 GB | PVE Host Boot / OS / LVM thin pool |

* **Pool Mount Point:** `/mnt/data`
* **Usable Protected Storage:** $\approx 4.95\text{ TB}$ (1-disk fault tolerance).
* **Mount Parameters (`/etc/fstab`):**
  ```fstab
  UUID=<FS_UUID>  /mnt/data  btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,nofail,x-systemd.device-timeout=15s  0  2
  ```
* **Subvolume Layout:**
  * `/mnt/data/@simba` — Primary Windows Samba network share.
  * `/mnt/data/@shares` — Secondary / general network storage.
  * `/mnt/data/@backups` — Proxmox host and client backup datasets.

### 3.2. Windows File Sharing (Samba / SMB3)

* **Service Daemon:** `smbd.service` (managed via systemd, auto-enabled).
* **Discovery Daemon:** `wsdd.service` (Web Services Dynamic Discovery for Windows Explorer).
* **Shares:**
  * `[simba]`: Path `/mnt/simba`, `valid users = bjm`, force create/directory mode `0660`/`0770`.
  * `[Shared-All-Family]`: Path `/mnt/simba/Shared-All-Family`, `valid users = bjm`, force create/directory mode `0664`/`0775` (synced via Syncthing).
  * `[Media]`: Path `/mnt/simba/Media`, `valid users = bjm, htpc`, `force user = bjm`, `force group = bjm`, force create/directory mode `0664`/`0775` (contains Movies, Music, TV Shows, Audiobooks, Podcasts for HTPC ripping, network streaming, and Audiobookshelf management).
* **Windows Tuning & Compatibility:**
  * Protocol: `SMB3` with multi-channel support (`server multi channel support = yes`).
  * High-Throughput I/O: Asynchronous I/O (`aio read/write size = 1`), `use sendfile = yes`.
  * NTFS / Windows Compatibility: `store dos attributes = yes`, `ea support = yes`, `vfs objects = btrfs acl_xattr`, `map acl inherit = yes`.
  * Access Control: Multi-client isolation. Administrative access via `bjm`; HTPC optical ripping client restricted to `[Media]` via isolated service account `htpc` (UID 1003). Files written under `[Media]` are forced to `bjm:bjm` with world-readability (`0664`/`0775`) ensuring unprivileged container stacks (Jellyfin) and operator desktops have seamless access.

---

## 4. Virtualization Inventory


| VMID | Type | Name | Status | Memory | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 910 | LXC | `codebox` | Running | - | Development container (`192.168.68.172`) |
| 920 | LXC | `services` | Running | 4096 MB | Docker services host (`192.168.68.175/24`), Ubuntu 24.04, 4 vCPUs |
| 930 | LXC | `agcode` | Running | - | Antigravity execution container |
| 940 | QEMU | `haos` | Provisioning | 2048 MB | Home Assistant OS KVM VM, 2 vCPUs, 32 GB SSD, attached to `vmbr0` |
| 900 | QEMU | `openwrt` | Stopped | 512 MB | Virtual router / firewall |
| 901 | QEMU | `test-lan` | Stopped | 512 MB | Isolated test LAN environment |

### 4.1. Dedicated Microservices & Docker Host (LXC 920: `services`)

* **Container Specifications:**
  * **OS / Template:** Ubuntu 24.04 LTS unprivileged LXC container.
  * **Network:** Static IP `192.168.68.175/24`, Gateway `192.168.68.1`, attached to `vmbr0`.
  * **Resources:** 4 vCPUs, 8192 MB RAM, 32 GB SSD root disk on `local-lvm`.
  * **LXC Features:** `nesting=1,keyctl=1` (required for Docker Engine and secure keyrings).
* **Storage Mounts:**
  * **SSD Fast Data Root (`/opt/stacks`):** GitOps source of truth tracking private repository `git@github.com:benkaboo/homelab-stacks.git` on branch `main` via dedicated read-only deploy key (`~/.ssh/id_ed25519_deploy`). Stores declarative Compose files, proxy rules, and container configs; runtime state and SQLite databases are excluded via `.gitignore`.
  * **Btrfs Media/Pool Bind Mount (`mp0`):** Pass-through from host `/mnt/data/@simba` to container `/mnt/simba` (`/mnt/simba/{Books,Documents,Media,Scripts}`).
* **Docker Network Topology:**
  * **Bridge Network (`gateway_net`):** Dedicated internal bridge network connecting edge proxies and application services without exposing container ports to the external LAN unnecessarily.
* **Service Stack Inventory:**
  * **Dockge** (`/opt/stacks/dockge/compose.yaml`): Web Compose management UI exposed on port `5001`, protected by Authelia SSO, routed via Caddy at `https://dockge.dixon.home` and `https://dockge.192.168.68.175.nip.io`.
  * **Caddy Reverse Proxy** (`/opt/stacks/caddy/compose.yaml`): Edge HTTP/HTTPS reverse proxy on host ports `80` and `443`, joined to `gateway_net`. Dual-stack routing supporting both `*.dixon.home` and `*.192.168.68.175.nip.io` with automated internal PKI TLS certificates. Provides forward-auth integration with Authelia and reverse proxy termination for all local container stacks and remote Maslen services.
  * **LLDAP Identity Provider** (`/opt/stacks/lldap/compose.yaml`): Lightweight LDAP directory server and user management portal exposed on port `3890` (LDAP protocol) and port `17170` (web admin UI), routed via Caddy at `https://ldap.dixon.home` and `https://ldap.192.168.68.175.nip.io`. Joined to `gateway_net`. Authoritative identity source (`dc=home,dc=arpa`) supporting role-based access control groups (`admins`, `family`).
  * **Authelia SSO, 2FA & OIDC Provider** (`/opt/stacks/authelia/compose.yaml`): Centralized authentication portal and OpenID Connect (OIDC) provider exposed on port `9091` and joined to `gateway_net`. Authenticates against local LLDAP directory (`ldap://lldap:3890`). Multi-domain session cookies configured for both `dixon.home` and `192.168.68.175.nip.io`. Secrets decoupled into `/opt/stacks/authelia/.env` using `HOMELAB_` prefix with `X_AUTHELIA_CONFIG_FILTERS=template`. Serves registered OIDC clients (`jellyfin`, `immich`) with dedicated RSA signing key (`/opt/stacks/authelia/config/oidc.key`).
  * **Jellyfin Media Server** (`/opt/stacks/jellyfin/compose.yaml`): Media streaming server exposed on port `8096` and routed via Caddy at `https://jellyfin.dixon.home` and `https://jellyfin.192.168.68.175.nip.io`. Media library mapped read-only from `/mnt/simba/Media`. Configured with application-level OIDC Single Sign-On via `jellyfin-plugin-sso` (v4.0.0.4) using Authelia backend (`client_secret_post`, PAR disabled). Edge proxy uses native routing without forward-auth redirects, preserving smart TV (Sony Android TV) compatibility, Quick Connect, and native mobile clients. Container includes `extra_hosts` mapping `auth.dixon.home:192.168.68.175` and mounts Caddy internal PKI root CA (`/etc/ssl/certs/ca-certificates.crt:ro`) for trusted internal TLS validation.
  * **Calibre-Web E-Book Library** (`/opt/stacks/calibre-web/compose.yaml`): Digital book management exposed on port `8083` and routed via Caddy at `https://books.dixon.home` and `https://books.192.168.68.175.nip.io`. Configured with linuxserver Calibre-Web mods for cover conversion, backed by `/mnt/simba/Books` with seeded `metadata.db`. Supports native LDAP authentication directly to `lldap:3890` enabling OPDS feed authentication for hardware e-readers (Kobo, Kindle).
  * **FileBrowser Web File Manager** (`/opt/stacks/filebrowser/compose.yaml`): Lightweight web file explorer exposed on port `8082`, protected by Authelia SSO with header authentication (`Remote-User`), and routed via Caddy at `https://files.dixon.home` and `https://files.192.168.68.175.nip.io`. Mounts the full Btrfs storage root (`/mnt/simba`) for browser-based file management across all shares. Database permissions maintained at `0664` owned by `1000:1000`.
  * **AdGuard Home Local DNS & Ad-Blocking** (`/opt/stacks/adguard/compose.yaml`): High-performance DNS server and network-wide privacy sinkhole listening on port `53` (TCP/UDP) and port `8085` (direct web). Routed via Caddy at `https://adguard.dixon.home` and `https://adguard.192.168.68.175.nip.io`. Provides internal DNS rewrites for `*.dixon.home` $\rightarrow$ `192.168.68.175` with zero external DNS leakage.
  * **Audiobookshelf** (`/opt/stacks/audiobookshelf/compose.yaml`): Self-hosted audiobook and podcast server exposed on port `13378` and routed via Caddy at `https://audiobooks.dixon.home` and `https://audiobooks.192.168.68.175.nip.io`. Libraries mapped from `/mnt/simba/Media/Audiobooks` and `/mnt/simba/Media/Podcasts`. Uses native authentication at the proxy level to preserve seamless streaming and offline downloads for official and third-party mobile clients (e.g. Absorb, Plappa) as well as the Progressive Web App (PWA).
  * **Immich Photo & Video Management** (`/opt/stacks/immich/compose.yaml`): Self-hosted Google Photos alternative exposed internally on port `2283`, joined to `gateway_net`. Routed via Caddy at `https://photos.dixon.home` and `https://photos.192.168.68.175.nip.io` with internal PKI TLS. Configured with application-level OIDC Single Sign-On against Authelia (`immich` client), while retaining native mobile API authentication for background camera roll uploads. Container includes `extra_hosts` mapping `auth.dixon.home:192.168.68.175`, mounts Caddy internal PKI root CA (`/etc/ssl/certs/ca-certificates.crt:ro`), and injects `NODE_EXTRA_CA_CERTS` for trusted backchannel token verification. PostgreSQL database with vector search (`pgvectors`) hosted on SSD fast storage (`/opt/stacks/immich/postgres`), new camera uploads routed to `/mnt/simba/Shared-All-Family/Photos/Immich/Uploads`, and synced Google Drive photos mapped read-only (`/mnt/media/GoogleDrive:ro`) as an External Library.
  * **Homepage Dashboard ("Dixon Fleet")** (`/opt/stacks/homepage/compose.yaml`): Modern application launchpad and central homelab portal exposed on port `3000` and routed via Caddy at `https://home.dixon.home` and `https://home.192.168.68.175.nip.io` (plain HTTP at `http://home.192.168.68.175.nip.io`). Integrates directly with `/var/run/docker.sock` for live container health telemetry, CPU/RAM stats, bookmarks to both local and remote brother services across WireGuard, and LLDAP directory tile.
  * **Uptime Kuma Health Monitor** (`/opt/stacks/uptime-kuma/compose.yaml`): 24/7 self-hosted monitoring and incident alerting daemon listening on port `3001` and routed via Caddy at `https://status.dixon.home` and `https://status.192.168.68.175.nip.io`. Continuously monitors container HTTP health, gateway ping, and WireGuard remote peer status with push alerting.
  * **Rest-Server Backup Target** (`/opt/stacks/rest-server/compose.yaml`): High-performance, append-only restic backup server exposed on port `8000`, joined to `gateway_net` with persistent storage at `/mnt/backups`. Enforces `--append-only` and `--private-repos` flags to guarantee cryptographic tenant isolation across client endpoints.
  * **Backrest Backup Orchestrator & Snapshot Explorer** (`/opt/stacks/backrest/compose.yaml`): Centralized web-based Restic management dashboard and snapshot browser exposed on port `9898` and joined to `gateway_net`. Routed via Caddy at `https://backup.dixon.home` and `https://backup.192.168.68.175.nip.io` with internal PKI TLS, strictly restricted by Authelia SSO to `group: admins`. Mounts `/opt/stacks` (read-only) and `/mnt/simba` (read-only). Orchestrates a unified three-tier backup architecture:
    * **`workstation_lenovo_bm`** (`/mnt/backups/workstation`): Ingests daily backups from Lenovo ThinkPad (OneDrive, Code repositories, Calibre library).
    * **`rath15_htpc`** (`/mnt/backups/htpc`): Ingests daily backups from living-room HTPC (user profiles, game saves, configs).
    * **`services`** (`/mnt/backups/services`): Automated daily snapshots protecting:
      * **`stacks_and_databases` Plan:** Scheduled daily at 03:00 AEDT, backing up all LXC 920 microservices, environment secrets, and live SQLite databases (`users.db`, `db.sqlite3`, `dockge.db`, `filebrowser.db`, `app.db`, `kuma.db`) with zero-knowledge operator encryption. Retention: 24 hourly, 30 daily, 12 monthly.
      * **`family_photos` Plan:** Scheduled daily at 04:00 AEDT, backing up `/userdata/simba/Shared-All-Family/Photos` (including synced Google Drive libraries) to the encrypted Btrfs backup pool. Retention: 30 daily, 12 monthly, 5 yearly.
    * **Server-Side Google Drive Photo Ingestion:**
      * **Automation:** Managed via systemd service and timer (`rclone-photos-sync.service` / `rclone-photos-sync.timer`) running daily at 02:00 AEDT on LXC 920.
      * **Ingestion Script:** Executed via `/home/bjm/scripts/sync-gdrive-photos.sh`, logging to `/home/bjm/logs/rclone-photos-sync.log` with logrotate policy (`/etc/logrotate.d/rclone-photos-sync`).
      * **Safety Constraints:** Uses `scope = drive.readonly` OAuth token to prevent any cloud modification or deletion, and non-destructive `rclone copy` with rate pacing (`--tpslimit 8`) targeting `/mnt/simba/Shared-All-Family/Photos/GoogleDrive`.
    * **Synchronized Maintenance Lifecycle:** Enforces rolling **7-4-12** retention (7 daily, 4 weekly, 12 monthly) and weekly prune execution on Sundays at 02:00 AM across all repositories, with monthly repository integrity checks (`restic check`) on the 1st of every month at 03:00 AM.
* **Deployment Automation:**
  * Declarative GitOps repository (`git@github.com:benkaboo/homelab-stacks.git`) synchronized to `/opt/stacks`.
  * Legacy modularized provisioning scripts retained in [`scripts/lxc-setup/`](scripts/lxc-setup/) for disaster recovery reference.

### 4.2. Dedicated Home Automation Host (VM 940: `haos`)

* **Virtual Machine Specifications:**
  * **OS / Flavor:** Home Assistant OS (HAOS) official KVM / QEMU appliance.
  * **Network:** Attached to `vmbr0` (Management / Main LAN `192.168.68.0/24`), dynamic DHCP allocation from router (`192.168.68.1`).
  * **Resources:** 2 vCPUs (`host` type), 2048 MB RAM (expandable on-demand), 32 GB SSD boot disk on `local-lvm`.
  * **Architecture & Features:** UEFI (`ovmf`) BIOS, `q35` machine type, `virtio-scsi-pci` controller with SSD discard enabled, QEMU guest agent enabled (`agent: 1`).
* **Topology & Integration Role:**
  * Direct L2 bridge on `vmbr0` enables native, zero-forwarding mDNS / SSDP broadcast auto-discovery for local smart home hardware:
    * **Google Cast:** Google Nest Audio, Nest Mini, and Chromecast devices for local media playback and Text-to-Speech (TTS) announcements.
    * **Local IoT:** Direct LAN communication with Matter/Thread controllers, local switches, and future USB Zigbee/Z-Wave coordinators via host USB passthrough.
* **Reverse Proxy & Ingress Routing:**
  * Configured Caddy routes on LXC 920 (`/opt/stacks/caddy/Caddyfile`) proxying to `192.168.68.170:80`:
    * HTTPS: `https://ha.dixon.home` and `https://ha.192.168.68.175.nip.io` (internal PKI TLS).
    * HTTP: `http://ha.192.168.68.175.nip.io` and `http://ha.dixon.home`.
  * Trusted proxy configuration managed via Home Assistant UI (**Settings > System > Network**) with `192.168.68.175` authorized.
* **Deployment Automation:**
  * Staged installation script: [`scripts/setup-haos-vm.sh`](scripts/setup-haos-vm.sh)
  * Workstation orchestrator: [`scripts/deploy-haos-vm.ps1`](scripts/deploy-haos-vm.ps1)
  * Caddy reverse proxy automation: [`scripts/configure-caddy-ha.sh`](scripts/configure-caddy-ha.sh) / [`scripts/deploy-caddy-ha.ps1`](scripts/deploy-caddy-ha.ps1)

---

## 5. Access Control & Security Boundaries

Access to `rath15nas` is partitioned by role adhering to the Principle of Least Privilege (PoLP):

```mermaid
graph TD
    subgraph Local Workstation
        A[Operator Workstation]
        K1[~/.ssh/id_ed25519]
        K2[~/.ssh/id_ed25519_agy]
    end

    subgraph Proxmox Host: rath15nas (192.168.68.169)
        U1[User: bjm]
        U2[User: agy-auditor]
        S1[Full Sudo / Sudoers]
        S2["Sudoers Read-Only (/etc/sudoers.d/agy-readonly)"]
    end

    subgraph Services Container: LXC 920 (192.168.68.175)
        U3[User: agy-auditor]
        S3["Sudoers Read-Only (/etc/sudoers.d/agy-readonly)"]
        R0["Root SSH: REVOKED (No Authorized Keys)"]
    end

    A -- "ssh bjm@192.168.68.169" --> U1
    K1 --> U1
    U1 --> S1

    A -- "ssh rath15nas-agent" --> U2
    K2 --> U2
    U2 --> S2

    A -- "ssh services-agent" --> U3
    K2 --> U3
    U3 --> S3
```

### 5.1. Account Matrix

* **Administrative Operator (`bjm`):**
  * Interactive administrative access on Proxmox hypervisor (`rath15nas`).
  * Sudo access with password authentication.
  * Sole administrator authorized to execute mutating container scripts via `sudo pct exec 920` or host bash.

* **Proxmox Audit & Automation Service Account (`agy-auditor` on `rath15nas`):**
  * Non-interactive service account dedicated to automated hypervisor diagnostics, auditing, and network telemetry.
  * Password login: Disabled (`passwd -l`).
  * Authentication: Dedicated key pair (`~/.ssh/id_ed25519_agy`).
  * SSH Host Alias: `rath15nas-agent` (`HostName 192.168.68.169`, `User agy-auditor`).
  * Permissions: Strict read-only sudoers whitelist defined in `/etc/sudoers.d/agy-readonly`.

* **Container Audit Service Account (`agy-auditor` on LXC 920 `services`):**
  * Non-interactive service account dedicated to container and Docker stack inspection.
  * Password login: Disabled (`passwd -l`).
  * Authentication: Dedicated key pair (`~/.ssh/id_ed25519_agy`).
  * SSH Host Alias: `services-agent` (`HostName 192.168.68.175`, `User agy-auditor`).
  * Permissions: Strict read-only sudoers whitelist in `/etc/sudoers.d/agy-readonly` allowing `docker ps`, `docker inspect`, `docker logs`, `systemctl status`, `ss`, and reading Compose files.
  * Root Account: `/root/.ssh/authorized_keys` revoked. Root login completely disabled.
  * Mutating Actions: Strictly denied (no `docker run`, `docker exec`, `docker stop`, or filesystem mutations).

* **HTPC File Sharing Service Account (`htpc`):**
  * Dedicated service account for living-room optical media ripping (MakeMKV, Handbrake).
  * System User: UID `1003`, primary group `users` (GID 100), shell `/usr/sbin/nologin` (no interactive console/SSH shell access).
  * Scope: Restricted exclusively to `[Media]` share (`/mnt/simba/Media`).
  * Forced Ownership: Samba writes executed under `bjm:bjm` identity (`force user = bjm`, `force group = bjm`) with `0664`/`0775` permissions.

* **GitOps Deploy Key (`~/.ssh/id_ed25519_deploy` on LXC 920):**
  * Dedicated SSH key pair under `bjm` configured in `~/.ssh/config` for `Host github.com`.
  * Scope: Registered as a strictly read-only Deploy Key on private GitHub repository `benkaboo/homelab-stacks`.
  * Role: Autonomous configuration synchronization (`git pull`) for `/opt/stacks` without operator credential exposure.

* **LLDAP Identity Directory (`dc=home,dc=arpa` on LXC 920):**
  * Central LDAP directory and single source of truth for user authentication and role-based access control (RBAC).
  * Standard Groups:
    * `admins`: Administrative access for infrastructure, Dockge, DNS, and hypervisors.
    * `family`: Read and streaming access for Jellyfin, Calibre-Web, and Audiobookshelf.
    * `lldap_admin`: Administrative access to manage LLDAP directory schema, users, and groups.
  * Directory Accounts: `admin` (LDAP service bind account), `bjm` (operator account with `admins`, `family`, `lldap_admin` memberships).

### 5.2. Sudoers Whitelists

#### Proxmox Host (`/etc/sudoers.d/agy-readonly` on `rath15nas`):
```sudoers
agy-auditor ALL=(ALL) NOPASSWD: \
    /usr/bin/wg show*, \
    /usr/sbin/iptables -S*, \
    /usr/sbin/iptables -L*, \
    /usr/sbin/nft list*, \
    /usr/sbin/pct list, \
    /usr/sbin/qm list, \
    /usr/bin/systemctl status *
```

#### Services Container (`/etc/sudoers.d/agy-readonly` on LXC 920):
```sudoers
agy-auditor ALL=(ALL) NOPASSWD: \
    /usr/bin/docker ps*, \
    /usr/bin/docker inspect*, \
    /usr/bin/docker logs*, \
    /usr/bin/systemctl status*, \
    /usr/bin/ss*, \
    /usr/bin/cat /opt/stacks/*
```

### 5.3. Privilege History & Posture Status

* **Current Status:** Purely read-only least privilege across both hypervisor (`rath15nas-agent`) and container (`services-agent`).
* **Root SSH on Container:** Permanently revoked. Direct mutation by agents is cryptographically and administratively impossible. All state mutations must be provided as reviewed scripts executed by operator `bjm`.

---

## 6. Agent & Tooling Environment

* **Workstation AGY Agent:** Runs on the operator's Windows laptop, connecting remotely via `ssh rath15nas-agent` for telemetry and diagnostics.
* **Host-Local AGY Agent:** Installed directly on `rath15nas` (`~/.local/bin/agy` v1.1.27) for local terminal-driven administration and maintenance tasks.
* **Automation Scripts:** Maintained under [`scripts/`](scripts/) for turnkey, reproducible deployments:
  * [`deploy-samba.ps1`](scripts/deploy-samba.ps1) & [`setup-samba.sh`](scripts/setup-samba.sh): Initial Btrfs storage pool Samba configuration.
  * [`deploy-htpc-media.ps1`](scripts/deploy-htpc-media.ps1) & [`setup-htpc-media-share.sh`](scripts/setup-htpc-media-share.sh): Dedicated HTPC `[Media]` share and `htpc` service account setup.
  * [`scripts/lxc-setup/`](scripts/lxc-setup/): Turnkey provisioning pipeline for LXC 920, Docker, Caddy, Authelia, Jellyfin, and Calibre-Web.
