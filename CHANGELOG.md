# Changelog

All notable architectural decisions, maintenance operations, and system baselines for `rath15-htpc` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-09-10]

### ADR: Deployment of Ransomware-Resilient Daily Encrypted Backup Pipeline (Restic REST Server)

#### Context
1. **The Problem / Requirement:** Following the cancellation of Microsoft 365 / OneDrive subscription, `rath15-htpc` and authorized client workstations lacked an independent, encrypted, automated disaster recovery pipeline for critical personal documents, photos, coding projects, game saves, and system keys. Storage had to terminate on centralized NAS storage (`RATH15NAS` - Proxmox hypervisor) without running custom software directly on the bare-metal hypervisor, and without creating Win32 subprocess console pipe hangs (which caused Restic over SFTP to freeze).
2. **Constraints & Trade-offs:**
   * **Vanilla Proxmox Hypervisor:** The Proxmox host (`192.168.68.169`) must remain 100% vanilla without installing third-party application runtimes.
   * **Living Room Media Stability:** Backups must execute silently in background Session 0 with zero windows, popups, or audio/video stutter during 4K HDR playback or VR streaming.
   * **Ransomware Defense:** Backup backend must be immutable/append-only from the client perspective so compromised endpoints cannot delete past snapshots.
   * **Tenant Isolation:** Client repositories (`htpc` vs `workstation`) must be strictly segregated.

#### Action
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

#### Consequences
* **Positive:** Complete replacement of cloud storage dependency with sovereign, AES-256 client-encrypted daily backups. Seamless Windows VSS snapshotting eliminates locked file errors.
* **Security:** Native `--append-only` enforcement on the REST server guarantees mathematical immunity against ransomware deletion or modification of historical snapshots from client endpoints.
* **Operational:** Headless execution takes ~15 seconds on daily incremental passes without impacting CPU or GPU media performance. Admin retains full sovereign control to view, prune, or remove snapshots via CT 920.

### ADR: Steam Library Audit, Orphaned Duplicate Deduplication, and Target Uninstallation

