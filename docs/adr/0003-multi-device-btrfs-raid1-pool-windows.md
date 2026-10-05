# ADR-0003: Multi-Device Btrfs RAID1 Pool, Windows-Optimized Samba Share, and AGY Host Runtime

* **Status:** Accepted
* **Date:** 2026-09-06
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Storage Infrastructure:** The host had unformatted or legacy single-disk partitions (`sdd1`, `sde1`, `sdc1`). Resilient, self-healing shared network storage was required across heterogeneous drives (4 TB Seagate IronWolf, 4 TB WD Red, 3 TB WD Purple).
2. **Network File Sharing:** Local workstations on the network are predominantly Windows clients requiring fast, reliable file access with support for Windows metadata, file locking, and alternate data streams.
3. **Host Administration:** Operating the Proxmox server directly benefits from a local AI assistant runtime on the hypervisor host in addition to the remote workstation agent.

## Action
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

## Consequences
* **Positive:** ~4.95 TB of resilient, self-healing mirrored storage with 1-disk fault tolerance across mismatched disk capacities.
* **Positive:** Native, high-performance file sharing for Windows clients with zero permission friction.
* **Positive:** Local `agy` presence on the Proxmox hypervisor enables direct on-host troubleshooting, while remote operations continue through the least-privilege `agy-auditor` SSH alias.
