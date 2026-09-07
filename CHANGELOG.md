# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), with architectural changes recorded in Architectural Decision Record (ADR) format.

## [2026-09-06]

### ADR: Dedicated Read-Only Service Account (`agy-auditor`) for Agent Telemetry

#### Context
Automated diagnostic workflows and pair-programming agents require inspection access to host network interfaces (`wg0`, `vmbr0`), firewall rules (`iptables`, `nftables`), virtualization status (`pct`, `qm`), and system service health on `rath15nas` (`192.168.68.169`). Granting unrestricted administrative access or sharing the interactive `bjm` account creates security risks and violates the Principle of Least Privilege (PoLP).

#### Action
1. Provisioned dedicated system user `agy-auditor` on `rath15nas` with disabled password authentication (`passwd -l`).
2. Configured public-key-only SSH access using dedicated key `~/.ssh/id_ed25519_agy` into `/home/agy-auditor/.ssh/authorized_keys` with `700`/`600` permissions owned by `agy-auditor:agy-auditor`.
3. Added `/etc/sudoers.d/agy-readonly` allowing passwordless sudo strictly for read-only inspection commands:
   * `/usr/bin/wg show*`
   * `/usr/sbin/iptables -S*`
   * `/usr/sbin/iptables -L*`
   * `/usr/sbin/nft list*`
   * `/usr/sbin/pct list`
   * `/usr/sbin/qm list`
   * `/usr/bin/systemctl status *`
4. Added SSH client alias `rath15nas-agent` in `~/.ssh/config` pointing to `192.168.68.169` as user `agy-auditor` with `IdentityFile ~/.ssh/id_ed25519_agy`.

#### Consequences
* **Positive:** Diagnostic tools and agents can inspect WireGuard tunnel state, packet filters, container states, and service status non-interactively without requiring administrative passwords.
* **Positive:** Mutating commands (e.g., stopping services, modifying routing/firewall rules, editing configuration files) are explicitly denied by sudo.
* **Operational:** All future agent-driven telemetry and diagnostic queries target `rath15nas-agent`. Administrative operations remain restricted to `bjm` via explicit operator approval.

### ADR: WireGuard Boot Persistence & Cross-Subnet Gateway Routing

#### Context
1. **Reboot Persistence:** WireGuard was previously started interactively/manually without systemd service management. On host reboot, the tunnel would not automatically reconnect.
2. **Cross-Subnet Access:** Operator workstations on the local LAN (`192.168.68.0/24`) need to reach the remote peer network (`192.168.6.0/24`) across the WireGuard tunnel. The Proxmox host lacked kernel packet forwarding and NAT masquerading, causing packets to be dropped or rejected due to asymmetric routes and WireGuard cryptokey routing constraints.

#### Action
1. **Phase 1 (Persistence):**
   * Enabled `wg-quick@wg0.service` in systemd (`systemctl enable wg-quick@wg0`) to ensure tunnel creation on boot milestone.
   * Validated tunnel endpoint connectivity (`ping -c 3 10.10.0.1`) and handshake status.
2. **Phase 2 (Cross-Subnet Gateway):**
   * Enabled IPv4 kernel forwarding (`sysctl -w net.ipv4.ip_forward=1`).
   * Configured NAT masquerading on the WireGuard egress interface (`iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE`).
   * Configured stateful filter forwarding rules (`iptables -A FORWARD -d 192.168.6.0/24 -o wg0 -j ACCEPT` and `iptables -A FORWARD -i wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT`).
   * Defined static route on client workstation: `route -p add 192.168.6.0 mask 255.255.255.0 192.168.68.169`.
3. **Phase 3 (Persistence Lock-In & Privilege Revocation):**
   * Appended `PostUp` and `PostDown` hooks into `/etc/wireguard/wg0.conf` for automatic iptables lifecycle management.
   * Persisted kernel forwarding across boots via `/etc/sysctl.d/99-wireguard-forwarding.conf`.
   * Revoked temporary scoped permissions (`/etc/sudoers.d/agy-wireguard`), returning `agy-auditor` strictly to least-privilege read-only inspection (`/etc/sudoers.d/agy-readonly`).
   * Tagged release: `v1.0-wireguard-routing`.