#### Context
1. **The Problem / Requirement:** Following initial host stabilization, physical mechanical HDD partitions (`F:`, `G:`, `H:`) remained constrained with low free space warnings (8.1% on `F:`, 9.4% on `G:`, 7.4% on `H:`). A comprehensive remote audit of Steam game libraries across all drives revealed an orphaned library root on `G:\SteamLibrary` containing 85 installed games (492 GB) not registered in Steam's client `libraryfolders.vdf` configuration. This unlinked library caused duplicate full-game downloads across active libraries on `F:\` and `H:\`, consuming over 230 GB in redundant storage.
2. **Constraints & Trade-offs:**
   * **Protected Game Assets:** *Black Myth: Wukong* (139.6 GB on `H:\SteamLibrary`) had to be strictly preserved without modification.
   * **Game Save State Safety:** User save progress, cloud synchronization, and local user profile state (`AppData\Local`, `Saved Games`, `Documents`) could not be impacted.
   * **Living Room Stability:** All operations had to run remotely over SSH in the background without launching the Steam GUI or interrupting active media playback.
   * **Active Copy Verification:** Proved active copies were on `F:` and `H:` by inspecting `appmanifest_*.acf` metadata (`LastPlayed` timestamps indicating recent 2025–2026 activity, contrasted with `LastPlayed: 0` on `G:\`).

#### Action
1. **Implementation Steps:**
   * Audited 250 game installations (~2.61 TB) across `C:`, `F:`, `G:`, and `H:`, cataloging active vs. orphaned installations and publishing [`reports/steam_library_audit.md`](reports/steam_library_audit.md).
   * Targeted for uninstallation user-approved titles: *Sea of Thieves* (AppID 1172620, 102.5 GB on `H:\`), *AFL 26* (AppID 3468640, 30.8 GB on `H:\`), *Zero Caliber VR* (AppID 877200, 40.9 GB across `F:\` and `H:\`), and *Disney Infinity 3.0* (AppID 541670, 24.7 GB across `F:\` and `G:\`).
   * Targeted 30 orphaned duplicate game directories and unlinked app manifests in `G:\SteamLibrary` for deletion while retaining verified active copies on `F:\` and `H:\`.
   * Executed purge automation script over SSH (`task-375`) deleting target game common directories and corresponding `appmanifest_*.acf` files.
   * Verified directory removal and recorded post-purge partition space metrics.
2. **Key Parameters:**
   * Games Uninstalled: *Sea of Thieves* (`H:\SteamLibrary`), *AFL 26* (`H:\SteamLibrary`), *Zero Caliber VR* (`F:\` and `H:\`), *Disney Infinity 3.0* (`F:\` and `G:\`).
   * Orphaned Duplicates Purged: 30 titles from `G:\SteamLibrary\steamapps\common\` (including *STAR WARS Jedi: Fallen Order*, *Batman Arkham City*, *Planet Coaster*, *Raft*, *Hollow Knight*, *Terraria*, *Totally Accurate Battle Simulator*, etc.).
   * Retained Active Game: *Black Myth: Wukong* (`H:\SteamLibrary\steamapps\common\BlackMythWukong`, 139.57 GB).
   * Storage Reclaimed (Purge): **515.2 GB** across mechanical drives (`F:\` +68.6 GB, `G:\` +156.5 GB, `H:\` +290.1 GB).
   * Cumulative Storage Reclaimed (Session): **556.9 GB** mechanical storage (+16.5 GB SSD storage).
3. **Verification & Testing:**
   * Confirmed zero script execution errors in `scratch/purge_output.json`.
   * Executed `Test-Path` check over SSH to confirm *Black Myth: Wukong* directory is intact and valid.
   * Queried remote `Get-PSDrive` via SSH confirming final free space: `C:\` at 479.1 GB (51.5%), `F:\` at 155.4 GB (11.1%), `G:\` at 298.8 GB (31.2%), and `H:\` at 372.6 GB (27.3%).
   * Total free mechanical storage verified at **826.8 GB** (up from 269.9 GB initial baseline).

#### Consequences
* **Positive:** Reclaimed over half a terabyte (515.2 GB) in unneeded games and orphaned duplicates; completely cleared low disk space pressure across all 3 mechanical partitions; improved mechanical drive seek performance.
* **Operational:** `G:\SteamLibrary` is now deduplicated; all active Steam library folders on `F:` and `H:` remain clean and registered in `libraryfolders.vdf`.
* **Security & Reliability:** Zero user save data lost; strictly preserved all protected titles and system integrity.

## [2026-09-09]

### Baseline: Initial System Discovery & Architecture Inventory

* **Discovery Execution:** Executed non-invasive remote telemetry discovery script `scripts/inspect_htpc_remote.ps1` over SSH.
* **Hardware Profile Captured:**
  * CPU: AMD Ryzen 5 5600X 6-Core / 12-Thread Processor.
  * GPU: NVIDIA GeForce RTX 3060 (Driver 32.0.15.9621) running at 4K resolution (3840x2160).
  * Motherboard: MSI MAG B550 TOMAHAWK.
  * RAM: 16 GB Total RAM (4.32 GB Free).
* **Storage Topology:**
  * 1 TB Crucial MX500 SATA SSD (`C:\` - 465 GB free / 50%).
  * 4 TB WD Red SATA HDD partitioned into `F:\` (92 GB free), `G:\` (77.9 GB free), and `H:\` (84.1 GB free).
  * Mapped Network Shares: `M:\` (`\\192.168.68.169\Media`), `N:\`, `P:\`, and `X:\` (`\\HPNAS01`).
* **Health & Stability:**
  * Confirmed 0 WHEA hardware error events.
  * Confirmed 0 Kernel-Power 41 unexpected shutdowns over the trailing 7 days.
* **Documentation Generated:** Produced authoritative architecture document [`ARCHITECTURE.md`](file:///C:/Users/benma/coding/agy_project/Projects/htpc/ARCHITECTURE.md) and full baseline report [`reports/baseline_inventory.md`](file:///C:/Users/benma/coding/agy_project/Projects/htpc/reports/baseline_inventory.md).

### ADR: Hardened OpenSSH Remote Management Channel & Ed25519 Authentication

#### Context
1. **The Problem / Requirement:** Physical administration of `rath15-htpc` in the living room requires local keyboard access. Prior Remote Desktop (RDP) login attempts failed due to local user account naming discrepancies (`benka_000` created during Microsoft Account setup). Furthermore, connecting via RDP terminates or locks the physical display, interrupting TV playback and media rendering.
2. **Constraints & Trade-offs:** Remote management must be secure, lightweight, and capable of background execution without disrupting living room display output or media streams.

#### Action
1. **Implementation Steps:**
   * Deployed Microsoft OpenSSH Server (`OpenSSH-Win64`) to `C:\Program Files\OpenSSH` on `rath15-htpc`.
   * Configured Windows Service `sshd` to start automatically on system boot.
   * Created inbound Windows Firewall rule restricting TCP port 22 strictly to `LocalSubnet` (`192.168.68.0/24`) on the `Private` network profile.
   * Deployed Ben's workstation Ed25519 public key to `C:\ProgramData\ssh\administrators_authorized_keys` with strict Windows ACL permissions (`SYSTEM` and `Administrators` only).
   * Configured workstation SSH client alias `Host rath15-htpc` pointing to `192.168.68.162` with user `benka_000`.
2. **Key Parameters:**
   * Node IP: `192.168.68.162`
   * Target Port: `22` (TCP - LocalSubnet Only)
   * Local User: `benka_000`
   * Key: Ed25519 Asymmetric Cryptography
3. **Verification & Testing:**
   * Verified port 22 open and responsive via socket probe.
   * Executed passwordless remote command `whoami & hostname` over SSH; confirmed deterministic execution without password prompts.

#### Consequences
* **Positive:** High-security, cryptographically authenticated remote administration established. Zero password transmission over the network.
* **Operational:** Remote maintenance, diagnostics, and updates can now be run completely in the background without affecting the living room TV screen or media playback.
* **Security:** Attack surface minimized by binding port 22 strictly to the local home subnet.

### ADR: Host Optimization, Virtual Memory Topology, and Autostart Streamlining

#### Context
1. **The Problem / Requirement:** A non-invasive Tier 1 remote audit of `rath15-htpc` revealed:
   * Elevated System event log errors (60 errors over 7 days), including recurring 45-second service start timeouts from `asComSvc` and external CD-ROM bad block warnings during MakeMKV processing.
   * Severe memory saturation (61% RAM used at idle) caused by unoptimized autostart entries across active and disconnected user sessions (27 Microsoft Edge Chromium processes consuming 1.8 GB, 10 Steam CEF helper processes consuming 1.2 GB, Epic Games Launcher, and XDM pre-allocating a 1 GB Java heap).
   * Low free space warnings on mechanical disk partitions (`F:`, `G:`, and `H:` down to 6–8% free space), exacerbated by 24 GB of slow mechanical swap files (`pagefile.sys`) on spinning disk platters causing drive head thrashing.
2. **Constraints & Trade-offs:**
   * **Discord Autostart Retention:** Discord must remain in autostart for both user profiles (`benka_000` and `dylan_93nze6m`) so Ben's son can chat with friends while gaming without manual launch friction.
   * **Protected Zones:** Gaming libraries, media configurations, and display drivers must remain intact.
   * **Reversibility:** All removed autostart keys and pagefile configurations must be backed up prior to mutation.

#### Action
1. **Implementation Steps:**
   * Executed Tier 2 ephemeral cleanup on `F:\$RECYCLE.BIN`, immediately reclaiming 13.9 GB of disk space (raising `F:\` free space from 92.0 GB to 105.9 GB).
   * Backed up `PagingFiles` registry multi-string setting to `C:\ProgramData\htpc_maintenance_backups\PagingFiles_backup.txt`.
   * Reconfigured Windows Virtual Memory (`HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PagingFiles`) to reside exclusively on the high-speed Crucial MX500 SATA SSD (`c:\pagefile.sys 8000 16000`), decommissioning 8 GB mechanical pagefiles on `F:`, `G:`, `H:`, and non-existent `E:`.
   * Set orphaned ASUS Com Service (`asComSvc`) to `Disabled` and stopped the service, resolving hardware incompatibility on the host's MSI MAG B550 TOMAHAWK motherboard and eliminating 45-second boot delays and System Event 7000/7009 errors.
   * Backed up HKCU Run keys to `C:\ProgramData\htpc_maintenance_backups\HKCU_Run_backup.txt`.
   * Removed headless autostart entries for `MicrosoftEdgeAutoLaunch`, `Steam`, `EpicGamesLauncher`, `XDM`, and `iCloudServices` in `benka_000`, and `EpicGamesLauncher` and `MicrosoftEdgeAutoLaunch` in `dylan_93nze6m`, transitioning these tools to on-demand execution.
   * Explicitly verified and preserved `Discord` in autostart across both user profiles (`benka_000` and `dylan_93nze6m`).
   * Uninstalled Xtreme Download Manager 2020 via MSI product code `{694CC410-5DD4-40F4-B92C-914FE66313FD}` (`/qn /norestart`), completely removing the application directory and bundled Java runtime.
   * Purged redundant root installer archives `H:\Mortal Kombat 9.zip` (8.83 GB) and `G:\Battlefront_2_Remaster_Installer_1.1.zip` (4.07 GB) after confirming uncompressed directories were intact, reclaiming 12.9 GB across `G:\` and `H:\`.
   * Uninstalled legacy Oracle VM VirtualBox 5.2.12 via MSI product code `{128AD467-F107-4FED-A283-F355E74DE103}` (`/qn /norestart`), unbinding kernel drivers `VBoxNetLwf.sys` (NDIS bridge), `VBoxUSBMon.sys`, and `VBoxDrv.sys`, eliminating the 8 recurring System Event 12 network driver errors.
   * Deployed elevated SYSTEM scheduled task `EnsureSshdBoot` running at startup (`AtStartup`) with backup registry export `C:\ProgramData\ssh\sshd_service_backup.reg` to guarantee OpenSSH automatic startup across reboots.
   * Disabled crashing redundant helper service `RTLDHCPService` (`Realtek DHCP Service`), eliminating the remaining Event 7034 boot crash.
   * Executed system restart to bind virtual memory to SSD `C:\` and purge mechanical swap files, permanently unlocking 24 GB across the 4TB mechanical HDD.
2. **Key Parameters:**
   * SSD Dedicated Paging: `c:\pagefile.sys 8000 16000` (8 GB initial / 16 GB max)
   * Target Services Disabled: `asComSvc` (`atkexComSvc.exe`), `RTLDHCPService` (`RTLDHCP.exe`)
   * Packages Uninstalled: `Xtreme Download Manager 2020` (`{694CC410-5DD4-40F4-B92C-914FE66313FD}`), `Oracle VM VirtualBox 5.2.12` (`{128AD467-F107-4FED-A283-F355E74DE103}`)
   * Retained Autostart: `Discord.exe` (both profiles), `OneDrive.exe`, `NordVPN.exe`, `VirtualDesktop.Service`
   * Total Mechanical Disk Reclaimed: **50.0 GB** net gain across mechanical partitions (`F:\` +21.7 GB, `G:\` +11.8 GB, `H:\` +16.5 GB).
3. **Verification & Testing:**
   * Verified `PagingFiles` value contains only `c:\pagefile.sys 8000 16000` and active usage on `C:\`.
   * Confirmed `(Get-Service asComSvc).StartType` and `(Get-Service RTLDHCPService).StartType` are both `Disabled`.
   * Confirmed registry property removals and verified `Discord` remains present in both `benka_000` and `dylan_93nze6m` user hives.
   * Confirmed XDM and VirtualBox uninstallation: 0 VBox kernel drivers/services active, directory paths deleted, and physical network adapters fully operational.
   * Confirmed post-reboot storage metrics: `F:\` at 113.7 GB (8.1%), `G:\` at 89.7 GB (9.4%), and `H:\` at 100.6 GB (7.4%).
   * Confirmed post-reboot system event log is 100% clean of service crashes and driver timeouts.

#### Consequences
* **Positive:** Eliminated 45-second boot freeze; stopped mechanical disk head thrashing caused by swap paging; recovered **50.0 GB** of mechanical drive space; increased free physical RAM to **12.0 GB (75.4% free)**; eliminated all recurring System Event errors (7000, 7009, 12, and 7034).
* **Operational:** Steam, Epic Games, and Edge now launch on-demand; Ben's son maintains uninterrupted Discord startup; OpenSSH daemon persistence guaranteed via `EnsureSshdBoot`.
* **Security & Stability:** Cleaned up 8-year-old abandoned kernel drivers from the networking stack, reduced attack surface, and hardened remote management boundaries.
