# Changelog

All notable changes, architectural decisions, and maintenance operations for this workstation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-09-11]

### ADR: Deployment of "Asylum Reborn" 4K/2K HD Texture Overhaul and Standalone Advanced Launcher for Batman: Arkham Asylum

#### Context
1. **The Problem / Requirement:** The user desired remastered 4K/2K visual fidelity for *Batman: Arkham Asylum GOTY* running on `rath15-htpc` and streamed to the Workstation. Vanilla textures from 2009 exhibit noticeable compression and blur at modern resolutions. The solution required non-invasive deployment without runtime DLL/RAM hooks (TexMod/uMod), without requiring elevated privileges for user `gamer`, and without introducing stability or performance regressions.
2. **Constraints & Trade-offs:**
   * **Engine Architecture:** Unreal Engine 3 compiles texture caches into `.tfc` packages. Modifying textures natively requires permanent injection into the engine package files rather than volatile memory hooks.
   * **Zero-LPE Security:** Dedicated gaming user `gamer` has zero administrative rights and cannot install system-wide .NET runtimes. Any third-party launcher or tool must run standalone or leverage pre-installed runtimes.
   * **Pre-Flight Antivirus Defense:** All downloaded mod archives, executables, and batch scripts must undergo verification scans via Microsoft Defender before staging and execution.
   * **Reversibility & Rollback:** Vanilla texture archives (~945 MB) and executables must be fully backed up to allow instantaneous recovery without redownloading through Steam.

#### Action
1. **Implementation Steps:**
   * Scanned all incoming packages with Microsoft Defender Antivirus (`MpCmdRun.exe`), verifying zero threats across `Asylum Reborn - HD Texture Pack` (550 MB), `Batman Arkham Asylum - Advanced Launcher Standalone` (250 MB), and `TFC Installer` (9.4 MB).
   * Backed up vanilla game assets: `Textures.tfc` (945 MB) ➡️ `Textures.tfc.vanilla.bak` and `BmLauncher.exe` (8.5 MB) ➡️ `BmLauncher.exe.vanilla.bak`.
   * Deployed Neato's standalone .NET 8 `BmLauncher.exe` (self-contained 250 MB binary) into `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY\Binaries\`, eliminating all external framework dependencies.
   * Injected 4K/2K DirectDraw Surface (`.dds`) textures into `CookedPC` using `TFCInstaller.exe` in an isolated staging workspace, generating `Texture2D_0.tfc` (578 MB) and patching 351 map and character packages.
   * Tuned engine parameters in `BmEngine.ini`: expanded `PoolSize` from vanilla 120 MB to 2048 MB VRAM allocation, and enabled high-res LOD overrides across `Character`, `World_Hi`, `WorldNormalMap_Hi`, and `Cinematic` texture groups.
   * Executed headless console handoff via [`scripts/htpc/switch_and_stream.ps1`](scripts/htpc/switch_and_stream.ps1), binding `gamer` to the physical RTX 3060 adapter with verified Remote Play port `27036` connectivity.
2. **Key Parameters:**
   * Game Installation: `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY`
   * Target Texture Cache: `BmGame\CookedPC\Texture2D_0.tfc` (577,694,792 bytes)
   * Engine Configuration: `BmEngine.ini` (`PoolSize=2048`, `Texture Pack Support: Enabled`)
   * Vanilla Backups: `Textures.tfc.vanilla.bak` (991,494,144 bytes), `BmLauncher.exe.vanilla.bak` (8,579,400 bytes)
   * Launcher: Standalone .NET 8 `BmLauncher.exe` v2.1.0.5

#### Consequences
* **Positive:** Unlocked 4K/2K remastered visuals streamed headlessly at 60 FPS powered by RTX 3060 NVENC encoding; zero runtime memory injection instability; native engine texture streaming.
* **Operational:** Mod management is fully decoupled from daily gaming; vanilla state is 100% recoverable instantly via `.vanilla.bak` restores without Steam redownload.
* **Security:** All binaries verified clean by Defender; zero privilege elevation required; standard user `gamer` remains strictly sandboxed.

