# Backup Strategy & Data Governance Specification

This document defines the authoritative backup architecture, directory classification taxonomy, operational workflows, and disaster recovery playbooks for the home network, specifically focusing on `rath15-htpc` and authorized client workstations.

---

## 1. Architectural Topology & Threat Model

The backup infrastructure is designed to be **ransomware-resilient, headless, zero-trust encrypted, and non-invasive** to living room media playback and gaming operations.

```mermaid
flowchart TD
    subgraph Host ["Proxmox VE Hypervisor (RATH15NAS - 192.168.68.169)"]
        BtrfsSubvol["Btrfs Subvolume: @backups\nPhysical Device: /dev/sdd1\nMount: /mnt/backups (3.6 TB Free)"]
    end

    subgraph LXC920 ["LXC 920: services (192.168.68.175)"]
        BindMount["Bind-Mount: /mnt/backups"]
        Dockge["Dockge Managed Stack: /opt/stacks/rest-server"]
        RestServer["restic/rest-server:latest (:8000)\nEnforced Flags: --append-only --private-repos"]
    end

    subgraph ClientHTPC ["Endpoint: rath15-htpc (192.168.68.162)"]
        TaskHTPC["Scheduled Task: ResticBackup\nCadence: Daily @ 21:00\nPrivilege: SYSTEM (VSS Enabled)"]
        ScriptHTPC["C:\\ProgramData\\restic\\backup.ps1"]
        KeyHTPC["C:\\ProgramData\\restic\\repo_key.txt (AES-256)"]
        RepoHTPC["Repo: rest:http://htpc:***@192.168.68.175:8000/htpc/"]
    end

    subgraph ClientWS ["Endpoint: Workstation (192.168.68.154)"]
        RepoWS["Repo: rest:http://workstation:***@192.168.68.175:8000/workstation/"]
    end

    BtrfsSubvol === BindMount
    BindMount --> RestServer
    Dockge --> RestServer
    TaskHTPC --> ScriptHTPC
    ScriptHTPC --> KeyHTPC
    ScriptHTPC -->|HTTP/2 REST (Append-Only)| RestServer
    ClientWS -->|HTTP/2 REST (Append-Only)| RestServer
```

### Security & Ransomware Defenses
1. **Client-Side AES-256 Encryption:** All data blocks are encrypted on the client machine before leaving RAM. The NAS resting disk never sees plain-text files.
2. **Server-Enforced Append-Only Mode (`--append-only`):** Clients are cryptographically restricted to appending new snapshots. A compromised client host (or active ransomware payload) has zero API permissions to delete, prune, overwrite, or encrypt historical snapshots.
3. **Tenant Repo Isolation (`--private-repos`):** Each client account (`htpc`, `workstation`) can only access its own directory path (`/data/<user>/`).
4. **Btrfs Snapshot Layering:** The underlying Proxmox storage pool uses Btrfs subvolumes, enabling instantaneous hypervisor-level snapshots of the entire repository before administrative maintenance.

---

## 2. Backup Execution Parameters

* **Cadence:** **Daily at 21:00 (9:00 PM)**.
* **Execution Engine:** Windows Task Scheduler (`\ResticBackup`) running as `NT AUTHORITY\SYSTEM` with highest privileges (`RunLevel: Highest`).
* **Volume Shadow Copy (VSS):** Uses `--use-fs-snapshot` to create a point-in-time snapshot, ensuring open databases, registry hives, and locked game saves are safely read without process locks.
* **Network Protocol:** Native Go HTTP/2 REST client in `restic.exe`. Zero child process overhead, zero Win32 pipe deadlocks.
* **Logging & Rotation:** Full execution logs written to `C:\ProgramData\restic\backup.log`. Automatically rotates to `backup.log.old` when exceeding 5 MB.

---

## 3. Directory Taxonomy & Tiers of Importance

Target data is organized into rigorous tiers to ensure that 100% of critical personal assets are protected while avoiding storage and bandwidth waste on disposable or re-downloadable files.

### 3.1. Target Inclusion Inventory

