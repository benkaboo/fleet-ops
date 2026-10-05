# Workstation Backup Strategy & Data Governance Specification

**Target Host:** `LENOVO16_LP` (Lenovo ThinkPad E16 Gen 1 AMD)  
**Primary User:** `benma`  
**Storage Target:** `rest:http://workstation:***@192.168.68.175:8000/workstation/` (Proxmox CT 920 REST Server)  
**Last Updated:** 2026-09-10  

---

## 1. Architectural Topology & Threat Model

Following the cancellation of the Microsoft 365 / OneDrive cloud subscription, this workstation operates an independent, zero-trust encrypted, automated backup pipeline terminating on local network storage (`RATH15NAS`).

```mermaid
flowchart TD
    subgraph Host ["Host: LENOVO16_LP (Workstation - 192.168.68.154)"]
        TaskWS["Scheduled Task: \\ResticBackup\nCadence: Daily @ 21:00\nEngine: restic.exe v0.19.1"]
        ScriptWS["C:\\ProgramData\\restic\\backup.ps1"]
        KeyWS["C:\\ProgramData\\restic\\repo_key.txt (AES-256)"]
        TargetsWS["Data Targets:\nOneDrive (Hydrated), coding, .ssh, .keepsidian, Calibre Library"]
    end

    subgraph LXC920 ["LXC 920: services (192.168.68.175)"]
        BindMount["Bind-Mount: /mnt/backups"]
        Dockge["Dockge Managed Stack: /opt/stacks/rest-server"]
        RestServer["restic/rest-server:latest (:8000)\nEnforced Flags: --append-only --private-repos"]
    end

    subgraph ProxmoxHost ["Proxmox VE Hypervisor (RATH15NAS - 192.168.68.169)"]
        BtrfsSubvol["Btrfs Subvolume: @backups\nPhysical Disk: /dev/sdd1\nMount: /mnt/backups (3.6 TB Free Pool)"]
    end

    TargetsWS --> ScriptWS
    KeyWS --> ScriptWS
    TaskWS --> ScriptWS
    ScriptWS -->|HTTP/2 REST (Append-Only)| RestServer
    Dockge --> RestServer
    BindMount --> RestServer
    BtrfsSubvol === BindMount
```

### Security & Ransomware Defenses
1. **Client-Side AES-256 Encryption:** All files are chunked and encrypted in memory prior to transmission. The NAS resting disk never stores unencrypted bytes.
2. **Server-Side Append-Only Enforcement (`--append-only`):** The client workstation has strictly append-only credentials. Even in the event of an active malware or ransomware compromise of the workstation, historical snapshots cannot be deleted, altered, or encrypted.
3. **Tenant Isolation (`--private-repos`):** The workstation repository (`/mnt/backups/workstation`) is completely isolated from other network endpoints (such as `rath15-htpc`).
4. **Btrfs Snapshot Layering:** Hypervisor-level snapshots of the `@backups` subvolume provide instantaneous disaster recovery prior to administrative maintenance.

---

## 2. Backup Execution Parameters

* **Cadence:** **Daily at 21:00 (9:00 PM)**.
* **Execution Engine:** Windows Task Scheduler (`\ResticBackup`) running under user profile `benma` (or `SYSTEM` with VSS).
* **Network Protocol:** Native Go HTTP/2 REST client in `restic.exe`. Zero child process overhead, zero Win32 pipe deadlocks.
* **Runtime Path:** `C:\ProgramData\restic\backup.ps1`.
* **Excludes File:** `C:\ProgramData\restic\excludes.txt`.
* **Logging & Rotation:** Execution logs written to `C:\ProgramData\restic\backup.log` (automatically rotated to `backup.log.old` when exceeding 5 MB).
* **Performance:** Full baseline backup: **631 MiB in 22 seconds**; daily incremental scan: **under 2 seconds**.

---

## 3. Target Inclusion Inventory & Directory Taxonomy

