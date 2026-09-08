# System Architecture & Network Topology

## 1. Host Overview

* **Hostname:** `rath15nas`
* **Operating System:** Debian GNU/Linux 13 (trixie) / Proxmox VE
* **Primary IP:** `192.168.68.169/24` (via `vmbr0`)
* **Default Gateway:** `192.168.68.1`

---

## 2. Network Topology & Interfaces

| Interface | Type | IP / Subnet | State | Role / Description |
| :--- | :--- | :--- | :--- | :--- |
| `vmbr0` | Linux Bridge | `192.168.68.169/24` | UP | Management LAN & Proxmox Web GUI bridge |
| `vmbr1` | Linux Bridge | Unassigned | DOWN | Secondary bridge |
| `wg0` | WireGuard Interface | `10.10.0.4/24` | UP | WireGuard VPN tunnel (Port: `40846`) |
| `veth910i0` | Virtual Ethernet | Attached to `vmbr0` | UP | Virtual interface for LXC 910 (`codebox`) |
| `veth920i0` | Virtual Ethernet | Attached to `vmbr0` | UP | Virtual interface for LXC 920 (`services`) |

### Routing Table
* `default via 192.168.68.1 dev vmbr0`
* `10.10.0.0/24 dev wg0 proto kernel scope link src 10.10.0.4`
* `192.168.6.0/24 dev wg0 scope link`
* `192.168.68.0/24 dev vmbr0 proto kernel scope link src 192.168.68.169`

### WireGuard Peer Configuration (`wg0`)
* **Endpoint:** `203.132.95.12:51820`
* **Allowed IPs:** `10.10.0.0/24`, `192.168.6.0/24`
* **Persistent Keepalive:** 25 seconds
* **Systemd Service:** `wg-quick@wg0.service` (`enabled` on boot)

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
| 910 | LXC | `codebox` | Stopped | - | Development container (`192.168.68.172`) |
| 920 | LXC | `services` | Running | 4096 MB | Docker services host (`192.168.68.175/24`), Ubuntu 24.04, 4 vCPUs |
| 900 | QEMU | `openwrt` | Stopped | 512 MB | Virtual router / firewall |
| 901 | QEMU | `test-lan` | Stopped | 512 MB | Isolated test LAN environment |

### 4.1. Dedicated Microservices & Docker Host (LXC 920: `services`)

* **Container Specifications:**
  * **OS / Template:** Ubuntu 24.04 LTS unprivileged LXC container.
  * **Network:** Static IP `192.168.68.175/24`, Gateway `192.168.68.1`, attached to `vmbr0`.
  * **Resources:** 4 vCPUs, 4096 MB RAM, 32 GB SSD root disk on `local-lvm`.
  * **LXC Features:** `nesting=1,keyctl=1` (required for Docker Engine and secure keyrings).
* **Storage Mounts:**
  * **SSD Fast Data Root (`/opt/stacks`):** Stores Compose files, container configurations, and local application databases (e.g. Authelia SQLite).
  * **Btrfs Media/Pool Bind Mount (`mp0`):** Pass-through from host `/mnt/data/@simba` to container `/mnt/simba` (`/mnt/simba/{Books,Documents,Media,Scripts}`).
* **Docker Network Topology:**
  * **Bridge Network (`gateway_net`):** Dedicated internal bridge network connecting edge proxies and application services without exposing container ports to the external LAN unnecessarily.
* **Service Stack Inventory:**
  * **Dockge** (`/opt/stacks/dockge/compose.yaml`): Web Compose management UI exposed on port `5001`, protected by Authelia SSO, routed via Caddy at `https://dockge.dixon.home` and `https://dockge.192.168.68.175.nip.io`.
  * **Caddy Reverse Proxy** (`/opt/stacks/caddy/compose.yaml`): Edge HTTP/HTTPS reverse proxy on host ports `80` and `443`, joined to `gateway_net`. Dual-stack routing supporting both `*.dixon.home` and `*.192.168.68.175.nip.io` with automated internal PKI TLS certificates.
  * **Authelia SSO, 2FA & OIDC Provider** (`/opt/stacks/authelia/compose.yaml`): Centralized authentication portal and OpenID Connect (OIDC) provider exposed on port `9091` and joined to `gateway_net`. Multi-domain session cookies configured for both `dixon.home` and `192.168.68.175.nip.io`. User database uses Argon2id password hashing; storage backed by `/opt/stacks/authelia/data/db.sqlite3`. Configured with `X_AUTHELIA_CONFIG_FILTERS=template` for dynamic secret templating and dedicated RSA signing key (`/opt/stacks/authelia/config/oidc.key`) serving registered OIDC clients (e.g. `jellyfin`).
  * **Jellyfin Media Server** (`/opt/stacks/jellyfin/compose.yaml`): Media streaming server exposed on port `8096` and routed via Caddy at `https://jellyfin.dixon.home` and `https://jellyfin.192.168.68.175.nip.io`. Media library mapped read-only from `/mnt/simba/Media`. Configured with application-level OIDC Single Sign-On via `jellyfin-plugin-sso` (v4.0.0.4) using Authelia backend (`client_secret_post`, PAR disabled). Edge proxy uses native routing without forward-auth redirects, preserving smart TV (Sony Android TV) compatibility, Quick Connect, and native mobile clients. Container includes `extra_hosts` mapping `auth.dixon.home:192.168.68.175` and mounts Caddy internal PKI root CA (`/etc/ssl/certs/ca-certificates.crt:ro`) for trusted internal TLS validation.
  * **Calibre-Web E-Book Library** (`/opt/stacks/calibre-web/compose.yaml`): Digital book management exposed on port `8083` and routed via Caddy at `https://books.dixon.home` and `https://books.192.168.68.175.nip.io`. Configured with linuxserver Calibre-Web mods for cover conversion, backed by `/mnt/simba/Books` with seeded `metadata.db`.
  * **FileBrowser Web File Manager** (`/opt/stacks/filebrowser/compose.yaml`): Lightweight web file explorer exposed on port `8082`, protected by Authelia SSO, and routed via Caddy at `https://files.dixon.home` and `https://files.192.168.68.175.nip.io`. Mounts the full Btrfs storage root (`/mnt/simba`) for browser-based file management across all shares.
  * **AdGuard Home Local DNS & Ad-Blocking** (`/opt/stacks/adguard/compose.yaml`): High-performance DNS server and network-wide privacy sinkhole listening on port `53` (TCP/UDP) and port `8085` (direct web). Routed via Caddy at `https://adguard.dixon.home` and `https://adguard.192.168.68.175.nip.io`. Provides internal DNS rewrites for `*.dixon.home` $\rightarrow$ `192.168.68.175` with zero external DNS leakage.
  * **Audiobookshelf** (`/opt/stacks/audiobookshelf/compose.yaml`): Self-hosted audiobook and podcast server exposed on port `13378` and routed via Caddy at `https://audiobooks.dixon.home` and `https://audiobooks.192.168.68.175.nip.io`. Libraries mapped from `/mnt/simba/Media/Audiobooks` and `/mnt/simba/Media/Podcasts`. Uses native authentication at the proxy level to preserve seamless streaming and offline downloads for official and third-party mobile clients (e.g. Absorb, Plappa) as well as the Progressive Web App (PWA).
* **Deployment Automation:**
  * Modularized scripts located in [`scripts/lxc-setup/`](scripts/lxc-setup/) (`01-create-lxc.sh` through `14-setup-readonly-auditor.sh`).

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
