# Cold-Start Disaster Recovery Playbook

This runbook details the exact, step-by-step procedure to rebuild the Dixon Homelab fleet from bare metal in the event of total hardware loss, disk destruction, or critical ransomware compromise.

---

## 1. Prerequisites (Offline Recovery Kit)

* **Physical USB:** Proxmox VE 8.x installation media.
* **Credentials & Secrets:** 1Password / Bitwarden emergency kit containing:
  - WireGuard private keys (`/etc/wireguard/wg0.conf`).
  - GitHub SSH deploy keys.
  - LLDAP admin password & JWT secrets.
  - Restic repository encryption passwords.
* **Network Connectivity:** Temporary internet access to pull packages from Debian/Ubuntu mirrors.

---

## 2. Phase 1: Proxmox Host Bare-Metal Rebuild

1. **Install Base OS:**
   * Boot server from Proxmox VE 8.x ISO.
   * Target root drive with ZFS (RAID1 or single depending on topology).
   * Set management IP: `192.168.68.169/24`, Gateway: `192.168.68.1`, DNS: `1.1.1.1`.
2. **Clone Fleet Knowledge Repository:**
   ```bash
   git clone git@github.com:benkaboo/fleet-ops.git /root/fleet-ops
   ```
3. **Mount Storage Pools:**
   * Reconnect Btrfs storage pool drives and execute mount script:
     ```bash
     bash /root/fleet-ops/storage/update_fstab_btrfs.sh
     mount -a
     ```
   * Verify `/mnt/simba` is accessible with read/write permissions.
4. **Restore NVIDIA GPU Drivers (GTX 1080 Ti):**
   * Execute host setup script:
     ```bash
     bash /root/fleet-ops/hosts/proxmox/scripts/gpu/01-host-nvidia-setup.sh
     ```
   * Reboot host and confirm `nvidia-smi` reports driver `580.178.04`.

---

## 3. Phase 2: WireGuard Tunnel Restoration

1. **Hydrate Interface Configuration:**
   * Recreate `/etc/wireguard/wg0.conf` using the offline secret key.
   * Ensure `chmod 600 /etc/wireguard/wg0.conf`.
2. **Enable & Start Interface:**
   ```bash
   systemctl enable --now wg-quick@wg0.service
   wg show wg0
   ```
3. **Validate Site-to-Site Connectivity:**
   * Ping remote gateway: `ping -c 3 10.10.0.1`.
   * Ping remote subnet: `ping -c 3 192.168.6.1`.

---

## 4. Phase 3: LXC 920 (`services`) Provisioning

1. **Create Unprivileged LXC:**
   ```bash
   bash /root/fleet-ops/hosts/proxmox/scripts/lxc-setup/01-create-lxc.sh
   bash /root/fleet-ops/hosts/proxmox/scripts/lxc-setup/02-bindmount-and-start.sh
   bash /root/fleet-ops/hosts/proxmox/scripts/lxc-setup/03-install-docker.sh
   ```
2. **Apply GPU Passthrough Rules:**
   ```bash
   bash /root/fleet-ops/hosts/proxmox/scripts/gpu/02-pve-lxc-passthrough.sh
   pct enter 920
   bash /root/fleet-ops/hosts/proxmox/scripts/gpu/03-container-docker-setup.sh
   exit
   ```
3. **Authorize GitOps Deploy Key:**
   * Install the read-only GitHub deploy key in `/home/bjm/.ssh/id_ed25519_deploy` inside LXC 920.

---

## 5. Phase 4: Container Application GitOps Hydration

1. **Pull Declarative Stacks on LXC 920:**
   ```bash
   ssh bjm@192.168.68.175 "git clone git@github.com:benkaboo/homelab-stacks.git /opt/stacks"
   ```
2. **Hydrate Secrets from Password Manager:**
   * Populate runtime environment variables from templates:
     - `/opt/stacks/authelia/.env` (from `authelia.env.example`)
     - `/opt/stacks/lldap/.env` (from `lldap.env.example`)
     - `/opt/stacks/immich/.env` (from `immich/.env.example`)
3. **Launch Core Stacks:**
   ```bash
   ssh bjm@192.168.68.175 "cd /opt/stacks/caddy && docker compose up -d"
   ssh bjm@192.168.68.175 "cd /opt/stacks/lldap && docker compose up -d"
   ssh bjm@192.168.68.175 "cd /opt/stacks/authelia && docker compose up -d"
   ssh bjm@192.168.68.175 "cd /opt/stacks/immich && docker compose up -d"
   ssh bjm@192.168.68.175 "cd /opt/stacks/jellyfin && docker compose up -d"
   ```

---

## 6. Phase 5: Verification & Health Check

1. Verify container health: `docker ps` on LXC 920 (all containers reporting `healthy` or `Up`).
2. Test internal ingress:
   - `curl -k https://192.168.68.175`
   - Access Homepage dashboard at `https://home.dixon.home`.
3. Check GPU utilization:
   - `docker exec jellyfin nvidia-smi`
   - `docker exec immich_machine_learning nvidia-smi`