| Tier | Target Directory | Measured Size | File Count | Rationale & Criticality |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | `C:\Users\benma\OneDrive` | **~485 MB** | 808 files | **Primary Personal Archive:** 100% hydrated locally (resumes, family planning, financial records, Obsidian notes/vaults, tax docs, scans). Replaces cancelled M365 subscription. |
| **Tier 1** | `C:\Users\benma\coding` | **~65 MB** | 4,118 files | **Active Intellectual Property:** Git repositories (`agy_project`, `kraken`, `reflection-engine`) and commit histories. |
| **Tier 1** | `C:\Users\benma\.ssh` | **<0.1 MB** | 7 files | **Security & Access Keys:** Client SSH private keys (`id_ed25519`) and remote configs. Essential for accessing `rath15-htpc`, `RATH15NAS`, and GitHub. |
| **Tier 1** | `C:\Users\benma\.keepsidian` | **~140 MB** | 1 file | **Knowledge Base:** Consolidated Obsidian and Google Keep notes archive. |
| **Tier 1** | `D:\Calibre_Library_Main` | **~19.2 GB** | 13,472 files | **Curated Ebook Library:** Personal Calibre digital library (7,227 EPUBs, 4,710 covers, 662 MOBIs, 409 PDFs, `metadata.db`). Irreplaceable personal digital collection. |
| **Tier 1** | `C:\Users\benma\Documents` | **<1 MB** | 2 files | Local document root. |
| **Tier 3** | `C:\Users\benma\Desktop` | **<1 MB** | 64 files | Active desktop workspace shortcuts and temporary working files. |
| **Tier 3** | `C:\Users\benma\Pictures` | **<1 MB** | 5 files | Local photo directory. |

*Workstation Baseline Stored Size:* **~19.8 GiB uncompressed** (~17.9 GiB stored compressed & deduplicated on Btrfs).

---

## 4. Explicit Omissions & Exclusions (Tier 0)

The following categories are **strictly excluded** via `C:\ProgramData\restic\excludes.txt`:

| Category / Path | Typical Size | Rationale for Exclusion |
| :--- | :--- | :--- |
| **Local Game Saves** (`C:\Users\benma\Saved Games`) | ~918 MB | **100% Cloud Synced:** Inspected Steam Cloud manifests (`remotecache.vdf` and `steam_autocloud.vdf`); all saves for *Kingdom Come: Deliverance* (saves 1–451) and *God of War* are verified safely stored in Valve's Steam Cloud. Local backup is redundant. |
| **Python Virtual Environments** (`.venv`, `venv`, `env`) | 1–5 GB | Ephemeral binaries re-creatable in seconds via `requirements.txt` / `pip install`. |
| **Build Artifacts & Package Caches** (`node_modules`, `__pycache__`, `.pytest_cache`, `pip\cache`, `npm-cache`, `.devbox`) | 2–10 GB | High-churn transient directories that cause repository bloat without recovery value. |
| **WSL2 Virtual Machine Disks** (`*.vhdx`) | 20–50 GB | Monolithic virtual hard drives. Project code and dotfiles inside WSL are already synced via Git. |
| **Temporary Files & Downloads** (`Downloads`, `AppData\Local\Temp`, `.*-*-*-*`, `*.tmp`, `*.log`) | 5–20 GB | Disposable scratch files. |

---

## 5. Administrator Operations & Snapshot Management

Because client nodes run with **`--append-only`**, administrative operations (pruning, forgotten snapshots) must be run from the server host (`services` CT 920).

### 5.1. Viewing Workstation Snapshots
From your workstation:
```bash
ssh services
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/workstation snapshots
```

### 5.2. Removing an Unwanted Snapshot
```bash
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/workstation \
  forget <SNAPSHOT_ID> --prune
```

### 5.3. Recommended Server-Side Retention Policy
Run as a weekly cron job on CT 920:
```bash
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/workstation \
  forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
```

---

## 6. Disaster Recovery & Restoration Playbook

### Scenario A: Restoring a Single Deleted File
```cmd
restic -r rest:http://workstation:<pw>@192.168.68.175:8000/workstation/ --password-file C:\ProgramData\restic\repo_key.txt restore latest --target C:\Restore_Temp --include "C:\Users\benma\OneDrive\Documents\Important.pdf"
```

### Scenario B: Restoring Entire Coding Repositories
```cmd
restic -r rest:http://workstation:<pw>@192.168.68.175:8000/workstation/ --password-file C:\ProgramData\restic\repo_key.txt restore latest --target C:\Restore_Temp --include "C:\Users\benma\coding"
```

### Scenario C: Browsing Historical Snapshots via Virtual Drive Mount
```cmd
restic -r rest:http://workstation:<pw>@192.168.68.175:8000/workstation/ --password-file C:\ProgramData\restic\repo_key.txt mount X:
```