| Tier | Owner / Profile | Target Directory | Approx. Size | Rationale & Criticality |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | `benka_000` | `C:\Users\benka_000\Documents` | ~1.00 GB | Personal records, resumes, tax/financial files, scans. Irreplaceable. |
| **Tier 1** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\Documents` | ~2.96 GB | Schoolwork, personal projects, documents. Irreplaceable. |
| **Tier 1** | `benka_000` | `C:\Users\benka_000\Pictures` | ~318 MB | Personal and family photo archives. Zero recovery alternative. |
| **Tier 1** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\Pictures` | ~200 MB | Personal pictures and creative media. |
| **Tier 1** | `benka_000` | `C:\Users\benka_000\.ssh` | <1 MB | User SSH authentication keys and known hosts. |
| **Tier 1** | Host / System | `C:\ProgramData\ssh` | <0.1 MB | Windows OpenSSH Server host keys and authorized keys. Critical for disaster recovery and remote administration. |
| **Tier 1** | Host / System | `C:\ProgramData\htpc_maintenance_backups` | <0.1 MB | System architecture snapshots, maintenance scripts, and baseline configs. |
| **Tier 1** | `benka_000` | `C:\Users\benka_000\pythonProject` & `PycharmProject` | ~48 MB | Ben's local codebases and development repositories. |
| **Tier 1** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\MCreatorWorkspaces` | ~259 MB | Dylan's custom Minecraft mod creations. Hundreds of hours of creative effort. |
| **Tier 1** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\My project` & `PycharmProjects` | ~122 MB | Dylan's Python and game development projects. |
| **Tier 2** | `benka_000` | `C:\Users\benka_000\Saved Games` | ~272 MB | Game progression, non-cloud save files, and emulator state. |
| **Tier 2** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\Saved Games` | ~92 MB | Dylan's game save states and local progression. |
| **Tier 3** | `benka_000` | `C:\Users\benka_000\Desktop` | ~592 MB | Active desktop shortcuts, notes, and temporary working files. |
| **Tier 3** | `dylan_93nze6m` | `C:\Users\dylan_93nze6m\Desktop` | ~5.3 GB (excl. ISO) | Active desktop workspace files and shortcuts. |

*Total Initial Footprint:* **~10.8 GB** (Deduplicated and compressed via zstd on the Btrfs pool).

---

### 3.2. Explicit Omissions & Exclusions (Tier 0)

The following categories are **strictly excluded** from automated backups via `C:\ProgramData\restic\excludes.txt`:

| Category / Path | Typical Size | Rationale for Exclusion |
| :--- | :--- | :--- |
| **Steam & Epic Game Libraries** (`SteamLibrary`, `Games`, `F:\`, `G:\`, `H:\` common) | 500+ GB | High-bandwidth binaries, 4K textures, audio tracks. Permanently retained in user Steam/Epic accounts and re-downloadable on demand at 500+ Mbps from Valve/Epic CDNs. Backing them up wastes terabytes of NAS storage. |
| **Windows OS Files** (`C:\Windows`, `Program Files`, `Program Files (x86)`) | 60+ GB | Backing up live OS files causes dirty registry states, driver locks, and restore instability. In catastrophic drive failure, a fresh 10-minute Windows 11 ISO reinstall produces a pristine, high-performance system. |
| **Centralized Network Media** (`M:\Media`, `N:\`, `P:\film`, `X:\tvshows`) | 8+ TB | Media files already reside on `RATH15NAS` (Simba pool) with hardware/subvolume redundancy. Backing them up into another folder on the same NAS creates redundant storage loops. |
| **CurseForge Modpack Data** (`C:\Users\dylan_93nze6m\curseforge`) | ~916 MB | Modpack jars and downloaded assets can be fetched on-demand from CurseForge. *(Omitted by default pending confirmation with Dylan; can be activated if custom local world configs are present).* |
| **Temporary Caches & Build Garbage** (`AppData\Local\Temp`, `node_modules`, `__pycache__`, `*.tmp`, `*.log`, `Thumbs.db`) | 5–20 GB | Transient scratch files that churn constantly and bloat snapshot indexes without providing recovery value. |
| **Optical Disc Images on Desktop** (`*.ISO`) | 3.7+ GB | Large static emulator disc dumps (e.g. PS2 ISOs) that do not change and bloat daily incremental passes. |

---

## 4. Administrator Operations & Snapshot Management

Because client nodes run in **`--append-only`** mode, you as the system administrator must perform maintenance, pruning, or snapshot removal directly on the server host (`services` CT 920 or `RATH15NAS`).

### 4.1. Viewing Available Snapshots
From your workstation, SSH into the LXC container:
```bash
ssh services
```
Run the ephemeral restic administration container:
```bash
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/htpc snapshots
```

### 4.2. Removing an Unwanted or Erroneous Snapshot
If a large file or mistaken directory was captured in a backup and you want to erase it completely:
```bash
# 1. Identify the snapshot ID from the command above (e.g., 817e5c91)
# 2. Delete the snapshot reference and reclaim the raw storage space:
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/htpc \
  forget <SNAPSHOT_ID> --prune
