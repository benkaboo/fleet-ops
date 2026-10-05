# Fleet Topology & Infrastructure Directory

Comprehensive mapping of the Dixon Homelab fleet, network boundaries, hardware specifications, and containerized services.

---

## 1. Network Subnets & Routing

| Network Zone | CIDR / Subnet | Gateway | Primary Role |
| :--- | :--- | :--- | :--- |
| **Dixon LAN** | `192.168.68.0/24` | `192.168.68.1` | Physical devices, hypervisor, workstation, HTPC, containers |
| **WireGuard Site-to-Site** | `10.10.0.0/24` | `10.10.0.1` | Inter-site tunnel connecting Dixon (`.2`) and Maslen (`.1`) |
| **Remote LAN (Maslen)** | `192.168.6.0/24` | `192.168.6.1` | Federated remote subnet routed across WireGuard |
| **WireGuard Road-Warrior** | `10.10.0.5/32` | `10.10.0.2` | Mobile remote access client with split-tunneling |

---

## 2. Physical Hosts & Hypervisors

### `rath15nas` (Proxmox VE 8.x Hypervisor)
* **Management IP:** `192.168.68.169:8006`
* **Interface Bridge:** `vmbr0` attached to `nic0`
* **Hardware:** Intel Core platform with dedicated NVIDIA GeForce GTX 1080 Ti (11 GB VRAM, GP102 architecture)
* **GPU Driver Stack:** NVIDIA Production Driver `580.178.04-1` (proprietary DKMS, APT-pinned), CUDA 13.0
* **Storage Pools:**
  * `rpool` (ZFS): Proxmox boot and container root disks.
  * Btrfs RAID1 Pool: High-capacity media and backup datasets mounted under `/mnt/simba`.
* **Host Services:** WireGuard kernel interface (`wg0`), Samba export daemon.

### `Workstation` (Primary Development Machine)
* **OS:** Windows 11 Pro with WSL2 resource sandbox (capped in `.wslconfig`).
* **Role:** Local AI pairing runtime (Antigravity), code development, Restic encrypted backup client.

### `HTPC` (Living Room Media & Streaming Target)
* **OS:** Windows 11 with hardened OpenSSH daemon (Ed25519 authentication).
* **Role:** Moonlight/Sunshine game streaming display, media consumption, Restic backup client.

---

## 3. Containers & Virtual Machines

| VM/LXC ID | Hostname | IP Address | OS / Type | Primary Function |
| :--- | :--- | :--- | :--- | :--- |
| **LXC 920** | `services` | `192.168.68.175` | Debian 12 (Unprivileged) | Main Docker service host; GPU passthrough enabled |
| **VM 940** | `haos` | DHCP / Reserved | Home Assistant OS (KVM) | Dedicated smart home automation |

---

## 4. Container Services Inventory (LXC 920)

All container stacks are managed declaratively via GitOps in `Projects/homelab-stacks` tracking `benkaboo/homelab-stacks.git`:

| Service | Port(s) | Proxy Domain | Storage Mount | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Caddy** | `80`, `443` | `*.dixon.home` | `/opt/stacks/caddy` | Ingress reverse proxy with internal PKI TLS |
| **Immich** | `2283` | `photos.dixon.home` | `/mnt/simba/Immich/Uploads` | Accelerated with GTX 1080 Ti (CUDA), Authelia OIDC |
| **Jellyfin** | `8096` | `jellyfin.dixon.home` | `/mnt/simba/Media` | Hardware transcoding via NVENC, Authelia OIDC |
| **Authelia** | `9091` | `auth.dixon.home` | `/opt/stacks/authelia` | Identity provider & forward-auth portal |
| **LLDAP** | `3890`, `17170` | `ldap.dixon.home` | `/opt/stacks/lldap` | Lightweight LDAP directory backend |
| **FileBrowser** | `8080` | `files.dixon.home` | `/mnt/simba` | Web file management |
| **Calibre-Web** | `8083` | `books.dixon.home` | `/mnt/simba/Media/Books` | E-book reader with OPDS support |
| **Audiobookshelf** | `13378` | `audiobooks.dixon.home` | `/mnt/simba/Media/Audiobooks` | Audiobooks & podcast stream engine |
| **Homepage** | `3000` | `home.dixon.home` | `/opt/stacks/homepage` | Central dashboard |
| **Uptime Kuma** | `3001` | `kuma.dixon.home` | `/opt/stacks/uptime-kuma` | 24/7 service monitoring & alerting |
| **Backrest** | `9898` | `backrest.dixon.home` | `/opt/stacks/backrest` | Web orchestrator for Restic backups |
| **Rest-Server** | `8000` | `restic.dixon.home` | `/mnt/simba/Backups` | High-performance append-only Restic backend |
| **Dockge** | `5001` | `dockge.dixon.home` | `/opt/stacks` | Container stack management UI |