### ADR: Headless In-Home Game Streaming via Steam Remote Play and Zero-LPE Console Handoff to HTPC

#### Context
1. **The Problem / Requirement:** The user desired high-performance, low-latency PC gaming on the developer workstation (`LENOVO16_LP`) utilizing the dedicated NVIDIA GeForce RTX 3060 graphics processor on `rath15-htpc` (`192.168.68.162`) via Steam Remote Play. The physical television connected to `rath15-htpc` is actively used for living room entertainment (Google TV on an alternate HDMI input), requiring completely non-invasive, headless session switching, user account isolation, and zero HDMI mode disruptions.
2. **Constraints & Trade-offs:**
   * **TV Display Independence:** Windows session handoffs (`tscon %SessionId% /dest:console`) attach directly to the physical RTX 3060 display adapter without triggering HDMI-CEC input switching or video signal interruptions on the television.
   * **Zero-LPE Security Boundary:** Creating an unhardened scheduled task running as `NT AUTHORITY\SYSTEM` triggerable by standard user `gamer` introduces a classic Local Privilege Escalation (LPE) vulnerability (MITRE ATT&CK T1053.005) via script replacement. The architecture strictly mandates that `gamer` possesses **zero elevated tasks**; all console handoffs are driven over authenticated OpenSSH from the Workstation using administrative `benka_000` ed25519 keys.
   * **Pragmatic Game Management:** Headless CLI game installation across multi-drive Steam libraries proved brittle due to interactive drive-picker modals. Game installations are designated as occasional visual RDP operations, while daily gaming operates 100% headlessly.

#### Action
1. **Implementation Steps:**
   * Provisioned dedicated local standard user `gamer` on `rath15-htpc`, assigned to the `Remote Desktop Users` security group with non-expiring credentials stored in Windows Credential Manager (`TERMSRV/rath15-htpc`).
   * Configured Steam on HTPC for target account `coppertrumpet2`, secured a long-lived persistent OAuth/JWT session token (valid through April 2027), and updated `loginusers.vdf` and `config.vdf` (`AlwaysShowUserChooser: 0`, `AutoLogin: 1`) to eliminate interactive account-picker prompts on headless start.
   * Developed [`scripts/htpc/switch_and_stream.ps1`](scripts/htpc/switch_and_stream.ps1) and [`scripts/htpc/do_tscon.ps1`](scripts/htpc/do_tscon.ps1) to orchestrate session inspection, background RDP handshake, one-shot temporary SYSTEM `tscon` console attachment, and verification of Steam Remote Play TCP port `27036`.
   * Created non-invasive desktop telemetry tool [`scripts/htpc/get_screenshot.ps1`](scripts/htpc/get_screenshot.ps1) with Win32 DPI awareness to verify GUI dialog states without user disruption.
   * Successfully installed *Batman: Arkham Asylum GOTY Edition* to `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY` (8.47 GB).
   * Verified hardware-accelerated NVENC H.264 video streaming at 60 FPS, Steam Streaming Speakers low-latency audio, and Xbox wireless controller input routing via Steam Input.
   * Synchronized architectural documentation in [`ARCHITECTURE.md`](ARCHITECTURE.md) Section 12.
2. **Key Parameters:**
   * Host Node: `rath15-htpc` (`192.168.68.162`), Windows 11 Pro, RTX 3060 (Driver `32.0.15.9621`)
   * Client Node: `LENOVO16_LP` (`192.168.68.166` / `192.168.68.154`)
   * Shared Steam Account: `coppertrumpet2`
   * Networking Ports: TCP `27036` (Control), UDP `27031` / `27036` (Streaming Transport)
   * Local Libraries: `F:\SteamLibrary` (155 GB free), `H:\SteamLibrary` (372 GB free)
   * Automation Scripts: [`scripts/htpc/switch_and_stream.ps1`](scripts/htpc/switch_and_stream.ps1), [`scripts/htpc/do_tscon.ps1`](scripts/htpc/do_tscon.ps1), [`scripts/htpc/ensure_steam_stream.ps1`](scripts/htpc/ensure_steam_stream.ps1)

