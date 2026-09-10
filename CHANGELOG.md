# Changelog

All notable changes, architectural decisions, and maintenance operations for this workstation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-09-10]

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
