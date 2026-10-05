# ADR-0003: Transition Game Launchers to On-Demand Execution

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The host machine boots multiple heavy game launchers (EA Desktop `EALauncher.exe` and GOG Galaxy `GalaxyClient.exe`) on login via `HKCU Run`, causing unnecessary boot latency, idle RAM consumption, and recurring network polling on a primary development machine.
2. **Constraints & Trade-offs:** The applications must remain fully installed, functional, and intact. Game library launching must remain completely accessible when deliberately invoked by the user.

## Action
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

## Consequences
* **Positive:** Reduced Windows startup time, eliminated idle memory and CPU overhead from dormant game client updaters, freed resources for developer workloads.
* **Operational:** Playing games on EA or GOG now requires launching the respective client manually from the Start Menu or desktop shortcut instead of starting automatically at login.
* **Security:** Reduced attack surface by preventing network-connected background daemons from running automatically with user session privileges.