#### Consequences
* **Positive:** Unlocked high-framerate PC gaming on the developer laptop powered by remote RTX 3060; zero television disruptions; complete separation between development and gaming identities.
* **Operational:** Installing new games is performed visually via RDP as `gamer`; post-install handoff or daily gaming is executed via `switch_and_stream.ps1`.
* **Security:** User `gamer` is strictly unprivileged; elevated console switching is confined to authenticated SSH administration with zero persistent privilege escalation vectors.

## [2026-09-10]

### ADR: Establishment of Additive Calibre Library Sync and Consolidation to NAS Media Storage

#### Context
1. **The Problem / Requirement:** The user required regular, automated synchronization of the primary workstation Calibre ebook library (`D:\Calibre_Library_Main`) to local network storage on `RATH15NAS` for access via Calibre-Web and family devices. However:
   * Workstation could not mount or browse `S:` (`\\RATH15NAS\simba`) due to Windows 11 blocking unauthenticated guest logons resulting from a username mismatch (`benma` on workstation vs `bjm` on NAS) and missing stored credentials.
   * On the NAS, books resided separately at `/mnt/simba/Books` instead of within the centralized media hierarchy (`/mnt/simba/Media/Books`).
   * The synchronization policy had to be non-destructive: books uploaded directly via Calibre-Web or added manually to the NAS must never be purged or deleted by workstation synchronization.
2. **Constraints & Trade-offs:**
   * **Zero Deletion Guarantee:** Omitted `/MIR` and `/PURGE` from Robocopy; utilized `/E` and `/XO` (exclude older) to ensure purely additive synchronization and protect web-uploaded titles.
   * **Container Continuity:** Containerized `calibre-web` (CT 920 on `services`) required re-pointing its bind mount to the relocated path without database corruption or permission issues.
   * **Authentication Hardening:** Restored SMB client access via explicit Windows Credential Manager mapping to user `bjm` rather than weakening Windows 11 guest security policies.

#### Action
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

#### Consequences
* **Positive:** Complete consolidation of books under the `/Media` taxonomy, functional Calibre-Web library integration, seamless workstation access to `S:`, and automated daily synchronization.
* **Operational:** Additive sync model means books deleted on the workstation will persist on the NAS (requiring deliberate manual pruning on Calibre-Web if removal is desired), completely eliminating the risk of losing web-uploaded ebooks.
* **Security:** Workstation SMB credentials cleanly isolated in Windows Credential Manager without enabling insecure guest authentication.

### ADR: Integration of Calibre Ebook Library into Workstation Backup Scope

#### Context
1. **The Problem / Requirement:** The user identified `D:\Calibre_Library_Main` (13,472 files / 19.2 GB) containing a curated, irreplaceable digital ebook library (EPUB, MOBI, PDF, JPEG covers, and Calibre SQLite database `metadata.db`) as requiring disaster recovery protection terminating on the home lab REST server (`services` CT 920 on `RATH15NAS`).
2. **Constraints & Trade-offs:**
   * **Pool Capacity:** Hypervisor backup storage (`/mnt/backups`) has 3.6 TB free pool; 19.2 GB consumes < 0.5% of capacity.
   * **Incremental Speed:** Initial ingestion of 19.2 GB takes ~5 minutes over LAN, but daily incremental change scans must remain negligible (< 10 seconds).
   * **Zero File Mutation:** Backup pipeline requires strictly read-only traversal of the Calibre directory.

#### Action
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

#### Consequences
* **Positive:** Guaranteed sovereign disaster recovery for irreplaceable ebook library without external cloud subscription dependencies.
* **Operational:** Sub-10-second daily incremental scans ensure zero disruption to workstation performance or scheduled task execution.

### ADR: Deployment of Ransomware-Resilient Daily Encrypted Backup Pipeline (Restic REST Server)