#### Consequences
* **Positive:** Complete host-side WireGuard and routing lifecycle automatically persists across reboots.
* **Positive:** Local LAN clients can transparently route traffic to `192.168.6.0/24` via Proxmox (`192.168.68.169`) without requiring changes to the remote peer's router or AllowedIPs list.
* **Security:** `agy-auditor` credentials and privileges are strictly locked down to read-only diagnostics; secrets remain isolated from automation.

### ADR: Multi-Device Btrfs RAID1 Pool, Windows-Optimized Samba Share, and AGY Host Runtime

#### Context
1. **Storage Infrastructure:** The host had unformatted or legacy single-disk partitions (`sdd1`, `sde1`, `sdc1`). Resilient, self-healing shared network storage was required across heterogeneous drives (4 TB Seagate IronWolf, 4 TB WD Red, 3 TB WD Purple).
2. **Network File Sharing:** Local workstations on the network are predominantly Windows clients requiring fast, reliable file access with support for Windows metadata, file locking, and alternate data streams.
3. **Host Administration:** Operating the Proxmox server directly benefits from a local AI assistant runtime on the hypervisor host in addition to the remote workstation agent.

#### Action
1. **Btrfs RAID1 Storage Pool:**
   * Formatted `/dev/sdd1`, `/dev/sde1`, and `/dev/sdc1` as a Btrfs `raid1` array (data & metadata) mounted at `/mnt/data`.
   * Created dedicated subvolumes: `/mnt/data/@simba`, `/mnt/data/@shares`, and `/mnt/data/@backups`.
   * Configured `/etc/fstab` persistence with options `defaults,noatime,compress=zstd:1,space_cache=v2,nofail,x-systemd.device-timeout=15s`.
2. **Windows-Optimized Samba (SMB3) Service:**
   * Installed `samba` and configured `/etc/samba/smb.conf` with Windows-first tuning (`SMB3`, `server multi channel support`, `aio read/write size = 1`, `use sendfile = yes`, `store dos attributes = yes`, `ea support = yes`, `vfs objects = streams_xattr acl_xattr`).
   * Configured share `[simba]` mapped to `/mnt/data/@simba`, restricted to authenticated user `bjm` with forced `0664`/`0775` permission masking.
   * Enabled and started `smbd.service` via systemd.
3. **Deployment Automation:**
   * Added interactive variable-prompting deployment scripts: [`scripts/deploy-samba.ps1`](scripts/deploy-samba.ps1) (PowerShell) and [`scripts/setup-samba.sh`](scripts/setup-samba.sh) (Bash).
4. **Antigravity Host Runtime:**
   * Installed Google Antigravity CLI (`agy` v1.1.27) directly on the Proxmox host (`~/.local/bin/agy`).

#### Consequences
* **Positive:** ~4.95 TB of resilient, self-healing mirrored storage with 1-disk fault tolerance across mismatched disk capacities.
* **Positive:** Native, high-performance file sharing for Windows clients with zero permission friction.
* **Positive:** Local `agy` presence on the Proxmox hypervisor enables direct on-host troubleshooting, while remote operations continue through the least-privilege `agy-auditor` SSH alias.

### ADR: Dedicated Docker Services Container (LXC 920), Reverse Proxy Gateway, and Authelia SSO Portal

#### Context
1. **Service Isolation & Lifecycle:** Running self-hosted media and application stacks (Dockge, Caddy, Authelia, Jellyfin, Calibre-Web) directly on the Proxmox hypervisor (`rath15nas`) compromises host stability, security, and backup simplicity. A dedicated, lightweight, unprivileged environment was required.
2. **Access Control & User Experience:** Local network clients (including family members using the Home Theatre PC and Windows Samba shares) must not have their existing network connectivity or file access disrupted. However, web interfaces for management, media, and tools need centralized Single Sign-On (SSO) and Two-Factor Authentication (2FA) without exposing unauthenticated ports to the LAN or internet.
3. **Storage & Performance Requirements:** Application metadata, databases (e.g. SQLite), and Docker overlay files require high-IOPS NVMe/SSD storage (`local-lvm`), while bulk media datasets (`Media/`, `Books/`) reside on the resilient Btrfs RAID1 storage pool mounted at `/mnt/data/@simba`.

