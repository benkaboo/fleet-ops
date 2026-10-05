# ADR-0009: Deployment of Ransomware-Resilient Daily Encrypted Backup Pipeline (Restic REST Server)

* **Status:** Accepted
* **Date:** 2026-09-10
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Following the cancellation of the Microsoft 365 / OneDrive cloud subscription, the developer workstation (`lenovo16_lp`) required a sovereign, automated, client-side encrypted disaster recovery pipeline for primary personal archives, coding projects, SSH keys, and Obsidian notes. The backup target needed to terminate on centralized home lab storage (`RATH15NAS` - Proxmox hypervisor) without installing custom services directly on the bare-metal hypervisor, and with robust protection against ransomware attacks that could target local network shares.
2. **Constraints & Trade-offs:**
   * **Vanilla Proxmox Hypervisor:** The Proxmox host (`192.168.68.169`) must remain 100% vanilla without installing third-party application runtimes.
   * **Ransomware Defense:** Backup backend must enforce immutable/append-only permissions from the client perspective so a compromised workstation cannot destroy or overwrite historical recovery snapshots.
   * **Tenant Isolation:** Workstation repository (`workstation`) must be strictly segregated from HTPC (`htpc`).
   * **High Efficiency & Low Noise:** Backups must execute silently in the background without Win32 console pipe deadlocks or disk thrashing.
   * **Hydrated Data Verification:** Verified that all 808 files in `C:\Users\benma\OneDrive` were 100% physically hydrated on the local NVMe drive (0 cloud-only stubs).
   * **Game Save Optimization:** Inspected Steam Cloud manifests (`remotecache.vdf` and `steam_autocloud.vdf`); confirmed 100% of game saves for *Kingdom Come: Deliverance* (saves 1–451) and *God of War* are cloud-synced via Steam Cloud, allowing safe exclusion of `Saved Games` (~918 MB) from local backup to prevent bloat.

## Action
1. **Implementation Steps:**
   * Bound physical Btrfs subvolume `@backups` on `/dev/sdd1` (`/mnt/backups`) into LXC Container 920 (`services` - `192.168.68.175`).
   * Deployed `restic/rest-server:latest` via Dockge stack (`/opt/stacks/rest-server`) on port 8000 enforcing `--append-only` and `--private-repos`.
   * Initialized dedicated encrypted repository for `workstation` using client-side AES-256 keys (`repo_key.txt`).
   * Deployed `C:\ProgramData\restic\backup.ps1` and `excludes.txt` to the workstation with native Win32 output redirection (`cmd.exe /c ... >> backup.log 2>&1`) and log rotation, targeting `OneDrive`, `coding`, `.ssh`, `.keepsidian`, `Documents`, `Desktop`, and `Pictures`.
   * Excluded high-churn transient directories (`.venv`, `node_modules`, `__pycache__`, `Downloads`, `AppData\Local\Temp`, `Saved Games`).
   * Registered Windows Scheduled Task `\ResticBackup` running Daily at 21:00 (9:00 PM) for user profile `benma`.
   * Executed baseline backup: captured 1,335 files (631.565 MiB uncompressed, compressed to 514 MiB stored on Btrfs) in 22 seconds with exit code 0 (`snapshot 840d619b`).
   * Verified incremental execution: completed change scan and metadata sync in **1 second** (`snapshot c4c6d2c5`).
   * Authored authoritative specification [`backup_strategy.md`](backup_strategy.md) documenting taxonomy, administrative pruning via CT 920 Docker container, and recovery playbooks.
2. **Key Parameters:**
   * REST Endpoint: `http://workstation:***@192.168.68.175:8000/workstation/`
   * Cadence: Daily at 21:00 (9:00 PM)
   * Execution Identity: `benma` (`\ResticBackup` scheduled task)
   * Baseline Snapshot: `840d619b` (1,335 files / 631.565 MiB)
   * Incremental Snapshot: `c4c6d2c5` (1,323 files / 4.354 KiB incremental change, 1 second runtime)
   * Stored Repository Size: ~514 MiB (zstd compressed & deduplicated on Btrfs)

## Consequences
* **Positive:** Complete elimination of cloud subscription reliance with sovereign, zero-trust AES-256 encrypted backups to local NAS storage.
* **Security:** Enforced `--append-only` mode at the REST server guarantees mathematical immunity against ransomware or compromised endpoint snapshot deletion.
* **Operational:** Headless execution takes ~1 second on daily incremental passes without interrupting active development. Admin retains full sovereign control to view, prune, or remove snapshots via CT 920.