#### Context
1. **The Problem / Requirement:** Following the cancellation of the Microsoft 365 / OneDrive cloud subscription, the developer workstation (`lenovo16_lp`) required a sovereign, automated, client-side encrypted disaster recovery pipeline for primary personal archives, coding projects, SSH keys, and Obsidian notes. The backup target needed to terminate on centralized home lab storage (`RATH15NAS` - Proxmox hypervisor) without installing custom services directly on the bare-metal hypervisor, and with robust protection against ransomware attacks that could target local network shares.
2. **Constraints & Trade-offs:**
   * **Vanilla Proxmox Hypervisor:** The Proxmox host (`192.168.68.169`) must remain 100% vanilla without installing third-party application runtimes.
   * **Ransomware Defense:** Backup backend must enforce immutable/append-only permissions from the client perspective so a compromised workstation cannot destroy or overwrite historical recovery snapshots.
   * **Tenant Isolation:** Workstation repository (`workstation`) must be strictly segregated from HTPC (`htpc`).
   * **High Efficiency & Low Noise:** Backups must execute silently in the background without Win32 console pipe deadlocks or disk thrashing.
   * **Hydrated Data Verification:** Verified that all 808 files in `C:\Users\benma\OneDrive` were 100% physically hydrated on the local NVMe drive (0 cloud-only stubs).
   * **Game Save Optimization:** Inspected Steam Cloud manifests (`remotecache.vdf` and `steam_autocloud.vdf`); confirmed 100% of game saves for *Kingdom Come: Deliverance* (saves 1–451) and *God of War* are cloud-synced via Steam Cloud, allowing safe exclusion of `Saved Games` (~918 MB) from local backup to prevent bloat.

#### Action
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

#### Consequences
* **Positive:** Complete elimination of cloud subscription reliance with sovereign, zero-trust AES-256 encrypted backups to local NAS storage.
* **Security:** Enforced `--append-only` mode at the REST server guarantees mathematical immunity against ransomware or compromised endpoint snapshot deletion.
* **Operational:** Headless execution takes ~1 second on daily incremental passes without interrupting active development. Admin retains full sovereign control to view, prune, or remove snapshots via CT 920.

## [2026-09-09]

### ADR: Microsoft GameInput Conflict Resolution & Service Unification

#### Context
1. **The Problem / Requirement:** System logs revealed recurring `MsiInstaller` Event ID 1035 reconfiguration cycles and a sleep-state hard shutdown (`Kernel-Power` Event ID 41, `BugcheckCode 0`) occurring during Modern Standby. Inspection identified two competing GameInput services: the native Windows 11 system service (`GameInputSvc` in `System32`) and a redundant standalone MSI redistributable (`GameInputRedistService` v3.3.221.0 in `Program Files\Microsoft GameInput`).
2. **Constraints & Trade-offs:** Controller support and input APIs must remain completely operational. The native Windows 11 system service handles all GameInput APIs and renders the standalone redistributable redundant.

