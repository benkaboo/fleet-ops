# ADR-0004: Dedicated Docker Services Container (LXC 920), Reverse Proxy Gateway, and Authelia SSO Portal

* **Status:** Accepted
* **Date:** 2026-09-06
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Service Isolation & Lifecycle:** Running self-hosted media and application stacks (Dockge, Caddy, Authelia, Jellyfin, Calibre-Web) directly on the Proxmox hypervisor (`rath15nas`) compromises host stability, security, and backup simplicity. A dedicated, lightweight, unprivileged environment was required.
2. **Access Control & User Experience:** Local network clients (including family members using the Home Theatre PC and Windows Samba shares) must not have their existing network connectivity or file access disrupted. However, web interfaces for management, media, and tools need centralized Single Sign-On (SSO) and Two-Factor Authentication (2FA) without exposing unauthenticated ports to the LAN or internet.
3. **Storage & Performance Requirements:** Application metadata, databases (e.g. SQLite), and Docker overlay files require high-IOPS NVMe/SSD storage (`local-lvm`), while bulk media datasets (`Media/`, `Books/`) reside on the resilient Btrfs RAID1 storage pool mounted at `/mnt/data/@simba`.

## Action
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

## Consequences
* **Positive:** Complete isolation of Docker containers inside an unprivileged LXC guest; hypervisor OS remains pristine.
* **Positive:** Family network traffic (HTPC, Windows file shares) remains entirely untouched and operational.
* **Positive:** High I/O performance achieved through SSD-backed Docker stacks paired with high-capacity Btrfs storage for media.
* **Security:** All sensitive materials (passwords, JWT secrets, session keys) are generated on-demand at deployment time and excluded from Git version control. Reproducible deployment scripts are maintained in [`scripts/lxc-setup/`](scripts/lxc-setup/).