#### Action
1. **LXC Container Provisioning (`01-create-lxc.sh`, `02-bindmount-and-start.sh`):**
   * Created unprivileged Ubuntu 24.04 LTS container `920` (`services`) with 4 vCPUs, 4096 MB RAM, and 32 GB SSD root disk on `local-lvm`.
   * Assigned static IP `192.168.68.175/24` with gateway `192.168.68.1` bridged to `vmbr0`.
   * Enabled container features `nesting=1,keyctl=1` to support Docker Engine and secure system keyrings.
   * Bind-mounted host Btrfs subvolume `/mnt/data/@simba` to container `/mnt/simba` (`mp0`), granting the container direct filesystem access to `Books/`, `Documents/`, `Media/`, and `Scripts/`.
2. **Docker Runtime & Web Stack Management (`03-install-docker.sh`, `04-deploy-dockge.sh`):**
   * Installed official Docker Engine (`v29.8.0`) and Docker Compose (`v5.5.1`) inside LXC 920.
   * Deployed Dockge on host port `5001` with stack root configured at `/opt/stacks` on high-speed SSD storage.
3. **Edge Reverse Proxy & Internal Network (`05-deploy-caddy.sh`):**
   * Created internal Docker bridge network `gateway_net` for secure inter-container routing.
   * Deployed Caddy reverse proxy container listening on host ports `80` and `443` (TCP/UDP).
4. **Authelia SSO & 2FA Portal (`06-deploy-authelia.sh`):**
   * Deployed Authelia container attached to `gateway_net` with external port `9091`.
   * Configured wildcard domain `192.168.68.175.nip.io` for seamless cross-subdomain session cookie sharing across LAN clients without client-side `hosts` modification.
   * Generated cryptographically secure secrets (`JWT_SECRET`, `SESSION_SECRET`, `STORAGE_KEY`) and Argon2id password hash for administrator `bjm`.
   * Backed configuration and SQLite database in persistent directories `/opt/stacks/authelia/config/` and `/opt/stacks/authelia/data/`.
   * Automated configuration validation with `authelia config validate` and validated `/api/health` returns `{"status":"ok"}`.

#### Consequences
* **Positive:** Complete isolation of Docker containers inside an unprivileged LXC guest; hypervisor OS remains pristine.
* **Positive:** Family network traffic (HTPC, Windows file shares) remains entirely untouched and operational.
* **Positive:** High I/O performance achieved through SSD-backed Docker stacks paired with high-capacity Btrfs storage for media.
* **Security:** All sensitive materials (passwords, JWT secrets, session keys) are generated on-demand at deployment time and excluded from Git version control. Reproducible deployment scripts are maintained in [`scripts/lxc-setup/`](scripts/lxc-setup/).

### ADR: Media Applications Deployment (Jellyfin & Calibre-Web) on LXC 920

#### Context
1. **Media Streaming:** Living-room clients, mobile devices, and smart TVs require high-performance, direct-play and hardware-assisted media streaming without needing raw SMB network drive access.
2. **Digital Library Management:** An accessible e-book library is required for reading, metadata management, and conversion on local devices without exposing raw storage filesystems to unauthenticated clients.
3. **Container Storage Architecture:** Both stacks require high-speed configuration databases on NVMe/SSD storage while reading bulk libraries from the resilient Btrfs storage pool (`/mnt/simba`).

#### Action
1. **Jellyfin Media Server Deployment (`08-deploy-jellyfin.sh`):**
   * Deployed official `jellyfin/jellyfin:latest` stack in `/opt/stacks/jellyfin/compose.yaml` on host port `8096`.
   * Bind-mounted `/mnt/simba/Media` as read-only (`:ro`) into container `/media`.
   * Routed HTTPS endpoint `https://jellyfin.192.168.68.175.nip.io` via Caddy with native authentication to support smart TV and mobile client apps.