#### Action
1. **Implementation Steps:**
   * Developed maintenance script [`scripts/uninstall_gameinput.ps1`](file:///C:/Users/benma/coding/agy_project/Projects/Workstation/scripts/uninstall_gameinput.ps1).
   * Executed silent uninstallation of standalone package `{14EDF950-06B9-415F-862C-1D5DEC321AE6}` (`Microsoft.GameInput`).
   * Purged redundant `GameInputRedistService` while retaining native Windows 11 `GameInputSvc` (`C:\WINDOWS\System32\GameInputSvc.exe`).
   * Updated `ARCHITECTURE.md` Section 9 to document the tradeoff decision.
2. **Key Parameters:**
   * Target Package: `Microsoft GameInput` (`3.3.221.0`)
   * Removed Service: `GameInputRedistService`
   * Retained Service: `GameInputSvc` (Status: Running)
3. **Verification & Testing:**
   * Executed `Get-Service *gameinput*`; confirmed only native `GameInputSvc` is present and active.
   * Executed `winget list -q GameInput`; confirmed package completely deregistered.
   * Confirmed Event ID 1034 / 11724 (successful removal) in Application Event Log.

#### Consequences
* **Positive:** Completely eliminates background MSI reconfiguration loops and removes a known trigger of Modern Standby stalls and sleep-state hard resets.
* **Operational:** Peripheral and controller support continues natively via the built-in Windows 11 system service.
* **Security:** Removes unmanaged third-party binary surface in `Program Files`.

## [2026-09-08]

### Maintenance: Ephemeral Cache Cleanup (Tier 2)

* **npm Cache:** Executed `npm cache clean --force`; purged stale global package tarballs, reclaiming **410.22 MB** (footprint reduced to 12 MB).
* **pip Cache:** Executed `python -m pip cache purge`; purged leftover wheel build caches, reclaiming **30.20 MB** (footprint reduced to 0 MB).
* **User Temp:** Purged stale, unlocked temporary files from `%TEMP%`, reclaiming **15.15 MB**.
* **Automation:** Scripted into version-controlled utility `scripts/cleanup_caches.ps1`.
* **Total Ephemeral Reclamation:** **455.57 MB**.
* **Post-Optimization Verification:** Regenerated `reports/baseline_inventory.md`; confirmed disk free space on C: increased to 204.61 GB and available RAM rose to 2.76 GB.

### ADR: Host Python Simplification & Devbox Offloading Strategy

#### Context
1. **The Problem / Requirement:** The host workstation had dual Python installations (Python 3.12 in user AppData and Python 3.14 in system root) registered across multiple package managers (Winget and Chocolatey), alongside a conflicting Microsoft Store execution alias for `python3.exe`. Because primary application engineering, models, and container builds are offloaded to the dedicated devbox, maintaining multiple local runtimes created unnecessary version fragmentation.
2. **Constraints & Trade-offs:** The host requires a reliable, lightweight Python environment strictly for system management, local scripts, and agent tooling. Both `python` and `python3` commands must execute cleanly without opening the Microsoft Store.

#### Action
1. **Implementation Steps:**
   * Executed `winget uninstall --id Python.Python.3.12 --silent` to cleanly remove the user-level Python 3.12 runtime and unregister it from Windows.
   * Created and executed `scripts/finalize_python_unification.ps1` to purge residual user `site-packages` (reclaimed 40.45 MB) and deploy `python3.cmd` shim (`@"C:\Python314\python.exe" %*`) to `%LOCALAPPDATA%\agy\bin`.
   * Updated `ARCHITECTURE.md` Section 6.1 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Unified Host Runtime: `Python 3.14.6` (`C:\Python314\python.exe`)
   * Removed Package: `Python.Python.3.12`
   * Shim Path: `%LOCALAPPDATA%\agy\bin\python3.cmd`
3. **Verification & Testing:**
   * Executed `py --list`; confirmed only `-V:3.14 * Python 3.14 (64-bit)` is registered.
   * Executed `python --version` -> `Python 3.14.6`.
   * Executed `python3 --version` -> `Python 3.14.6`.
   * Confirmed zero Microsoft Store popups or execution alias errors.

#### Consequences
* **Positive:** Completely eliminated runtime drift and Microsoft Store alias traps. The local host workstation operates with a lean, single-version Python 3.14 installation dedicated to host automation, with zero clutter from legacy project libraries.
* **Operational:** All application development, virtual environments, and heavy libraries remain isolated on devbox.
* **Security:** Reduced attack surface and dependency vulnerabilities by purging unmanaged local Python 3.12 site-packages.

### ADR: User PATH Hygiene & Runtime Toolchain Standardization

#### Context
1. **The Problem / Requirement:** The User PATH environment variable (`HKCU:\Environment`) contained an invalid file path pointer (`C:\Program Files\nodejs\node.exe` instead of a directory) and lingering pointers to Python 3.12 (`C:\Users\benma\AppData\Local\Programs\Python\Python312\`). This caused runtime version collision with the primary Python 3.14 toolchain configured in System PATH (`C:\Python314\`), leading to command resolution ambiguity across terminal shells.
2. **Constraints & Trade-offs:** Node.js execution must remain unaffected (authoritatively handled by `C:\Program Files\nodejs\` in System PATH). Python 3.14 must become the unambiguous primary interpreter. User PATH changes must be fully restorable via automated tooling.

#### Action
1. **Implementation Steps:**
   * Backed up current raw User PATH string to `reports/backup_user_path.txt`.
   * Created reversible maintenance scripts `scripts/optimize_user_path.ps1` and `scripts/restore_user_path.ps1`.
   * Executed `scripts/optimize_user_path.ps1` removing `node.exe` and `Python312` paths from `HKCU:\Environment`.
   * Broadcasted environment update `WM_SETTINGCHANGE` to running shells.
   * Updated `ARCHITECTURE.md` Section 6.1 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Target Resource: `HKCU:\Environment` (`Path`)
   * Pruned Entries:
     * `C:\Program Files\nodejs\node.exe`
     * `C:\Users\benma\AppData\Local\Programs\Python\Python312\Scripts\`
     * `C:\Users\benma\AppData\Local\Programs\Python\Python312\`
   * Unified Python: `Python 3.14.6` at `C:\Python314\python.exe`
   * Reversal Script: `scripts/restore_user_path.ps1`
3. **Verification & Testing:**
   * Verified User PATH contains only valid directories (`agy\bin`, `Python\Launcher`, `WindowsApps`, `VS Code\bin`, `npm`, `Antigravity IDE\bin`, `rclone`).
   * Executed `python --version` -> `Python 3.14.6`.
   * Executed `node --version` -> `v24.16.0`.
   * Validated `agy`, `npm`, and `git` command resolution.

#### Consequences
* **Positive:** Restored clean PATH directory syntax, eliminated version shadowing between Python 3.12 and 3.14, and unified execution across all developer shells.
* **Operational:** Running `python` explicitly targets 3.14. If Python 3.12 is ever needed for a legacy project, it remains installed on disk and can be referenced directly or managed via virtual environments (`py -3.12 -m venv`).
* **Security:** Reduced PATH traversal risks from invalid file references.

### ADR: Enforce WSL2 Resource Sandbox via .wslconfig

#### Context
1. **The Problem / Requirement:** The workstation host runs WSL2 (`Ubuntu`), but lacks a `%USERPROFILE%\.wslconfig` boundary file. By default, WSL2 dynamically claims up to 50% of total host RAM (7.5 GB on this 16 GB machine) without aggressive memory reclamation. Since primary container and Linux development is now offloaded to the dedicated codebox, unconstrained local WSL allocation presents unnecessary host memory contention risk.
2. **Constraints & Trade-offs:** Local Linux tools must remain accessible without deleting the Ubuntu distro (7.58 GB `ext4.vhdx`). Resource ceilings must guarantee the Windows host never experiences out-of-memory pressure or page-file thrashing from dormant or minor WSL tasks.

#### Action
1. **Implementation Steps:**
   * Created version-controlled configuration template at `configs/.wslconfig`.
   * Created deployment script `scripts/apply_wslconfig.ps1` and rollback script `scripts/remove_wslconfig.ps1`.
   * Applied configuration to `%USERPROFILE%\.wslconfig` setting `memory=2GB`, `processors=2`, `swap=1GB`, and `autoMemoryReclaim=dropcache`.
   * Executed `wsl --shutdown` to cleanly enforce bounds on the subsystem.
   * Updated `ARCHITECTURE.md` Section 4.2 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Target Path: `%USERPROFILE%\.wslconfig`
   * Memory Limit: `2GB`
   * Processor Limit: `2 vCPUs`
   * Swap Limit: `1GB`
   * Memory Reclaim Mode: `dropcache`
   * Reversal Script: `scripts/remove_wslconfig.ps1`
3. **Verification & Testing:**
   * Verified `%USERPROFILE%\.wslconfig` file contents.
   * Confirmed successful shutdown and registration with WSL2.

#### Consequences
* **Positive:** Guaranteed host stability; WSL2 can never consume more than 2 GB of memory. Cached memory is proactively reclaimed and returned to Windows.
* **Operational:** Heavy multi-core container builds cannot be run locally without adjusting `.wslconfig`, which aligns with the decision to offload container workflows to the codebox.
* **Security:** Hardened host boundaries by limiting compute and memory access granted to subsystem virtual machines.

### ADR: Disable Browser Background Pre-Launchers for Memory Reclamation

#### Context
1. **The Problem / Requirement:** Google Chrome, Microsoft Edge, and Microsoft Copilot automatically launch at Windows boot with `--no-startup-window`, pre-allocating memory and retaining dozens of background Chromium worker processes in RAM even when windows are closed. Across both engines, active memory consumption exceeded 6.1 GB, causing severe memory pressure (88% utilization) on a 16 GB workstation.
2. **Constraints & Trade-offs:** Zero impact to bookmarks, history, user profiles, or browser extensions. Zero impact to standalone cloud sync clients (Google Drive for Desktop). The decision must remain an easily reversible "two-way door" if background pre-warming is ever desired.

#### Action
1. **Implementation Steps:**
   * Exported structured JSON registry backup to `reports/backup_browser_autostart.json`.
   * Created reversible maintenance scripts: `scripts/disable_browser_autostart.ps1` and `scripts/restore_browser_autostart.ps1`.
   * Executed `scripts/disable_browser_autostart.ps1` removing `GoogleChromeAutoLaunch_*`, `MicrosoftEdgeAutoLaunch_*`, and `MicrosoftCopilotAutoLaunch_*` from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`.
   * Verified that remaining entries preserve core productivity tools (OneDrive, Google Drive, Signal, Lenovo Vantage).
   * Updated `ARCHITECTURE.md` Section 7 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Registry Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
   * Removed Values: `GoogleChromeAutoLaunch_4D84F28729775318C627E672514BD80D`, `MicrosoftEdgeAutoLaunch_321C9B9C46B6500E0A5A39232496A26D`, `MicrosoftCopilotAutoLaunch_E4CE1E454A58C9D2EC7FDA74FB4FEC1D`
   * Reversal Script: `scripts/restore_browser_autostart.ps1`
3. **Verification & Testing:**
   * Queried `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`; confirmed all three browser pre-launch keys are absent.
   * Confirmed Google Drive FS and Signal remained unaffected.

#### Consequences
* **Positive:** Prevents duplicate Chromium engines from pre-allocating gigabytes of RAM on boot. Closing browser windows now properly releases memory back to Windows for developer workloads and AI orchestration.
* **Operational:** Browser launch on cold boot takes ~1 second from NVMe storage instead of opening instantaneously from pre-warmed RAM. Background web push notifications only trigger while browser windows are open.
* **Security:** Reduced background process surface area by eliminating persistent, unprompted browser daemons.

### ADR: Transition Game Launchers to On-Demand Execution

#### Context
1. **The Problem / Requirement:** The host machine boots multiple heavy game launchers (EA Desktop `EALauncher.exe` and GOG Galaxy `GalaxyClient.exe`) on login via `HKCU Run`, causing unnecessary boot latency, idle RAM consumption, and recurring network polling on a primary development machine.
2. **Constraints & Trade-offs:** The applications must remain fully installed, functional, and intact. Game library launching must remain completely accessible when deliberately invoked by the user.

#### Action
1. **Implementation Steps:**
   * Exported pre-optimization registry backups to `reports/backup_run_hkcu.reg` and `reports/backup_run_hklm.reg`.
   * Created and executed `scripts/optimize_autostart.ps1` to remove `EADM` and `GogGalaxy` properties from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`.
   * Verified that remaining entries preserve essential productivity and security tools (KeePass 2, OneDrive, Google Drive, Signal, Lenovo Vantage).
   * Updated `ARCHITECTURE.md` Section 7 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Registry Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
   * Removed Values: `EADM` (`"C:\Program Files\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe" -silent`), `GogGalaxy` (`C:\Program Files (x86)\GOG Galaxy\GalaxyClient.exe /launchViaAutoStart`)
   * Backup Path: `reports/backup_run_hkcu.reg`
3. **Verification & Testing:**
   * Queried `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`; confirmed `EADM` and `GogGalaxy` are absent.
   * Confirmed zero filesystem changes to game installation directories.

#### Consequences
* **Positive:** Reduced Windows startup time, eliminated idle memory and CPU overhead from dormant game client updaters, freed resources for developer workloads.
* **Operational:** Playing games on EA or GOG now requires launching the respective client manually from the Start Menu or desktop shortcut instead of starting automatically at login.
* **Security:** Reduced attack surface by preventing network-connected background daemons from running automatically with user session privileges.

### ADR: Workstation Baseline Inventory & System Architecture Specification

#### Context
1. **The Problem / Requirement:** The workstation lacked an authoritative hardware, storage, networking, runtime, and autostart specification to establish baseline health, memory utilization, and safety boundaries before attempting optimization or cleanups.
2. **Constraints & Trade-offs:** Strictly non-invasive read-only inspection (Tier 1) with zero mutation to system files, registry entries, or services during discovery.

#### Action
1. **Implementation Steps:**
   * Executed non-invasive host inventory script `scripts/inspect_host.ps1` to query CIM/WMI hardware profiles, logical disk topology, developer runtimes, WSL distributions, active network interfaces, cache directories, and autostart registry entries.
   * Captured full timestamped inventory report in `reports/baseline_inventory.md`.
   * Refined script logic for accurate multi-core CPU enumeration (`Select-Object -First 1`) and WSL text output sanitization.
   * Authored authoritative `ARCHITECTURE.md` capturing hardware topology (Ryzen 5 7530U, 16GB DDR4, dual-NVMe Micron 512GB + Crucial 1TB), OS and subsystem configurations, developer toolchains, autostart overhead analysis, and execution safety tiers.
2. **Key Parameters:**
   * Host: `LENOVO16_LP` (Lenovo ThinkPad E16 Gen 1 AMD `21JT001GAU`)
   * OS: Windows 11 Pro 64-bit (Build 26200)
   * Storage: Drive `C:` (474.72 GB, 203.69 GB free), Drive `D:` (931.50 GB, 292.76 GB free)
   * Primary Network Uplink: `Wi-Fi` (`192.168.68.163` via RZ616 Wi-Fi 6E)
   * WSL Bridge: `vEthernet (WSL)` (`192.168.0.1`)
3. **Verification & Testing:**
   * Validated exit code 0 on `scripts/inspect_host.ps1`.
   * Confirmed generated report structure in `reports/baseline_inventory.md`.
   * Validated markdown formatting and mermaid diagrams in `ARCHITECTURE.md`.

#### Consequences
* **Positive:** Established a reproducible, version-controlled baseline of host hardware, software runtimes, and startup services; identified primary memory pressure factors (autostart background pre-loaders and game clients).
* **Operational:** Future system mutations or runtime updates will synchronize against `ARCHITECTURE.md` and require explicit ADR logging in `CHANGELOG.md`.
* **Security:** Formalized Tier 1-3 execution governance boundaries directly within project architecture docs to guarantee safe execution.

### ADR: Workstation Audit & Governance Initialization

#### Context
1. **The Problem / Requirement:** The host machine requires a comprehensive architectural inventory and cautious, non-disruptive cleanup of developer runtimes, caches, and legacy files.
2. **Constraints & Trade-offs:** Zero operational disruption to the workstation; strictly adhere to tiered execution (autonomous read-only inspection, mandatory pre-flight security cards for mutations).

#### Action
1. Created dedicated repository at `Projects/Workstation`.
2. Configured workspace boundaries and execution tiers in `AGENTS.md`.
3. Created non-invasive baseline inspection script `scripts/inspect_host.ps1`.

#### Consequences
* **Positive:** Isolated audit workspace; inherits global governance rules and changelog discipline from `personal-governance`.
* **Operational:** Maintenance records and system architecture documents will be tracked via Git version control.
* **Security:** Hardened safety boundaries prevent accidental modification of system files or registry keys.
