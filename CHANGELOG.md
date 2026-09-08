# Changelog

All notable changes, architectural decisions, and maintenance operations for this workstation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-09-08]

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
