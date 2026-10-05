# ADR-0004: Disable Browser Background Pre-Launchers for Memory Reclamation

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Google Chrome, Microsoft Edge, and Microsoft Copilot automatically launch at Windows boot with `--no-startup-window`, pre-allocating memory and retaining dozens of background Chromium worker processes in RAM even when windows are closed. Across both engines, active memory consumption exceeded 6.1 GB, causing severe memory pressure (88% utilization) on a 16 GB workstation.
2. **Constraints & Trade-offs:** Zero impact to bookmarks, history, user profiles, or browser extensions. Zero impact to standalone cloud sync clients (Google Drive for Desktop). The decision must remain an easily reversible "two-way door" if background pre-warming is ever desired.

## Action
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

## Consequences
* **Positive:** Prevents duplicate Chromium engines from pre-allocating gigabytes of RAM on boot. Closing browser windows now properly releases memory back to Windows for developer workloads and AI orchestration.
* **Operational:** Browser launch on cold boot takes ~1 second from NVMe storage instead of opening instantaneously from pre-warmed RAM. Background web push notifications only trigger while browser windows are open.
* **Security:** Reduced background process surface area by eliminating persistent, unprompted browser daemons.
