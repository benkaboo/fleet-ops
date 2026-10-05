# ADR-0020: Server-Side Google Drive Photo Ingestion & Backrest Family Photos Backup Plan

* **Status:** Accepted
* **Date:** 2026-10-04
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Cloud Photo Redundancy & Virtual File Pitfalls:** The operator maintained a ~115 GB Google Drive photo library (34,902 files in `import_onedrive/Pictures`). On the primary Windows workstation, Google Drive operates in "Stream files" mode where file metadata is represented as sparse stubs. Attempting to back up these folders using local workstation Restic/VSS creates an uncontrolled download storm filling local SSD caches (`%LOCALAPPDATA%`) and causing VSS snapshot failures.
2. **Zero-Knowledge Operator Sovereignty & Cloud Safety:** Cloud-to-NAS synchronization must guarantee that cloud photos cannot be altered or deleted. Access must be constrained strictly to read-only API scopes (`drive.readonly`) with non-destructive one-way ingestion (`rclone copy`) to prevent accidental deletion cascades.
3. **Automated Snapshot Lifecycle:** Ingested photos stored on the NAS storage pool (`/mnt/simba/Shared-All-Family/Photos`) require integration into the centralized Backrest orchestration engine to ensure point-in-time, deduplicated, encrypted restic snapshots with extended retention.

## Action
1. **Read-Only Server-Side Ingestion Architecture:**
   * Deployed `rclone` (v1.60.1) on LXC 920 (`services`) configured with dedicated OAuth credentials enforcing `scope = drive.readonly`.
   * Created automated sync script `/home/bjm/scripts/sync-gdrive-photos.sh` using non-destructive `rclone copy` with rate-limiting pacing (`--tpslimit 8`, `--transfers 4`, `--checkers 8`) targeting `/mnt/simba/Shared-All-Family/Photos/GoogleDrive`.
   * Configured dedicated log rotation via `/etc/logrotate.d/rclone-photos-sync` for `/home/bjm/logs/rclone-photos-sync.log`.
2. **Timezone Synchronization & Systemd Automation:**
   * Synchronized LXC 920 timezone to `Australia/Melbourne (AEDT, +1100)` to eliminate clock skew with the Proxmox host (`rath15nas`) and workstation.
   * Installed and enabled systemd units `rclone-photos-sync.service` and `rclone-photos-sync.timer` scheduled to run daily at 02:00 AM AEDT with `Persistent=true`.
3. **Backrest Backup Plan Provisioning (`family_photos`):**
   * Registered declarative plan `family_photos` in Backrest (`/opt/stacks/backrest/config/config.json`) targeting `/userdata/simba/Shared-All-Family/Photos`.
   * Linked plan to encrypted repository `services` (`/mnt/backups/services`) with daily execution scheduled at 04:00 AM AEDT (`0 4 * * *`).
   * Configured rolling retention policy: 30 daily, 12 monthly, and 5 yearly snapshots.
4. **Initial Library Ingestion:**
   * Initiated initial transfer of 115.22 GiB across 34,902 objects directly into the Btrfs storage pool without workstation bandwidth or disk consumption.

## Consequences
* **Positive:** Bypasses Windows virtual file / VSS streaming limitations, establishing direct, autonomous server-to-server photo backup.
* **Positive:** Google Drive cloud data is cryptographically protected against modification or deletion via Google API server-side enforcement of `drive.readonly`.
* **Positive:** Photos are accessible locally to family users via Samba and FileBrowser while backed up with 5-year point-in-time recovery in Backrest.
* **Operational:** LXC 920 container timezone aligned to AEDT, preventing scheduled job misalignments across the homelab fleet.
