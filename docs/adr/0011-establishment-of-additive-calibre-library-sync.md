# ADR-0011: Establishment of Additive Calibre Library Sync and Consolidation to NAS Media Storage

* **Status:** Accepted
* **Date:** 2026-09-10
* **Component:** Security & Governance
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The user required regular, automated synchronization of the primary workstation Calibre ebook library (`D:\Calibre_Library_Main`) to local network storage on `RATH15NAS` for access via Calibre-Web and family devices. However:
   * Workstation could not mount or browse `S:` (`\\RATH15NAS\simba`) due to Windows 11 blocking unauthenticated guest logons resulting from a username mismatch (`benma` on workstation vs `bjm` on NAS) and missing stored credentials.
   * On the NAS, books resided separately at `/mnt/simba/Books` instead of within the centralized media hierarchy (`/mnt/simba/Media/Books`).
   * The synchronization policy had to be non-destructive: books uploaded directly via Calibre-Web or added manually to the NAS must never be purged or deleted by workstation synchronization.
2. **Constraints & Trade-offs:**
   * **Zero Deletion Guarantee:** Omitted `/MIR` and `/PURGE` from Robocopy; utilized `/E` and `/XO` (exclude older) to ensure purely additive synchronization and protect web-uploaded titles.
   * **Container Continuity:** Containerized `calibre-web` (CT 920 on `services`) required re-pointing its bind mount to the relocated path without database corruption or permission issues.
   * **Authentication Hardening:** Restored SMB client access via explicit Windows Credential Manager mapping to user `bjm` rather than weakening Windows 11 guest security policies.

## Action
1. **Implementation Steps:**
   * Diagnosed SMB guest rejection; provisioned Windows Credential Manager entries for `RATH15NAS` and `192.168.68.169` under user `bjm`, restoring full read/write connectivity to `S:` (`\\RATH15NAS\simba`).
   * Stopped `calibre-web` Docker stack in CT 920 (`services` - `192.168.68.175`).
   * Atomically relocated `/mnt/simba/Books` to `/mnt/simba/Media/Books` (20 GB / 3,256 author folders, `metadata.db`) on `RATH15NAS` via Btrfs filesystem move.
   * Updated `/opt/stacks/calibre-web/compose.yaml` volume binding to `/mnt/simba/Media/Books:/books`, recreated container, and verified HTTP 302 / clean database ingestion.
   * Developed non-destructive synchronization script [`scripts/sync_calibre.ps1`](scripts/sync_calibre.ps1) (installed to `C:\ProgramData\calibre-sync\sync_calibre.ps1`) using Robocopy `/E /XO /FFT /R:2 /W:2 /MT:8 /NP /NDL` with automated log rotation.
   * Executed baseline dry-run (verified 0 deletions) and live initial sync: transferred 133 modified/new files (4.801 GB) at ~58.8 MB/s with 0 errors (`exit code 1`).
   * Registered Windows Scheduled Task `\CalibreSyncDaily` set to run daily at 21:30 (9:30 PM) under user `benma`.
   * Updated system documentation in [`ARCHITECTURE.md`](ARCHITECTURE.md) Section 11.3.
2. **Key Parameters:**
   * Source Path: `D:\Calibre_Library_Main` (~19.2 GB)
   * Destination Path: `S:\Media\Books` (`\\RATH15NAS\simba\Media\Books` / host path `/mnt/simba/Media/Books`)
   * Calibre-Web Service: CT 920 `services` (Port 8083), volume mount `/mnt/simba/Media/Books:/books`
   * Scheduled Task: `\CalibreSyncDaily` (Daily at 21:30)
   * Client Automation: `C:\ProgramData\calibre-sync\sync_calibre.ps1`
   * Log Location: `C:\ProgramData\calibre-sync\sync.log`

## Consequences
* **Positive:** Complete consolidation of books under the `/Media` taxonomy, functional Calibre-Web library integration, seamless workstation access to `S:`, and automated daily synchronization.
* **Operational:** Additive sync model means books deleted on the workstation will persist on the NAS (requiring deliberate manual pruning on Calibre-Web if removal is desired), completely eliminating the risk of losing web-uploaded ebooks.
* **Security:** Workstation SMB credentials cleanly isolated in Windows Credential Manager without enabling insecure guest authentication.
