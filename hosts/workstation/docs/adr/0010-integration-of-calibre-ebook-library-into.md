# ADR-0010: Integration of Calibre Ebook Library into Workstation Backup Scope

* **Status:** Accepted
* **Date:** 2026-09-10
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The user identified `D:\Calibre_Library_Main` (13,472 files / 19.2 GB) containing a curated, irreplaceable digital ebook library (EPUB, MOBI, PDF, JPEG covers, and Calibre SQLite database `metadata.db`) as requiring disaster recovery protection terminating on the home lab REST server (`services` CT 920 on `RATH15NAS`).
2. **Constraints & Trade-offs:**
   * **Pool Capacity:** Hypervisor backup storage (`/mnt/backups`) has 3.6 TB free pool; 19.2 GB consumes < 0.5% of capacity.
   * **Incremental Speed:** Initial ingestion of 19.2 GB takes ~5 minutes over LAN, but daily incremental change scans must remain negligible (< 10 seconds).
   * **Zero File Mutation:** Backup pipeline requires strictly read-only traversal of the Calibre directory.

## Action
1. **Implementation Steps:**
   * Appended `"D:\Calibre_Library_Main"` to `$candidateTargets` array in [`C:\ProgramData\restic\backup.ps1`](file:///C:/ProgramData/restic/backup.ps1).
   * Updated [`backup_strategy.md`](file:///C:/Users/benma/coding/agy_project/Projects/Workstation/backup_strategy.md) and [`ARCHITECTURE.md`](file:///C:/Users/benma/coding/agy_project/Projects/Workstation/ARCHITECTURE.md) Section 11.2 classifying Calibre under **Tier 1 (Irreplaceable Personal Assets & Media)**.
   * Executed initial baseline backup: ingested 14,832 total files (19.825 GiB uncompressed / 17.870 GiB stored on Btrfs) in 5 minutes 41 seconds (`snapshot 28a89625`).
   * Verified incremental change scan: completed full 14,832 file scan in **9 seconds** (`snapshot b795b20e`).
2. **Key Parameters:**
   * Target Path: `D:\Calibre_Library_Main`
   * Target Datasets: `OneDrive`, `coding`, `.ssh`, `.keepsidian`, `D:\Calibre_Library_Main`, `Documents`, `Desktop`, `Pictures`
   * Baseline Snapshot with Calibre: `28a89625` (14,832 files / 19.825 GiB)
   * Incremental Verification Snapshot: `b795b20e` (9 seconds runtime)
   * Total Repository Stored Size: ~19 GB on Btrfs

## Consequences
* **Positive:** Guaranteed sovereign disaster recovery for irreplaceable ebook library without external cloud subscription dependencies.
* **Operational:** Sub-10-second daily incremental scans ensure zero disruption to workstation performance or scheduled task execution.