2. **Calibre-Web E-Book Library Deployment (`09-deploy-calibre-web.sh`):**
   * Deployed `lscr.io/linuxserver/calibre-web:latest` in `/opt/stacks/calibre-web/compose.yaml` on host port `8083`.
   * Seeded official starter `metadata.db` into `/mnt/simba/Books/metadata.db`.
   * Configured dynamic DOCKER_MODS (`linuxserver/mods:universal-calibre`) with polling retry validation for automated e-book cover conversion and format processing.
   * Routed HTTPS endpoint `https://books.192.168.68.175.nip.io` via Caddy with Authelia forward authentication.

#### Consequences
* **Positive:** High-performance media playback and digital reading portals available across the home LAN.
* **Positive:** Bulk media datasets remain protected in read-only mode for streaming, preventing accidental deletion from client apps.

### ADR: Dedicated HTPC Service Account and Isolated [Media] Samba Share

#### Context
1. **Optical Media Ripping Workflow:** The Home Theatre PC (`rath15-htpc`, `192.168.68.162`) requires direct filesystem write access to the media repository (`/mnt/simba/Media`) to dump DVD and Blu-ray rips (MakeMKV, Handbrake) directly into `Movies`, `TV Shows`, and `Music`.
2. **Windows Multi-Session Collision:** Windows clients permit only one authenticated user context per target server IP/hostname. When the HTPC connected anonymously or with local machine credentials (due to Samba's `map to guest = Bad User`), subsequent attempts to authenticate to `[simba]` as `bjm` triggered client-side Windows error 1219 (*"Multiple connections to a server or shared resource by the same user, using more than one user name, are not allowed"*).
3. **Least Privilege & Ownership Isolation:** Granting the living-room HTPC full access to the root `[simba]` share exposed personal backups and documents. Furthermore, adding `htpc` to the operator's User Private Group (`bjm`) violated least privilege.

#### Action
1. **Isolated Linux Service Account:**
   * Created dedicated system user `htpc` (UID 1003) on `rath15nas` with disabled interactive login shell (`/usr/sbin/nologin`), no home directory (`-M`), and standard membership in primary group `users` (GID 100).
   * User `htpc` is explicitly excluded from the administrative `bjm` and `sudo` groups.
2. **Dedicated `[Media]` Share Configuration (`smb.conf`):**
   * Added share `[Media]` mapped to `/mnt/simba/Media` restricted to `valid users = bjm, htpc`.
   * Configured Samba identity forcing: `force user = bjm` and `force group = bjm`.
   * Configured creation masks `force create mode = 0664` and `force directory mode = 0775`.
3. **Deployment Automation:**
   * Created [`scripts/setup-htpc-media-share.sh`](scripts/setup-htpc-media-share.sh) and PowerShell wrapper [`scripts/deploy-htpc-media.ps1`](scripts/deploy-htpc-media.ps1) with automated configuration backup and service reload (`systemctl reload smbd.service`).
4. **Client-Side Mount Configuration:**
   * Cleared stale anonymous sessions on HTPC and registered dedicated credentials in Windows Credential Manager:
     `cmdkey /add:192.168.68.169 /user:htpc /pass:<secret>`
     `net use M: \\192.168.68.169\Media /persistent:yes`

#### Consequences
* **Positive:** Seamless DVD ripping directly to `M:\Movies`, `M:\TV Shows`, and `M:\Music` without exposing personal files or backups in `/mnt/simba`.
* **Positive:** All files created by the HTPC are written on disk as `bjm:bjm`, eliminating file-ownership discrepancies with the operator's primary workstation.
* **Positive:** Permissions `0664`/`0775` guarantee that the unprivileged Jellyfin container (LXC 920) can read and index newly ripped media immediately.
* **Positive:** Client-side Windows session conflicts are permanently resolved via dedicated Credential Manager mapping.
* **Security:** `htpc` has zero SSH or terminal access to the Proxmox hypervisor.