```

### 4.3. Recommended Server-Side Retention Policy
To prevent infinite storage accumulation while keeping a robust historical trail, run this rolling retention command (e.g., as a weekly cron job on CT 920):
```bash
docker run --rm -v /mnt/backups:/data -e RESTIC_PASSWORD="<repo_key>" restic/restic:latest -r /data/htpc \
  forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
```
* Retains **7 daily snapshots** (full daily rollback for the trailing week).
* Retains **4 weekly snapshots** (weekly rollback for the trailing month).
* Retains **12 monthly snapshots** (monthly historical checkpoints for the year).
* Automatically reclaims unreferenced data blocks via `--prune`.

### 4.4. Proxmox Btrfs Snapshot Safety Net
Before executing any major pruning or manual repository manipulation, create an instantaneous snapshot of the Btrfs subvolume on the Proxmox host (`RATH15NAS` - `192.168.68.169`):
```bash
# Run on RATH15NAS:
sudo btrfs subvolume snapshot /mnt/backups /mnt/backups-snapshot-$(date +%F)
```
If anything ever goes wrong, rollback takes under 5 seconds.

---

## 5. Disaster Recovery & Restoration Playbook

### Scenario A: Restoring a Single Deleted or Corrupted File
To recover a file (e.g., a deleted document) to a temporary folder on `rath15-htpc`:
```cmd
# Over SSH on rath15-htpc:
restic -r rest:http://htpc:<pw>@192.168.68.175:8000/htpc/ --password-file C:\ProgramData\restic\repo_key.txt restore latest --target C:\Restore_Temp --include "C:\Users\benka_000\Documents\Important.docx"
```

### Scenario B: Restoring an Entire User Directory
To restore Dylan's custom mod creations or save states:
```cmd
restic -r rest:http://htpc:<pw>@192.168.68.175:8000/htpc/ --password-file C:\ProgramData\restic\repo_key.txt restore latest --target C:\Restore_Temp --include "C:\Users\dylan_93nze6m\MCreatorWorkspaces"
```

### Scenario C: Browsing Historical Snapshots via Virtual Drive Mount
Restic allows mounting any historical snapshot as a virtual read-only Windows drive letter (requires WinFsp installed):
```cmd
restic -r rest:http://htpc:<pw>@192.168.68.175:8000/htpc/ --password-file C:\ProgramData\restic\repo_key.txt mount X:
```
You can then browse snapshots directly in Windows File Explorer as if they were local folders.

---

## 6. Future Monitoring & Alignment Roadmap

To maintain operational visibility and verify daily execution without manually checking logs:
1. **Completion Telemetry (Planned):**
   * Integrate an alert hook into `C:\ProgramData\restic\backup.ps1` upon completion.
   * Delivery options under evaluation:
     * **Email (SMTP):** Native PowerShell `Send-MailMessage` or mail gateway script sending a summary log on success/failure.
     * **Discord Webhook:** Instant ping to a private family/admin Discord channel with snapshot metrics (duration, files backed up, MB transferred).
     * **NTFY / Pushover:** Lightweight push notification directly to phone.
2. **Health Check Monitoring:**
   * Probing the latest snapshot age from Home Assistant or Uptime Kuma to raise an alert if no new snapshot has been recorded in >36 hours.
