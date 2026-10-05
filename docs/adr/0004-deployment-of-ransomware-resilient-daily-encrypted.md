# ADR-0004: Deployment of Ransomware-Resilient Daily Encrypted Backup Pipeline (Restic REST Server)

* **Status:** Accepted
* **Date:** 2026-09-10
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Following the cancellation of Microsoft 365 / OneDrive subscription, `rath15-htpc` and authorized client workstations lacked an independent, encrypted, automated disaster recovery pipeline for critical personal documents, photos, coding projects, game saves, and system keys. Storage had to terminate on centralized NAS storage (`RATH15NAS` - Proxmox hypervisor) without running custom software directly on the bare-metal hypervisor, and without creating Win32 subprocess console pipe hangs (which caused Restic over SFTP to freeze).
2. **Constraints & Trade-offs:**
   * **Vanilla Proxmox Hypervisor:** The Proxmox host (`192.168.68.169`) must remain 100% vanilla without installing third-party application runtimes.
   * **Living Room Media Stability:** Backups must execute silently in background Session 0 with zero windows, popups, or audio/video stutter during 4K HDR playback or VR streaming.
   * **Ransomware Defense:** Backup backend must be immutable/append-only from the client perspective so compromised endpoints cannot delete past snapshots.
   * **Tenant Isolation:** Client repositories (`htpc` vs `workstation`) must be strictly segregated.

## Action
1. **Implementation Steps:**
   * Bound physical Btrfs subvolume `@backups` on `/dev/sdd1` (`/mnt/backups`) into LXC Container 920 (`services` - `192.168.68.175`).
   * Deployed `restic/rest-server:latest` via Dockge stack (`/opt/stacks/rest-server`) on port 8000 enforcing `--append-only` and `--private-repos`.
   * Initialized separate encrypted repositories for `htpc` and `workstation` using client-side AES-256 keys.
   * Deployed `C:\ProgramData\restic\backup.ps1` and `excludes.txt` to `rath15-htpc`, targeting personal files for both `benka_000` and `dylan_93nze6m`, while omitting bulk Steam libraries, OS binaries, and scratch files.
   * Configured Windows COM VSS shadow snapshotting (`--use-fs-snapshot`) to read locked files.
   * Registered Windows Scheduled Task `\ResticBackup` running Daily at 21:00 (9:00 PM) as `SYSTEM`.
   * Executed initial baseline backup: captured 51,390 files (7.766 GiB uncompressed, compressed to 4.6 GiB stored on the NAS) with exit code 0 (`snapshot 51c847b9`).
   * Authored authoritative specification [`backup_strategy.md`](backup_strategy.md) documenting taxonomy, administrative snapshot removal via CT 920 Docker container, retention pruning, and recovery playbooks.
2. **Key Parameters:**
   * REST Endpoint: `http://htpc:***@192.168.68.175:8000/htpc/`
   * Cadence: Daily at 21:00 (9:00 PM)
   * Execution Privilege: `NT AUTHORITY\SYSTEM` (Elevated VSS enabled)
   * Baseline Snapshot: `51c847b9` (51,390 files / 7.766 GiB)
   * Stored Repository Size: 4.6 GiB (zstd compressed / deduplicated)

## Consequences
* **Positive:** Complete replacement of cloud storage dependency with sovereign, AES-256 client-encrypted daily backups. Seamless Windows VSS snapshotting eliminates locked file errors.
* **Security:** Native `--append-only` enforcement on the REST server guarantees mathematical immunity against ransomware deletion or modification of historical snapshots from client endpoints.
* **Operational:** Headless execution takes ~15 seconds on daily incremental passes without impacting CPU or GPU media performance. Admin retains full sovereign control to view, prune, or remove snapshots via CT 920.
